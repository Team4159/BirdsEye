import {
  createClient,
  SupabaseClient,
} from "jsr:@supabase/supabase-js@2";
import { Database } from "./database.types.ts";
import { MatchInfo } from "./tba.types.ts";
import process2023TBA from "./season2023.ts";
import process2024TBA from "./season2024.ts";
import process2025TBA from "./season2025.ts";
const fuserMap: {
  [key: string]: (
    dbdata: { [key: string]: Set<number> },
    team: string,
    tbadata: MatchInfo,
  ) => void;
} = { "2023": process2023TBA, "2024": process2024TBA, "2025": process2025TBA };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const teamPattern = new RegExp("^\\d{1,5}[A-Z]?$");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const params: URLSearchParams = new URL(req.url).searchParams; // Grab query parameters
  // deno-lint-ignore no-explicit-any
  for (const entry of Object.entries<any>(await req.json().catch(() => {return {}}))) { // Grab request body parameters
    params.append(entry[0], entry[1].toString());
  }

  // Validate parameters
  let season: number | undefined;
  let event: string | undefined;
  let team: string | undefined;
  let mode: AggMode = "mean";
  if (params.has("season")) {
    const out = Number.parseInt(params.get("season")!);
    if (!isFinite(out) || out <= 0) {
      return new HTTP400(
        "Invalid Parameter\nseason: valid frc season year (e.g. 2023)",
      );
    }
    season = out;
  }
  if (params.has("event")) event = params.get("event")!;
  if (params.has("team")) {
    if (!teamPattern.test(params.get("team")!)) {
      return new HTTP400(
        "Invalid Parameter\nteam: valid frc team number (e.g. 4159)",
      );
    }
    team = params.get("team")!;
  }
  if (!season || !(event || team)) {
    return new HTTP400("Missing Required Parameters\nseason, event OR team");
  }
  if (params.has("mode")) {
    // deno-lint-ignore no-explicit-any
    const out = params.get("mode") as any;
    if (!aggregationMethods.has(out)) {
      return new HTTP400(
        "Invalid Parameter\nmode: " + [...aggregationMethods.keys()].join(", "),
      );
    }
    mode = out;
  }

  // Execute
  try {
    const supabase = createClient<Database>(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: {
          headers: { authorization: req.headers.get("Authorization")! },
        },
      },
    );

    return await aggregateMatches(supabase, mode, season, event, team);
  } catch (e) {
    console.error(e);
    return new Response("Internal Server Error", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
});

