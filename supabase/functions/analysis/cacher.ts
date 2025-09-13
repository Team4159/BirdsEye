import { Middleware } from "@oak/oak";
import { crypto } from "@std/crypto";

const byteToHex: string[] = [];
for (let n = 0; n <= 0xff; ++n) {
  const hexOctet = n.toString(16).padStart(2, "0");
  byteToHex.push(hexOctet);
}

function hex(arrayBuffer: ArrayBuffer) {
  const buff = new Uint8Array(arrayBuffer);
  const hexOctets = new Array(buff.length);

  for (let i = 0; i < buff.length; ++i)
    hexOctets[i] = byteToHex[buff[i]!];

  return hexOctets.join("");
}

// Middleware to handle ETags for all routes
export const etagMiddleware: Middleware = async (ctx, next) => {
  await next();

  // Skip ETag for non-GET and non-successful responses
  if (ctx.request.method !== "GET" || ctx.response.status !== 200) return;

  // Skip ETag for empty responses
  if (ctx.response.body === undefined) return;

  const body = ctx.response.body;

  // Convert body into a hashable form
  let buffer: Uint8Array;
  if (typeof body === "string") {
    const enc = new TextEncoder();
    buffer = enc.encode(body);
  } else if (body instanceof Uint8Array) {
    buffer = body;
  } else {
    // Skip ETag for unhashable responses
    return;
  }

  const hash = await crypto.subtle.digest("SHA-256", buffer);
  const etag = `W/"${hex(hash)}"`
  ctx.response.headers.set("ETag", etag);
  
  const ifNoneMatch = ctx.request.headers.get("if-none-match");
  if (ifNoneMatch && ifNoneMatch === etag) {
    // Resource hasn't changed, return 304
    ctx.response.body = undefined;
    ctx.response.status = 304;
    return;
  }
}

export function maxAgeMiddleware(maxAgeSeconds: number): Middleware {
  return async (ctx, next) => {
    await next();
    ctx.response.headers.set("Cache-Control", `public, max-age=${maxAgeSeconds}`);
  };
}