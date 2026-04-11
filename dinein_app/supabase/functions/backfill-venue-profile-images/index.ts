import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  createVenueAdminClient,
  fetchVenueForEnrichment,
  getErrorMessage,
  isVenueEnrichmentInFlight,
  type VenueRecord,
} from "../_shared/venue-enrichment.ts";
import {
  createVenueProfileImageAdminClient,
  getVenueProfileImageEnv,
  HttpError,
  isVenueProfileImageGenerationInFlight,
  normalizeVenueProfileImageLimit,
  processVenueProfileImageGeneration,
  requireServiceInvocation,
  venueNeedsProfileImageGeneration,
} from "../_shared/venue-profile-image.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const env = getVenueProfileImageEnv();
    await requireServiceInvocation(req);

    const body = await parseJsonBody(req);
    const venueId = typeof body.venueId === "string" ? body.venueId.trim() : "";
    const limit = normalizeVenueProfileImageLimit(body.limit);
    const forceRegenerate = body.forceRegenerate === true;
    const forceGroundingRefresh = body.forceGroundingRefresh === true;
    const skipSearchGrounding = body.skipSearchGrounding === true;

    const adminClient = createVenueProfileImageAdminClient(env);
    const venues = venueId
      ? [
        await fetchVenueForEnrichment(
          adminClient as unknown as ReturnType<typeof createVenueAdminClient>,
          venueId,
        ),
      ]
      : await loadVenuesForBackfill(adminClient, limit, forceRegenerate);

    const results: unknown[] = [];
    let generated = 0;
    let skipped = 0;
    let failed = 0;

    for (const venue of venues) {
      try {
        const result = await processVenueProfileImageGeneration({
          adminClient,
          env,
          venue,
          forceRegenerate,
          forceGroundingRefresh,
          skipSearchGrounding,
        });
        results.push(result);
        if (result.status === "success") {
          generated += 1;
        } else {
          skipped += 1;
        }
      } catch (error) {
        failed += 1;
        results.push({
          venueId: venue.id,
          status: "failed",
          error: getErrorMessage(error),
        });
      }
    }

    return jsonResponse(
      {
        status: "ok",
        attempted: venues.length,
        generated,
        skipped,
        failed,
        results,
      },
      { status: 200 },
    );
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse({ error: getErrorMessage(error) }, { status });
  }
});

async function loadVenuesForBackfill(
  adminClient: ReturnType<typeof createVenueProfileImageAdminClient>,
  limit: number,
  forceRegenerate: boolean,
): Promise<VenueRecord[]> {
  const scanLimit = Math.max(limit * 5, limit);
  const { data, error } = await adminClient
    .from("dinein_venues")
    .select("*")
    .eq("image_locked", false)
    .order("last_enriched_at", { ascending: false })
    .limit(Math.min(100, scanLimit));

  if (error) {
    throw new HttpError(
      500,
      `Unable to load venues for profile image backfill: ${error.message}`,
      error,
    );
  }

  return ((data ?? []) as VenueRecord[])
    .filter((venue) =>
      !isVenueEnrichmentInFlight(venue) &&
      !isVenueProfileImageGenerationInFlight(venue) &&
      venueNeedsProfileImageGeneration(venue, forceRegenerate)
    )
    .slice(0, limit);
}

async function parseJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    return (await req.json()) as Record<string, unknown>;
  } catch (_) {
    return {};
  }
}
