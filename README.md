# DineIn Workspace

This workspace contains the canonical Flutter application for guest, venue, and
admin flows:

- `dinein_app`: the primary Flutter application (guest ordering, venue management, admin portal)

> **Note:** `dinein-kigali` (the legacy React/Vite reference) has been deleted after achieving full parity in the Flutter app.

## Local commands

```bash
cd dinein_app
flutter pub get
flutter analyze
flutter test
flutter run
```

## Repository notes

- Lockfiles are intentionally kept for application reproducibility.
- Generated files and local debug artifacts are ignored at the workspace level.
- All feature work lands in `dinein_app`.
- CI enforces Flutter analysis/tests.
