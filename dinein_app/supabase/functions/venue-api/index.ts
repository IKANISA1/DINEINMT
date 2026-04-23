// ─── DineIn API Edge Function (venue-api) ─────────────────────────────
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
  handleCreateVenue,
  handleGetAllVenues,
  handleGetVenueById,
  handleGetVenueBySlug,
  handleGetVenueForOwner,
  handleGetVenues,
  handleUpdateVenue
} from "./handlers/venue.ts";
import {
  handleGetBellRequests,
  handleResolveBellRequest,
  handleSendWave
} from "./handlers/bell.ts";
import {
  handleSearchGoogleMaps
} from "./handlers/search.ts";
import {
  handleGetVenueNotificationSettings,
  handleRegisterPushDevice,
  handleUnregisterPushDevice,
  handleUpdateVenueNotificationSettings
} from "./handlers/notification.ts";
import {
  handleEnrichVenueProfile,
  handleBackfillVenueProfiles,
  handleGenerateVenueProfileImage,
  handleBackfillVenueProfileImages,
  handleUploadVenueImage
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
case "get_venues":
          return await handleGetVenues(getSupabase(), body);
case "get_all_venues":
          return await handleGetAllVenues(getSupabase(), req, body);
case "create_venue":
          return await handleCreateVenue(getSupabase(), req, body);
case "get_venue_by_slug":
          return await handleGetVenueBySlug(getSupabase(), req, body);
case "get_venue_by_id":
          return await handleGetVenueById(getSupabase(), req, body);
case "get_venue_for_owner":
          return await handleGetVenueForOwner(getSupabase(), req, body);
case "update_venue":
          return await handleUpdateVenue(getSupabase(), req, body);
case "enrich_venue_profile":
          return await handleEnrichVenueProfile(getSupabase(), req, body);
case "backfill_venue_profiles":
          return await handleBackfillVenueProfiles(getSupabase(), req, body);
case "generate_venue_profile_image":
          return await handleGenerateVenueProfileImage(getSupabase(), req, body);
case "backfill_venue_profile_images":
          return await handleBackfillVenueProfileImages(getSupabase(), req, body);
case "get_venue_notification_settings":
          return await handleGetVenueNotificationSettings(getSupabase(), req, body);
case "update_venue_notification_settings":
          return await handleUpdateVenueNotificationSettings(
            getSupabase(),
            req,
            body,
          );
case "register_push_device":
          return await handleRegisterPushDevice(getSupabase(), req, body);
case "unregister_push_device":
          return await handleUnregisterPushDevice(getSupabase(), req, body);
case "send_wave":
          return await handleSendWave(getSupabase(), req, body);
case "get_bell_requests":
          return await handleGetBellRequests(getSupabase(), req, body);
case "resolve_bell_request":
          return await handleResolveBellRequest(getSupabase(), req, body);
case "search_google_maps":
          return await handleSearchGoogleMaps(req, body);
case "upload_venue_image":
          return await handleUploadVenueImage(getSupabase(), req, body);
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
