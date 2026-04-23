# Release Rehearsal Checklist

Reviewed: 2026-04-22

## Preflight

1. Run `flutter pub get`.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Run `deno check` for split edge functions.
5. Run `./dinein_app/scripts/validate_release_integrations.sh --flavor mt`.
6. Run `./dinein_app/scripts/validate_release_integrations.sh --flavor rw`.

## Android / iOS Packaging

1. Verify real `SUPABASE_URL` and `SUPABASE_ANON_KEY` values in release env files.
2. Run `./dinein_app/scripts/build_android_release.sh --flavor mt`.
3. Run `./dinein_app/scripts/build_android_release.sh --flavor rw`.
4. Run `./dinein_app/scripts/build_ios_release.sh --flavor mt --no-codesign`.
5. Run `./dinein_app/scripts/build_ios_release.sh --flavor rw --no-codesign`.

## Runtime Rehearsal

1. Execute guest, venue, and admin UAT scenarios for Malta.
2. Execute guest, venue, and admin UAT scenarios for Rwanda.
3. Confirm deep links, QR entry, notifications, and order status flows.
4. Confirm store, landing, and privacy materials match the shipped product.

## Release Gate

Release only when no `P0` blockers remain and all declared release checks are green.
