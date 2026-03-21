# Menu Image Generation Setup

This folder contains the first backend slice for Gemini-powered menu image generation.

## What Was Added

- A migration that extends `dinein_menu_items` with AI image metadata and creates the `menu-images` storage bucket.
- `generate-menu-item-image` for single-item generation/regeneration.
- `backfill-menu-images` for batch-filling missing images.

## Required Secrets

Set these in Supabase before deploying the functions:

```bash
supabase secrets set \
  GEMINI_API_KEY=your_google_api_key \
  GEMINI_IMAGE_MODELS=gemini-3.1-flash-image-preview,gemini-2.5-flash-image \
  MENU_IMAGE_BUCKET=menu-images \
  MENU_IMAGE_CRON_SECRET=choose-a-long-random-secret
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are provided by the Supabase runtime.

## Deploy

Run from the repository root:

```bash
supabase db push
supabase functions deploy generate-menu-item-image
supabase functions deploy backfill-menu-images
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

## Flutter Behavior

- New menu items without images automatically trigger single-item generation.
- OCR imports trigger a bounded backfill.
- Venue owners can generate/regenerate an image from the item editor.
- Venue owners can trigger a missing-image backfill from the menu manager.
- Protected images are skipped by automatic AI generation.
