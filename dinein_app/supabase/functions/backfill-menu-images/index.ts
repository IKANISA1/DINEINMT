import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  assertVenueAccess,
  createAdminClient,
  fetchVenue,
  getErrorMessage,
  getFunctionEnv,
  HttpError,
  MenuItemRecord,
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
    const actor = await resolveInvocationActor(req, env);
    const venueId =
      typeof body.venueId === "string" && body.venueId.trim().length > 0
        ? body.venueId.trim()
        : null;
    const limit = normalizeLimit(body.limit);
    const forceRegenerate = body.forceRegenerate === true;

    if (actor.kind !== "service" && actor.kind !== "cron" && !venueId) {
      throw new HttpError(
        400,
        "venueId is required when a venue owner triggers a backfill.",
      );
    }

    const adminClient = createAdminClient(env);

    if (venueId) {
      const venue = await fetchVenue(adminClient, venueId);
      await assertVenueAccess(actor, venue, adminClient, body);
    }

    let query = adminClient
      .from("dinein_menu_items")
      .select(
        "id, venue_id, name, description, category, class, menu_context, menu_context_status, menu_context_error, menu_context_model, menu_context_attempts, menu_context_locked, menu_context_updated_at, image_url, image_source, image_status, image_model, image_error, image_attempts, image_locked, image_storage_path, tags",
      )
      .eq("image_locked", false)
      .order("id")
      .limit(limit);

    if (venueId) {
      query = query.eq("venue_id", venueId);
    }

    query = forceRegenerate
      ? query.or(
        "image_url.is.null,image_status.eq.failed,image_source.eq.ai_gemini",
      )
      : query.or("image_url.is.null,image_status.eq.failed");

    const { data, error } = await query;
    if (error) {
      throw new HttpError(
        500,
        `Unable to load menu items for backfill: ${error.message}`,
        error,
      );
    }

    const items = (data ?? []) as unknown as MenuItemRecord[];
    const venueCache = new Map<
      string,
      Awaited<ReturnType<typeof fetchVenue>>
    >();
    const results: unknown[] = [];
    let generated = 0;
    let skipped = 0;
    let failed = 0;

    for (const item of items) {
      let venue = venueCache.get(item.venue_id);
      if (!venue) {
        venue = await fetchVenue(adminClient, item.venue_id);
        venueCache.set(item.venue_id, venue);
      }

      try {
        await assertVenueAccess(actor, venue, adminClient, body);
        const result = await processMenuItemImageGeneration({
          adminClient,
          env,
          item,
          venue,
          forceRegenerate,
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
          itemId: item.id,
          venueId: item.venue_id,
          status: "failed",
          error: getErrorMessage(error),
        });
      }
    }

    return jsonResponse(
      {
        status: "ok",
        venueId,
        attempted: items.length,
        generated,
        skipped,
        failed,
        results,
      },
      { status: 200 },
    );
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

function normalizeLimit(value: unknown): number {
  if (typeof value !== "number") return 12;
  if (!Number.isFinite(value)) return 12;
  return Math.max(1, Math.min(25, Math.floor(value)));
}
