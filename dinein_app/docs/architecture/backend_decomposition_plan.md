# Backend Decomposition Status

## Current State

The canonical backend surface is now the split Supabase edge-function set:

- `core-api`
- `venue-api`
- `menu-api`
- `orders-api`
- `admin-api`
- `whatsapp-otp`

The Flutter client routes app-owned actions to those functions directly through
`DineinApiService._actionToEdgeFunction`.

`dinein-api` is no longer the source of truth. It remains in the repo only as a
deprecated compatibility dispatcher for legacy callers that have not yet been
retired.

## Domain Ownership

### `orders-api`
Owns guest order placement, venue order handling, admin order visibility, and
order realtime access.

### `menu-api`
Owns menu CRUD, OCR/import ingestion, menu image generation, manual image
uploads, and image-health reporting.

### `venue-api`
Owns venue CRUD, venue enrichment, bell/wave flows, venue notification
settings, push-device registration, venue image uploads, and venue image
backfill operations.

### `admin-api`
Owns admin menu catalog management and group assignment workflows.

### `core-api`
Owns health checks, profile bootstrap, role lookup, and guest telemetry.

## Remaining Transition Work

1. Keep the app and operational scripts on split functions only.
2. Keep CI focused on split-function type checks and shared module tests.
3. Treat `dinein-api` as compatibility-only in docs and release materials.
4. Retire `dinein-api` from config and deployment once legacy callers are
   confirmed absent.

## Exit Criteria For Full Retirement

- No active Flutter runtime path falls back to `dinein-api`.
- No release script or smoke script targets `dinein-api`.
- No CI job treats `dinein-api` as a required clean production module.
- Any remaining references are explicitly historical or compatibility-only.
