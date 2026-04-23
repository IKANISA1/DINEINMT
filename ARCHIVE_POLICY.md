# Archive Policy

## Purpose

Historical material remains in this repository for auditability, migration
reproducibility, and release forensics. It must be clearly separated from the
active production surface.

## Archive Locations

- `supabase.ARCHIVED/`
- `dinein_app/docs/archive/`

Additional archived material should be placed under one of these locations or a
new clearly named archive path.

## Rules

1. Archived code is not deployable.
2. Archived docs are not product, legal, store, platform, or release source of
   truth.
3. New runtime imports must never point into archived paths.
4. Historical migration filenames may stay in git when reproducibility requires
   them.
5. When active docs are superseded, move them into an archive path rather than
   leaving stale copies beside current guidance.

## When To Archive

Archive material when it is:

- replaced by a newer canonical implementation
- retained only for historical review
- no longer part of the active production runtime
- useful for audit trails but unsafe as live documentation

## Review Standard

Any path that could confuse engineers about what is active versus historical
should either be archived, deleted, or documented explicitly in the active repo
map.
