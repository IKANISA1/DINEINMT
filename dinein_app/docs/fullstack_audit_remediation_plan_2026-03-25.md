# DineIn Remediation Plan

Date: 2026-03-25
Based on audit: [`fullstack_audit_2026-03-25.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/docs/fullstack_audit_2026-03-25.md)

## Objective

Move the app from "not release-ready" to:

- Play-submission ready
- launch-ready for a controlled production rollout
- safer to operate with BioPay in scope

This plan is ranked in three bands:

- Must-fix before Play
- Should-fix before launch
- Post-launch hardening

## Release Decision

Current recommendation:

- Do not submit to Google Play yet.

Submission can be reconsidered only after all `Must-fix before Play` items are complete.

## Must-Fix Before Play

### 1. Make automated quality gates green

Priority: P0
Why: Current branch fails its own release gate.

Tasks:

- Fix all failing Flutter tests.
- Fix the BioPay Deno test that still expects 128-dimension embeddings.
- Re-run `flutter analyze`, `flutter test`, and targeted `deno test` until green.
- Update CI only if needed for real repo behavior, not to suppress failures.

Primary files:

- [`country_config_provider.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/config/country_config_provider.dart)
- [`enums.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/constants/enums.dart)
- [`role_switch_footer_test.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/widgets/role_switch_footer_test.dart)
- [`app_smoke_test.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/app_smoke_test.dart)
- [`index_test.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index_test.ts)

Acceptance criteria:

- `flutter analyze` passes with no new errors.
- `flutter test` passes.
- Key Deno backend tests pass, including BioPay tests.
- CI would pass on a clean branch.

### 2. Fix release integration blockers

Priority: P0
Why: Platform integration validation is failing now.

Tasks:

- Replace placeholder Apple Team IDs in both `.well-known/apple-app-site-association` files.
- Add the real Rwanda iOS Firebase plist.
- Re-run:
  - `./scripts/validate_release_integrations.sh --flavor mt`
  - `./scripts/validate_release_integrations.sh --flavor rw --well-known-dir ../landing-rw/.well-known`
- Validate published deep-link artifacts on both domains.

Primary files and artifacts:

- [`landing/.well-known/apple-app-site-association`](/Volumes/PRO-G40/DINEIN%20MALTA/landing/.well-known/apple-app-site-association)
- [`landing-rw/.well-known/apple-app-site-association`](/Volumes/PRO-G40/DINEIN%20MALTA/landing-rw/.well-known/apple-app-site-association)
- [`README.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/README.md)
- `ios/Runner/GoogleService-Info-rw.plist`

Acceptance criteria:

- Both validation scripts pass.
- Android app links and iOS universal-link artifacts are final, not placeholder content.

### 3. Reconcile actual Android permissions with docs and declarations

Priority: P0
Why: The current packaged app and the repo’s Play documentation do not match.

Tasks:

- Audit the release merged manifest, not just the source manifest.
- Determine which merged permissions are intentional and which are accidental.
- Remove non-essential merged permissions if possible, especially:
  - `RECORD_AUDIO`
  - `READ_EXTERNAL_STORAGE`
  - `WRITE_EXTERNAL_STORAGE`
- If any remain, update:
  - Play Data safety answers
  - privacy policy
  - internal release docs

Primary files:

- [`AndroidManifest.xml`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/android/app/src/main/AndroidManifest.xml)
- [`google_play_submission_permissions.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/docs/google_play_submission_permissions.md)
- `/Volumes/PRO-G40/DINEIN MALTA/dinein_app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`
- `/Volumes/PRO-G40/DINEIN MALTA/dinein_app/build/app/intermediates/manifest_merge_blame_file/mtDebug/processMtDebugMainManifest/manifest-merger-blame-mt-debug-report.txt`

Acceptance criteria:

- A final merged release manifest is reviewed and signed off.
- `google_play_submission_permissions.md` reflects the real release artifact.
- No undocumented sensitive permission remains.

