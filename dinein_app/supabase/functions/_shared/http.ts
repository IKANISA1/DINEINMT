export const corsAllowHeaders = "authorization, x-client-info, apikey, content-type";
export const corsAllowMethods = "GET, POST, OPTIONS";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": corsAllowHeaders,
  "Access-Control-Allow-Methods": corsAllowMethods,
};

export class HttpError extends Error {
  status: number;
  details?: Record<string, unknown>;

  constructor(status: number, message: string, details?: Record<string, unknown>) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export function buildResponseHeaders(origin: string | null = null): Headers {
  const headers = new Headers();
  headers.set("Access-Control-Allow-Headers", corsAllowHeaders);
  headers.set("Access-Control-Allow-Methods", corsAllowMethods);
  headers.set("Cache-Control", "no-store");
  headers.set("Pragma", "no-cache");
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Vary", "Origin");
  if (origin) {
    headers.set("Access-Control-Allow-Origin", origin);
  } else {
    // some legacy apis fallback to *
    headers.set("Access-Control-Allow-Origin", "*");
  }
  return headers;
}

export function ok(data: unknown, status = 200, origin: string | null = null): Response {
  const headers = buildResponseHeaders(origin);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify({ data }), { status, headers });
}

export function fail(message: string, status = 400, details?: Record<string, unknown>, origin: string | null = null): Response {
  const headers = buildResponseHeaders(origin);
  headers.set("Content-Type", "application/json");
  const retryAfterSeconds = typeof details?.retry_after_seconds === "number" ? details.retry_after_seconds : undefined;
  if (status == 429 && retryAfterSeconds !== undefined) {
    headers.set("Retry-After", String(Math.max(1, Math.ceil(retryAfterSeconds))));
  }
  return new Response(
    JSON.stringify({ error: message, ...(details ?? {}) }),
    { status, headers },
  );
}

export function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function errorResponse(message: string, status = 400, details?: Record<string, unknown>): Response {
  return jsonResponse(status, {
    success: false,
    message,
    ...(details ?? {}),
  });
}

export async function parseBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const json = await req.json();
    return json && typeof json == "object" && !Array.isArray(json)
      ? json as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

