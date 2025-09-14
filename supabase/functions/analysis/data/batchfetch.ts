// deno-lint-ignore-file no-explicit-any
import { DBClient } from "../supabase/supabase.ts";
import { MatchInfo, tba } from "./tba.ts";
import dynamicMap from "./dynamic/dynamic.ts";
import type { MatchIdentifier } from "./epa.ts";

/**
 * `{ objective: scorecount }`
 */
type RobotInMatch = { [key: string]: number };

type RobotInMatchIdentifier = MatchIdentifier & { robot: string };

function fuseData(
  season: keyof typeof dynamicMap,
  dbdata: { [key: string]: number },
  tbadata: MatchInfo,
  robot: string,
): RobotInMatch {
  return dynamicMap[season].fuseData(dbdata, robot, tbadata);
}

async function fetchRobotInMatch(
  supabase: DBClient,
  identifier: RobotInMatchIdentifier,
): Promise<RobotInMatch | undefined> {
  // Create a query to get the average of each scoreable column.
  const matchdataquery = dynamicMap[identifier.season].dbcolumns
    .map((columnname) => `${columnname}:${columnname}.avg()`).join(", ");
  const { data: dbdata, error: error } = await supabase
    .from(dynamicMap[identifier.season]!.dbtable as any)
    .select(
      matchdataquery + ", match_scouting!inner(season, event, match, team)",
    )
    .eq("match_scouting.event", identifier.event)
    .eq("match_scouting.match", identifier.match)
    .eq("match_scouting.team", identifier.robot)
    .maybeSingle();

  if (error) {
    console.error(error);
    throw error;
  }
  if (dbdata === null) return;

  const entry = dbdata as any;
  const tbadata: MatchInfo = (await tba.getMatches(identifier))[0]!;

  delete entry.match_scouting;
  return fuseData(
    identifier.season,
    entry,
    tbadata,
    identifier.robot,
  );
}

type BatchFetchFilter = {
  season: keyof typeof dynamicMap;
  event?: string;
  robot?: string;
  limit?: number;
};
/**
 * Fetches records from the database and corresponding data from TBA, then fuses them.
 * @param supabase {@link DBClient}
 * @param filter parameters to select information
 * @returns Map of {@link RobotInMatchIdentifier} to {@link RobotInMatch}
 */
async function batchFetchRobotInMatches(
  supabase: DBClient,
  filter: BatchFetchFilter,
): Promise<Map<RobotInMatchIdentifier, RobotInMatch>> {
  if (!filter.event && !filter.robot) {
    throw new Error(
      "Illegal Arguments: must provide filter.event and/or filter.robot.",
    );
  }

  // Create a query to get the average of each scoreable column.
  const matchdataquery = dynamicMap[filter.season].dbcolumns
    .map((columnname) => `${columnname}:${columnname}.avg()`).join(", ");
  let query = supabase
    .from(dynamicMap[filter.season].dbtable as any)
    .select(
      matchdataquery + " , match_scouting!inner(season, event, match, team)",
    );

  // Apply filters
  if (filter.event !== undefined) {
    query = query.eq("match_scouting.event", filter.event);
  }
  if (filter.robot !== undefined) {
    query = query.eq("match_scouting.team", filter.robot);
  }

  const { data: dbdata, error: error } = await query;

  if (error) {
    console.error(error);
    throw error;
  }
  if (dbdata?.length == 0) { // If dbdata is null or empty
    return new Map();
  }

  let tbadataraw: readonly MatchInfo[] = await tba.getMatches(filter);
  if ("limit" in filter) {
    const dbmatches = new Set(
      dbdata.map((entry: any) =>
        `${filter.season}${entry["match_scouting"].event}_${
          entry["match_scouting"].match
        }`
      ),
    );
    tbadataraw = tbadataraw
      .filter((m) => dbmatches.has(m.key))
      .sort((a, b) => (b.actual_time || b.time) - (a.actual_time || a.time))
      .slice(0, filter.limit);
  }

  const tbadata: { [key: string]: MatchInfo } = Object.fromEntries(
    tbadataraw.map((tbamatch) => [tbamatch.key, tbamatch]),
  );

  const output = new Map<RobotInMatchIdentifier, RobotInMatch>();
  // Iterate through each row from the database and fuse the data.
  for (const entry of dbdata as any[]) {
    const matchKey = `${filter.season}${entry["match_scouting"].event}_${
      entry["match_scouting"].match
    }`;
    if (!(matchKey in tbadata)) {
      if (!("limit" in filter)) {
        console.warn(`Missing referencing TBA data for ${matchKey}`);
      }
      continue;
    }

    const identifier = {
      season: filter.season,
      event: entry.match_scouting.event,
      match: entry.match_scouting.match,
      robot: entry.match_scouting.team,
    };
    delete entry.match_scouting;
    output.set(
      identifier,
      fuseData(
        identifier.season,
        entry,
        tbadata[matchKey]!,
        identifier.robot,
      ),
    );
  }
  return output;
}

