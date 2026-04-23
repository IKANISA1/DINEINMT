// ─── DineIn API Edge Function (menu-api) ─────────────────────────────
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
  handleCreateMenuItem,
  handleDeleteMenuItem,
  handleGetMenuItemById,
  handleGetMenuItems,
  handleIngestMenuDocument,
  handleSetMenuItemHighlights,
  handleToggleMenuItemAvailability,
  handleUpdateMenuItem
} from "./handlers/menu.ts";
import {
  handleGenerateMenuItemImage,
  handleBackfillMenuImages,
  handleAuditMenuItemImages,
  handleUploadMenuItemImage,
  handleImageHealth
} from "./handlers/image.ts";

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
case "get_menu_items":
          return await handleGetMenuItems(getSupabase(), req, body);
case "get_menu_item_by_id":
          return await handleGetMenuItemById(getSupabase(), req, body);
case "toggle_menu_item_availability":
          return await handleToggleMenuItemAvailability(getSupabase(), req, body);
case "create_menu_item":
          return await handleCreateMenuItem(getSupabase(), req, body);
case "update_menu_item":
          return await handleUpdateMenuItem(getSupabase(), req, body);
case "delete_menu_item":
          return await handleDeleteMenuItem(getSupabase(), req, body);
case "set_menu_item_highlights":
          return await handleSetMenuItemHighlights(getSupabase(), req, body);
case "ingest_menu_document":
          return await handleIngestMenuDocument(getSupabase(), req, body);
case "generate_menu_item_image":
          return await handleGenerateMenuItemImage(getSupabase(), req, body);
case "backfill_menu_images":
          return await handleBackfillMenuImages(getSupabase(), req, body);
case "audit_menu_item_images":
          return await handleAuditMenuItemImages(getSupabase(), req, body);
case "upload_menu_item_image":
          return await handleUploadMenuItemImage(getSupabase(), req, body);
case "image_health":
          return await handleImageHealth(getSupabase(), req);
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