### 4. Update privacy policy and BioPay disclosure coverage

Priority: P0
Why: BioPay materially changes the privacy and policy surface.

Tasks:

- Add explicit policy language for:
  - face capture
  - biometric embeddings
  - what is stored versus not stored
  - purpose of matching
  - retention/deletion path
  - abuse handling and security controls
- Confirm the in-app disclosure wording matches the public privacy policy.
- Ensure Malta and Rwanda policy pages remain aligned where needed and intentionally different where needed.

Primary files:

- [`landing/privacy.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing/privacy.html)
- [`landing-rw/privacy.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing-rw/privacy.html)
- [`biopay_register_screen.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/features/biopay/screens/biopay_register_screen.dart)
- [`permission_access_dialog.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/shared/widgets/permission_access_dialog.dart)

Acceptance criteria:

- Public policy explicitly covers BioPay data handling.
- In-app copy and public policy do not conflict.
- Play Data safety responses can be completed accurately from current behavior.

### 5. Harden BioPay face-match abuse controls

Priority: P0
Why: This is the highest security risk in the current app.

Tasks:

- Replace in-memory rate limiting with durable shared rate limiting.
- Add stronger abuse controls around `match_face`.
- Review whether `display_name` and `ussd_string` should be returned directly on successful face match.
- Add logging, alerting, and abuse runbooks for repeated match attempts.

Primary files:

- [`biopay-api/index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index.ts)
- [`20260322020000_biopay_rw_foundation.sql`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/migrations/20260322020000_biopay_rw_foundation.sql)

Acceptance criteria:

- Face-match limits survive cold starts and multi-instance traffic.
- Abuse controls are testable.
- Response payload is justified and documented.

### 6. Freeze a final release docs set

Priority: P0
Why: Current release docs are stale and operationally unsafe.

Tasks:

- Update:
  - `RELEASE_TODAY.md`
  - `google_play_submission_permissions.md`
  - any public download messaging that implies iOS is still "later" if that is no longer the intended launch message
- Remove or mark stale guidance that is no longer authoritative.

Primary files:

- [`RELEASE_TODAY.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/RELEASE_TODAY.md)
- [`google_play_submission_permissions.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/docs/google_play_submission_permissions.md)
- [`landing/download/index.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing/download/index.html)
- [`landing-rw/download/index.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing-rw/download/index.html)

Acceptance criteria:

- Ops/release docs match the actual state of the code and artifacts.
- No known stale release blocker remains documented as already solved.

## Should-Fix Before Launch

### 7. Tighten sensitive local token storage

Priority: P1

Tasks:

- Remove `SharedPreferences` fallback for:
  - admin sessions
  - venue sessions
  - BioPay owner tokens
- Review whether order receipt tokens also need stronger storage.

Primary files:

- [`auth_repository.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/auth_repository.dart)
- [`biopay_local_session_store.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/features/biopay/services/biopay_local_session_store.dart)
- [`order_receipt_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/order_receipt_service.dart)

Acceptance criteria:

- Sensitive session material does not silently downgrade to weak local storage.

### 8. Verify or reduce client-side Google Places key exposure

Priority: P1

Tasks:

- Confirm production restrictions on `GOOGLE_MAPS_API_KEY`.
- If restrictions are weak or difficult to guarantee, move the search behind a backend proxy.

Primary files:

- [`google_places_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/google_places_service.dart)
- [`discover_assistant_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/discover_assistant_service.dart)

Acceptance criteria:

- The key is restricted by package and SHA where applicable, or no longer directly usable for abuse.

### 9. Add true integration tests

Priority: P1

Tasks:

- Add an `integration_test/` layer for core flows:
  - guest browse to order
  - guest order history
  - venue OTP login
  - venue settings save
  - deep-link routing
  - BioPay enroll and match happy path plus denial path

