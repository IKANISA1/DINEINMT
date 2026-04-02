# DineIn Workspace

This workspace contains the canonical Flutter application for guest, venue, and
admin flows across mobile, web, and PWA surfaces:

- `dinein_app`: the primary Flutter application family (guest ordering, venue management, admin portal, web/PWA browser app)

> **Note:** `dinein-kigali` (the legacy React/Vite reference) has been deleted after achieving full parity in the Flutter app.

## Local commands

```bash
cd dinein_app
flutter pub get
flutter analyze
flutter test
flutter run
flutter build web --release
```

## Repository notes

- Lockfiles are intentionally kept for application reproducibility.
- Generated files and local debug artifacts are ignored at the workspace level.
- All feature work lands in `dinein_app`.
- CI enforces Flutter analysis/tests.

## ⛔ Release Critical

Before building any APK or AAB, `SUPABASE_URL` and `SUPABASE_ANON_KEY` must be
set to valid, non-placeholder values in the env file (`env/release.mt.json` or
`env/release.rw.json`). The build script enforces this automatically — see
[dinein_app/AGENTS.md](./AGENTS.md) and `dinein_app/README.md` for details.
