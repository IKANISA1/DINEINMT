export const corsAllowHeaders =
  "authorization, x-client-info, apikey, content-type";
export const corsAllowMethods = "GET, POST, OPTIONS";
const defaultAllowedAppOrigins = [
  "https://dineinmt.ikanisa.com",
  "https://www.dineinmt.ikanisa.com",
  "https://dineinmtg.ikanisa.com",
  "https://dineinmtv.ikanisa.com",
  "https://dineinmta.ikanisa.com",
  "https://dineinrw.ikanisa.com",
  "https://www.dineinrw.ikanisa.com",
  "https://dineinrwg.ikanisa.com",
  "https://dineinrwv.ikanisa.com",
  "https://dineinrwa.ikanisa.com",
];

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": corsAllowHeaders,
  "Access-Control-Allow-Methods": corsAllowMethods,
};

export class HttpError extends Error {
  status: number;
  details?: Record<string, unknown>;

  constructor(
    status: number,
    message: string,
    details?: Record<string, unknown>,
  ) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export function normalizeOrigin(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed || trimmed == "null") {
    return null;
  }

  try {
    return new URL(trimmed).origin;
  } catch {
    return null;
  }
}

function isLocalDevelopmentOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    return ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
  } catch {
    return false;
  }
}

export function allowedAppOrigins(): string[] {
  const configured = Deno.env.get("APP_ALLOWED_ORIGINS");
  const candidates = (configured?.split(",") ?? defaultAllowedAppOrigins)
    .map((value) => normalizeOrigin(value))
    .filter((value): value is string => Boolean(value));

  return [...new Set(candidates)];
}

export function resolveAllowedAppOrigin(origin: string | null): string | null {
  const normalized = origin ? normalizeOrigin(origin) : null;
  if (!normalized) {
    return null;
  }
  if (isLocalDevelopmentOrigin(normalized)) {
    return normalized;
  }
  return allowedAppOrigins().includes(normalized) ? normalized : null;
}

export function assertAllowedAppOrigin(req: Request): string | null {
  const origin = req.headers.get("origin");
  if (!origin) {
    return null;
  }

  const allowedOrigin = resolveAllowedAppOrigin(origin);
  if (!allowedOrigin) {
    throw new HttpError(403, "Origin not allowed.", {
      code: "origin_not_allowed",
    });
  }

  return allowedOrigin;
}

type BuildHeaderOptions = {
  fallbackWildcard?: boolean;
};

export function buildResponseHeaders(
  origin: string | null = null,
  options: BuildHeaderOptions = {},
): Headers {
  const { fallbackWildcard = true } = options;
  const headers = new Headers();
  headers.set("Access-Control-Allow-Headers", corsAllowHeaders);
  headers.set("Access-Control-Allow-Methods", corsAllowMethods);
  headers.set("Cache-Control", "no-store");
  headers.set("Pragma", "no-cache");
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Vary", "Origin");
  const allowedOrigin = resolveAllowedAppOrigin(origin);
  if (allowedOrigin) {
    headers.set("Access-Control-Allow-Origin", allowedOrigin);
  } else if (fallbackWildcard) {
    headers.set("Access-Control-Allow-Origin", "*");
  }
  return headers;
}

export function applyCorsHeaders(
  response: Response,
  origin: string | null = null,
  options: BuildHeaderOptions = {},
): Response {
  const headers = new Headers(response.headers);
  const corsHeadersForOrigin = buildResponseHeaders(origin, options);
  for (const [key, value] of corsHeadersForOrigin.entries()) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export function ok(
  data: unknown,
  status = 200,
  origin: string | null = null,
): Response {
  const headers = buildResponseHeaders(origin);
  headers.set("Content-Type", "application/json");
  return new Response(JSON.stringify({ data }), { status, headers });
}

export function fail(
  message: string,
  status = 400,
  details?: Record<string, unknown>,
  origin: string | null = null,
): Response {
  const headers = buildResponseHeaders(origin);
  headers.set("Content-Type", "application/json");
  const retryAfterSeconds = typeof details?.retry_after_seconds === "number"
    ? details.retry_after_seconds
    : undefined;
  if (status == 429 && retryAfterSeconds !== undefined) {
    headers.set(
      "Retry-After",
      String(Math.max(1, Math.ceil(retryAfterSeconds))),
    );
  }
  return new Response(
    JSON.stringify({ error: message, ...(details ?? {}) }),
    { status, headers },
  );
}

export function jsonResponse(
  status: number,
  body: Record<string, unknown>,
  origin: string | null = null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: (() => {
      const headers = buildResponseHeaders(origin);
      headers.set("Content-Type", "application/json");
      return headers;
    })(),
  });
}

export function errorResponse(
  message: string,
  status = 400,
  details?: Record<string, unknown>,
  origin: string | null = null,
): Response {
  return jsonResponse(status, {
    success: false,
    message,
    ...(details ?? {}),
  }, origin);
}

export async function parseBody(
  req: Request,
): Promise<Record<string, unknown>> {
  try {
    const json = await req.json();
    return json && typeof json == "object" && !Array.isArray(json)
      ? json as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}
