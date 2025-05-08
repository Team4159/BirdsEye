import * as oak from "@oak/oak";
import {
  batchFetchRobotInMatch,
  zipCountsAndScores,
} from "../data/batchfetch.ts";
import { dhrRobot, epaRobot, erpaRobot, isCategorizer } from "../data/epa.ts";
import { createSupaClient } from "../supabase/supabase.ts";
import { parseNatural } from "../util.ts";
import { InvalidSeason, validateSeason } from "./shared.ts";

const router = new oak.Router({ prefix: "/team/:team" });

router.get("/matches", async (ctx) => {
  const season = parseNatural(ctx.params["season"]);
  if (!validateSeason(season)) throw new InvalidSeason();

  ctx.response.body = Object.fromEntries(
    (await batchFetchRobotInMatch(
      createSupaClient(
        ctx.request.headers.get("Authorization")!,
      ),
      {
        season,
        event: ctx.params["event"],
        team: ctx.params["team"]!,
      },
    )).entries().map((
      [id, rim],
    ) => [
      `${id.season}${id.event}_${id.match}-${id.team}`,
      zipCountsAndScores(id, rim),
    ]),
  );
});

router.get("/epa", async (ctx) => { // note: this function pretty much ignores the :event. This is eh, fine.
  const season = parseNatural(ctx.params["season"]);
  if (!validateSeason(season)) throw new InvalidSeason();

  const mostRecentN = parseNatural(ctx.request.url.searchParams.get("last")) ??
    5;
  if (mostRecentN !== null && mostRecentN < 3) {
    throw new oak.HttpError<oak.Status.BadRequest>(
      "Illegal Arguments: last must be >= 3.",
    );
  }

  const client = createSupaClient(ctx.request.headers.get("Authorization")!);
  const team = ctx.params["team"]!;

  const method = ctx.request.url.searchParams.get("categorize") || "total";
  switch (method) {
    case "rp":
      ctx.response.body = await erpaRobot(client, {
        season,
        team,
        mostRecentN,
      });
      break;
    case "dhr":
      if (!("event" in ctx.params)) {
        throw new oak.HttpError<oak.Status.BadRequest>(
          "Illegal Arguments: method cannot be dhr on this path.",
        );
      }
      ctx.response.body = await dhrRobot(client, {
        season,
        event: ctx.params["event"]!,
        team,
      });
      break;
    default:
      if (!isCategorizer(method)) {
        throw new oak.HttpError<oak.Status.BadRequest>(
          "Illegal Arguments: categorizer must be one of ().",
        );
      }
      // This bit is necessary to trick the typescript compiler
      ctx.response.body = await (method === "total"
        ? epaRobot(
          client,
          { season, team, mostRecentN },
          method,
        )
        : epaRobot(
          client,
          { season, team, mostRecentN },
          method,
        ));
      break;
  }
});

export default router;
