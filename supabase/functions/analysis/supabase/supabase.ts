import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { Database } from "./database.types.ts";
import { createFetcher, fetchWrapper } from "../fetcher.ts";

/**
 * the Supabase Client for the Database
 */
export type DBClient = SupabaseClient<Database>;

export function createSupaClient(authorization: string, apikey = Deno.env.get("SUPABASE_ANON_KEY")!): DBClient {
  return createClient<Database>(
    Deno.env.get("SUPABASE_URL")!,
    apikey,
    {
      global: {
        headers: { Authorization: authorization },
        fetch: fetchWrapper(createFetcher())
      },
    },
  );
}
