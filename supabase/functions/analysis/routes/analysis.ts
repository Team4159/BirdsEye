// deno-lint-ignore-file ban-types
import * as oak from "@oak/oak";
import { fetchRobotScore } from "../data/batchfetch.ts";
import dynamicMap from "../data/dynamic/dynamic.ts";
import {
  aggRobot,
  categorizers,
  epaMatch,
} from "../data/epa.ts";
import { createSupaClient, DBClient } from "../supabase/supabase.ts";
import { Normal } from "../util.ts";

const router = new oak.Router({ prefix: "/analysis" });

router.get("/season/:season/event/:event/match/:match/robot/:robot", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/event/:event/match/:match", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/event/:event/robot/:robot", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/event/:event", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/robot/:robot", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));

/**
 * Selection Types
 * string = x (Specific Item)
 * string[] = [x] (List of Items)
 * asterisk = [x*] (List of All Items)
 * undefined = f(x) (Aggregate of Items)
 */
async function handler(
  params: { season: string; event?: string; match?: string; robot?: string },
  request: oak.Request,
): Promise<{ [key: string]: { [key: string]: {[key: string]: {}} | undefined } }> {
  const client = createSupaClient(request.headers.get("Authorization")!);
  const filter = await expandGlobs(client, ParameterParser.parse(params, request));
  
  if (filter === undefined) {
    throw oak.createHttpError(oak.Status.NotFound, "No Relevant Data");
  }

  return Object.fromEntries<{ [key: string]: {[key: string]: {}} | undefined }>(
    await Promise.all(
      (filter.match ?? [undefined]).map(async (
        m,
      ): Promise<[string, { [key: string]: {[key: string]: {}} | undefined }]> => [
        m ?? "",
        Object.fromEntries<{[key: string]: {}} | undefined>(
          await Promise.all(
            (filter.robot ?? [undefined]).map(async (
              r,
            ): Promise<[string, {[key: string]: {}} | undefined]> => [
              r ?? "",
              await getSingle(client, {
                ...filter,
                limit: filter.calclimit,
                match: m,
                robot: r,
              }),
            ]),
          ),
        ),
      ]),
    ),
  );
}

const globbable: ["match", "robot"] = ["match", "robot"];
/**
 * Expands all globs (`*`, gets converted to `[]`) to their real values
 * @param filter A filter, possibly including globs
 * @returns The filter, with all globs replaced with a list of values
 */
async function expandGlobs(client: DBClient, filter: Filter): Promise<Filter | undefined> {
  // Identify fields to glob
  const globs = globbable.filter((g) => filter[g]?.length === 0);
  // Return original filter if no expansion needed
  if (globs.length === 0) return filter;

  if (filter.selectlimit === undefined) throw new Error("Endpoint requires selectlimit");
  
  // Build query to database (rename "team" to "robot")
  let query = client.from("match_scouting").select("match, robot:team").eq("season", filter.season);
  if (filter.event !== undefined) query = query.eq("event", filter.event);
  if (filter.match !== undefined && filter.match.length !== 0) query = query.in("match", filter.match);
  if (filter.robot !== undefined && filter.robot.length !== 0) query = query.in("team" , filter.robot);
  query = query.order("match_code", {ascending: false}).limit(filter.selectlimit);
  
  // Execute query
  const { data } = await query;
  if (data === null || data.length === 0) return undefined;

  const out = Object.fromEntries<Set<string>>(globs.map((k) => [k, new Set<string>()]))
  for (const entry of data) {
    for (const [k, v] of Object.entries(entry)) {
      if (k in out) out[k]!.add(v);
    }
  }
  for (const [k, v] of Object.entries(out)) {
    filter[k as "match" | "robot"] = [...v];
  }

  return filter;
}

/**
 * Return Types
 * category = @type {string} (return value of categorizer | score objective if no categorizer)
 * score = @type {number} (number of points earned)
 * performance = @type {Normal} (distribution of points earned) | @type {number} (heuristic score)
 */
