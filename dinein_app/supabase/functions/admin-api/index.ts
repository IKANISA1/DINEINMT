// ─── DineIn API Edge Function (admin-api) ─────────────────────────────
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
  handleAssignAdminMenuGroup,
  handleCreateAdminMenuGroups,
  handleDeleteAdminMenuGroup,
  handleGetAdminMenuCatalog,
  handleGetAdminMenuGroupAssignments,
  handleGetAdminMenuQueue
} from "./handlers/menu-admin.ts";

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
case "get_admin_menu_queue":
          return await handleGetAdminMenuQueue(getSupabase(), req);
case "get_admin_menu_catalog":
          return await handleGetAdminMenuCatalog(getSupabase(), req);
case "get_admin_menu_group_assignments":
          return await handleGetAdminMenuGroupAssignments(getSupabase(), req, body);
case "create_admin_menu_groups":
          return await handleCreateAdminMenuGroups(getSupabase(), req, body);
case "assign_admin_menu_group":
          return await handleAssignAdminMenuGroup(getSupabase(), req, body);
case "delete_admin_menu_group":
          return await handleDeleteAdminMenuGroup(getSupabase(), req, body);
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
