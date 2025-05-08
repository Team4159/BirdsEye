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
    throw new oak.HttpError<oak.Status.BadRequest>(
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
    throw new oak.HttpError<oak.Status.BadRequest>(
      "Illegal Arguments: last must be >= 3.",
    );
  }

  const teams = ctx.request.url.searchParams.get("teams")?.split(",").map((t) =>
    t.trim()
  );
  if (!teams) {
    throw new oak.HttpError<oak.Status.BadRequest>(
      "Illegal Arguments: must provide teams",
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
        ).then((norm) => norm.mean);
      break;
    default: {
      const methodFormal = categorizerSupertype(season, method);
      if (!methodFormal) {
        throw new oak.HttpError<oak.Status.BadRequest>(
          "Illegal Arguments: categorizer must be one of ().",
        );
      }
      rankingFunction = (team) =>
        epaRobot(
          client,
          { season, team, mostRecentN },
          methodFormal,
        ).then((res) => res[method].mean);
      break;
    }
  }

  const rankedTeams = await Promise.all(
    teams.map(async (
      t,
    ): Promise<[string, number]> => [t, await rankingFunction(t)]),
  );
  return new Map(rankedTeams.sort((a, b) => b[1] - a[1]));
});

export default router;
