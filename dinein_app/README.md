# DineIn

`dinein_app` is the canonical DineIn mobile application.

It consolidates the previous Flutter app and the Kigali React/Vite app into a
single Flutter codebase with:

- guest, venue, and admin flows
- merged venue onboarding and OCR menu-review flows
- Android and iOS mobile targets from one codebase

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Run on a mobile target only:

```bash
flutter run -d android
# or
flutter run -d ios
```

## Release

Create a real Android signing config before store upload:

```bash
cp android/key.properties.example android/key.properties
```

Provide runtime secrets through `--dart-define-from-file`:

```bash
cp env/release.example.json env/release.json
flutter build appbundle --release --dart-define-from-file=env/release.json
```

For flavor-specific builds:

```bash
cp env/release.mt.example.json env/release.mt.json
cp env/release.rw.example.json env/release.rw.json
flutter build appbundle --release --flavor mt -t lib/main_mt.dart --dart-define-from-file=env/release.mt.json
flutter build appbundle --release --flavor rw -t lib/main_rw.dart --dart-define-from-file=env/release.rw.json
```

For a guarded one-command Android release flow:

```bash
./scripts/build_android_release.sh --flavor mt
./scripts/build_android_release.sh --flavor rw
```

For iOS release builds:

```bash
cp ios/Runner/GoogleService-Info-rw.plist.example ios/Runner/GoogleService-Info-rw.plist
# replace the placeholder values above with the real Rwanda Firebase iOS app config

./scripts/build_ios_release.sh --flavor mt
./scripts/build_ios_release.sh --flavor rw
```

For a live backend sanity check against the hosted Supabase project:

```bash
./scripts/smoke_live_backend.sh --flavor mt
./scripts/smoke_live_backend.sh --flavor rw
```

For platform release integration checks before store submission:

```bash
./scripts/validate_release_integrations.sh --flavor mt
./scripts/validate_release_integrations.sh --flavor rw --android-only
```

The Rwanda iOS path is scaffolded in-repo but still needs a real
`ios/Runner/GoogleService-Info-rw.plist` before `--flavor rw` iOS archives can
be produced. The committed `.example` file is intentionally non-secret and
non-buildable.

The project now reads Android signing values from `android/key.properties` or
the environment variables `ANDROID_KEYSTORE_FILE`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
`ANDROID_KEY_PASSWORD`.

The production deep-link hosts are `https://dineinmalta.com/v/{slug}` for Malta
and `https://dineinrw.ikanisa.com/v/{slug}` for Rwanda. Publish the app-link
artifacts to each domain's `.well-known/` directory before testing verified
links on devices. Generate those files with:

```bash
PLAY_APP_SIGNING_SHA256="AA:BB:..." \
APPLE_TEAM_ID="ABCDE12345" \
./scripts/render_app_links.sh --flavor mt

PLAY_APP_SIGNING_SHA256="AA:BB:..." \
APPLE_TEAM_ID="ABCDE12345" \
./scripts/render_app_links.sh --flavor rw --output-dir ../landing-rw/.well-known
```

## Supabase Backend

> **Canonical backend tree:** `dinein_app/supabase/`
>
> The top-level `supabase.ARCHIVED/` is a stale copy — do NOT deploy from it.

Apply linked schema changes and deploy the required Edge Functions whenever the
mobile backend changes. Always run from `dinein_app/`:

```bash
supabase db push --linked
supabase functions deploy whatsapp-otp
supabase functions deploy dinein-api
```

## Notes

- `../dinein-kigali` is now a legacy reference copy, not the primary app.
- No web, PWA, or Flutter web target is supported or maintained here.
- The mobile backend depends on the `whatsapp-otp` and `dinein-api` Edge
  Functions under `supabase/functions/`.
- New venue onboarding draft state is stored locally with `shared_preferences`.
- Committed Flutter smoke and provider tests live under `test/`.
- `flutter analyze` and `flutter test` are the main automated quality gates for
  this mobile app.
