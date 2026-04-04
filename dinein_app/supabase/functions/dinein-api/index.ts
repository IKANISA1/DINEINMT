// ─── DineIn API Edge Function ──────────────────────────────────────────────
// Slim dispatch entry point.  Handler logic lives in handlers/*.ts → core.ts.
// ────────────────────────────────────────────────────────────────────────────
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// ─── Core infrastructure ───────────────────────────────────────────────────
import {
  adminClient,
  asRecord,
  corsHeaders,
  fail,
  HttpError,
  MenuImageHttpError,
  ok,
  parseBody,
  requireString,
  VenueEnrichmentHttpError,
  VenueProfileImageHttpError,
} from "./core.ts";

// ─── Domain handlers ───────────────────────────────────────────────────────
import { handleCreateProfile, handleGetUserRole } from "./handlers/auth.ts";
import { handleTrackGuestEvent } from "./handlers/telemetry.ts";
import {
  handleGetVenues,
  handleGetAllVenues,
  handleCreateVenue,
  handleGetVenueBySlug,
  handleGetVenueById,
  handleGetVenueForOwner,
  handleUpdateVenue,
} from "./handlers/venue.ts";
import {
  handleGetMenuItems,
  handleGetMenuItemById,
  handleToggleMenuItemAvailability,
  handleCreateMenuItem,
  handleUpdateMenuItem,
  handleDeleteMenuItem,
  handleSetMenuItemHighlights,
} from "./handlers/menu.ts";
import {
  handleGetAdminMenuQueue,
  handleGetAdminMenuCatalog,
  handleGetAdminMenuGroupAssignments,
  handleCreateAdminMenuGroups,
  handleAssignAdminMenuGroup,
  handleDeleteAdminMenuGroup,
} from "./handlers/menu-admin.ts";
import {
  handleGenerateMenuItemImage,
  handleBackfillMenuImages,
  handleAuditMenuItemImages,
  handleEnrichVenueProfile,
  handleBackfillVenueProfiles,
  handleGenerateVenueProfileImage,
  handleBackfillVenueProfileImages,
  handleImageHealth,
} from "./handlers/image.ts";
import {
  handleGetVenueNotificationSettings,
  handleUpdateVenueNotificationSettings,
  handleRegisterPushDevice,
  handleUnregisterPushDevice,
} from "./handlers/notification.ts";
import {
  handlePlaceOrder,
  handleGetOrdersForVenue,
  handleGetOrdersForUser,
  handleGetAllOrders,
  handleGetOrderById,
  handleUpdateOrderStatus,
} from "./handlers/order.ts";
import {
  handleSendWave,
  handleGetBellRequests,
  handleResolveBellRequest,
} from "./handlers/bell.ts";
import { handleSearchGoogleMaps } from "./handlers/search.ts";

// ─── Re-exports for backward-compatible test imports ──────────────────────
export {
  assertValidOrderStatusTransition,
  generateOrderNumber,
  normalizePaymentMethod,
  normalizeVenueSupportedPaymentMethods,
  normalizeWaveTableNumber,
  orderPaymentStatusForMethod,
  resetGoogleMapsSearchRateLimitState,
  resetWaveRateLimitState,
  sanitizeOrderInsert,
  shouldGenerateAiVenueProfileImage,
  venueOrderingReadiness,
} from "./core.ts";

