# DineIn Supabase

`dinein_app/supabase/` is the only active backend tree in this monorepo.
Historical materials under `supabase.ARCHIVED/` remain for audit and
reproducibility only.

This backend now includes the active production pipelines for:

- Gemini-powered menu image generation
- Gemini Google Maps grounding plus Gemini Search-grounded venue profile
  enrichment
- Gemini-powered venue profile image generation
- Firebase Cloud Messaging delivery for venue operational push alerts

## Project Environments

|                       | **Rwanda (RW)**                            | **Malta (MT)**                             |
| --------------------- | ------------------------------------------ | ------------------------------------------ |
| **Project Ref**       | `kczghhipbyykluuiiunp`                     | `uskfnszcdqpcfrhjxitl`                     |
| **API URL**           | `https://kczghhipbyykluuiiunp.supabase.co` | `https://uskfnszcdqpcfrhjxitl.supabase.co` |
| **Country Code**      | `250`                                      | `356`                                      |
| **Default Currency**  | `RWF`                                      | `EUR`                                      |
| **WhatsApp Template** | `gikundiro`                                | _(MT template)_                            |
| **Table Pattern**     | Base tables (`venues`) + `dinein_*` views  | `dinein_*` tables directly                 |

> **⚠️ Schema difference:** RW uses base table names (`venues`, `profiles`,
> `orders`, etc.) with `dinein_*` views aliasing them for edge function
> compatibility. MT uses `dinein_*` prefixed tables directly. Edge functions
> reference `dinein_*` names on both projects.

## Active Edge Functions

- `core-api`: profile bootstrap and guest telemetry
- `venue-api`: venue CRUD, search, push registration, bell/wave flows, venue AI
- `menu-api`: menu CRUD, OCR/import, item imagery
- `orders-api`: guest orders, venue/admin order operations, admin KPIs
- `admin-api`: admin-managed menu catalog and grouping
- `whatsapp-otp`: venue/admin OTP delivery and verification

`dinein-api` is no longer the canonical runtime surface. It is retained only as
a deprecated compatibility dispatcher for legacy callers while the split
functions remain the production source of truth.

## Required Secrets

Set these in **each** Supabase project before deploying the functions:

```bash
# Replace --project-ref with the target project
supabase secrets set \
  GEMINI_API_KEY=your_google_api_key \
  GOOGLE_MAPS_API_KEY=your_google_places_api_key \
  GEMINI_IMAGE_MODELS=gemini-3.1-flash-image-preview,gemini-2.5-flash-image \
  GEMINI_VENUE_MODELS=gemini-2.5-flash,gemini-2.5-flash-lite \
  GEMINI_VENUE_IMAGE_MODELS=gemini-2.5-flash-image \
  VENUE_IMAGE_REFERENCE_LIMIT=3 \
  GEMINI_VENUE_DEEP_RESEARCH_AGENT=deep-research-pro-preview-12-2025 \
  GEMINI_VENUE_DEEP_RESEARCH_POLL_MS=5000 \
  GEMINI_VENUE_DEEP_RESEARCH_MAX_WAIT_MS=60000 \
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

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
provided by the Supabase runtime.

`GEMINI_API_KEY` must be able to call Gemini image generation, Gemini Google
Maps grounding, and Gemini Google Search grounding.

`GOOGLE_MAPS_API_KEY` must be set and should have Places API (New) enabled so
venue enrichment can fetch Place Details and Place Photos for image-reference
grounding.

`GEMINI_VENUE_DEEP_RESEARCH_*` is required for venue profile image generation.
The venue-image pipeline now fails closed if Gemini deep research is not
available, because Google Maps grounding plus deep research is treated as a
mandatory prerequisite for venue-specific imagery. The default wait budget is
`60000` milliseconds so the background research interaction has enough time to
finish before image generation gives up.

`FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` must come from a Firebase
service account with permission to call the FCM HTTP v1 API for
`FIREBASE_PROJECT_ID`.

## Deploy

Run from `dinein_app/`. **Always specify `--project-ref` and deploy the active
function surface explicitly:**

```bash
# ── Rwanda (RW) ──
for fn in core-api venue-api menu-api orders-api admin-api whatsapp-otp; do
  supabase functions deploy "$fn" --project-ref kczghhipbyykluuiiunp
done

# ── Malta (MT) ──
for fn in core-api venue-api menu-api orders-api admin-api whatsapp-otp; do
  supabase functions deploy "$fn" --project-ref uskfnszcdqpcfrhjxitl
done
```

Deploy `dinein-api` only if an explicitly supported legacy client still depends
on the compatibility dispatcher.

## Image Generation Policy

Menu item images and venue profile images are manual-only.

- Do not schedule `generate-menu-item-image`, `backfill-menu-images`,
  `generate-venue-profile-image`, or `backfill-venue-profile-images`.
- Generated AI images are locked after a successful run. Regeneration requires
  an explicit unlock plus a manual trigger.
- Venue enrichment may still be run operationally, but it no longer auto-chains
  venue profile image generation.
- If legacy cron jobs exist from earlier rollouts, remove them from each project
  before relying on this policy.

Venue enrichment itself can still be run in small manual batches. Grounded
Google Maps plus Search enrichment is materially heavier than the old
provider-only path, so a `limit` of `1` remains the safe default for operational
runs on Supabase Edge Functions.

## Venue Enrichment Notes

- Gemini Google Maps grounding is the structured source of truth for address,
  phone, price level, rating, place ID, Maps links, grounded review summaries,
  and grounded place summaries.
- Gemini Google Search grounding is used to fill missing web-facing fields such
  as website, reservation link, social links, and a short factual venue
  description.
- The enrichment pipeline normalizes venue categories to `Bar`,
  `Bar & Restaurants`, `Restaurants`, or `Hotels`.
- The batch function updates provider metadata on every pass, but only fills
  first-party fields like `description`, `image_url`, `website_url`, and
  `reservation_url` when they are missing unless `overwriteExisting=true` is
  passed.
- Venue `image_url` backfill now prefers the official website hero image or
  JSON-LD image metadata once the grounded website is known.

## Ops Scripts

From `dinein_app/`, these scripts can drive the same production workflow that is
now running live:

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

`scripts/venue_profile_backfill.sh` defaults to enrichment-only. Set
`GENERATE_PROFILE_IMAGES=true` only when an operator explicitly wants a manual
venue-image pass after grounding completes.

Venue image generation now persists Gemini Deep Research state on the venue
record. The first manual image call may return a pending result while Deep
Research runs asynchronously in the background. Re-run the same manual image
call or backfill iteration later to poll the saved interaction and finish image
generation once the research summary is ready.

The venue row also persists the last observed Gemini interaction status, last
HTTP status, last poll timestamp, provider error text, and a small debug event
trail so stalled Deep Research jobs can be distinguished from code-side
failures.

`PARTITION=even` and `PARTITION=odd` can be used to run multiple
representative-generation workers in parallel.

## Flutter Behavior

- New menu items do not auto-generate images.
- OCR or import workflows do not auto-trigger image generation.
- Venue owners can generate or regenerate an image from the item editor through
  `menu-api`.
- Venue owners can trigger a missing-image backfill from the menu manager
  through `menu-api`.
- Protected images are skipped by generated-image requests until they are
  unlocked.
