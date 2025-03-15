import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { Database } from "./database.types.ts";
import { MatchInfo } from "./tba.types.ts";
import process2023TBA from "./season2023.ts";
import process2024TBA from "./season2024.ts";
import process2025TBA from "./season2025.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
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

    // Request Argument Validation
    const params: URLSearchParams = new URL(req.url).searchParams;
    for (const entry of await req.json()
        .then((p) => Object.entries<string>(p))
        .catch((e) => {console.warn(e); return []}))
      params.append(entry[0], entry[1]);
    if (!params.has("season") || !(params.has("event") || params.has("team"))) {
      return new Response(
        "Missing Required Parameters\nseason: valid frc season year (e.g. 2023)\n\nevent: valid tba event code (e.g. casf)\nOR\nteam: valid frc team number (e.g. 4159)",
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "text/plain" },
        },
      );
    }
    // Database Fetching
    let query = supabase.from(`match_data_${params.get("season")}`).select("*, match_scouting!inner(scouter, event, match, team)");
    if (params.has("event")) query = query.eq("match_scouting.event", params.get("event")!)
    if (params.has("team")) query = query.eq("match_scouting.team", params.get("team")!)
    const { data, error } = await query;
    if (!data || data.length === 0) {
      return new Response(
        `No Data Found for ${params.has("team") ? params.get("team")+"@ " : ""}${params.get("season")}${params.has("event") ? params.get("event") : ""}\n${error?.message}`,
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "text/plain" },
        }
      );
    }
    if (params.get("type") === "text") {
      // Data Aggregation
      const agg: {
        [key: string]: { [key: string]: { [key: string]: string } };
      } = {}; // {team / event: {match: {question: value}}}
      for (const scoutingEntry of data) {
        const mkey: string = !params.has("event") ? scoutingEntry.match_scouting["event"] : scoutingEntry.match_scouting["team"];
        if (agg[mkey] == null) agg[mkey] = {};
        const match: string = scoutingEntry.match_scouting["match"];
        if (agg[mkey][match] == null) agg[mkey][match] = {};
        const scouter: string | undefined = scoutingEntry.match_scouting["scouter"];
        delete scoutingEntry.match_scouting;
        delete scoutingEntry.id;
        for (const [key, value] of Object.entries(scoutingEntry)) {
          if (!(typeof value === "string") || value.length === 0) continue;
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
    } else if (params.has("event")) {
      // TBA Fetching
      const tbadataraw: MatchInfo[] = await fetch(
        `https://www.thebluealliance.com/api/v3/event/${params.get("season")}${params.get("event")}/matches`,
        { headers: { "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")! } },
      ).then((resp) => resp.json());
      const tbadata: { [key: string]: MatchInfo } = Object.fromEntries(
        tbadataraw.map((match) => [match.key.split("_").at(-1), match]),
      );

      // Data Aggregation
      const agg: {
        [key: string]: { [key: string]: { [key: string]: Set<number> } };
      } = {}; // {match: {team: {scoretype: value}}}
      for (const scoutingEntry of data) {
        const match: string = scoutingEntry.match_scouting["match"];
        if (agg[match] == null) agg[match] = {};
        const team: string = scoutingEntry.match_scouting["team"];
        if (agg[match][team] == null) agg[match][team] = {};

        if (!(match in tbadata)) continue;
        delete scoutingEntry.match_scouting;
        delete scoutingEntry.id;
        for (let [key, value] of Object.entries(scoutingEntry)) {
          if (typeof value === "boolean") value = value ? 1 : 0;
          if (typeof value !== "number") continue;
          if (agg[match][team][key] == null) agg[match][team][key] = new Set();
          agg[match][team][key]!.add(value);
        }

        switch (params.get("season")) {
          case "2023":
            process2023TBA(agg[match][team], team, tbadata[match]);
            break;
          case "2024":
            process2024TBA(agg[match][team], team, tbadata[match]);
            break;
          case "2025":
              process2025TBA(agg[match][team], team, tbadata[match]);
              break;
        }
      }
      // Data Aggregation 2: Electric Boogaloo
      const isMedian: boolean = params.get("mode") === "median";
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
                  isMedian
                    ? [...v3].sort()[Math.floor(v3.size / 2)]
                    : [...v3].reduce((v, c) => v + c) / v3.size,
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
      // TBA Fetching
      const tbadataraw: MatchInfo[] = await fetch(
        `https://www.thebluealliance.com/api/v3/team/frc${params.get("team")}/matches/${params.get("season")}`,
        { headers: { "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")! } },
      ).then((resp) => resp.json());
      const tbadata: { [key: string]: MatchInfo } = Object.fromEntries(
        tbadataraw.map((match) => [match.key.split("_").at(-1), match]),
      );

      // Data Aggregation
      const agg: {
        [key: string]: { [key: string]: { [key: string]: Set<number> } };
      } = {}; // {event: {match: {scoretype: [values]}}}
      const team = params.get("team")!;
      for (const scoutingEntry of data) {
        const event: string = scoutingEntry.match_scouting["event"];
        if (agg[event] == null) agg[event] = {};
        const match: string = scoutingEntry.match_scouting["match"];
        if (agg[event][match] == null) agg[event][match] = {};

        delete scoutingEntry.match_scouting;
        delete scoutingEntry.id;
        for (let [key, value] of Object.entries(scoutingEntry)) {
          if (typeof value === "boolean") value = value ? 1 : 0;
          if (typeof value !== "number") continue;
          if (agg[event][match][key] == null) agg[event][match][key] = new Set();
          agg[event][match][key]!.add(value);
        }

        if (!(match in tbadata)) continue;
        switch (params.get("season")) {
          case "2023":
            process2023TBA(agg[event][match], team, tbadata[match]);
            break;
          case "2024":
            process2024TBA(agg[event][match], team, tbadata[match]);
            break;
          case "2025":
              process2025TBA(agg[event][match], team, tbadata[match]);
              break;
        }
      }
      // Data Aggregation 2: Electric Boogaloo
      const isMedian: boolean = params.get("mode") === "median";
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
                  isMedian
                    ? [...v3].sort()[Math.floor(v3.size / 2)]
                    : [...v3].reduce((v, c) => v + c) / v3.size,
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
    }
  } catch (e) {
    console.error(e);
    return new Response("Internal Server Error", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
});