type AggMode = "text" | "mean" | "median" | "75th";
const aggregationMethods: Map<AggMode, (l: Set<number>) => number> = new Map([
  ["text", (_) => {
    throw new Error();
  }],
  ["mean", (l) => [...l].sort()[Math.floor(l.size / 2)]],
  ["median", (l) => [...l].reduce((v, c) => v + c) / l.size],
  ["75th", (l) => [...l].sort()[Math.floor(l.size * 3 / 4)]],
]);
async function aggregateMatches(
  supabase: SupabaseClient<Database, "public", Database["public"]>,
  aggMode: AggMode,
  season: number,
  event: string | undefined,
  team: string | undefined,
): Promise<Response> {
  // Database Fetching
  // deno-lint-ignore no-explicit-any
  let query = supabase.from(`match_data_${season}` as any).select( // shut up typescript
    "*, match_scouting!inner(scouter, event, match, team)",
  );
  if (event != null) query = query.eq("match_scouting.event", event);
  if (team != null) query = query.eq("match_scouting.team", team);
  // deno-lint-ignore no-explicit-any
  const { data: dbdata, error } = (await query) as any; // shut up typescript
  if (!dbdata || dbdata.length === 0) {
    return new Response(
      `No Data Found for ${team == null ? "" : team + "@ "}${season}${
        event ?? ""
      }\n${error?.message ?? ""}`,
      {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "text/plain" },
      },
    );
  }

  // Processing
  if (aggMode === "text") { // Text Aggregation
    // Data Aggregation
    const agg: {
      [key: string]: { [key: string]: { [key: string]: string } };
    } = {}; // {team / event: {match: {question: value}}}
    for (const scoutingEntry of dbdata) {
      const mkey: string = !event
        ? scoutingEntry.match_scouting["event"]
        : scoutingEntry.match_scouting["team"];
      if (agg[mkey] == null) agg[mkey] = {};
      const match: string = scoutingEntry.match_scouting["match"];
      if (agg[mkey][match] == null) agg[mkey][match] = {};
      const scouter: string | undefined =
        scoutingEntry.match_scouting["scouter"];
      for (const [key, value] of Object.entries(scoutingEntry)) {
        if (key === "id" || !(typeof value === "string") || value.length === 0) continue;
        if (agg[mkey][match][key] == null) agg[mkey][match][key] = "";
        agg[mkey][match][key] = `${
          agg[mkey][match][key]
        }\n${scouter}: ${value}`;
      }
    }
    // Return
    return Response.json(agg, {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } else if (event) { // Event Aggregtion
    // TBA Fetching
    const tbadataraw: MatchInfo[] = await fetch(
      `https://www.thebluealliance.com/api/v3/event/${season}${event}/matches`,
      { headers: { "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")! } },
    ).then((resp) => resp.json());
    const tbadata: { [key: string]: MatchInfo } = Object.fromEntries(
      tbadataraw.map((tbamatch) => [tbamatch.key.split("_").at(-1), tbamatch]),
    );

    // Data Aggregation
    const agg: {
      [key: string]: { [key: string]: { [key: string]: Set<number> } }
    } = {}; // {match: {team: {scoretype: values}}}
    for (const scoutingEntry of dbdata) {
      const match: string = scoutingEntry.match_scouting["match"];
      if (agg[match] == null) agg[match] = {};
      const team: string = scoutingEntry.match_scouting["team"];
      if (agg[match][team] == null) agg[match][team] = {};

      if (!(match in tbadata)) continue;
      for (let [key, value] of Object.entries(scoutingEntry)) {
        if (key === "id" || key === "match_scouting") continue;
        if (typeof value === "boolean") value = value ? 1 : 0;
        if (typeof value !== "number") continue;
        if (agg[match][team][key] == null) agg[match][team][key] = new Set();
        agg[match][team][key]!.add(value);
      }

      fuserMap[season.toString()](agg[match][team], team, tbadata[match]);
    }
    // Data Aggregation 2: Electric Boogaloo
    // match: {team: {scoretype: aggregate_value}}
    const matches: {
      [key: string]: { [key: number]: { [key: string]: number } };
    } = Object.fromEntries(
      Object.entries(agg).map((
        [k1, v1]: [string, { [key: number]: { [key: string]: Set<number> } }],
      ) => [
        k1,
        Object.fromEntries(
          Object.entries(v1).map((
            [k2, v2]: [string, { [key: string]: Set<number> }],
          ) => [
            k2,
            Object.fromEntries(
              Object.entries(v2).map(([k3, v3]: [string, Set<number>]) => [
                k3,
                aggregationMethods.get(aggMode)!(v3),
              ]),
            ),
          ]),
        ),
      ]),
    );
    // Return
    return Response.json(matches, {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } else if (team) { // Team Aggregation
    // TBA Fetching
    const tbadataraw: MatchInfo[] = await fetch(
      `https://www.thebluealliance.com/api/v3/team/frc${team}/matches/${season}`,
      { headers: { "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")! } },
    ).then((resp) => resp.json());
    const tbadata: { [key: string]: MatchInfo } = Object.fromEntries(
      tbadataraw.map((match) => [match.key.split("_").at(-1), match]),
    );

    // Data Aggregation
    const agg: {
      [key: string]: { [key: string]: { [key: string]: Set<number> } };
    } = {}; // {event: {match: {scoretype: [values]}}}
    for (const scoutingEntry of dbdata) {
      const event: string = scoutingEntry.match_scouting["event"];
      if (agg[event] == null) agg[event] = {};
      const match: string = scoutingEntry.match_scouting["match"];
      if (agg[event][match] == null) agg[event][match] = {};

      for (let [key, value] of Object.entries(scoutingEntry)) {
        if (key === "id" || key === "match_scouting") continue;
        if (typeof value === "boolean") value = value ? 1 : 0;
        if (typeof value !== "number") continue;
        if (agg[event][match][key] == null) agg[event][match][key] = new Set();
        agg[event][match][key]!.add(value);
      }

      if (!(match in tbadata)) continue;
      fuserMap[season.toString()](agg[event][match], team, tbadata[match]);
    }
    // Data Aggregation 2: Electric Boogaloo
    // event: {match: {scoretype: aggregate_value}}
    const matches: {
      [key: string]: { [key: number]: { [key: string]: number } };
    } = Object.fromEntries(
      Object.entries(agg).map((
        [k1, v1]: [string, { [key: number]: { [key: string]: Set<number> } }],
      ) => [
        k1,
        Object.fromEntries(
          Object.entries(v1).map((
            [k2, v2]: [string, { [key: string]: Set<number> }],
          ) => [
            k2,
            Object.fromEntries(
              Object.entries(v2).map(([k3, v3]: [string, Set<number>]) => [
                k3,
                aggregationMethods.get(aggMode)!(v3),
              ]),
            ),
          ]),
        ),
      ]),
    );
    // Return
    return Response.json(matches, {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } else {
    console.error("This should never occur if parameters are validated correctly.");
    return new HTTP400("Missing Required Parameters\nseason, event OR team");
  }
}

class HTTP400 extends Response {
  constructor(message: string) {
    super(message, {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
}
