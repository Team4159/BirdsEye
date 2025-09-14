import * as oak from "@oak/oak";
import { fetchRobotScore } from "../data/batchfetch.ts";
import dynamicMap from "../data/dynamic/dynamic.ts";
import { aggRobot, categorizers, epaMatch } from "../data/epa.ts";
import { DBClient } from "../supabase/supabase.ts";
import { Normal } from "../math.ts";
import { maxAgeMiddleware } from "../cacher.ts";

const router = new oak.Router<DBClient>({ prefix: "/analysis" });

router.get(
  "/season/:season/event/:event/match/:match/robot/:robot",
  maxAgeMiddleware(60),
  async (ctx) =>
    ctx.response.body = await handler(
      ctx.state as DBClient,
      ctx.params,
      ctx.request,
    ),
);
router.get(
  "/season/:season/event/:event/match/:match",
  maxAgeMiddleware(60),
  async (ctx) =>
    ctx.response.body = await handler(
      ctx.state as DBClient,
      ctx.params,
      ctx.request,
    ),
);
router.get(
  "/season/:season/event/:event/robot/:robot",
  maxAgeMiddleware(60),
  async (ctx) =>
    ctx.response.body = await handler(
      ctx.state as DBClient,
      ctx.params,
      ctx.request,
    ),
);
router.get(
  "/season/:season/event/:event",
  maxAgeMiddleware(3600),
  async (ctx) =>
    ctx.response.body = await handler(
      ctx.state as DBClient,
      ctx.params,
      ctx.request,
    ),
);
router.get(
  "/season/:season/robot/:robot",
  maxAgeMiddleware(60),
  async (ctx) =>
    ctx.response.body = await handler(
      ctx.state as DBClient,
      ctx.params,
      ctx.request,
    ),
);
router.get(
  "/season/:season",
  maxAgeMiddleware(3600),
  async (ctx) =>
    ctx.response.body = await handler(
      ctx.state as DBClient,
      ctx.params,
      ctx.request,
    ),
);

/**
 * Selection Types
 * string = x (Specific Item)
 * string[] = [x] (List of Items)
 * asterisk = [x*] (List of All Items)
 * undefined = f(x) (Aggregate of Items)
 */
async function handler(
  client: DBClient,
  params: { season: string; event?: string; match?: string; robot?: string },
  request: oak.Request,
): Promise<{[key: string]: {[key: string]: { [key: string]: NonNullable<Awaited<ReturnType<typeof getSingle>>>}}}> {
  const filter = await expandGlobs(
    client,
    ParameterParser.parse(params, request),
  );

  if (filter.length === 0) {
    throw oak.createHttpError(oak.Status.NotFound, "No Data");
  }
  
  // Fetch all queries in parallel
  const results = await Promise.all(
    filter.map(
      async (single): Promise<
        [SingleFilter, Awaited<ReturnType<typeof getSingle>>]
      > => 
        [single, await getSingle(client, single)]
    )
  )

  // Organize results
  const output: Awaited<ReturnType<typeof handler>> = {}
  for (const [ filter, value ] of results) {
    // Not Found - Should be impossible if globbing
    if (value === undefined) continue;
    
    const l0 = output;
    const l1 = (l0[filter[globbable[0]] ?? ""] ??= {})
    const l2 = (l1[filter[globbable[1]] ?? ""] ??= {})
    l2[filter[globbable[2]] ?? ""] = value;
  }

  return output;
}

const globbable: ["event", "match", "robot"] = ["event", "match", "robot"];
/**
 * Expands all globs (`*`, gets converted to `[]`) to their real values
 * @param filter A filter, possibly including globs
 * @returns The filter, with all globs replaced with a list of values
 */
async function expandGlobs(
  client: DBClient,
  filter: Filter,
): Promise<SingleFilter[]> {
  const globs = globbable.filter((g) => filter[g] !== undefined && filter[g].length === 0);

  // Return all combinations of list filters if no glob
  if (globs.length === 0) {
    if (filter.selectlimit !== undefined) {
      throw oak.createHttpError(oak.Status.BadRequest, "Endpoint doesn't support selectlimit");
    }

    const output: SingleFilter[] = [];

    // All loops WILL run because we know there are no empty lists
    for (const e of filter.event ?? [undefined]) 
    for (const m of filter.match ?? [undefined]) 
    for (const r of filter.robot ?? [undefined]) 
      output.push({...filter, event: e, match: m, robot: r})
        
    return output;
  }

  if (filter.selectlimit === undefined) {
    throw oak.createHttpError(oak.Status.BadRequest, "Endpoint requires selectlimit");
  }

  // Build query to database (rename "team" to "robot")
  let query = client
    .from("match_scouting")
    .select(
      "scouter.count(), " +
      (globs.includes("match") ? "match_code, " : "") +
      globs.join(", ").replace("robot", "robot:team")
    )
    .eq("season", filter.season);
  
  for (const key of globbable) {
    // If the parameter is absent || the parameter is being globbed
    if (filter[key] === undefined || filter[key].length === 0) continue;

    // Translate "robot" (clientside) to "team" (serverside)
    const dbKey = key === "robot" ? "team" : key;

    // Modify the query to add the filter
    query = query.in(dbKey, filter[key]);
  }

  if (globs.includes("match")) {
    // TODO make this also take events into account
    // Sort the request by match recency
    query = query
      .order("match_code", { ascending: false })
  }

  // Limit the request
  query = query
    .limit(filter.selectlimit);

  // Execute query, typecast to known result (`, string>` only works because all globbables are type string)
  // Note: the entry objects do have more parameters (scouter.count(), match_code), but they are ignored.
  const data = (await query).data as unknown as Record<(typeof globbable)[number], string>[];

  // Process Results
  return data!.map(entry => ({...filter, ...entry}));
}

