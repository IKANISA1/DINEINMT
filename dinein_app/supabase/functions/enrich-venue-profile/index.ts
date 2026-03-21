import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  createVenueAdminClient,
  fetchVenueForEnrichment,
  getErrorMessage,
  getVenueEnrichmentEnv,
  HttpError,
  processVenueEnrichment,
  requireServiceOrCronInvocation,
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
    const overwriteExisting = body.overwriteExisting === true;
    const forcePlaceRefresh = body.forcePlaceRefresh === true;
    const skipSearchGrounding = body.skipSearchGrounding === true;

    if (!venueId) {
      throw new HttpError(400, "venueId is required.");
    }

    const adminClient = createVenueAdminClient(env);
    const venue = await fetchVenueForEnrichment(adminClient, venueId);
    const result = await processVenueEnrichment({
      adminClient,
      env,
      venue,
      overwriteExisting,
      forcePlaceRefresh,
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
