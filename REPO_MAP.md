# DineIn Repository Map

## Production-Critical Paths

- `dinein_app/`
  Canonical app workspace.
- `dinein_app/lib/`
  Flutter runtime code for guest, venue, and admin surfaces.
- `dinein_app/supabase/`
  Active backend, migrations, function config, and release-facing backend docs.
- `dinein_app/android/`, `dinein_app/ios/`, `dinein_app/web/`
  Platform packaging and manifest metadata.
- `dinein_app/scripts/`
  Release, validation, smoke, and deployment scripts.
- `.github/workflows/`
  CI entry points.

## Shared Package Paths

- `packages/core/`
  Country config, enums, and shared runtime primitives.
- `packages/db/`
  Database models and serialization contracts.
- `packages/ui/`
  Shared presentation components and permission dialogs.

## Distribution And Marketing Paths

- `landing-src/`
  Source templates and country config.
- `landing/`
  Malta deployable landing output.
- `landing-rw/`
  Rwanda deployable landing output.
- `store_assets/`
  Store screenshots, listings, and review assets.

## Documentation Paths

- `README.md`
  Workspace entry point.
- `ARCHITECTURE.md`
  Top-level architectural boundaries.
- `PRODUCTION_SCOPE.md`
  Supported product scope and runtime guarantees.
- `RUNTIME_FLOWS.md`
  Runtime and backend interaction model.
- `ARCHIVE_POLICY.md`
  Rules for historical material.
- `dinein_app/docs/`
  App- and release-specific operational docs.

## Historical Paths

- `supabase.ARCHIVED/`
  Legacy backend material kept only for reference.
- `dinein_app/docs/archive/`
  Superseded audits, release notes, and historical review material.

## Ownership Rules

- New product work starts in `dinein_app/` or `packages/`.
- New backend work starts in `dinein_app/supabase/`.
- Marketing and policy changes start in `landing-src/` and are propagated to
  generated outputs.
- Historical paths are never the source of truth for runtime behavior,
  permissions, releases, or legal claims.
