import { SupabaseClient, createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { Database } from "./database.types.ts";

// more clearly, this should be called "event_ranker"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
  "authorization, x-client-info, apikey, content-type",
};

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
  let mode: string = "defense";
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
  if (!season || !event) {
    return new HTTP400("Missing Required Parameters\nseason, event");
  }
  if (params.has("mode")) {
    // deno-lint-ignore no-explicit-any
    const out = params.get("mode") as any;
    if (!(out in rankMethods)) {
      return new HTTP400(
        "Invalid Parameter\nmode: " + Object.keys(rankMethods).join(", "),
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

    return await rankTeams(supabase, mode, season, event);
  } catch (e) {
    console.error(e);
    return new Response("Internal Server Error", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
}

function rankTeams(supabase: SupabaseClient<Database>, mode, season: number, event: string) {
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
    
    const rankFunc = rankMethods[mode]!;
    const agg: {[key: string]: Set<number>} = {};
    // {team: heuristic (one per match)}
    for (const { match_scouting, ...en......................try } of data) {
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

const rankMethods: {[key: string]: RankFunction} = {
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


class HTTP400 extends Response {
  constructor(message: string) {
    super(message, {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
}
