# DineIn

`dinein_app` is the canonical DineIn application family for guest, venue, and
admin flows across Android, iOS, web, and PWA surfaces.

## Product Scope

- guest QR and table ordering
- venue operations and menu management
- admin venue oversight
- Malta and Rwanda country support
- external payment handoffs managed outside the app

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Native vs Web

Native apps handle device-specific flows such as:

- venue media capture through system-owned tools
- venue Wi-Fi assistance
- operational push notifications

Web and PWA cover guest, venue, and admin browser-safe workflows.

## Backend

Canonical backend path: `dinein_app/supabase/`

Active function surfaces:

- `core-api`
- `venue-api`
- `menu-api`
- `orders-api`
- `admin-api`
- `whatsapp-otp`

`dinein-api` remains as a compatibility layer during the modular rollout.

## Release Critical

Before any APK or AAB build, verify that the flavor env file contains real
`SUPABASE_URL` and `SUPABASE_ANON_KEY` values. The release scripts abort when
placeholders are detected.

## Archive Notes

- `supabase.ARCHIVED/` is historical only.
- `dinein_app/docs/archive/` contains superseded audits and older review
  material.
