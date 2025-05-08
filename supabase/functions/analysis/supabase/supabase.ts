import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { Database } from "./database.types.ts";

/**
 * the Supabase Client for the Database
 */
export type DBClient = SupabaseClient<Database>;

export function createSupaClient(authorization: string): DBClient {
  return createClient<Database>(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { // comment this out while in development
      global: {
        headers: { authorization: authorization },
      },
    },
  );
}
