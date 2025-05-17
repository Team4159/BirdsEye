
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import * as oak from "@oak/oak";
import { oakCors } from "https://deno.land/x/cors/mod.ts";
import robotRouter from "./routes/team.ts"
import eventRouter from "./routes/event.ts"

const router = new oak.Router({ prefix: "/analysis/season/:season" });
router.use(robotRouter.routes());
router.use(eventRouter.routes());

const app = new oak.Application();
app.use(oakCors()); // Enable CORS for All Routes
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
app.use(router.routes());
app.use(router.allowedMethods());
// TODO Needs an outward caching layer (using http headers probably) using etag and cache-control or whatever

app.listen();

export default { fetch: app.fetch }