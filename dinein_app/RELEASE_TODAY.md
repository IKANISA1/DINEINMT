# Release Today — March 25, 2026

Verified on March 25, 2026 against Supabase project `uskfnszcdqpcfrhjxitl` (Malta) and `kczghhipbyykluuiiunp` (Rwanda).

## Build Status

- **Version:** `1.0.1+2`
- **Flavors:** `mt` (Malta), `rw` (Rwanda)
- **Artifacts:** 
  - `dinein_app/build/app/outputs/flutter-apk/app-mt-release.apk`
  - `dinein_app/build/app/outputs/flutter-apk/app-rw-release.apk`
  - `dinein_app/build/app/outputs/bundle/mtRelease/app-mt-release.aab` (In progress)
  - `dinein_app/build/app/outputs/bundle/rwRelease/app-rw-release.aab` (In progress)

## QA & Testing

- `flutter analyze`: **PASS** (0 issues)
- `flutter test`: **PASS** (206/206 tests)
- `scripts/smoke_live_backend.sh`: **PASS** for both MT and RW.
- Security Hardening:
  - Durable BioPay rate limiting active via database audit.
  - Secure storage enforced for sensitive tokens (no SharedPreferences fallback).
  - Android permissions stripped (`RECORD_AUDIO`, `STORAGE`) and scoped (`CAMERA`).

## Migration Status

Remote is fully applied. All local migrations have been reconciled.

## Android Submission Notes

- **Target API:** 36 (Android 16 DP)
- **Permissions:** Reconciled and documented in `docs/google_play_submission_permissions.md`.
- **Privacy Policy:** Updated and published at `dineinmt.ikanisa.com/privacy` and `dineinrw.ikanisa.com/privacy`.

## Security Checklist (Pre-Upload)

- [ ] **⛔ Supabase Credentials (CRITICAL — build will abort without these):**
  - [ ] `env/release.mt.json` has real `SUPABASE_URL` (starts with `https://`, ends with `.supabase.co`)
  - [ ] `env/release.mt.json` has real `SUPABASE_ANON_KEY` (starts with `eyJ`)
  - [ ] `env/release.rw.json` has real `SUPABASE_URL` (starts with `https://`, ends with `.supabase.co`)
  - [ ] `env/release.rw.json` has real `SUPABASE_ANON_KEY` (starts with `eyJ`)
  - [ ] Run `./scripts/build_android_release.sh --flavor mt` — verify ✅ credential check passes
  - [ ] Run `./scripts/build_android_release.sh --flavor rw` — verify ✅ credential check passes
- [ ] **Google Cloud Console:** Ensure `GOOGLE_MAPS_API_KEY` is restricted to:
  - **Android apps:** `com.dineinmalta.app` and `com.dineinrw.app`.
  - **Certificate fingerprint:** Must include the SHA-1 of the production signing key.
  - **API restrictions:** Limit to "Places API" only.
- [ ] **Supabase:** Confirm `verify_jwt` is enabled for non-public Edge Functions if required, though BioPay uses service_role + RLS.
- [ ] **Local Storage:** Verified that no sensitive tokens fall back to unencrypted `SharedPreferences`.

## Recommended Final Manual Smoke

- **Guest:** discover, venue detail, cart, place order, order history (MT/RW).
- **BioPay (RW only):** Enrollment, matching, profile management.
- **Venue:** WhatsApp OTP login, dashboard, notification toggle, settings.
- **Admin:** OTP login, claims review, global venue list.