function getSingle(client: DBClient, filter: {
  season: keyof typeof dynamicMap;
  event?: string;
  match?: string;
  robot?: string;
  limit?: number;
  categorizer?: keyof typeof categorizers | "dhr";
}): Promise<{[key: string]: (object | boolean) | Normal | number} | undefined> {
  const { event, match, robot, categorizer } = filter; // for type checking

  if (event !== undefined) {
    if (match !== undefined) {
      if (robot !== undefined) {
        // event, match, robot <categorizer>
        // Robot Scores of match played at event by robot
        // => { category: score }

        if ( categorizer === undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires categorizer")
        if ( categorizer === "dhr" ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint doesn't support dhr categorizer")
        if ( filter.limit !== undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint doesn't support calclimit")

        const typecheckedIdentifier = { ...filter, event, match, robot };

        return fetchRobotScore(
            client,
            typecheckedIdentifier,
            categorizers[categorizer](filter.season),
          );
      } else {
        // event, match, f(robot) <limit>
        // Insights for match played at event
        // => see epaMatchup's return type

        if ( categorizer !== undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint doesn't support categorizer")
        if ( filter.limit === undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires calclimit")

        const typecheckedIdentifier = { ...filter, event, match };

        return epaMatch(client, typecheckedIdentifier, filter.limit!);
      }
    } else {
      if (robot !== undefined) {
        // event, f(match), robot <limit, categorizer>
        // EPA of robot at event
        // => { category: performance }

        if ( categorizer === undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires categorizer")
        if ( filter.limit === undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires calclimit")

        return categorizer === "dhr"
        ? aggRobot(client, filter, categorizer)
        : aggRobot(client, filter, categorizer);
      } else {
        // event, f(match, robot)
        // Insights for event

        // TODO unimplemented, fall through
      }
    }
  } else if (match === undefined) { // makes no sense to define a match without an event
    if (robot !== undefined) {
      // f(event, match), robot <limit, categorizer>
      // EPA of robot in season
      // => { category: performance }

      if ( categorizer === undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires categorizer")
      if ( filter.limit === undefined ) throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires calclimit")
      
      return categorizer === "dhr"
        ? aggRobot(client, filter, categorizer)
        : aggRobot(client, filter, categorizer);
    } else {
      // f(event, match, robot)
      // Statistics of season

      // TODO unimplemented, fall through
    }
  }

  throw oak.createHttpError(oak.Status.BadRequest, "Invalid Endpoint");
}

type Filter = { season: keyof typeof dynamicMap, event?: string; match?: readonly string[], robot?: readonly string[], selectlimit?: number, calclimit?: number, categorizer?: keyof typeof categorizers | "dhr"};

class ParameterParser {
  public static parse(
    params: { event?: string; match?: string; robot?: string },
    request: oak.Request,
  ): Filter {
    return {
      season: this.season(params),
      event: params["event"],
      match: params["match"] === "*" ? [] : params["match"]?.split(","),
      robot: params["robot"] === "*" ? [] : params["robot"]?.split(","),
      selectlimit: this.selectLimit(request),
      calclimit: this.calcLimit(request),
      categorizer: this.categorizer(request),
    };
  }

  private static validateSeason(
    season: number | null,
  ): season is keyof typeof dynamicMap {
    return season !== null && season in dynamicMap;
  }

  private static season(
    params: Record<string | number, string | undefined>,
  ): keyof typeof dynamicMap {
    const season = this.parseNatural(params["season"]);
    if (season === null || !this.validateSeason(season)) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        `Illegal Arguments: season must be one of ${
          Object.keys(dynamicMap).join(", ")
        }.`,
      );
    }
    return season;
  }

  private static selectLimit(request: oak.Request): number | undefined {
    const limit = this.parseNatural(request.url.searchParams.get("selectlimit"));
    if (limit === null) return;
    if (Number.isNaN(limit) || limit < 1) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: selectlimit must be a positive integer >= 1.",
      );
    }
    return limit;
  }

  private static calcLimit(request: oak.Request): number | undefined {
    const limit = this.parseNatural(request.url.searchParams.get("calclimit"));
    if (limit === null) return;
    if (Number.isNaN(limit) || limit < 3) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: calclimit must be a positive integer >= 3.",
      );
    }
    return limit;
  }

  private static validateCategorizer(
    categorizer: string | null,
  ): categorizer is keyof typeof categorizers {
    return categorizer !== null && categorizer in categorizers;
  }

  private static categorizer(
    request: oak.Request,
  ): keyof typeof categorizers | "dhr" | undefined {
    const categorizer = request.url.searchParams.get("categorizer");
    if (categorizer === null) return; // omission is legal
    if (categorizer === "dhr") return categorizer;
    if (!this.validateCategorizer(categorizer)) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        `Illegal Arguments: categorizer must be one of ${
          Object.keys(categorizers).join(", ")
        }, dhr.`,
      );
    }
    return categorizer;
  }

  private static parseNatural(x: string | null | undefined): number | null {
    if (!x) return null;
    const i = parseInt(x, 10);
    if (i <= 0) return null;
    return i;
  }
}

export default router;
