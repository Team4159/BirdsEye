import { average } from "simple-statistics";
import { DBClient } from "../supabase/supabase.ts";
import { Normal, teamworkSum } from "../math.ts";
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
      undefined;
  },
  total: (_: keyof typeof dynamicMap) => (_: string) => "",
};

export function isCategorizer(x: string): x is keyof typeof categorizers {
  return x in categorizers;
}

/**
 * Estimated Points Added per Category
 * @returns Map of Category to Normal Distribution
 */
async function epaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: keyof typeof categorizers,
): Promise<{ [key: string]: Normal } | undefined> {
  const scores = await batchFetchRobotScores(
    supabase,
    filter,
    categorizers[categorizer](filter.season),
  );
  if (scores.size === 0) return;
  return Object.fromEntries(
    scores.entries().map((
      [cat, catscores],
    ) => [cat, new Normal(catscores)]),
  );
}

/**
 * Estimated Ranking Points Added
 * @returns Map of Ranking Point to Probability Normal Distribution
 */
async function erpaRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
): Promise<{ [key: string]: Normal }> {
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
    ) => [cat, new Normal(vals)]),
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
    comments_agility: number; // [0, 1]
    comments_fouls: number; // [0, infinity)
    comments_defense: number; // [0, 1]
  };
  function isDHRValid(rim: { [key: string]: number }): rim is DHRValidRIM {
    return Number.isFinite(rim["comments_agility"]) &&
      Number.isFinite(rim["comments_fouls"]) &&
      Number.isFinite(rim["comments_defense"]);
  }

  for (
    const rim of rims
      .values()
  ) {
    if (!isDHRValid(rim)) {
      throw new Error(
        "Unsupported Schema: RobotInMatch not processable by DHR.",
      );
    }
    dhrs.push(
      (rim.comments_defense / 2 + 1) *
        (rim.comments_agility / (5 * rim.comments_fouls + 1)),
    );
  }

  return average(dhrs);
}

function aggRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: keyof typeof categorizers,
): Promise<{ [key: string]: Normal } | undefined>;
function aggRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: "dhr",
): Promise<{ "dhr": number } | undefined>;
function aggRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: "total",
): Promise<{ "": Normal } | undefined>;
async function aggRobot(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: keyof typeof categorizers | "dhr",
): Promise<{ [key: string]: Normal | number } | undefined> {
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
export type EPAMatchupResult = 
{
  blue: Partial<AlliancePrediction>;
  red: Partial<AlliancePrediction>;
  isMissingData: true;
} | {
  blue: AlliancePrediction;
  red: AlliancePrediction;
  isMissingData: false;
};
async function epaMatchup(
  supabase: DBClient,
  season: keyof typeof dynamicMap,
  blue: string[],
  red: string[],
  limit: number,
): Promise<EPAMatchupResult> {
  let isMissingData: boolean = false;
  async function epaAlliance(teams: string[]): Promise<Normal | undefined> {
    const epas = (await Promise.all(
      teams.map((robot) =>
        epaRobot(supabase, { season, robot, limit }, "total")
      ),
    )).map((epa) => epa === undefined ? undefined : epa[""]).filter(
      (n): n is NonNullable<typeof n> => {
        if (n !== undefined) return true;
        isMissingData = true;
        return false;
      },
    );

    if (epas.length === 0) return;
    return Normal.sum(...epas);
  }
  async function erpaAlliance(
    teams: string[],
  ): Promise<{ [k: string]: number } | undefined> {
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
      ) => [rpname, teamworkSum(rptotal)]),
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
    : Normal.difference(blueDist, redDist); // advantage of blue over red
  const redProb = diff?.cdf(0); // probability that the advantage is <= 0

  return isMissingData
    ? {
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
      isMissingData: isMissingData,
    }
    : {
      blue: {
        winChance: 1 - redProb!,
        points: blueDist!.mean,
        rp: blueRPDist!,
        teams: blue,
      },
      red: {
        winChance: redProb!,
        points: redDist!.mean,
        rp: redRPDist!,
        teams: red,
      },
      isMissingData: isMissingData,
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

export { aggRobot, epaMatch, epaMatchup, erpaRobot };