/**
 * Calculates the score a robot earned in a match.
 * @param identifier {@link RobotInMatchIdentifier}
 * @param data The robot's objective counts
 * @returns Map of objective to score[]
 */
function scoreRobotInMatch(
  identifier: RobotInMatchIdentifier,
  data: RobotInMatch,
  categorizer?: undefined,
): { [key: string]: number };
/**
 * Calculates the score a robot earned in a match in each category.
 * @param identifier {@link RobotInMatchIdentifier}
 * @param data The robot's objective counts
 * @param categorizer function to aggregate types of objectives
 * @returns Map of category to score[]
 */
function scoreRobotInMatch(
  identifier: RobotInMatchIdentifier,
  data: RobotInMatch,
  categorizer: (objective: string) => string | undefined,
): { [key: string]: number };
function scoreRobotInMatch(
  identifier: RobotInMatchIdentifier,
  data: RobotInMatch,
  categorizer?: (objective: string) => string | undefined,
): { [key: string]: number } {
  const scores: { [key: string]: number } = {};

  const scoringpoints = dynamicMap[identifier.season].scoringpoints;
  for (const [objective, scorecount] of Object.entries(data)) {
    if (!(objective in scoringpoints)) continue; // if this objective (e.g. comments_agility) isn't worth points, ignore
    const category = categorizer ? categorizer(objective) : objective; // if there is no categorizer, dont categorize
    if (category === undefined) continue; // If the categorizer returns null, ignore this objective

    const score = scoringpoints[objective as keyof typeof scoringpoints] * scorecount;
    scores[category] ??= 0;
    scores[category] += score;
  }

  return scores;
}

/**
 * @param supabase Database Client
 * @param identifier RobotInMatch to fetch
 * @param categorizer Function to sort scores into bins
 * @returns Map of category to score for a given RobotInMatch, undefined when no data is found
 */
async function fetchRobotScore(
  supabase: DBClient,
  identifier: RobotInMatchIdentifier,
  categorizer?: (objective: string) => string | undefined,
): Promise<{ [key: string]: number } | undefined> {
  const match = await fetchRobotInMatch(supabase, identifier);
  if (match === undefined) return;
  return categorizer === undefined
    ? scoreRobotInMatch(identifier, match, categorizer)
    : scoreRobotInMatch(identifier, match, categorizer);
}

/**
 * Calculates score earned per RobotInMatch
 * @param supabase {@link DBClient}
 * @param filter parameters to select information
 * @returns Map of objective to score[]
 */
function batchFetchRobotScores(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer?: undefined,
): Promise<Map<string, number[]>>;
/**
 * Aggregates score earned in various objectives
 * @param supabase {@link DBClient}
 * @param filter parameters to select information
 * @param categorizer function to aggregate types of objectives
 * @returns Map of category to score[]
 */
function batchFetchRobotScores(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer: (objective: string) => string | undefined,
): Promise<Map<string, number[]>>;
async function batchFetchRobotScores(
  supabase: DBClient,
  filter: BatchFetchFilter,
  categorizer?: (objective: string) => string | undefined,
): Promise<Map<string, number[]>> {
  const scores: Map<string, number[]> = new Map();

  const matches = await batchFetchRobotInMatches(supabase, filter);
  for (const [key, match] of matches) {
    for (
      const [category, score] of Object.entries(
        categorizer === undefined
          ? scoreRobotInMatch(key, match, categorizer)
          : scoreRobotInMatch(key, match, categorizer),
      )
    ) {
      if (!scores.has(category)) scores.set(category, []);
      scores.get(category)!.push(score);
    }
  }

  return scores;
}

export { batchFetchRobotInMatches, batchFetchRobotScores, fetchRobotScore };
export type { BatchFetchFilter };
