// deno-lint-ignore-file no-explicit-any
import { DBClient } from "../supabase/supabase.ts";
import { MatchInfo, tba } from "../thebluealliance/tba.ts";
import dynamicMap from "./dynamic/dynamic.ts";
import type { MatchIdentifier } from "./epa.ts";

/**
 * `{ objective: scorecount }[]`
 */
type RobotInMatch = { [key: string]: number };

type RobotInMatchIdentifier = MatchIdentifier & { team: string };

function fuseData(
  season: keyof typeof dynamicMap,
  dbdata: { [key: string]: number },
  tbadata: MatchInfo,
  team: string,
): RobotInMatch {
  return dynamicMap[season].fuseData(dbdata, team, tbadata);
}

/**
 * Fetches records from the database and corresponding data from TBA, then fuses them.
 * @param supabase {@link DBClient}
 * @param filter parameters to select information
 * @returns Map of {@link RobotInMatchIdentifier} to {@link RobotInMatch}
 */
async function batchFetchRobotInMatch(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    event?: string;
    team?: string;
  } | {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
): Promise<Map<RobotInMatchIdentifier, RobotInMatch>> {
  if (!("mostRecentN" in filter) && (!filter.event && !filter.team)) {
    throw new Error(
      "Illegal Arguments: must provide filter.event and/or filter.team.",
    );
  }

  // Create a query to get the average of each scoreable column.
  const matchdataquery = dynamicMap[filter.season].dbcolumns
    .map((columnname) => `${columnname}:${columnname}.avg()`).join(", ");
  let query = supabase
    .from(dynamicMap[filter.season].dbtable as any)
    .select(matchdataquery + " , match_scouting!inner(event, match, team)");

  // Apply filters
  if ("mostRecentN" in filter) {
    query = query.eq("match_scouting.team", filter.team);
  } else {
    if (filter.event) query = query.eq("match_scouting.event", filter.event);
    if (filter.team) query = query.eq("match_scouting.team", filter.team);
  }

  const { data: dbdataraw, error: error } = await query;

  if (dbdataraw?.length == 0) { // If dbdata is null or empty
    return new Map();
  }
  if (error) {
    console.error(error);
    throw error;
  }

  const dbdata = Object.fromEntries(dbdataraw.map(
    (
      entry: any,
    ) => [
      `${filter.season}${entry["match_scouting"].event}_${
        entry["match_scouting"].match
      }`,
      entry,
    ],
  ));

  let tbadataraw: MatchInfo[] = await tba.get(filter);
  if ("mostRecentN" in filter) {
    tbadataraw = tbadataraw
      .filter((m) => m.key in dbdata)
      .sort((a, b) => (b.actual_time || b.time) - (a.actual_time || a.time))
      .slice(0, filter.mostRecentN);
  }

  const tbadata: { [key: string]: MatchInfo } = Object.fromEntries(
    tbadataraw.map((tbamatch) => [tbamatch.key, tbamatch]),
  );

  const output = new Map<RobotInMatchIdentifier, RobotInMatch>();
  // Iterate through each row from the database and fuse the data.
  for (const [matchkey, entry] of Object.entries(dbdata)) {
    if (!(matchkey in tbadata)) {
      if (!("mostRecentN" in filter)) {
        console.warn(`Missing referencing TBA data for ${matchkey}`);
      }
      continue;
    }

    const identifier = {
      season: filter.season,
      event: entry.match_scouting.event,
      match: entry.match_scouting.match,
      team: entry.match_scouting.team,
    };
    delete entry.match_scouting;
    output.set(
      identifier,
      fuseData(
        identifier.season,
        entry,
        tbadata[matchkey],
        identifier.team,
      ),
    );
  }
  return output;
}

/**
 * Calculates the score a robot earned in a match.
 * @param identifier {@link RobotInMatchIdentifier}
 * @param data The robot's objective counts
 * @returns The robot's points-added this match
 */
function scoreRobotInMatch(
  identifier: RobotInMatchIdentifier,
  data: RobotInMatch,
): number;
/**
 * Calculates the score a robot earned in a match in each category.
 * @param identifier {@link RobotInMatchIdentifier}
 * @param data The robot's objective counts
 * @param categorizer function to aggregate types of objectives
 * @returns Map of category to points-added
 */
function scoreRobotInMatch(
  identifier: RobotInMatchIdentifier,
  data: RobotInMatch,
  categorizer: (objective: string) => string | null,
): { [key: string]: number };
function scoreRobotInMatch(
  identifier: RobotInMatchIdentifier,
  data: RobotInMatch,
  categorizer?: (objective: string) => string | null,
): { [key: string]: number } | number {
  const scores: { [key: string]: number } = {};
  if (!categorizer) scores[""] = 0;

  const scoringpoints = dynamicMap[identifier.season].scoringpoints;
  for (const [objective, scorecount] of Object.entries(data)) {
    if (!(objective in scoringpoints)) continue;
    const category = categorizer ? categorizer(objective) : "";
    if (category === null) continue; // If the categorizer returns null, ignore this objective

    const score = scoringpoints[objective] * scorecount;
    scores[category] ??= 0;
    scores[category] += score;
  }

  return categorizer ? scores : scores[""];
}

/**
 * Calculates score earned per RobotInMatch
 * @param supabase {@link DBClient}
 * @param filter parameters to select information
 * @returns Map of {@link RobotInMatchIdentifier} to score
 */
function batchFetchRobotScores(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    event?: string;
    team?: string;
  } | {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
): Promise<Map<RobotInMatchIdentifier, number>>;
/**
 * Aggregates score earned in various objectives
 * @param supabase {@link DBClient}
 * @param filter parameters to select information
 * @param categorizer function to aggregate types of objectives
 * @returns Map of category to score[]
 */
function batchFetchRobotScores(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    event?: string;
    team?: string;
  } | {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
  categorizer: (objective: string) => string | null,
): Promise<Map<string, number[]>>;
async function batchFetchRobotScores(
  supabase: DBClient,
  filter: {
    season: keyof typeof dynamicMap;
    event?: string;
    team?: string;
  } | {
    season: keyof typeof dynamicMap;
    team: string;
    mostRecentN: number;
  },
  categorizer?: (objective: string) => string | null,
): Promise<Map<RobotInMatchIdentifier | string, number | number[]>> {
  const scores: Map<RobotInMatchIdentifier | string, number | number[]> =
    new Map();

  const matches = await batchFetchRobotInMatch(supabase, filter);
  for (const [key, match] of matches) {
    if (categorizer) {
      for (
        const [category, score] of Object.entries(
          scoreRobotInMatch(key, match, categorizer),
        )
      ) {
        if (!scores.has(category)) scores.set(category, []);
        (scores.get(category)! as number[]).push(score);
      }
    } else {
      scores.set(key, scoreRobotInMatch(key, match));
    }
  }

  return scores;
}

function zipCountsAndScores(id: RobotInMatchIdentifier, rim: RobotInMatch) {
  const scoringpoints = dynamicMap[id.season].scoringpoints;
  return Object.fromEntries(
    Object.entries(rim).map((
      [objective, count],
    ) => [objective, { count, score: scoringpoints[objective] * count }]),
  );
}

export { batchFetchRobotInMatch, batchFetchRobotScores, zipCountsAndScores };
