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
    for (const entry of await req.json()
        .then((p) => Object.entries<string>(p))
        .catch((e) => {console.warn(e); return []}))
      params.append(entry[0], entry[1]);
    if (!params.has("season") || !(params.has("event") || !params.has("method") || !(params.get("method")! in rankFunctions))) {
      return new Response(
        "Missing Required Parameters\nseason: valid frc season year (e.g. 2023)\nevent: valid tba event code (e.g. casf)\nmethod: metric to rank on "+`(e.g. ${Object.keys(rankFunctions).join(", ")})`,
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "text/plain" },
        },
      );
    }

    let data: any, error: any = null;

    if (params.get('season') === '2025') {
      ({ data, error } = await supabase.from('sum_coral_view')
        .select('*')
        .eq('event', params.get('event')));
    } else {
      ({ data, error } = await supabase.from(`match_data_${params.get("season")}`)
        .select("*, match_scouting!inner(event, team)")
        .eq("match_scouting.event", params.get("event")));
    }

    if (!data || data.length === 0) {
      return new Response(
        `No Data Found for ${params.get('season')}${params.has('event') ? params.get('event') : ''}\n${error?.message}`,
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
        }
      );
    }



    const rankFunc = rankFunctions[params.get("method")!]!;
    const agg: {[key: string]: Set<number>} = {};
    for (const { match_scouting, ...entry } of data) {
      if (!agg[match_scouting!.team]) agg[match_scouting!.team] = new Set<number>();
      agg[match_scouting!.team].add(rankFunc(entry));
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

interface RankFunction {
  (entry: {[key: string]: number | boolean}): number;
}

const rankFunctions: {[key: string]: RankFunction} = {
  "defense": (entry) => (entry["comments_agility"] as number) / ( ((5 * (entry["comments_fouls"] as number) + 1) * (entry["comments_defensive"] ? 0.7 : 1)) ),
  "accuracy": (entry) => {
    const b = Object.keys(entry).filter(k => {
      if (!k.endsWith("_missed")) return false;
      const g: number | boolean | undefined = entry[k.slice(0, -7)];
      if (typeof g !== "number") return false;
      return g !== 0 || entry[k] !== 0;
    });
    return b.map(k => {
      const denom = entry[k.slice(0, -7)] as number;
      if (denom === 0) return -0.5;
      return 1 - (entry[k] as number / denom)
    }).reduce((a, b) => a+b, 0) / b.length;
  }
}

