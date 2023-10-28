import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
// import { Database } from './database.types.ts'

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabase = createClient( // <Database>
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {global: {headers: {authorization: req.headers.get('Authorization')!}}}
  )

  // Request Argument Validation
  const params: URLSearchParams = new URL(req.url).searchParams;
  // for (const entry of await req.json()) params.append(entry[0], entry[1]);
  if (!params.has("season") || !params.has("event")) {
    return new Response(
      "Missing Required Parameters\nseason: valid frc season year (e.g. 2023)\nevent: valid tba event code (e.g. casf)",
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "text/plain" },
      }
    );
  }
  // Database Fetching
  const { data } = await supabase
    .from(`${params.get("season")}_match`)
    .select()
    .eq("event", params.get("event")!);
  if (!data || data.length === 0) {
    return new Response(
      `No Data Found for ${params.get("season")}${params.get("event")}`,
      {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "text/plain" },
      }
    );
  }
  if (params.get("type") === "text") {
    // Data Aggregation
    const agg: { [key: number]: { [key: string]: { [key: string]: string } } } =
      {}; // {team: {match: {question: value}}}
    for (const scoutingEntry of data) {
      const team: number = parseInt(scoutingEntry["team"]);
      if (agg[team] == null) agg[team] = {};
      const match: string = scoutingEntry["match"];
      if (agg[team][match] == null) agg[team][match] = {};
      const scouter: string | undefined = scoutingEntry["scouter"];
      ["event", "match", "team", "scouter"].forEach((k) =>
        delete scoutingEntry[k]
      );
      for (const [key, value] of Object.entries(scoutingEntry)) {
        if (!(typeof value === "string") || value.length === 0) continue;
        if (agg[team][match][key] == null) agg[team][match][key] = "";
        agg[team][match][key] = `${
          agg[team][match][key]
        }\n${scouter}: ${value}`;
      }
    }
    // Return
    return Response.json(agg, {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  } else {
    // Data Aggregation
    const agg: {
      [key: string]: { [key: number]: { [key: string]: Set<number> } };
    } = {}; // {match: {team: {scoretype: value}}}
    for (const scoutingEntry of data) {
      const match: string = scoutingEntry["match"];
      if (agg[match] == null) agg[match] = {};
      const team: number = parseInt(scoutingEntry["team"]);
      if (agg[match][team] == null) agg[match][team] = {};
      ["event", "match", "team", "scouter"].forEach((k) =>
        delete scoutingEntry[k]
      );
      for (let [key, value] of Object.entries(scoutingEntry)) {
        if (typeof value === "boolean") value = value ? 1 : 0;
        if (typeof value !== "number") continue;
        if (agg[match][team][key] == null) agg[match][team][key] = new Set();
        agg[match][team][key]!.add(value);
      }
    }
    // Data Aggregation 2: Electric Boogaloo
    const isMedian: boolean = params.get("mode") === "median";
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
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
