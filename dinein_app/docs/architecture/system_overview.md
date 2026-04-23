# System Overview

DineIn is a two-country hospitality platform built around one Flutter app,
shared Dart packages, country-specific landing surfaces, and a Supabase backend
with modular Deno edge functions.

## Product Surfaces

- Guest surface: QR/table entry, venue discovery, menu browsing, cart, order
  placement, order tracking
- Venue surface: WhatsApp OTP login, active orders, menu management, QR tools,
  venue notifications
- Admin surface: venue provisioning, oversight, catalog moderation, order
  visibility

## Country Model

- Malta (`mt`): cash and Revolut handoff
- Rwanda (`rw`): cash and MoMo USSD handoff

Both countries share the same application shell, shared packages, and release
discipline. Country differences belong in configuration and data, not duplicate
feature trees.

## Backend Topology

Active backend path: `dinein_app/supabase/`

Active function surfaces:

- `core-api`
- `venue-api`
- `menu-api`
- `orders-api`
- `admin-api`
- `whatsapp-otp`

`dinein-api` is retained only as a deprecated compatibility dispatcher for
legacy callers. The split functions above are the production source of truth.

## Archive Boundaries

- `supabase.ARCHIVED/` is historical only.
- `dinein_app/docs/archive/` contains historical audits and superseded release
  documentation.

## Out Of Scope

The active product does not include:

- direct card capture inside the app
- automated device-inbox ingestion
- identity-template matching or special-category identity verification
