import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  assertVenueAccess,
  createAdminClient,
  fetchMenuItem,
  fetchVenue,
  getErrorMessage,
  getFunctionEnv,
  HttpError,
  processMenuItemImageGeneration,
  resolveInvocationActor,
} from "../_shared/menu-image.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const env = getFunctionEnv();
    const body = await parseJsonBody(req);
    const itemId = typeof body.itemId === "string" ? body.itemId.trim() : "";
    const forceRegenerate = body.forceRegenerate === true;

    if (!itemId) {
      throw new HttpError(400, "itemId is required.");
    }

    const adminClient = createAdminClient(env);
    const actor = await resolveInvocationActor(req, env);
    const item = await fetchMenuItem(adminClient, itemId);
    const venue = await fetchVenue(adminClient, item.venue_id);

    await assertVenueAccess(actor, venue);

    const result = await processMenuItemImageGeneration({
      adminClient,
      env,
      item,
      venue,
      forceRegenerate,
    });

    return jsonResponse(result, { status: 200 });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse(
      {
        error: getErrorMessage(error),
      },
      { status },
    );
  }
});

async function parseJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    return (await req.json()) as Record<string, unknown>;
  } catch (_) {
    return {};
  }
}
