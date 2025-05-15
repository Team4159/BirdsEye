import * as oak from "@oak/oak";
import {
  categorizerSupertype,
  dhrRobot,
  epaMatch,
  epaRobot,
} from "../data/epa.ts";
import { createSupaClient } from "../supabase/supabase.ts";
import { matches, ParameterParser } from "./shared.ts";
import robotRouter from "./team.ts";

const router = new oak.Router({ prefix: "/event/:event" });

router.use(robotRouter.routes());

router.get("/matches", matches);
router.get("/match/:match/epa", async (ctx) => {
  const identifier = {
    season: ParameterParser.season(ctx.params),
    event: ctx.params["event"]!,
    match: ctx.params["match"]!,
  };
  const mostRecentN = ParameterParser.mostRecentN(ctx.request) ?? 5;

  const client = createSupaClient(ctx.request.headers.get("Authorization")!);

  ctx.response.body = await epaMatch(
    client,
    identifier,
    mostRecentN,
  );
});

router.get("/rankings", async (ctx) => {
  const season = ParameterParser.season(ctx.params);
  const event = ctx.params["event"]!;
  const mostRecentN = ParameterParser.mostRecentN(ctx.request) ?? undefined;
  function filter(team: string) {
    return { season, event: event === "*" ? undefined : event, team, mostRecentN };
  }

  const percentile = ParameterParser.percentile(ctx.request);
  const teams = ctx.request.url.searchParams.get("teams")?.split(",").map((t) =>
    t.trim()
  ).filter(t => t.length !== 0);
  if (!teams) {
    throw oak.createHttpError(
      oak.Status.BadRequest,
      "Illegal Arguments: must provide teams",
    );
  }

  const client = createSupaClient(ctx.request.headers.get("Authorization")!);

  const method = ctx.request.url.searchParams.get("categorize") || "total";
  let rankingFunction: (team: string) => Promise<number | null>;
  switch (method) {
    case "dhr":
      rankingFunction = (team) => dhrRobot(client, filter(team));
      break;
    case "total":
      rankingFunction = (team) =>
        epaRobot(
          client,
          filter(team),
          method,
        ).then((norm) => norm === null ? null :
          percentile === null ? norm.mean : norm.quantile(percentile / 100)
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
      rankingFunction = (team) =>
        epaRobot(
          client,
          filter(team),
          methodFormal,
        ).then((norms) =>norms === null ? null :
          percentile === null
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

export default router;
