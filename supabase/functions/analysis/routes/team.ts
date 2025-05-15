import * as oak from "@oak/oak";
import { dhrRobot, epaRobot, erpaRobot, isCategorizer } from "../data/epa.ts";
import { createSupaClient } from "../supabase/supabase.ts";
import { matches, ParameterParser } from "./shared.ts";

const router = new oak.Router({ prefix: "/team/:team" });

router.get("/matches", matches);
router.get("/epa", async (ctx) => {
  const filter = {
    season: ParameterParser.season(ctx.params),
    event: ctx.params["event"],
    team: ctx.params["team"]!,
    mostRecentN: ParameterParser.mostRecentN(ctx.request) ?? 10,
  };

  const client = createSupaClient(ctx.request.headers.get("Authorization")!);

  const method = ctx.request.url.searchParams.get("categorize") || "total";
  switch (method) {
    case "rp":
      ctx.response.body = await erpaRobot(client, filter);
      break;
    case "dhr":
      ctx.response.body = await dhrRobot(client, filter);
      break;
    default:
      if (!isCategorizer(method)) {
        throw oak.createHttpError(
          oak.Status.BadRequest,
          "Illegal Arguments: categorizer must be one of ().",
        );
      }
      // This bit is necessary to trick the typescript compiler
      ctx.response.body = await (method === "total"
        ? epaRobot(
          client,
          filter,
          method,
        )
        : epaRobot(
          client,
          filter,
          method,
        ));
      break;
  }
});

export default router;
