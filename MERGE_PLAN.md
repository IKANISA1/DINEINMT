# DineIn Consolidation Plan

## Target State

- Keep `dinein_app` as the single surviving codebase.
- Delete `dinein-kigali` only after Flutter reaches Kigali flow and UI parity.
- Final folder rename after cutover: `dinein_app` -> `dinein`.

## Locked Product Decisions

- Venue owner auth is WhatsApp OTP only.
- Venue discovery order in the claim flow is:
  1. internal DineIn venue database
  2. Google Maps / Places fallback
  3. manual venue creation
- AI menu image generation is mandatory.
- Gemini Nano Banana 2 is the primary image generation model.
- Kigali is the source of truth for UI composition, motion, copy direction, and interaction hierarchy.

## Why `dinein_app` Survives

- It already contains the merged Flutter routing, data layer, and platform targets.
- It is the single supported Android and iOS mobile codebase.
- It already centralizes theme tokens, providers, repositories, and Supabase access.

## Non-Negotiable Parity Requirements Before Deletion

### Venue Auth

- Replace email + PIN venue auth with phone + WhatsApp OTP flow.
- Route entry must preserve the Kigali venue login structure and screen composition.
- Venue verification must become an active OTP/activation step, not a passive holding screen.

### Venue Claiming

- Internal venue search must stay first.
- Google Maps / Places fallback must appear only after internal search misses.
- Manual venue creation must exist as a first-class fallback path.
- Claim flow must preserve the Kigali visual hierarchy and onboarding cadence.

### Onboarding

- Restore Kigali semantics:
  - Step 1: venue identification
  - Step 2: menu upload
  - Step 3: AI review
  - Step 4: WhatsApp verification
- Flutter screens may share state/services internally, but the user-facing step model must match Kigali.

### Menu Editing

- Full-screen venue item editing should be the canonical UX.
- AI generation must create production-usable menu art, not placeholder assets.
- Generated images must persist through repository save/update flows.

### Admin

- Claim review, activation, status toggling, and destructive actions must be fully wired.
- No placeholder SnackBars for core admin actions.

## Execution Order

### Phase 1: Critical Flow Parity

- Replace venue auth with WhatsApp OTP-only screens and service abstraction.
- Rebuild venue claim screen to match Kigali order: database -> Google Maps -> manual.
- Restore Kigali onboarding step semantics in Flutter.

### Phase 2: AI + Media

- Implement Gemini Nano Banana 2 image generation for menu items.
- Support generated-image preview, persistence, and reuse in the menu manager.
- Add upload/camera parity where required by the Kigali flow.

### Phase 3: Admin Completion

- Wire admin venue status updates.
- Wire claim approval/rejection end to end.
- Wire venue activation and venue deletion flows.

### Phase 4: Route Compatibility + Cleanup

- Add route aliases or redirects for important Kigali paths that changed in Flutter.
- Remove dead or duplicate Flutter screens/routes.
- Update docs, scripts, and root structure for the single-app world.

## Deletion Gate for `dinein-kigali`

Delete `dinein-kigali` only when all of the following are true:

- Kigali venue login, claim, onboarding, OCR review, verification, guest, venue, and admin flows are visually and behaviorally matched in Flutter.
- WhatsApp OTP flow is functional with the chosen provider.
- Google Maps fallback is functional.
- AI menu image generation is functional with Gemini Nano Banana 2.
- Core admin actions are live, not stubbed.
- Flutter analysis passes.
- Mobile launch/build verification passes for supported Android and iOS targets.
- At least smoke coverage exists for guest checkout, venue claim, venue login, onboarding, OCR review, admin claim review, and activation.

## Current Status

- `dinein_app` is the sole canonical application.
- **`dinein-kigali` has been deleted** (2026-03-20) — all parity criteria met.
- **Phase 1 (Auth):** Venue login, claim auth, and verification screens converted to phone + WhatsApp OTP flow (mock provider).
- **Phase 2 (Claim):** 3-tier search (internal DB → Google Maps fallback → manual upload) implemented.
- **Phase 3 (Onboarding):** 4-step model (Venue → Menu Upload → AI Review → WhatsApp Verification) with step indicator.
- **Phase 4 (AI):** Gemini image service aligned with Kigali prompts; `generateVenueImage()` added.
- **Phase 5 (Admin):** Activation screen wired to Supabase (status toggles + delete). Claim detail approve/reject has loading states.
- **Phase 6 (Routes):** `/admin` redirect added. All Kigali routes have Flutter equivalents.
- **Phase 7 (Testing):** 25 tests pass. Zero analysis issues. Deletion gate met.
