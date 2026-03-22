# Release Today

Verified on March 21, 2026 against Supabase project `uskfnszcdqpcfrhjxitl`.

## Live Backend Status

- `scripts/smoke_live_backend.sh` passed against the hosted `dinein-api`.
- Live checks passed for:
  - health
  - venue listing
  - menu listing
  - unauthenticated user-role rejection
  - unsigned venue-session rejection
  - database SSL enforcement
  - database network restrictions

## Live Function Inventory

- `whatsapp-otp` active, version `20`
- `dinein-api` active, version `26`
- `generate-menu-item-image` active, version `18`
- `backfill-menu-images` active, version `17`

## Remote Secrets Present

Verified secret names include:

- `DINEIN_ADMIN_SESSION_SECRET`
- `DINEIN_VENUE_SESSION_SECRET`
- `WHATSAPP_ACCESS_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_TEMPLATE_NAME`
- `WHATSAPP_TEMPLATE_LANGUAGE`
- `WHATSAPP_OTP_PEPPER`
- `GEMINI_API_KEY`
- `VENUE_ENRICHMENT_CRON_SECRET`
- `MENU_IMAGE_CRON_SECRET`

## Migration Status

Remote is applied through `20260321033000_venue_profile_enrichment.sql`.

Still local-only:

- `20260321034500_normalize_venue_categories.sql`
- `20260321040000_venue_profile_backfill_automation.sql`

Do not run `supabase db push --linked` blindly before release.

Reason:

- `20260321040000_venue_profile_backfill_automation.sql` still contains the placeholder string `VENUE_ENRICHMENT_CRON_SECRET` inside the scheduled HTTP header payload.
- Applying it as-is would create a broken cron job.

Release recommendation:

- Ship without these two migrations, or patch `20260321040000` with the real cron secret before pushing.

## Android Release Blockers

The release script is currently blocked by missing local packaging config:

- `env/release.json` is missing
- `android/key.properties` is missing

You can satisfy the second requirement with environment variables instead:

- `ANDROID_KEYSTORE_FILE`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## Platform Release Blockers

The repo now includes iOS entitlements, native Firebase config, and release
validation. The remaining external artifacts are:

- rendered `landing/.well-known/assetlinks.json` with the real Play App Signing SHA-256
- rendered `landing/.well-known/apple-app-site-association` with the real Apple Team ID
- published those files to `https://dineinmalta.com/.well-known/`

Validate these before store submission with:

```bash
PLAY_APP_SIGNING_SHA256="AA:BB:..." APPLE_TEAM_ID="ABCDE12345" ./scripts/render_app_links.sh
./scripts/validate_release_integrations.sh
```

## Minimal Next Steps

1. Copy and fill the release env file:

```bash
cp env/release.example.json env/release.json
```

2. Add Android signing config:

```bash
cp android/key.properties.example android/key.properties
```

3. Build signed release artifacts:

```bash
./scripts/build_android_release.sh
```

## Recommended Final Manual Smoke

- Guest: discover, venue detail, cart, place order, status page
- Venue: WhatsApp OTP login, dashboard, orders, menu edit, settings save
- Admin: OTP login, claims review, venue list, orders list
