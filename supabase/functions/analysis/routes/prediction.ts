import * as oak from "@oak/oak";
import { predictEvent } from "../data/predict.ts";
import dynamicMap from "../data/dynamic/dynamic.ts";
import { DBClient } from "../supabase/supabase.ts";
import { maxAgeMiddleware } from "../cacher.ts";

const router = new oak.Router<DBClient>({ prefix: "/prediction" });

router.get(
  "/season/:season/event/:event",
  maxAgeMiddleware(600),
  async (ctx) => {
    const season = ParameterParser.season(ctx.params);
    const event = ctx.params["event"]!;
    const limit = ParameterParser.calcLimit(ctx.request);
    const realmatches = ParameterParser.realMatches(ctx.request);

    ctx.response.body = await predictEvent(
      ctx.state as DBClient,
      season,
      event,
      limit ?? 8,
      realmatches
    );
  },
);

class ParameterParser {
  private static validateSeason(
    season: number | null,
  ): season is keyof typeof dynamicMap {
    return season !== null && season in dynamicMap;
  }

  public static season(
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

  public static calcLimit(request: oak.Request): number | undefined {
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

  public static realMatches(request: oak.Request): number | undefined {
    const realmatches = this.parseNatural(request.url.searchParams.get("realmatches"));
    if (realmatches === null) return;
    if (Number.isNaN(realmatches) || realmatches < 0) {
      throw oak.createHttpError(
        oak.Status.BadRequest,
        "Illegal Arguments: realmatches must be a positive integer",
      );
    }
    return realmatches;
  }

  private static parseNatural(x: string | null | undefined): number | null {
    if (x === undefined || x === null) return null;
    const i = parseInt(x, 10);
    if (i < 0) return null;
    return i;
  }
}

export default router;
