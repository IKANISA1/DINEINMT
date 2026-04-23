# Migration History — DineIn

This document explains how to reason about the SQL history under
`dinein_app/supabase/migrations/`.

## Canonical Rule

- New production work goes into `dinein_app/supabase/migrations/`.
- Historical filenames remain in git because Supabase tracks applied migrations
  by filename.
- Historical migrations may stay in the main sequence when reproducibility
  requires them, but they are not active feature-development targets.

## Current Domain Map

### Active DineIn domains

- profiles / auth bootstrap
- venues / venue access / venue notifications
- menus / OCR / menu images
- guest orders / bell requests / realtime access
- guest analytics
- admin-managed catalog tooling
- release hardening / rate limiting / storage policies

### Historical but inactive domains

- early-2026 experimental payment and identity migrations
  Retained only because they were part of historical schema evolution.

## Forward Cleanup Rule

April 2026 cleanup migrations retire the historical experimental subsystems
from the active schema while preserving migration reproducibility.

## Practical Guidance

1. Do not reintroduce retired experimental domains in new migrations.
2. When auditing schema drift, treat the latest forward cleanup migrations as
   the current source of truth.
3. If a historical migration reference must stay, document it as historical
   rather than active.
