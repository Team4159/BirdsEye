import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { Database } from "./database.types.ts";

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
    // for (const entry of await req.json()) params.append(entry[0], entry[1]);
    if (!params.has("season") || !(params.has("event"))) {
      return new Response(
        "Missing Required Parameters\nseason: valid frc season year (e.g. 2023)\nevent: valid tba event code (e.g. casf)",
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "text/plain" },
        },
      );
    }
    // Database Fetching
    const { data, error } = await supabase.from(`match_data_${params.get("season")}`)
      .select("*, match_scouting!inner(event, team)").eq("match_scouting.event", params.get("event"));
    if (!data || data.length === 0) {
      return new Response(
        `No Data Found for ${params.get("season")}${params.has("event") ? params.get("event") : ""}\n${error?.message}`,
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "text/plain" },
        }
      );
    }

    const agg: {[key: string]: Set<number>} = {};
    for (const entry of data) {
      const skill = entry["comments_agility"] / ( ((5 * entry["comments_fouls"] + 1) * (entry["comments_defensive"] ? 0.7 : 1)) );
      if (!agg[entry.match_scouting["team"]]) agg[entry.match_scouting["team"]] = new Set<number>();
      agg[entry.match_scouting["team"]].add(skill);
    }
    return Response.json(Object.fromEntries(
      Object.entries(agg).map(([k, v]: [string, Set<number>]) => [k, [...v.values()].reduce((a, b) => a+b) / v.size])
    ), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  } catch (e) {
    console.error(e);
    return new Response("Internal Server Error", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
});