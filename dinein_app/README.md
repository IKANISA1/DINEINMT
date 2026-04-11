# DineIn

`dinein_app` is the canonical DineIn application family for guest, venue, and
admin flows across mobile, web, and PWA surfaces.

It consolidates the previous Flutter app and the Kigali React/Vite app into a
single Flutter codebase with:

- guest, venue, and admin flows
- admin-managed venue access plus OCR-assisted menu management
- mobile apps plus web/PWA app surfaces from one product line

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Run on the target that matches the workflow you are testing:

```bash
flutter run -d android
# or
flutter run -d ios
# or
flutter run -d chrome
```

For browser release builds (Cloudflare PWAs):

```bash
# Malta (dinein-mt-pwa)
PLAY_APP_SIGNING_SHA256_MT="AA:BB:..." \
APPLE_TEAM_ID_MT="ABCDE12345" \
./scripts/build_web_release.sh --flavor mt

# Rwanda (dinein-rw-pwa)
PLAY_APP_SIGNING_SHA256_RW="AA:BB:..." \
APPLE_TEAM_ID_RW="ABCDE12345" \
./scripts/build_web_release.sh --flavor rw
```

BioPay, face enrollment, Wi-Fi auto-connect, and other device-native flows stay
in the Android/iOS apps. The web/PWA surfaces cover guest, venue, and admin
browser-safe flows.

## Supabase Projects

This monorepo connects to **two separate Supabase projects** — one per country:

| | **Rwanda (RW)** | **Malta (MT)** |
|---|---|---|
| **Project Ref** | `kczghhipbyykluuiiunp` | `uskfnszcdqpcfrhjxitl` |
| **Dashboard** | [supabase.com/…/kczghhipbyykluuiiunp](https://supabase.com/dashboard/project/kczghhipbyykluuiiunp) | [supabase.com/…/uskfnszcdqpcfrhjxitl](https://supabase.com/dashboard/project/uskfnszcdqpcfrhjxitl) |
| **API URL** | `https://kczghhipbyykluuiiunp.supabase.co` | `https://uskfnszcdqpcfrhjxitl.supabase.co` |
| **Country Code** | `250` | `356` |
| **Default Currency** | `RWF` | `EUR` |
| **WhatsApp Template** | `gikundiro` | *(MT template)* |
| **Flutter env file** | `env/release.rw.json` | `env/release.mt.json` |

> **Important:** Always use `--project-ref` when running Supabase CLI commands to
> target the correct project. The local `supabase link` can only point to one
> project at a time.

```bash
# Link to Rwanda
supabase link --project-ref kczghhipbyykluuiiunp

# Link to Malta
supabase link --project-ref uskfnszcdqpcfrhjxitl
```

## Release

Create a real Android signing config before store upload:

```bash
cp android/key.properties.example android/key.properties
```

Google Play upload credentials are no longer stored in the repo. Fastlane now
expects one of:

- `PLAY_STORE_JSON_KEY_PATH`
- `PLAY_STORE_JSON_KEY_JSON`
- `android/fastlane/play-store-service-account.local.json` (gitignored)

Provide runtime secrets through `--dart-define-from-file`:

```bash
cp env/release.example.json env/release.json
flutter build appbundle --release --dart-define-from-file=env/release.json
```

> ⛔ **CRITICAL: Before building any APK or AAB, verify that `SUPABASE_URL` and
> `SUPABASE_ANON_KEY` are set to real project values (not placeholders) in the
> env file.** The build script will abort if it detects missing or placeholder
> credentials. A release binary built without valid Supabase credentials will
> crash on first launch.
>
> **Valid values:**
> - `SUPABASE_URL` — must start with `https://` and end with `.supabase.co`
> - `SUPABASE_ANON_KEY` — must be a real JWT (starts with `eyJ`)

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
python3 scripts/sync_firebase_configs.py

./scripts/build_ios_release.sh --flavor mt
./scripts/build_ios_release.sh --flavor rw
```

Firebase app IDs for both DineIn flavors are committed in `firebase.json`.
When the Firebase project changes, re-pull the live Android, iOS, web, and
`firebase_options.dart` config from the configured project with:

```bash
python3 scripts/sync_firebase_configs.py
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

The project now reads Android signing values from `android/key.properties` or
the environment variables `ANDROID_KEYSTORE_FILE`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
`ANDROID_KEY_PASSWORD`.

The production deep-link hosts are `https://dineinmt.ikanisa.com/v/{slug}` for Malta
and `https://dineinrw.ikanisa.com/v/{slug}` for Rwanda. Publish the app-link
artifacts to each domain's `.well-known/` directory before testing verified
links on devices. Generate those files with:

```bash
PLAY_APP_SIGNING_SHA256_MT="AA:BB:..." \
APPLE_TEAM_ID_MT="ABCDE12345" \
./scripts/render_app_links.sh --flavor mt

PLAY_APP_SIGNING_SHA256_RW="AA:BB:..." \
APPLE_TEAM_ID_RW="ABCDE12345" \
./scripts/render_app_links.sh --flavor rw
```

`build_web_release.sh` and `validate_release_integrations.sh` can render those
artifacts automatically when the matching flavor-specific environment variables
are present. The rendered `.well-known` files are generated at build/validation
time and are no longer committed as static landing-page files.

## Supabase Backend

> **Canonical backend tree:** `dinein_app/supabase/`
>
> The top-level `supabase.ARCHIVED/` is a stale copy — do NOT deploy from it.

Apply schema changes and deploy Edge Functions from `dinein_app/`.
**Always specify `--project-ref`** to avoid deploying to the wrong project:

```bash
# ── Rwanda (RW) ──
supabase link --project-ref kczghhipbyykluuiiunp
supabase db push --password '...'
supabase functions deploy --project-ref kczghhipbyykluuiiunp

# ── Malta (MT) ──
supabase link --project-ref uskfnszcdqpcfrhjxitl
supabase db push --password '...'
supabase functions deploy --project-ref uskfnszcdqpcfrhjxitl
```

> **⚠️ RW database note:** The RW project uses base table names (`venues`,
> `profiles`, etc.) with `dinein_*` views aliasing them for edge function
> compatibility. MT uses `dinein_*` as the actual table names. Do not rename
> tables on either project without updating the corresponding views/functions.

## Notes

- `../dinein-kigali` is now a legacy reference copy, not the primary app.
- Web and PWA app surfaces are now part of the product direction alongside the
  native mobile apps.
- Venue access is provisioned from the admin panel. Venue staff log in with the
  WhatsApp number saved on their venue record.
- The mobile backend depends on the `whatsapp-otp` and `dinein-api` Edge
  Functions under `supabase/functions/`.
- Committed Flutter smoke and provider tests live under `test/`.
- `flutter analyze` and `flutter test` are the main automated quality gates for
  this mobile app.