/**
 * Return Types
 * category = @type {string} (return value of categorizer | score objective if no categorizer)
 * score = @type {number} (number of points earned)
 * performance = @type {Normal} (distribution of points earned) | @type {number} (heuristic score)
 */
function getSingle(client: DBClient, filter: SingleFilter): Promise<
  { [key: string]: (object | boolean) | Normal | number } | undefined
> {
  const { event, match, robot, categorizer } = filter; // for type checking

  if (event !== undefined) {
    if (match !== undefined) {
      if (robot !== undefined) {
        // event, match, robot <categorizer?>
        // Robot Scores of match played at event by robot
        // => { category: score }

        if (categorizer === "dhr") {
          throw oak.createHttpError(
            oak.Status.BadRequest,
            "Endpoint doesn't support dhr categorizer",
          );
        }
        if (filter.calclimit !== undefined) {
          throw oak.createHttpError(
            oak.Status.BadRequest,
            "Endpoint doesn't support calclimit",
          );
        }

        const typecheckedIdentifier = { ...filter, event, match, robot };

        return fetchRobotScore(
          client,
          typecheckedIdentifier,
          categorizer === undefined ? undefined : categorizers[categorizer](filter.season),
        );
      } else {
        // event, match, f(robot) <limit>
        // Insights for match played at event
        // => see epaMatchup's return type

        if (categorizer !== undefined) {
          throw oak.createHttpError(
            oak.Status.BadRequest,
            "Endpoint doesn't support categorizer",
          );
        }
        if (filter.calclimit === undefined) {
          throw oak.createHttpError(
            oak.Status.BadRequest,
            "Endpoint requires calclimit",
          );
        }

        const typecheckedIdentifier = { ...filter, event, match };

        return epaMatch(client, typecheckedIdentifier, filter.calclimit!);
      }
    } else {
      if (robot !== undefined) {
        // event, f(match), robot <limit, categorizer>
        // EPA of robot at event
        // => { category: performance }

        if (categorizer === undefined) {
          throw oak.createHttpError(
            oak.Status.BadRequest,
            "Endpoint requires categorizer",
          );
        }
        if (filter.calclimit === undefined) {
          throw oak.createHttpError(
            oak.Status.BadRequest,
            "Endpoint requires calclimit",
          );
        }

        return categorizer === "dhr"
          ? aggRobot(client, filter, categorizer)
          : aggRobot(client, filter, categorizer);
      } else {
        // event, f(match, robot)
        // Insights for event

        // unimplemented, fall through
      }
    }
  } else if (match === undefined) { // makes no sense to define a match without an event
    if (robot !== undefined) {
      // f(event, match), robot <limit, categorizer>
      // EPA of robot in season
      // => { category: performance }

      if (categorizer === undefined) {
        throw oak.createHttpError(
          oak.Status.BadRequest,
          "Endpoint requires categorizer",
        );
      }
      if (filter.calclimit === undefined) {
        throw oak.createHttpError(
          oak.Status.BadRequest,
          "Endpoint requires calclimit",
        );
      }

      return categorizer === "dhr"
        ? aggRobot(client, filter, categorizer)
        : aggRobot(client, filter, categorizer);
    } else {
      // f(event, match, robot)
      // Statistics of season

      // unimplemented, fall through
    }
  }

  throw oak.createHttpError(oak.Status.BadRequest, "Invalid Endpoint");
}

type Filter = {
  season: keyof typeof dynamicMap;
  event?: readonly string[];
  match?: readonly string[];
  robot?: readonly string[];
  calclimit?: number;
  categorizer?: keyof typeof categorizers | "dhr";
  selectlimit?: number;
};

type SingleFilter = {
  season: keyof typeof dynamicMap;
  event?: string;
  match?: string;
  robot?: string;
  calclimit?: number;
  categorizer?: keyof typeof categorizers | "dhr";
};

class ParameterParser {
  public static parse(
    params: { event?: string; match?: string; robot?: string },
    request: oak.Request,
  ): Filter {
    return {
      season: this.season(params),
      event: params["event"] === "*" ? [] : params["event"]?.split(","),
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

  /**
   * Parses the season parameter from the request parameters.
   * @param params The request parameters object.
   * @returns The parsed season as a valid key of dynamicMap.
   * @throws If the season is invalid or not found in dynamicMap.
   */
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
    const param = request.url.searchParams.get("selectlimit");
    if (param === null) return;
    const limit = this.parseNatural(param);
    if (limit === null || limit < 1) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: selectlimit must be a positive integer >= 1.",
      );
    }
    return limit;
  }

  private static calcLimit(request: oak.Request): number | undefined {
    const param = request.url.searchParams.get("calclimit");
    if (param === null) return;
    const limit = this.parseNatural(param);
    if (limit === null || limit < 3) {
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
    if (i <= 0 || Number.isNaN(i)) return null;
    return i;
  }
}

export default router;
