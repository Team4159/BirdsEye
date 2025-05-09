import stats from "@stdlib/stats-base-dists-normal";
import { DBClient } from "../supabase/supabase.ts";
import { MatchInfo, tba } from "../thebluealliance/tba.ts";
import { avg, normalDifference, normalSum, Normal as NormalType, sigmoid, std } from "../util.ts";
import { batchFetchRobotInMatch, batchFetchRobotScores } from "./batchfetch.ts";
import dynamicMap from "./dynamic/dynamic.ts";

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
  filter: {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
  category: "total",
): Promise<NormalType>;
/**
 * Estimated Points Added per Category
 * @returns Map of Category to Normal Distribution
 */
async function epaRobot(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
  category: Exclude<keyof typeof categorizers, "total">,
): Promise<{ [key: string]: NormalType }>;
async function epaRobot(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
  category: keyof typeof categorizers = "total",
): Promise<NormalType | { [key: string]: NormalType }> {
  const categorizer = categorizers[category] === null
    ? null
    : categorizers[category](filter.season);
  if (categorizer) {
    const scores = (await batchFetchRobotScores(
      supabase,
      filter,
      categorizer,
    )).entries();
    return Object.fromEntries(
      scores.map((
        [cat, scores],
      ) => [cat, new stats.Normal(avg(scores), std(scores))]),
    );
  } else {
    const scores = (await batchFetchRobotScores(supabase, filter))
      .values().toArray();
    return new stats.Normal(avg(scores), std(scores));
  }
}

/**
 * Estimated Ranking Points Added
 * @returns Map of Ranking Point to Probability Normal Distribution
 */
async function erpaRobot(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
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
  filter: {
    season: keyof typeof dynamicMap;
    event: string;
    team: string;
  },
): Promise<number> {
  const rims = (await batchFetchRobotInMatch(supabase, filter))
    .values();
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

  for (const rim of rims) {
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
  blue: AlliancePrediction;
  red: AlliancePrediction;
}> {
  async function epaAlliance(teams: string[]) {
    return normalSum(
      ...await Promise.all(
        teams.map((team) =>
          epaRobot(supabase, { season, team, mostRecentN }, "total")
        ),
      ),
    );
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
    return Object.fromEntries(
      Object.entries(output).map((
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
  const diff = normalDifference(blueDist, redDist); // advantage of blue over red
  const redProb = diff.cdf(0); // probability that the advantage is <= 0

  return {
    blue: {
      winChance: 1 - redProb,
      points: blueDist.mean,
      rp: blueRPDist,
      teams: blue,
    },
    red: {
      winChance: redProb,
      points: redDist.mean,
      rp: redRPDist,
      teams: red,
    },
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
