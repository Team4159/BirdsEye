import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import * as oak from "@oak/oak";
import { oakCors } from "https://deno.land/x/cors/mod.ts";
import * as oakCompress from "https://deno.land/x/oak_compress@v0.0.2/mod.ts";
import { etagMiddleware } from "./cacher.ts";
import analysisRouter from "./routes/analysis.ts";
import predictionRouter from "./routes/prediction.ts";
import { createSupaClient, DBClient } from "./supabase/supabase.ts";
import { decode as decodeJWT } from '@zaubrik/djwt';

const app = new oak.Application<DBClient>();

// Global CORS and Compression Middleware
app.use(oakCors({"origin": [ "https://scouting.team4159.org", "http://localhost" ]}));
app.use(oakCompress.gzip());

// X-Response-Time Middleware
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  ctx.response.headers.set(
    "X-Response-Time",
    `${Date.now() - start}ms`
  );
});

// Serialization & Error Handling Middleware
app.use(async (ctx, next) => {
  try {
    await next();
    const resp = ctx.response.body;
    if (typeof resp === "object") {
      ctx.response.type = "application/json"
      ctx.response.body = JSON.stringify(resp);
    }
  } catch (e) {
    if (e instanceof oak.HttpError) {
      ctx.response.status = e.status;
      ctx.response.body = e.message;
      ctx.response.type = "text/plain";
    } else {
      ctx.response.status = oak.Status.InternalServerError;
      // deno-lint-ignore no-explicit-any
      ctx.response.body = (e as any).message;
      ctx.response.type = "text/plain";
    }
  }
})

// Authorization Middleware
app.use(async (ctx, next) => {
  // If the user provides a secret key, don't verify anything
  // If the key is forged, all internal requests will return nothing
  const apikey = ctx.request.headers.get("apikey");
  if (apikey?.startsWith("sb_secret_")) {
    ctx.state = createSupaClient("", apikey);
    await next();
    return;
  }

  const token = ctx.request.headers.get("Authorization");

  // If the token is not present or empty, immediately reject.
  if (!token) throw oak.createHttpError(oak.Status.Forbidden, "Missing Authorization Header");
  
  // Extract user information from the token
  let userid;
  try {
    const [_header, user, _signature] = decodeJWT(token.replace('Bearer ', ''))
    // deno-lint-ignore no-explicit-any
    const userCast: any = user;
    
    if (!userCast || !("sub" in userCast)) throw new Error();

    userid = userCast.sub;
  } catch (_) {
    throw oak.createHttpError(oak.Status.Forbidden, "Bad Authorization Header")
  }

  // Create a client with the token
  const client = createSupaClient(token);
  
  // Determine & check the user's permissions
  const perms = await client.from("permissions").select("graph_viewer").eq("id", userid).maybeSingle();
  if (!perms.data?.graph_viewer) throw oak.createHttpError(oak.Status.Forbidden, "Insufficient Permissions");

  // Pass the client down
  ctx.state = client;
  await next();
})

// ETag Middleware
app.use(etagMiddleware);

analysisRouter.use(predictionRouter.routes()); // Ideally this should be top-level, but edge functions must start with "/funcname"
app.use(analysisRouter.routes());
app.use(analysisRouter.allowedMethods());


app.listen();

export default { fetch: app.fetch }