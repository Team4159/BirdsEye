import {
  createClient,
  SupabaseClient,
} from "jsr:@supabase/supabase-js@2";
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
  let mode: keyof typeof rankMethods | undefined;
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
  if (params.has("method")) params.set("mode", params.get("method")!); // alias
  if (params.has("mode")) {
    const out = params.get("mode")!;
    if (!isValidRankMethod(out)) {
      return new HTTP400(
        "Invalid Parameter\nmode: " + Object.keys(rankMethods).join(", "),
      );
    }
    mode = out;
  }
  if (!season || !event || !mode) {
    return new HTTP400("Missing Required Parameters\nseason, event, mode");
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
});

// MatchRecord[] => score
const rankMethods = {
  "defense": sumAgg((l: {[key: string]: number | boolean}) => (l["comments_agility"] as number) / ( ((5 * (l["comments_fouls"] as number) + 1) * (l["comments_defensive"] ? 0.7 : 1)) )),

};
function isValidRankMethod(key: string): key is keyof typeof rankMethods {
  return key in rankMethods;
}
async function rankTeams(
  supabase: SupabaseClient<Database>,
  rankMode: keyof typeof rankMethods,
  season: number,
  event: string | undefined
): Promise<Response> {
    // deno-lint-ignore no-explicit-any
    let query = supabase.from(`match_data_${season}` as any)
      .select("*, match_scouting!inner(event, match, team)");
    if (event != null) query = query.eq("match_scouting.event", event);
    // deno-lint-ignore no-explicit-any
    const { data: dbdata, error } = (await query) as any; // shut up typescript
    if (!dbdata || dbdata.length === 0) {
      if (error) console.error(error);
      return new Response(
        `No Data Found for ${season}${event ?? ""}\n${error?.message ?? ""}`,
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "text/plain" },
        },
      );
    }
    
    const rankFunc = rankMethods[rankMode];
    const agg: {[key: string]: {[key: string]: number | boolean}[]} = {};
    // {team: list of matches}
    for (const { match_scouting, ...entry } of dbdata) {
      if (!agg[match_scouting.team]) agg[match_scouting.team] = [];
      const cleanedEntry = Object.fromEntries(Object.entries(entry).filter((e): e is [string, number | boolean] => typeof e[1] === "number" || typeof e[1] === "boolean"));
      agg[match_scouting.team].push(cleanedEntry);
    }
    return Response.json(Object.fromEntries(
      Object.entries(agg).map(([k, v]) => [k, rankFunc(v)])
    ), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
}

class HTTP400 extends Response {
  constructor(message: string) {
    super(message, {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "text/plain" },
    });
  }
}

function sumAgg<T>(inputFunction: (arg: T) => number): (arg: T[]) => number {
  return (arg) => arg.map(inputFunction).reduce((a, b) => a+b, 0) / arg.length;
}