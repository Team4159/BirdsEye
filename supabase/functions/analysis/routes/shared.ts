import * as oak from "@oak/oak";
import { batchFetchRobotInMatch, zipCountsAndScores } from "../data/batchfetch.ts";
import dynamicMap from "../data/dynamic/dynamic.ts";
import { createSupaClient } from "../supabase/supabase.ts";

// deno-lint-ignore no-explicit-any
function parseNatural(x: any): number | null {
  if (x === null) return null;
  const i = parseInt(x, 10);
  if (i <= 0) return null;
  return i;
}

export class ParameterParser {
  private static validateSeason(
    season: number | null,
  ): season is keyof typeof dynamicMap {
    return season !== null && season in dynamicMap;
  }

  public static season(
    params: Record<string | number, string | undefined>,
  ): keyof typeof dynamicMap {
    const season = parseNatural(params["season"]);
    if (season === null || !ParameterParser.validateSeason(season)) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        `Illegal Arguments: season must be one of ${
          Object.keys(dynamicMap).join(", ")
        }.`,
      );
    }
    return season;
  }

  public static mostRecentN(request: oak.Request): number | null {
    const mostRecentN = parseNatural(request.url.searchParams.get("last"));
    if (mostRecentN === null) return null;
    if (Number.isNaN(mostRecentN) || mostRecentN < 3) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: mostRecentN must be a number >= 3.",
      );
    }
    return mostRecentN;
  }

  public static percentile(request: oak.Request): number | null {

      const percentile = parseNatural(
        request.url.searchParams.get("percentile")
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
}

// deno-lint-ignore no-explicit-any
export async function matches(ctx: oak.RouterContext<"/matches", Record<string | number, string | undefined>, Record<string, any>>) {
  const filter = {
    season: ParameterParser.season(ctx.params),
    event: ctx.params["event"],
    team: ctx.params["team"]!,
    mostRecentN: ParameterParser.mostRecentN(ctx.request) ?? undefined,
  };
  const client = createSupaClient(ctx.request.headers.get("Authorization")!);

  const rims = await batchFetchRobotInMatch(
      client,
      filter,
    );
  if (rims.size === 0) {
    ctx.response.body = null;
    return;
  }

  ctx.response.body = Object.fromEntries(
    rims.entries().map((
      [id, rim],
    ) => [
      `${id.season}${id.event}_${id.match}-${id.team}`,
      zipCountsAndScores(id, rim),
    ]),
  );
}