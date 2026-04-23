// ─── DineIn API Edge Function (core-api) ─────────────────────────────
// Slim dispatch entry point. Handler logic lives in handlers/*.ts → core.ts.
// ────────────────────────────────────────────────────────────────────────────
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  applyCorsHeaders,
  assertAllowedAppOrigin,
  buildResponseHeaders,
} from "../_shared/http.ts";

// ─── Core infrastructure ───────────────────────────────────────────────────
import {
  adminClient,
  asRecord,
  fail,
  HttpError,
  ok,
  parseBody,
  requireString,
} from "../_shared/core-monolith.ts";

// ─── Domain handlers ───────────────────────────────────────────────────────
import {
  handleCreateProfile,
  handleGetUserRole
} from "./handlers/auth.ts";
import {
  handleTrackGuestEvent
} from "./handlers/telemetry.ts";

// ─── Main dispatch ─────────────────────────────────────────────────────────
export async function handleAppRequest(req: Request): Promise<Response> {
  let allowedOrigin: string | null = null;
  let action = "unknown";

  try {
    allowedOrigin = assertAllowedAppOrigin(req);
    if (req.method == "OPTIONS") {
      return new Response("ok", {
        headers: buildResponseHeaders(allowedOrigin, {
          fallbackWildcard: false,
        }),
      });
    }

    const body = await parseBody(req);
    action = requireString(body, "action");
    let supabase: ReturnType<typeof adminClient> | null = null;
    const getSupabase = () => (supabase ??= adminClient());

    const response = await (async () => {
      switch (action) {
case "health":
          return ok({ ok: true });
case "create_profile":
          return await handleCreateProfile(getSupabase(), req, body);
case "get_user_role":
          return await handleGetUserRole(getSupabase(), req, body);
case "track_guest_event":
          return await handleTrackGuestEvent(getSupabase(), req, body);
        default:
          throw new HttpError(400, `Unsupported action: ${action}`);
      }
    })();

    return applyCorsHeaders(response, allowedOrigin, {
      fallbackWildcard: false,
    });
  } catch (error) {
    if (error instanceof HttpError) {
      return applyCorsHeaders(
        fail(error.message, error.status, error.details),
        allowedOrigin,
        { fallbackWildcard: false },
      );
    }

    console.error(`[${action}] Unhandled exception:`, error);
    return applyCorsHeaders(fail("Internal Server Error", 500), allowedOrigin, {
      fallbackWildcard: false,
    });
  }
}

if (import.meta.main) {
  Deno.serve(handleAppRequest);
}
