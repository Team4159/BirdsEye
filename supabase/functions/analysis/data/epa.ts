import stats from "@stdlib/stats-base-dists-normal";
import { DBClient } from "../supabase/supabase.ts";
import {
  avg,
  Normal as NormalType,
  normalDifference,
  normalSum,
  sigmoid,
  std,
} from "../util.ts";
import {
  BatchFetchFilter,
  batchFetchRobotInMatches,
  batchFetchRobotScores,
} from "./batchfetch.ts";
import dynamicMap from "./dynamic/dynamic.ts";
import { MatchInfo, tba } from "./tba.ts";

export type MatchIdentifier = {
  season: keyof typeof dynamicMap;
  event: string;
  match: string;
};

export const categorizers = {
  gameperiod: (_: keyof typeof dynamicMap) => (objective: string) =>
    objective.split("_")[0],
  gameelements: (season: keyof typeof dynamicMap) => (objective: string) => {
    const objpts = objective.split("_");
    return dynamicMap[season].scoringelements.find((e) => objpts.includes(e)) ??
      null;
  },
  total: (_: keyof typeof dynamicMap) => (_: string) => "",
};

export function isCategorizer(x: string): x is keyof typeof categorizers {
  return x in categorizers;
}

/**
 * Finds the categorizer that would produce this category.
 */
export function categorizerSupertype(
  season: keyof typeof dynamicMap,
  category: string,
): Exclude<keyof typeof categorizers, "total"> | undefined {
  if (dynamicMap[season].scoringelements.includes(category)) {
    return "gameelements";
  }
  if (
    Object.keys(dynamicMap[season].scoringpoints).map(
      categorizers.gameperiod(season),
    ).includes(category)
  ) return "gameperiod";
  return;
}

/**
 * Estimated Points Added per Category
 * @returns Map of Category to Normal Distribution
 */
async function epaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: keyof typeof categorizers,
): Promise<{ [key: string]: NormalType } | undefined> {
  const scores = await batchFetchRobotScores(
    supabase,
    filter,
    categorizers[categorizer](filter.season),
  );
  if (scores.size === 0) return;
  return Object.fromEntries(
    scores.entries().map((
      [cat, catscores],
    ) => [cat, new stats.Normal(avg(catscores), std(catscores))]),
  );
}

/**
 * Estimated Ranking Points Added
 * @returns Map of Ranking Point to Probability Normal Distribution
 */
async function erpaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
): Promise<{ [key: string]: NormalType }> {
  const rims = (await batchFetchRobotInMatches(supabase, filter))
    .values();
  const rps: { [key: string]: number[] } = {};

  for (const rim of rims) {
    for (
      const [rpname, rpcriteria] of Object.entries(
        dynamicMap[filter.season].rankingpoints,
      )
    ) {
      rps[rpname] ??= [];
      rps[rpname].push(rpcriteria(rim));
    }
  }

  return Object.fromEntries(
    Object.entries(rps).map((
      [cat, vals],
    ) => [cat, new stats.Normal(avg(vals), std(vals))]),
  );
}

/**
 * Defensive Heuristic Rating
 * @returns Robot's event DHR (higher is better)
 */
async function dhrRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
): Promise<number | undefined> {
  const rims = await batchFetchRobotInMatches(supabase, filter);
  if (rims.size === 0) return;
  const dhrs: number[] = [];

  type DHRValidRIM = {
    comments_agility: number;
    comments_fouls: number;
    comments_defense: number;
  };
  function isDHRValid(rim: { [key: string]: number }): rim is DHRValidRIM {
    return Number.isFinite(rim["comments_agility"]) &&
      Number.isInteger(rim["comments_fouls"]) &&
      (rim["comments_defense"] === 0 || rim["comments_defense"] === 1);
  }

  for (
    const rim of rims
      .values()
  ) {
    if (!isDHRValid(rim)) {
      return Promise.reject(
        "Unsupported Schema: RobotInMatch not processable by DHR.",
      );
    }
    dhrs.push(
      rim.comments_agility /
        ((5 * rim.comments_fouls + 1) *
          (rim.comments_defense ? 0.7 : 1)),
    );
  }

  return avg(dhrs);
}

function aggRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: keyof typeof categorizers,
): Promise<{ [key: string]: NormalType } | undefined>;
function aggRobot(supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: "dhr"
): Promise<{"dhr": number} | undefined>;
async function aggRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: keyof typeof categorizers | "dhr",
): Promise<{ [key: string]: NormalType | number } | undefined> {
  if (categorizer === "dhr") {
    const dhr = await dhrRobot(supabase, filter);
    return dhr === undefined ? undefined : { "dhr": dhr };
  }
  return epaRobot(supabase, filter, categorizer);
}

type AlliancePrediction = {
  winChance: number;
  points: number;
  rp: { [key: string]: number };
  teams: string[];
};
async function epaMatchup(
  supabase: DBClient,
  season: keyof typeof dynamicMap,
  blue: string[],
  red: string[],
  limit: number,
): Promise<{
  blue: Partial<AlliancePrediction>;
  red: Partial<AlliancePrediction>;
  isMissingData: true;
} | {
  blue: AlliancePrediction,
  red: AlliancePrediction,
  isMisssingData: false;
}> {
  let isMissingData: boolean = false;
  async function epaAlliance(teams: string[]): Promise<NormalType | undefined> {
    const epas = (await Promise.all(
      teams.map((robot) => epaRobot(supabase, { season, robot, limit }, "total")),
    )).filter((n): n is NonNullable<typeof n> => {
      if (n !== null) return true;
      isMissingData = true;
      return false;
    }).map((epa) => epa[""]);

    if (epas.length === 0) return;
    return normalSum(...epas);
  }
  async function erpaAlliance(teams: string[]): Promise<{ [k: string]: number; } | undefined> {
    const output: { [key: string]: number } = {};
    for (
      const erpaTeam of await Promise.all(
        teams.map((robot) => erpaRobot(supabase, { season, robot, limit })),
      )
    ) {
      for (const [rpname, rpvalue] of Object.entries(erpaTeam)) {
        output[rpname] ??= 0;
        output[rpname] += rpvalue.mean;
      }
    }
    const ents = Object.entries(output);
    if (ents.length === 0) return;
    return Object.fromEntries(
      ents.map((
        [rpname, rptotal],
      ) => [rpname, sigmoid(rptotal)]),
    );
  }

  const [blueDist, redDist, blueRPDist, redRPDist] = await Promise.all([
    epaAlliance(blue),
    epaAlliance(red),
    erpaAlliance(blue),
    erpaAlliance(red),
  ]);
  const diff = blueDist === undefined || redDist === undefined
    ? undefined
    : normalDifference(blueDist, redDist); // advantage of blue over red
  const redProb = diff?.cdf(0); // probability that the advantage is <= 0

  return {
    blue: {
      winChance: redProb === undefined ? undefined : 1 - redProb,
      points: blueDist?.mean,
      rp: blueRPDist,
      teams: blue,
    },
    red: {
      winChance: redProb,
      points: redDist?.mean,
      rp: redRPDist,
      teams: red,
    },
    // deno-lint-ignore no-explicit-any
    isMissingData: isMissingData as any,
  };
}

async function epaMatch(
  supabase: DBClient,
  match: MatchIdentifier,
  limit: number,
) {
  const tbadata: MatchInfo = await tba.getMatch(match);

  // Remove the 'frc' prefixes
  const blue = tbadata.alliances.blue.team_keys.map((t) => t.slice(3));
  const red = tbadata.alliances.red.team_keys.map((t) => t.slice(3));

  return epaMatchup(supabase, match.season, blue, red, limit);
}

export { aggRobot, epaMatch, erpaRobot };
