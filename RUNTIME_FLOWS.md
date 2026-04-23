# DineIn Runtime Flows

## Guest Flow

1. A guest enters through QR, table link, deep link, or venue discovery.
2. The app loads country configuration and venue/menu data from Supabase-backed
   APIs.
3. The guest builds a cart, selects an external payment handoff method, and
   places the order.
4. The backend issues order-scoped access where needed for receipts, tracking,
   and realtime updates.

## Venue Flow

1. Venue staff authenticate through `whatsapp-otp`.
2. The app stores the short-lived venue session through `AuthRepository`.
3. Venue operators manage menus, active orders, and venue settings from the
   Flutter venue surface.
4. Venue mutations flow through split backend domains rather than screen-level
   business logic.

## Admin Flow

1. Admin users authenticate through `whatsapp-otp`.
2. The admin surface loads global venues, moderation queues, and oversight data.
3. Admin actions are authorized server-side on every request.

## Backend Routing

Edge functions are split by domain:

- `core-api` for shared bootstrap and telemetry actions
- `venue-api` for venue-owned operational actions
- `menu-api` for menu and media actions
- `orders-api` for guest order placement and venue order operations
- `admin-api` for global admin actions
- `whatsapp-otp` for OTP and session issuance

Client routing is handled in Flutter by `DineInApiService`, which maps actions
to the correct edge-function surface.

## Notifications And Device Services

- Push registration supports venue and admin operational alerts.
- Android Wi-Fi assistance is available where the venue workflow requires it.
- Media capture and upload use system-owned pickers or intents rather than
  broad device access.

## Release-Critical Runtime Config

Android release builds must use real `SUPABASE_URL` and `SUPABASE_ANON_KEY`
values in the flavor env file passed to `--dart-define-from-file`.

Expected env files:

- `env/release.mt.json`
- `env/release.rw.json`
- `env/release.json`

The release scripts and validation scripts enforce these checks before APK or
AAB packaging.
