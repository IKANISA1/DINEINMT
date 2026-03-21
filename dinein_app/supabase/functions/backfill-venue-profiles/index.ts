import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  createVenueAdminClient,
  fetchVenueForEnrichment,
  getErrorMessage,
  getVenueEnrichmentEnv,
  HttpError,
  isVenueEnrichmentInFlight,
  normalizeVenueEnrichmentLimit,
  processVenueEnrichment,
  requireServiceOrCronInvocation,
  venueNeedsEnrichment,
  type VenueRecord,
} from "../_shared/venue-enrichment.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const env = getVenueEnrichmentEnv();
    requireServiceOrCronInvocation(req, env);

    const body = await parseJsonBody(req);
    const venueId = typeof body.venueId === "string" ? body.venueId.trim() : "";
    const limit = normalizeVenueEnrichmentLimit(body.limit);
    const overwriteExisting = body.overwriteExisting === true;
    const forcePlaceRefresh = body.forcePlaceRefresh === true;
    const skipSearchGrounding = body.skipSearchGrounding === true;

    const adminClient = createVenueAdminClient(env);
    const venues = venueId
      ? [await fetchVenueForEnrichment(adminClient, venueId)]
      : await loadVenuesForBackfill(adminClient, limit, overwriteExisting);

    const results: unknown[] = [];
    let enriched = 0;
    let skipped = 0;
    let failed = 0;

    for (const venue of venues) {
      try {
        const result = await processVenueEnrichment({
          adminClient,
          env,
          venue,
          overwriteExisting,
          forcePlaceRefresh,
          skipSearchGrounding,
        });
        results.push(result);
        if (result.status === "success") {
          enriched += 1;
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
        enriched,
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
  adminClient: ReturnType<typeof createVenueAdminClient>,
  limit: number,
  overwriteExisting: boolean,
): Promise<VenueRecord[]> {
  const scanLimit = Math.max(limit * 5, limit);
  const { data, error } = await adminClient
    .from("dinein_venues")
    .select("*")
    .eq("enrichment_locked", false)
    .order("last_enriched_at", { ascending: true })
    .limit(Math.min(100, scanLimit));

  if (error) {
    throw new HttpError(
      500,
      `Unable to load venues for profile backfill: ${error.message}`,
      error,
    );
  }

  return ((data ?? []) as VenueRecord[])
    .filter((venue) =>
      !isVenueEnrichmentInFlight(venue) &&
      venueNeedsEnrichment(venue, overwriteExisting)
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
