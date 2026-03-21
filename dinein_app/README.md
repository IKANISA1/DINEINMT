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

For a guarded one-command Android release flow:

```bash
./scripts/build_android_release.sh
```

For a live backend sanity check against the hosted Supabase project:

```bash
./scripts/smoke_live_backend.sh
```

For platform release integration checks before store submission:

```bash
./scripts/validate_release_integrations.sh
```

The project now reads Android signing values from `android/key.properties` or
the environment variables `ANDROID_KEYSTORE_FILE`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
`ANDROID_KEY_PASSWORD`.

The production deep-link host is `https://dineinmalta.com/v/{slug}`. Publish
the app-link artifacts from `docs/release/app-links/` to the domain's
`.well-known/` directory before testing verified links on devices.

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
