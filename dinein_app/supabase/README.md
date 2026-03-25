# AI Content Setup

This Supabase project now includes two production AI pipelines:

- Gemini-powered menu image generation
- Gemini Google Maps grounding plus Gemini Search-grounded venue profile enrichment
- Gemini-powered venue profile image generation
- Firebase Cloud Messaging delivery for venue operational push alerts

## Project Environments

| | **Rwanda (RW)** | **Malta (MT)** |
|---|---|---|
| **Project Ref** | `kczghhipbyykluuiiunp` | `uskfnszcdqpcfrhjxitl` |
| **API URL** | `https://kczghhipbyykluuiiunp.supabase.co` | `https://uskfnszcdqpcfrhjxitl.supabase.co` |
| **Country Code** | `250` | `356` |
| **Default Currency** | `RWF` | `EUR` |
| **WhatsApp Template** | `gikundiro` | *(MT template)* |
| **Table Pattern** | Base tables (`venues`) + `dinein_*` views | `dinein_*` tables directly |

> **⚠️ Schema difference:** RW uses base table names (`venues`, `profiles`,
> `orders`, etc.) with `dinein_*` views aliasing them for edge function
> compatibility. MT uses `dinein_*` prefixed tables directly. Edge functions
> reference `dinein_*` names on both projects.

## What Was Added

- A migration that extends `dinein_menu_items` with AI image metadata and creates the `menu-images` storage bucket.
- A follow-up migration that explicitly grants `service_role` and app roles access to the DineIn tables.
- `generate-menu-item-image` for single-item generation and regeneration.
- `backfill-menu-images` for batch-filling missing images.
- A migration that extends `dinein_venues` with Google provider metadata, web links, review snapshots, and enrichment status fields.
- `enrich-venue-profile` for a single-venue refresh using Gemini Google Maps grounding plus Gemini Google Search grounding.
- `backfill-venue-profiles` for batch venue enrichment.
- `generate-venue-profile-image` for single-venue AI profile image generation.
- `backfill-venue-profile-images` for batch venue image backfill.

## Required Secrets

Set these in **each** Supabase project before deploying the functions:

```bash
# Replace --project-ref with the target project
supabase secrets set \
  GEMINI_API_KEY=your_google_api_key \
  GEMINI_IMAGE_MODELS=gemini-3.1-flash-image-preview,gemini-2.5-flash-image \
  GEMINI_VENUE_MODELS=gemini-2.5-flash,gemini-2.5-flash-lite \
  GEMINI_VENUE_IMAGE_MODELS=gemini-2.5-flash-image \
  FIREBASE_PROJECT_ID=your_firebase_project_id \
  FIREBASE_CLIENT_EMAIL=your_service_account_email \
  FIREBASE_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n' \
  MENU_IMAGE_BUCKET=menu-images \
  MENU_IMAGE_CRON_SECRET=choose-a-long-random-secret \
  VENUE_ENRICHMENT_CRON_SECRET=choose-a-second-long-random-secret \
  VENUE_IMAGE_BUCKET=venue-images \
  VENUE_IMAGE_CRON_SECRET=choose-a-third-long-random-secret \
  DEFAULT_WHATSAPP_COUNTRY_CODE=250 \
  --project-ref kczghhipbyykluuiiunp   # or uskfnszcdqpcfrhjxitl for MT
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are provided by the Supabase runtime.

`GEMINI_API_KEY` must be able to call Gemini image generation, Gemini Google
Maps grounding, and Gemini Google Search grounding.

`FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` must come from a Firebase
service account with permission to call the FCM HTTP v1 API for
`FIREBASE_PROJECT_ID`.

For the Rwanda BioPay rollout, also set:

```bash
supabase secrets set \
  BIOPAY_OWNER_TOKEN_SECRET=choose-a-long-random-secret \
  BIOPAY_MANAGE_CODE_PEPPER=choose-a-second-long-random-secret \
  BIOPAY_DEFAULT_MATCH_THRESHOLD=0.72 \
  BIOPAY_MIN_MATCH_THRESHOLD=0.80 \
  BIOPAY_DUPLICATE_FACE_THRESHOLD=0.90 \
  BIOPAY_MATCH_RATE_LIMIT_WINDOW_MINUTES=5 \
  BIOPAY_MATCH_RATE_LIMIT_MAX_REQUESTS=20 \
  BIOPAY_RATE_LIMIT_SECRET=choose-a-third-long-random-secret \
  BIOPAY_ALLOWED_ORIGINS=https://dineinrw.ikanisa.com \
  --project-ref kczghhipbyykluuiiunp
