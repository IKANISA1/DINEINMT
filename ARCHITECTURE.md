# DineIn Monorepo Architecture

This repository is the canonical source of truth for the DineIn Malta and
Rwanda hospitality platform.

## Active System

The production system is organized as one Flutter application family, three
shared Dart packages, one active Supabase backend, and country-specific landing
surfaces.

- `dinein_app/`
  The canonical application and backend workspace.
- `packages/core/`
  Shared enums, country configuration, and runtime contracts.
- `packages/db/`
  Shared models, DTOs, and Supabase-facing data contracts.
- `packages/ui/`
  Shared widgets and presentation primitives used by the app surfaces.
- `landing-src/`
  Source templates and configuration for landing pages.
- `landing/` and `landing-rw/`
  Generated deployment outputs for Malta and Rwanda.
- `store_assets/`
  App-store and distribution assets.

## Application Boundaries

`dinein_app/lib/` follows a feature-first structure:

- `core/`
  Bootstrapping, app shell, routing, permissions, and shared services.
- `features/guest/`
  Guest browsing, cart, checkout handoff, order tracking, and settings.
- `features/venue/`
  Venue login, order operations, venue profile, menu tools, and notifications.
- `features/admin/`
  Admin provisioning, catalog tooling, and oversight flows.
- `shared/`
  Cross-feature widgets and utilities that do not belong to one role surface.

Business logic belongs in service, repository, or backend layers. Feature UI
should stay thin and declarative.

## Backend Boundaries

The only active backend is `dinein_app/supabase/`.

Edge-function routing is split by domain:

- `core-api`
  Profile bootstrap, role lookup, and guest telemetry.
- `venue-api`
  Venue profile, operational settings, bell flows, and venue search helpers.
- `menu-api`
  Menu CRUD, menu ingestion, and menu-image operations.
- `orders-api`
  Guest ordering, venue order operations, and order-scoped access helpers.
- `admin-api`
  Admin dashboard, admin catalog, and global operational controls.
- `whatsapp-otp`
  Venue and admin authentication, token issuance, and OTP verification.

`dinein-api` remains in place only as a compatibility dispatcher while clients
and tests finish converging on the split module surface.

## Runtime Principles

- One product, two countries, shared codebase.
- Country-specific behavior lives in configuration and data, not duplicated
  feature trees.
- Payments stay outside the app through venue-configured handoff methods.
- Release validation is mandatory before shipping Android artifacts.
- The Flutter UI is treated as locked product truth unless a task explicitly
  requests visual change.

## Archive Boundary

The following paths are historical only and must not be treated as deployable
or current product truth:

- `supabase.ARCHIVED/`
- `dinein_app/docs/archive/`

Historical material may remain in git for auditability and migration
reproducibility, but active work must stay within the canonical paths above.
