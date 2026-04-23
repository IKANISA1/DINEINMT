# DineIn Production Scope

## Supported Product Scope

DineIn is a hospitality platform for table-linked ordering and venue
operations.

Supported capabilities:

- guest QR and table entry
- venue discovery and venue detail pages
- menu browsing, cart management, and order placement
- guest order status and history
- venue login through WhatsApp OTP
- venue order handling, menu updates, and venue profile management
- admin provisioning, oversight, and catalog operations
- push registration and operational notifications
- deep-link and QR-driven entry flows
- Malta and Rwanda runtime support from one codebase

## Supported Payment Handoffs

Payments are handed off outside the app according to venue and country
configuration.

- Malta: cash and Revolut link handoff
- Rwanda: cash and MoMo USSD handoff

The app stores order intent and payment method choice, but it does not capture
payment credentials inside the product.

## Platform Scope

- Android
- iOS
- Web
- PWA

Native platforms carry device-only operational capabilities such as push
registration and venue-side media capture through system-owned flows.

## Operational Scope

- release builds require validated Supabase environment files
- runtime country differences are configuration-driven
- app, landing, store, and legal materials must describe the same active
  feature set
- archived surfaces are non-deployable and non-authoritative

## Non-Goals

The active product does not provide:

- direct card capture inside the app
- automated device inbox ingestion
- identity-template checkout or special-category identity verification
- parallel backend stacks outside `dinein_app/supabase/`
