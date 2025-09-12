import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import * as oak from "@oak/oak";
import { oakCors } from "https://deno.land/x/cors/mod.ts";
import * as oakCompress from "https://deno.land/x/oak_compress@v0.0.2/mod.ts";
import analysisRouter from "./routes/analysis.ts";
import predictionRouter from "./routes/prediction.ts";

const app = new oak.Application();
app.use(oakCors({"origin": [ "https://scouting.team4159.org", "http://localhost" ]})); // Enable CORS for All Routes
app.use(oakCompress.gzip());
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  ctx.response.headers.set(
    "X-Response-Time",
    `${Date.now() - start}ms`
  );
});
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
      ctx.response.body = { error: (e as any).message };
      ctx.response.type = "application/json";
    }
  }
})
app.use(analysisRouter.routes());
app.use(analysisRouter.allowedMethods());
app.use(predictionRouter.routes());
app.use(predictionRouter.allowedMethods());
// TODO Needs an outward caching layer (using http headers probably) using etag and cache-control or whatever

app.listen();

export default { fetch: app.fetch }