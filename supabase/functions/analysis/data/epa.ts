import stats from "@stdlib/stats-base-dists-normal";
import { DBClient } from "../supabase/supabase.ts";
import { avg, normalDifference, normalSum, Normal as NormalType, sigmoid, std } from "../util.ts";
import { BatchFetchFilter, batchFetchRobotInMatch, batchFetchRobotScores } from "./batchfetch.ts";
import dynamicMap from "./dynamic/dynamic.ts";
import { MatchInfo, tba } from "./tba.ts";

export type MatchIdentifier = {
  season: keyof typeof dynamicMap;
  event: string;
  match: string;
};

const categorizers = {
  gameperiod: (_: keyof typeof dynamicMap) => (objective: string) =>
    objective.split("_")[0],
  gameelements: (season: keyof typeof dynamicMap) => (objective: string) => {
    const objpts = objective.split("_");
    return dynamicMap[season].scoringelements.find((e) => objpts.includes(e)) ??
      null;
  },
  total: null,
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
 * Estimated Points Added
 * @returns Normal distribution of robot's EPA
 */
async function epaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  category: "total",
): Promise<NormalType | null>;
/**
 * Estimated Points Added per Category
 * @returns Map of Category to Normal Distribution
 */
async function epaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  category: Exclude<keyof typeof categorizers, "total">,
): Promise<{ [key: string]: NormalType } | null>;
async function epaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  category: keyof typeof categorizers = "total",
): Promise<NormalType | { [key: string]: NormalType } | null> {
  const categorizer = categorizers[category] === null
    ? null
    : categorizers[category](filter.season);
  if (categorizer) {
    const scores = await batchFetchRobotScores(
      supabase,
      filter,
      categorizer,
    );
    if (scores.size === 0) return null;
    return Object.fromEntries(
      scores.entries().map((
        [cat, catscores],
      ) => [cat, new stats.Normal(avg(catscores), std(catscores))]),
    );
  } else {
    const scores = (await batchFetchRobotScores(supabase, filter))
      .values().toArray();
    if (scores.length === 0) return null;
    return new stats.Normal(avg(scores), std(scores));
  }
}

/**
 * Estimated Ranking Points Added
 * @returns Map of Ranking Point to Probability Normal Distribution
 */
async function erpaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
): Promise<{ [k: string]: NormalType }> {
  const rims = (await batchFetchRobotInMatch(supabase, filter))
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
): Promise<number | null> {
  const rims = await batchFetchRobotInMatch(supabase, filter);
  if (rims.size === 0) return null;
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
  mostRecentN: number,
): Promise<{
  blue: Partial<AlliancePrediction>;
  red: Partial<AlliancePrediction>;
  isMissingData: boolean;
}> {
  let isMissingData: boolean = false;
  async function epaAlliance(teams: string[]) {
    const epas = (await Promise.all(
        teams.map((team) =>
          epaRobot(supabase, { season, team, mostRecentN }, "total")
        ),
      )).filter((n): n is NonNullable<typeof n> => {
          if (n !== null) return true;
          isMissingData = true;
          return false;
        })
      ;
      if (epas.length === 0) return null;
    return normalSum(
      ...epas)
  }
  async function erpaAlliance(teams: string[]) {
    const output: { [key: string]: number } = {};
    for (
      const erpaTeam of await Promise.all(
        teams.map((team) => erpaRobot(supabase, { season, team, mostRecentN })),
      )
    ) {
      for (const [rpname, rpvalue] of Object.entries(erpaTeam)) {
        output[rpname] ??= 0;
        output[rpname] += rpvalue.mean;
      }
    }
    const ents = Object.entries(output);
    if (ents.length === 0) return null;
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
  const diff = blueDist === null || redDist === null ? null : normalDifference(blueDist, redDist); // advantage of blue over red
  const redProb = diff?.cdf(0); // probability that the advantage is <= 0

  return {
    blue: {
      winChance: redProb === undefined ? undefined : 1 - redProb,
      points: blueDist?.mean,
      rp: blueRPDist ?? undefined,
      teams: blue,
    },
    red: {
      winChance: redProb,
      points: redDist?.mean,
      rp: redRPDist ?? undefined,
      teams: red,
    },
    isMissingData,
  };
}

async function epaMatch(
  supabase: DBClient,
  match: MatchIdentifier,
  mostRecentN: number,
) {
  const tbadata: MatchInfo = await tba.getMatch(match);

  // Remove the 'frc' prefixes
  const blue = tbadata.alliances.blue.team_keys.map((t) => t.slice(3));
  const red = tbadata.alliances.red.team_keys.map((t) => t.slice(3));

  return epaMatchup(supabase, match.season, blue, red, mostRecentN);
}

export { dhrRobot, epaMatch, epaRobot, erpaRobot };
