# Auth And Session Lifecycle

This document describes the active session types in DineIn.

## 1. Guest Supabase Session

- Provider: Supabase Auth
- Purpose: guest profile bootstrap, guest order ownership, guest-visible data
- Transport: `Authorization: Bearer <supabase-access-token>`
- Storage: Supabase Flutter session handling

## 2. Venue Session

- Provider: `whatsapp-otp`
- Purpose: venue portal access without a Supabase user account for each venue
  operator
- Transport: custom venue JWT stored in the `venue_session` request body
- Storage: `AuthRepository`
- Guardrails:
  - short-lived access token
  - explicit venue claims
  - server-side authorization on every mutation

## 3. Admin Session

- Provider: `whatsapp-otp`
- Purpose: admin console access
- Transport: `Authorization: Bearer <admin-access-token>`
- Storage: `AuthRepository`
- Guardrails:
  - dedicated admin secret
  - strict server-side admin checks
  - no venue-session fallback for admin routes

## 4. Auxiliary Tokens

- order receipt token
- scoped realtime access token

These are narrow-purpose backend-issued tokens and must stay constrained to the
specific order or session scope they were created for.

## 5. Security Notes

- Venue and admin access are OTP-gated and custom-token based.
- Refresh, expiry, and verification rules live in `whatsapp-otp`.
- Guest, venue, and admin sessions are the only active long-lived session
  categories in the app.
