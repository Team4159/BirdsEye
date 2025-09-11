import axios from "axios";
import {
  AxiosCacheInstance,
  CacheRequestConfig,
  setupCache,
} from "axios-cache-interceptor";
import createAxiosDeduplicatorInstance from "axios-deduplicator";
import axiosRetry from "axios-retry";

export function createFetcher(
  cacheOverride: number | undefined = undefined,
  debug: boolean = false,
): AxiosCacheInstance {
  const axiosDeduplicator = createAxiosDeduplicatorInstance({
    repeatWindowMs: 1000,
    started: debug
      ? (key, _) => {
        console.log(`Deduplication\t`, key);
      }
      : undefined,
  });

  const axiosInstance = setupCache(
    axios.create({
      headers: { "X-TBA-Auth-Key": Deno.env.get("TBA_KEY")! },
      responseType: "json",
    }),
    cacheOverride === undefined
        ? { etag: true, interpretHeader: true }
        : { interpretHeader: false, ttl: cacheOverride }
,
  );
  axiosInstance.interceptors.request.use(
    axiosDeduplicator.requestInterceptor,
  );
  axiosInstance.interceptors.response.use(
    axiosDeduplicator.responseInterceptorFulfilled,
    axiosDeduplicator.responseInterceptorRejected,
  );
  axiosRetry(axios, { retries: 3, retryDelay: axiosRetry.exponentialDelay });

  if (debug) {
    axiosInstance.interceptors.request.use(
      (request) => {
        const url = URL.parse(request.url!)!;
        const trimmed = new URLSearchParams(
          url.searchParams.entries().map((
            [k, v],
          ) => [k, v.length > 40 ? v.substring(0, 37) + "..." : v]),
        );
        console.log(
          `Request (#${
            request["axios-retry"]?.retryCount ?? 0
          }):\t ${url?.pathname}?${trimmed.toString()}`,
        );
        return request;
      },
    );
    axiosInstance.interceptors.response.use((response) => {
      console.log(
        `Response (${response.status}): ${response.statusText},`,
        response.cached ? "Cache" : "Fresh",
      );
      return response;
    });
  }

  return axiosInstance;
}

export function fetchWrapper(axios: AxiosCacheInstance) {
  const encoder = new TextEncoder();
  return async (
    input: RequestInfo | URL,
    init?: RequestInit & { client?: Deno.HttpClient },
  ): Promise<Response> => {
    // Extract URL and method from input
    const url = typeof input === "string"
      ? input
      : "url" in input
      ? input.url
      : input.toString();
    const method =
      (typeof input !== "string" && "method" in input
        ? input.method
        : init?.method) || "GET";

    // Convert headers to Axios format
    const headers = new Headers(
      typeof input !== "string" && "headers" in input
        ? input.headers
        : init?.headers,
    ); // TODO optimize
    const axiosHeaders: Record<string, string> = {};
    headers.forEach((value, key) => {
      axiosHeaders[key] = value;
    });

    // Prepare Axios config
    const config: CacheRequestConfig = {
      url,
      method: method.toLowerCase(),
      headers: axiosHeaders,
      data: init?.body,
      validateStatus: null, // Don't throw on HTTP error status codes
    };

    // Map credentials option
    if (init?.credentials) {
      config.withCredentials = init.credentials === "include";
    }

    // Handle signal (abort controller)
    if (init?.signal) {
      config.signal = init.signal;
    }

    // Make request with Axios
    const response = await axios.request(config);

    const str = JSON.stringify(response.data);
    const bytes = encoder.encode(str);
    const blob = new Blob([bytes], { type: "application/json;charset=utf-8" });

    // Convert Axios response to Fetch Response
    return new Response(blob, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers as Record<string, string>,
    });
  };
}