// ─── Main dispatch ─────────────────────────────────────────────────────────
export async function handleAppRequest(req: Request): Promise<Response> {
  if (req.method == "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await parseBody(req);
    const action = requireString(body, "action");
    const supabase = adminClient();

    switch (action) {
      case "health":
        return ok({ ok: true });
      case "create_profile":
        return await handleCreateProfile(supabase, req, body);
      case "get_user_role":
        return await handleGetUserRole(supabase, req, body);
      case "track_guest_event":
        return await handleTrackGuestEvent(supabase, req, body);
      case "get_venues":
        return await handleGetVenues(supabase, body);
      case "get_all_venues":
        return await handleGetAllVenues(supabase, req, body);
      case "create_venue":
        return await handleCreateVenue(supabase, req, body);
      case "get_venue_by_slug":
        return await handleGetVenueBySlug(supabase, req, body);
      case "get_venue_by_id":
        return await handleGetVenueById(supabase, req, body);
      case "get_venue_for_owner":
        return await handleGetVenueForOwner(supabase, req, body);
      case "update_venue":
        return await handleUpdateVenue(supabase, req, body);
      case "get_menu_items":
        return await handleGetMenuItems(supabase, req, body);
      case "get_menu_item_by_id":
        return await handleGetMenuItemById(supabase, req, body);
      case "get_admin_menu_queue":
        return await handleGetAdminMenuQueue(supabase, req);
      case "get_admin_menu_catalog":
        return await handleGetAdminMenuCatalog(supabase, req);
      case "get_admin_menu_group_assignments":
        return await handleGetAdminMenuGroupAssignments(supabase, req, body);
      case "create_admin_menu_groups":
        return await handleCreateAdminMenuGroups(supabase, req, body);
      case "assign_admin_menu_group":
        return await handleAssignAdminMenuGroup(supabase, req, body);
      case "delete_admin_menu_group":
        return await handleDeleteAdminMenuGroup(supabase, req, body);
      case "toggle_menu_item_availability":
        return await handleToggleMenuItemAvailability(supabase, req, body);
      case "create_menu_item":
        return await handleCreateMenuItem(supabase, req, body);
      case "update_menu_item":
        return await handleUpdateMenuItem(supabase, req, body);
      case "delete_menu_item":
        return await handleDeleteMenuItem(supabase, req, body);
      case "set_menu_item_highlights":
        return await handleSetMenuItemHighlights(supabase, req, body);
      case "generate_menu_item_image":
        return await handleGenerateMenuItemImage(supabase, req, body);
      case "backfill_menu_images":
        return await handleBackfillMenuImages(supabase, req, body);
      case "audit_menu_item_images":
        return await handleAuditMenuItemImages(supabase, req, body);
      case "enrich_venue_profile":
        return await handleEnrichVenueProfile(supabase, req, body);
      case "backfill_venue_profiles":
        return await handleBackfillVenueProfiles(supabase, req, body);
      case "generate_venue_profile_image":
        return await handleGenerateVenueProfileImage(supabase, req, body);
      case "backfill_venue_profile_images":
        return await handleBackfillVenueProfileImages(supabase, req, body);
      case "get_venue_notification_settings":
        return await handleGetVenueNotificationSettings(supabase, req, body);
      case "update_venue_notification_settings":
        return await handleUpdateVenueNotificationSettings(supabase, req, body);
      case "register_push_device":
        return await handleRegisterPushDevice(supabase, req, body);
      case "unregister_push_device":
        return await handleUnregisterPushDevice(supabase, req, body);
      case "place_order":
        return await handlePlaceOrder(supabase, req, body);
      case "send_wave":
        return await handleSendWave(supabase, req, body);
      case "get_bell_requests":
        return await handleGetBellRequests(supabase, req, body);
      case "resolve_bell_request":
        return await handleResolveBellRequest(supabase, req, body);
      case "get_orders_for_venue":
        return await handleGetOrdersForVenue(supabase, req, body);
      case "get_orders_for_user":
        return await handleGetOrdersForUser(supabase, req, body);
      case "get_all_orders":
        return await handleGetAllOrders(supabase, req);
      case "get_order_by_id":
        return await handleGetOrderById(supabase, req, body);
      case "update_order_status":
        return await handleUpdateOrderStatus(supabase, req, body);
      case "search_google_maps":
        return await handleSearchGoogleMaps(req, body);
      case "image_health":
        return await handleImageHealth(supabase, req);
      default:
        throw new HttpError(400, `Unsupported action: ${action}`);
    }
  } catch (error) {
    if (error instanceof HttpError) {
      return fail(error.message, error.status, error.details);
    }

    if (error instanceof MenuImageHttpError) {
      return fail(error.message, error.status, asRecord(error.details));
    }

    if (error instanceof VenueEnrichmentHttpError) {
      return fail(error.message, error.status, asRecord(error.details));
    }

    if (error instanceof VenueProfileImageHttpError) {
      return fail(error.message, error.status, asRecord(error.details));
    }

    console.error("[dinein-api] unhandled error", error);
    return fail(
      error instanceof Error ? error.message : "Unexpected server error.",
      500,
    );
  }
}

Deno.serve(handleAppRequest);
