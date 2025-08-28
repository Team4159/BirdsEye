import * as oak from "@oak/oak";
import { SupabaseClient } from "@supabase/supabase-js";
import { BatchFetchFilter, fetchRobotScore } from "../data/batchfetch.ts";
import dynamicMap from "../data/dynamic/dynamic.ts";
import {
  aggRobot,
  categorizers,
  epaMatch,
} from "../data/epa.ts";
import { createSupaClient } from "../supabase/supabase.ts";

const router = new oak.Router({ prefix: "/analysis" });

router.get("/season/:season/event/:event/match/:match/robot/:robot/", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/event/:event/match/:match/", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/event/:event/robot/:robot/", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/event/:event/", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/robot/:robot/", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));
router.get("/season/:season/", async (ctx) => ctx.response.body = await handler(ctx.params, ctx.request));

/**
 * Selection Types
 * string = x (Specific Item)
 * string[] = [x] (List of Items)
 * undefined = f(x) (Aggregate of Items)
 */
async function handler(
  params: { season: string; event?: string; match?: string; robot?: string },
  request: oak.Request,
): Promise<{ [key: string]: { [key: string]: object | undefined } }> {
  const filter = ParameterParser.parse(params, request);
  const client = createSupaClient(request.headers.get("Authorization")!);

  const { match, robot } = filter;
  const matchArray = Array.isArray(match) ? match : [match];
  const robotArray = Array.isArray(robot) ? robot : [robot];

  return Object.fromEntries<{ [key: string]: object | undefined }>(
    await Promise.all(
      matchArray.map(async (
        m,
      ): Promise<[string, { [key: string]: object | undefined }]> => [
        m ?? "",
        Object.fromEntries<object | undefined>(
          await Promise.all(
            robotArray.map(async (
              r,
            ): Promise<[string, object | undefined]> => [
              r ?? "",
              await getSingle(client, {
                ...filter,
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

function getSingle(client: SupabaseClient, filter: {
  season: number;
  event?: string;
  match?: string;
  robot?: string;
  limit?: number;
  categorizer?: keyof typeof categorizers | "dhr";
}): Promise<object | undefined> {
  const { event, match, robot, categorizer } = filter;

  if (event !== undefined) {
    if (match !== undefined) {
      if (robot !== undefined) {
        // event, match, robot <categorizer>
        // Robot Scores of match played at event by robot
        const typecheckedIdentifier = { ...filter, event, match, robot };

        return categorizer === undefined || categorizer === "dhr"
          ? fetchRobotScore(client, typecheckedIdentifier)
          : fetchRobotScore(
            client,
            typecheckedIdentifier,
            categorizers[categorizer](filter.season),
          );
      } else {
        // event, match, f(robot) <limit>
        // Insights for match played at event
        const typecheckedIdentifier = { ...filter, event, match };

        return epaMatch(client, typecheckedIdentifier, filter.limit ?? 7);
      }
    } else {
      if (robot !== undefined) {
        // event, f(match), robot <limit, categorizer>
        // EPA of robot at event

        filter.limit ??= 7; // impose a limit to save the database
        return categorizer === "dhr"
          ? aggRobot(client, filter, categorizer)
          : aggRobot(client, filter, categorizer ?? "total");
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

      filter.limit ??= 14; // impose a limit to save the database
      return categorizer === "dhr"
        ? aggRobot(client, filter, categorizer)
        : aggRobot(client, filter, categorizer ?? "total");
    } else {
      // f(event, match, robot)
      // Statistics of season

      // TODO unimplemented, fall through
    }
  }

  throw oak.createHttpError(oak.Status.BadRequest, "Bad Request");
}

// TODO == deprecated ==

/**
 * Finds the categorizer that would produce this category.
 */
function categorizerSupertype(
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

router.get("/season/:season/event/:event/rankings", async (ctx) => {
  const { season, event, limit } = ParameterParser.parse(
    ctx.params,
    ctx.request,
  );
  function filter(robot: string): BatchFetchFilter {
    return {
      season,
      event: event === "*" ? undefined : event,
      robot,
      limit,
    };
  }

  const percentile = ParameterParser.percentile(ctx.request);
  const teams = ctx.request.url.searchParams.get("teams")?.split(",").map((t) =>
    t.trim()
  ).filter((t) => t.length !== 0);
  if (!teams) {
    throw oak.createHttpError(
      oak.Status.BadRequest,
      "Illegal Arguments: must provide teams",
    );
  }

  const client = createSupaClient(ctx.request.headers.get("Authorization")!);

  const method = ctx.request.url.searchParams.get("categorize") || "total";
  let rankingFunction: (robot: string) => Promise<number | null>;
  switch (method) {
    case "dhr":
      rankingFunction = (robot) =>
        aggRobot(
          client,
          filter(robot),
          method,
        ).then((norm) => norm === undefined ? null : norm["dhr"]);

      break;
    case "total":
      rankingFunction = (robot) =>
        aggRobot(
          client,
          filter(robot),
          method,
        ).then((norm) =>
          norm === undefined
            ? null
            : percentile === null
            ? norm[""].mean
            : norm[""].quantile(percentile / 100)
        );
      break;
    default: {
      const methodFormal = categorizerSupertype(season, method);
      if (!methodFormal) {
        throw oak.createHttpError(
          oak.Status.BadRequest,
          "Illegal Arguments: categorizer must be one of ().",
        );
      }
      rankingFunction = (robot) =>
        aggRobot(
          client,
          filter(robot),
          methodFormal,
        ).then((norms) =>
          norms === undefined
            ? null
            : percentile === null
            ? norms[method].mean
            : norms[method].quantile(percentile / 100)
        );
      break;
    }
  }

  ctx.response.body = Object.fromEntries(
    await Promise.all(
      new Set(teams).keys().map(async (
        t,
      ): Promise<[string, number | null]> => [t, await rankingFunction(t)]),
    ),
  );
});

// == end deprecated ==

class ParameterParser {
  public static parse(
    params: { event?: string; match?: string; robot?: string },
    request: oak.Request,
  ) {
    return {
      season: this.season(params),
      event: params["event"],
      match: params["match"]?.split(","),
      robot: params["robot"]?.split(","),
      limit: this.limit(request),
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

  private static limit(request: oak.Request): number | undefined {
    const limit = this.parseNatural(
      request.url.searchParams.get("last") ||
        request.url.searchParams.get("limit"),
    );
    if (limit === null) return;
    if (Number.isNaN(limit) || limit < 3) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: limit must be a number >= 3.",
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
  ): keyof typeof categorizers | undefined {
    const categorizer = request.url.searchParams.get("categorizer");
    if (!this.validateCategorizer(categorizer)) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        `Illegal Arguments: categorizer must be one of ${
          Object.keys(categorizers).join(", ")
        }.`,
      );
    }
    return categorizer;
  }

  public static percentile(request: oak.Request): number | null {
    const percentile = this.parseNatural(
      request.url.searchParams.get("percentile"),
    );
    if (percentile === null) return null;
    if (Number.isNaN(percentile) || percentile >= 100) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: percentile must be ℤ ∈ (0, 100).",
      );
    }
    return percentile;
  }

  // deno-lint-ignore no-explicit-any
  private static parseNatural(x: any): number | null {
    if (x === null) return null;
    const i = parseInt(x, 10);
    if (i <= 0) return null;
    return i;
  }
}

export default router;
