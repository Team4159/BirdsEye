import * as oak from "@oak/oak";
import {
  categorizerSupertype,
  dhrRobot,
  epaMatch,
  epaRobot,
} from "../data/epa.ts";
import { createSupaClient } from "../supabase/supabase.ts";
import { parseNatural } from "../util.ts";
import { InvalidSeason, validateSeason } from "./shared.ts";
import robotRouter from "./team.ts";

const router = new oak.Router({ prefix: "/event/:event" });

router.use(robotRouter.routes());

router.get("/match/:match/epa", async (ctx) => {
  const season = parseNatural(ctx.params["season"]);
  if (!validateSeason(season)) throw new InvalidSeason();

  const lastNMatches = parseNatural(ctx.request.url.searchParams.get("last"));
  if (lastNMatches !== null && lastNMatches < 3) {
    throw oak.createHttpError(oak.Status.BadRequest,
      "Illegal Arguments: last must be >= 3.",
    );
  }

  ctx.response.body = await epaMatch(
    createSupaClient(ctx.request.headers.get("Authorization")!),
    {
      season,
      event: ctx.params["event"]!,
      match: ctx.params["match"],
    },
    lastNMatches ?? 5,
  );
});

router.get("/rankings", async (ctx) => { // note: this function pretty much ignores the :event. This is eh, fine.
  const season = parseNatural(ctx.params["season"]);
  if (!validateSeason(season)) throw new InvalidSeason();

  const mostRecentN = parseNatural(ctx.request.url.searchParams.get("last")) ??
    5;
  if (mostRecentN < 3) {
    throw oak.createHttpError(oak.Status.BadRequest,
      "Illegal Arguments: last must be >= 3.",
    );
  }

  const teams = ctx.request.url.searchParams.get("teams")?.split(",").map((t) =>
    t.trim()
  );
  if (!teams) {
    throw oak.createHttpError(oak.Status.BadRequest,
      "Illegal Arguments: must provide teams"
    );
  }

  const percentile = parseNatural(ctx.request.url.searchParams.get("percentile"));
  if (percentile !== null && percentile >= 100) {
    throw oak.createHttpError(oak.Status.BadRequest,
      "Illegal Arguments: percentile must be ℤ ∈ (0, 100).",
    );
  }

  const client = createSupaClient(ctx.request.headers.get("Authorization")!);
  const event = ctx.params["event"]!;

  const method = ctx.request.url.searchParams.get("categorize") || "total";
  let rankingFunction: (team: string) => Promise<number>;
  switch (method) {
    case "dhr":
      rankingFunction = (team) => dhrRobot(client, { season, event, team });
      break;
    case "total":
      rankingFunction = (team) =>
        epaRobot(
          client,
          { season, team, mostRecentN },
          method,
        ).then((norm) => percentile === null ? norm.mean : norm.quantile(percentile/100));
      break;
    default: {
      const methodFormal = categorizerSupertype(season, method);
      if (!methodFormal) {
        throw oak.createHttpError(oak.Status.BadRequest,
          "Illegal Arguments: categorizer must be one of ().",
        );
      }
      rankingFunction = (team) =>
        epaRobot(
          client,
          { season, team, mostRecentN },
          methodFormal,
        ).then((res) => percentile === null ? res[method].mean : res[method].quantile(percentile/100));
      break;
    }
  }

  ctx.response.body = Object.fromEntries(await Promise.all(
    new Set(teams).keys().map(async (
      t,
    ): Promise<[string, number]> => [t, await rankingFunction(t)]),
  ));
});

export default router;
