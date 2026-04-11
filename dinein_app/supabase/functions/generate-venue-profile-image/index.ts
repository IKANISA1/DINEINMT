import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  createVenueAdminClient,
  fetchVenueForEnrichment,
} from "../_shared/venue-enrichment.ts";
import {
  createVenueProfileImageAdminClient,
  getErrorMessage,
  getVenueProfileImageEnv,
  HttpError,
  processVenueProfileImageGeneration,
  requireServiceInvocation,
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
    const forceRegenerate = body.forceRegenerate === true;
    const forceGroundingRefresh = body.forceGroundingRefresh === true;
    const skipSearchGrounding = body.skipSearchGrounding === true;

    if (!venueId) {
      throw new HttpError(400, "venueId is required.");
    }

    const adminClient = createVenueProfileImageAdminClient(env);
    const venue = await fetchVenueForEnrichment(
      adminClient as unknown as ReturnType<typeof createVenueAdminClient>,
      venueId,
    );
    const result = await processVenueProfileImageGeneration({
      adminClient,
      env,
      venue,
      forceRegenerate,
      forceGroundingRefresh,
      skipSearchGrounding,
    });

    return jsonResponse(result, { status: 200 });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse({ error: getErrorMessage(error) }, { status });
  }
});

async function parseJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    return (await req.json()) as Record<string, unknown>;
  } catch (_) {
    return {};
  }
}