Acceptance criteria:

- At least the highest-risk flows run in a real app runtime.

### 10. Run structured accessibility QA

Priority: P1

Tasks:

- Test TalkBack on Android.
- Test large text and display scaling.
- Audit primary controls and screen labels for semantics coverage.
- Review tiny text and truncation-heavy screens.

Primary files likely affected:

- [`shared_widgets.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/shared/widgets/shared_widgets.dart)
- [`role_switch_footer.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/shared/widgets/role_switch_footer.dart)
- venue and guest screens flagged in the audit

Acceptance criteria:

- Core guest, venue, and admin flows are usable with screen reader and large text.

### 11. Produce and test a signed Android release artifact

Priority: P1

Tasks:

- Build signed `apk` and `aab`.
- Install the signed release build on at least one physical Android device.
- Verify startup, auth, ordering, and deep links.

Acceptance criteria:

- Signed release artifact launches and passes manual smoke.

### 12. Run a full launch UAT matrix

Priority: P1

Suggested matrix:

- Guest:
  - discover
  - venue detail
  - add to cart
  - place order
  - order history
  - deep-link venue open
- Venue:
  - OTP login
  - dashboard
  - orders
  - settings
  - Wi-Fi config
  - notifications
- Admin:
  - login
  - claims review
  - venue list
  - role-based access boundaries
- BioPay:
  - enroll
  - re-enroll
  - match
  - report abuse
  - delete profile

Acceptance criteria:

- Every critical flow has a named owner, test result, and blocker status.

## Post-Launch Hardening

### 13. Refactor oversized backend functions

Priority: P2

Targets:

- `supabase/functions/dinein-api/index.ts`
- `supabase/functions/biopay-api/index.ts`
- large `_shared` enrichment/image modules

Goal:

- Reduce defect density and make security review easier.

### 14. Dependency refresh sprint

Priority: P2

Tasks:

- Upgrade stale Firebase, camera, ML Kit, secure-storage, and notification packages.
- Replace or eliminate discontinued transitive dependencies where possible.

### 15. Add performance budgets and measurement

Priority: P2

Tasks:

- Measure cold start, route transition latency, scroll performance, and release bundle size.
- Add a release-size check and basic Android vitals review to the release checklist.

### 16. Improve operational documentation

Priority: P2

Tasks:

- Document auth architecture, token flows, and country-flavor behavior.
- Add BioPay operational runbooks for abuse, false matches, deletion, and support handling.

## Recommended Execution Order

### Phase 1: Unblock release integrity

Target: 1 to 3 days

- Fix red tests
- Fix release integration validation
- Reconcile real Android permissions

### Phase 2: Fix policy and security blockers

Target: 2 to 4 days

- Update privacy policy and Play declarations
- Harden BioPay face-match controls
- Lock down sensitive token storage

### Phase 3: Prove runtime quality

Target: 2 to 5 days

- Add integration coverage for critical flows
- Run signed Android release smoke
- Run accessibility pass
- Run UAT matrix

### Phase 4: Submit

Target: after all P0 items and minimum P1 quality checks are complete

- Complete Play Console Data safety and app-content forms
- Run final pre-submission validation
- Ship to internal or closed track first

## Minimum Exit Criteria Before Play Submission

- All automated tests green
- Release integration validation green for target flavor
- Final merged release manifest reviewed
- Privacy policy updated and published
- Play Data safety answers prepared from current app behavior
- BioPay abuse controls upgraded beyond in-memory rate limiting
- Signed Android release build smoke-tested on physical device
- Closed-track manual UAT completed with no unresolved P0 defects

## Recommended Go/No-Go Rule

Go only if:

- every `Must-fix before Play` item is complete
- no unresolved P0 defect remains in guest ordering, auth, or BioPay
- release docs and public privacy disclosures match current shipped behavior

Otherwise:

- hold submission and continue on the next remediation phase