```

`BIOPAY_ALLOWED_ORIGINS` only affects browser-based requests. Native mobile
calls do not send an `Origin` header, so they continue to work without CORS
relaxation.

## Deploy

Run from `dinein_app/`. **Always specify `--project-ref`:**

```bash
# ── Rwanda (RW) ──
supabase functions deploy --project-ref kczghhipbyykluuiiunp

# ── Malta (MT) ──
supabase functions deploy --project-ref uskfnszcdqpcfrhjxitl
```

## Recommended Schedule

Create a scheduled call to `backfill-menu-images` with the `x-cron-secret` header and a small batch size, for example:

```json
{
  "limit": 12
}
```

Recommended cadence:

- every 5 to 15 minutes for production backfill
- every 30 to 60 minutes if cost control matters more than freshness

The checked-in migration
`20260321023000_menu_image_backfill_automation.sql`
installs `pg_net` and `pg_cron`, adds the image-signature indexes, and creates a
5-minute cron job that posts to `backfill-menu-images`.

Before applying it, replace the placeholder `MENU_IMAGE_CRON_SECRET` in that
migration with the actual deployed secret value for the target project.

The checked-in migration
`20260321040000_venue_profile_backfill_automation.sql`
is intentionally a no-op. It only enables `pg_net` and `pg_cron`; the actual
HTTP cron job must be provisioned manually per environment because the required
cron secret or service-role bearer token must not be committed to source
control.

For venue enrichment and venue profile image generation, keep the batch size
small. Grounded Google Maps plus Search enrichment is materially heavier than
the old provider-only path, so a `limit` of `1` is the safe default for
scheduled runs on Supabase Edge Functions. The venue image batch can run with a
slightly higher limit once grounding data exists, but it can also self-enrich
missing venues if needed.

Recommended production setup:

- Schedule `backfill_venue_profiles` every 10 to 15 minutes with a small batch.
- Schedule `backfill_venue_profile_images` every 10 to 15 minutes with a small batch.
- If you are only running the checked-in ops script, let it invoke both actions in sequence.

## Venue Enrichment Notes

- Gemini Google Maps grounding is the structured source of truth for address, phone, price level, rating, place ID, Maps links, grounded review summaries, and grounded place summaries.
- Gemini Google Search grounding is used to fill missing web-facing fields such as website, reservation link, social links, and a short factual venue description.
- The enrichment pipeline normalizes venue categories to `Bar`, `Bar & Restaurants`, `Restaurants`, or `Hotels`.
- The batch function updates provider metadata on every pass, but only fills first-party fields like `description`, `image_url`, `website_url`, and `reservation_url` when they are missing unless `overwriteExisting=true` is passed.
- Venue `image_url` backfill now prefers the official website hero image or JSON-LD image metadata once the grounded website is known.

## Ops Scripts

From `dinein_app/`, these scripts can drive the same production workflow that is now running live:

```bash
chmod +x scripts/menu_image_generate_representatives.sh
chmod +x scripts/menu_image_fanout.sh
chmod +x scripts/venue_profile_backfill.sh

DATABASE_URL=postgresql://... \
SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=your_service_role_jwt \
PARTITION=all \
scripts/menu_image_generate_representatives.sh

DATABASE_URL=postgresql://... \
ITERATIONS=20 \
SLEEP_SEC=60 \
scripts/menu_image_fanout.sh

SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=your_service_role_jwt \
LIMIT=1 \
ITERATIONS=6 \
SLEEP_SEC=60 \
scripts/venue_profile_backfill.sh
```

`scripts/venue_profile_backfill.sh` now chains the venue image backfill after
the venue enrichment pass by default, so one operator run refreshes both the
grounded venue metadata and the persisted AI profile images.

`PARTITION=even` and `PARTITION=odd` can be used to run multiple representative-generation workers in parallel.

## Flutter Behavior

- New menu items without images automatically trigger single-item generation.
- OCR imports trigger a bounded backfill.
- Venue owners can generate or regenerate an image from the item editor through `dinein-api`.
- Venue owners can trigger a missing-image backfill from the menu manager through `dinein-api`.
- Protected images are skipped by automatic AI generation.
