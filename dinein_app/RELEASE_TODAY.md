# Release Readiness Snapshot — 2026-04-22

Verified against:

- Malta project: `uskfnszcdqpcfrhjxitl`
- Rwanda project: `kczghhipbyykluuiiunp`

## Build Target

- Version: `1.0.2+10`
- Flavors: `mt`, `rw`
- Packaging targets:
  - release APK
  - release AAB
  - release web build

## Validation Baseline

- `flutter analyze`
- `flutter test`
- `./scripts/validate_release_integrations.sh --flavor mt`
- `./scripts/validate_release_integrations.sh --flavor rw`
- `./scripts/smoke_live_backend.sh`

## Packaging Notes

- Active Android permissions are documented in
  `docs/google_play_submission_permissions.md`.
- Privacy and store declarations must match `docs/DATA_SAFETY.md` and
  `docs/STORE_LISTING.md`.
- Release manifests should stay aligned across Malta and Rwanda except for
  package identifiers and flavor-specific assets.

## Pre-Upload Security Checklist

- Confirm flavor env files contain real Supabase URL and anon key values.
- Run `./scripts/build_android_release.sh --flavor mt`.
- Run `./scripts/build_android_release.sh --flavor rw`.
- Verify Google Maps keys are restricted to the correct package IDs and
  signing-certificate fingerprints.
- Confirm non-public backend functions enforce authorization on every mutation.
- Confirm sensitive local tokens remain on secure storage paths only.

## Required Manual Smoke

- Guest: venue entry, browse, cart, place order, order status
- Venue: OTP login, order handling, menu edit, notification toggle
- Admin: OTP login, venue oversight, catalog and operational checks
- Platform: deep links, push registration, low-network retry, startup behavior
