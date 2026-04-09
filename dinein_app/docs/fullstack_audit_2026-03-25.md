# DineIn Fullstack Audit

Date: 2026-03-25
Audited repo: `/Volumes/PRO-G40/DINEIN MALTA`
Primary app: `/Volumes/PRO-G40/DINEIN MALTA/dinein_app`
Audit mode: read-only repo audit, static analysis, test execution, backend smoke checks, Android device smoke, and policy research

## Executive Summary

This repo is not release-ready today for a production store push without remediation.

The strongest positive signals are:

- The hosted backends for both Malta and Rwanda are live and passed the repo’s own smoke checks.
- The Flutter app builds a current Android debug artifact and launches on a physical Pixel 4a.
- The Android app is already targeting API 36, which is above Google Play’s current minimum requirement of API 35 for phone/tablet submissions as of August 31, 2025.
- There is real security hardening work in the backend, especially around unsigned venue-session rejection and BioPay table isolation.

The main blockers are:

- Automated quality gates are red: 17 Flutter tests are currently failing and 1 Deno test is failing.
- Release integration validation is red for both flavors.
- Current Android permission posture and documentation are out of sync.
- BioPay introduces a materially higher security, privacy, and policy-review burden than the current privacy and Play-prep docs account for.

Overall readiness call:

- Product readiness: Partial
- Engineering readiness: Moderate, but unstable
- QA/UAT readiness: Not ready
- Security readiness: Mixed, with several high-risk issues concentrated in BioPay and client-side key handling
- Google Play readiness: Not ready

## Scope And Methodology

This audit covered:

- Flutter app structure, routing, app boot, native manifests, permissions, and key user flows
- Supabase edge functions, migrations, and security posture
- Local tests and analyzers
- Live backend smoke checks against both hosted Supabase projects
- Android build and hardware launch on device `13111JEC215558` (Pixel 4a)
- Current Google Play and Android policy guidance from official Google sources

Commands and checks executed:

- `flutter analyze`
- `flutter test` through the Dart MCP runner with JSON reporting
- `deno test` on key edge functions
- `./scripts/smoke_live_backend.sh --flavor mt`
- `./scripts/smoke_live_backend.sh --flavor rw`
- `./scripts/validate_release_integrations.sh --flavor mt`
- `./scripts/validate_release_integrations.sh --flavor rw --well-known-dir ../landing-rw/.well-known`
- `flutter build apk --debug --flavor mt -t lib/main_mt.dart --dart-define-from-file=env/release.mt.json`
- Android install and launch of `app-mt-debug.apk` on a physical device
- `flutter pub outdated`

Limits of this audit:

- No signed Android release build was produced because release signing assets were not used in this audit.
- No iOS archive was produced.
- No external penetration test was performed.
- No Play Console account was available to verify actual declaration forms or account-specific gates.

## Severity-Ranked Findings

### Critical 1: The automated release gate is red

Evidence:

- CI expects `flutter analyze` and `flutter test` on every PR and push: [`ci.yml`](/Volumes/PRO-G40/DINEIN%20MALTA/.github/workflows/ci.yml#L14)
- Flutter tests currently fail in 17 cases, including guest shell, profile, permissions, venue QR, venue settings, and role-switch footer flows.
- Deno tests have 1 current failure in BioPay embedding normalization.

Impact:

- This branch would not pass its own core quality gate.
- Regressions already exist in navigation and UI shell behavior.
- Store submission at this stage would push known instability into manual QA.

Primary causes found:

- `countryConfigProvider` now throws unless explicitly overridden, and several tests still instantiate `ProviderScope` without overriding it: [`country_config_provider.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/config/country_config_provider.dart#L8), [`app_smoke_test.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/app_smoke_test.dart)
- Enum boundary tests are stale after the repo expanded from Malta-only assumptions to Malta plus Rwanda and added `momoUssd`: [`enums.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/constants/enums.dart#L48)
- BioPay test fixture still expects 128-dimension embeddings while code and schema now require 192: [`index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index.ts#L445), [`20260323100000_biopay_embedding_dim_192.sql`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/migrations/20260323100000_biopay_embedding_dim_192.sql#L1), [`embedding_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/features/biopay/services/embedding_service.dart#L6)

Representative failing Flutter tests:

- `splash auto-navigates to discover after timeout`
- `venue table QR screen renders and updates table label`
- `guest profile matches the guest account design layout`
- `guest discover route shows the location popup when missing`
- `venue settings renders section headers and key configuration tiles`
- 8 `role_switch_footer_test.dart` cases

Representative failing Deno test:

- `normalizeBiopayEmbedding returns an L2-normalized vector`

Recommendation:

- Make green tests the immediate release blocker.
- Fix provider overrides in test harnesses.
- Update stale enum boundary tests.
- Align BioPay test vectors and comments with the 192-dimension model and schema.

### Critical 2: Android permission posture, Play documentation, and privacy disclosures are inconsistent

Evidence from source:

- Current source manifest explicitly declares `CAMERA`: [`AndroidManifest.xml`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/android/app/src/main/AndroidManifest.xml#L2)
- The in-repo Play submission doc still says `CAMERA` is intentionally not declared and says Android venue capture does not request it: [`google_play_submission_permissions.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/docs/google_play_submission_permissions.md#L56)

Evidence from current packaged Android artifact:

- The current `mtDebug` merged manifest includes `CAMERA`, `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` and `POST_NOTIFICATIONS`: `/Volumes/PRO-G40/DINEIN MALTA/dinein_app/build/app/intermediates/merged_manifests/mtDebug/processMtDebugManifest/AndroidManifest.xml`
- Manifest-merger blame shows:
  - `RECORD_AUDIO` comes from `camera_android_camerax`
  - `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE` are merged from the camera stack
  - `GET_CONTENT` query comes from `file_picker`
  Source: `/Volumes/PRO-G40/DINEIN MALTA/dinein_app/build/app/intermediates/manifest_merge_blame_file/mtDebug/processMtDebugMainManifest/manifest-merger-blame-mt-debug-report.txt`
- Android package diagnostics on the installed app showed requested permissions including `CAMERA`, `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, and `POST_NOTIFICATIONS`, plus install/runtime grants on the test device.

Policy significance:

- Google’s data-use guidance says declaring `READ_EXTERNAL_STORAGE` maps into Photos/Videos and Files/Docs disclosure scope, and `RECORD_AUDIO` maps into audio data scope.
- Google’s User Data policy requires accurate privacy policy coverage and in-app disclosure where access, collection, or sharing is outside user expectation.

Impact:

- Current Play prep documentation is not reliable.
- If the current packaged permission set is submitted without aligned declarations, the app risks Play review rejection or post-review enforcement.
- The privacy policy currently mentions camera and files, but not microphone-related access or any biometrics/BioPay face embedding processing.

Recommendation:

- Treat current Play submission docs as stale and rewrite them from the merged manifest, not from assumptions.
- Remove unintended merged permissions if they are not product requirements.
- If they cannot be removed, update Play Data safety, privacy policy, and store disclosures to match the real packaged artifact.

### Critical 3: BioPay face matching is too exposed for production as currently implemented

Evidence:

- Supabase edge functions broadly run with `verify_jwt = false`: [`config.toml`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/config.toml#L390)
- BioPay API uses wildcard CORS: [`biopay-api/index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index.ts#L4)
- Face-match rate limiting is only an in-memory `Map`, so it is process-local and non-durable across cold starts or multiple edge instances: [`biopay-api/index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index.ts#L22), [`biopay-api/index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index.ts#L611)
- A successful face match returns `biopay_id`, `display_name`, and `ussd_string`: [`biopay-api/index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/biopay-api/index.ts#L855)

Positive counter-evidence:

- BioPay tables are protected with RLS and revoked from `anon` and `authenticated`; access is granted to `service_role` only: [`20260322020000_biopay_rw_foundation.sql`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/migrations/20260322020000_biopay_rw_foundation.sql#L174)

Impact:

- The database layer is tighter than the API layer.
- The main residual risk is API abuse and enumeration at the function boundary, not raw table access.
- Returning payment identifiers and identity data on face match raises privacy, fraud, and abuse concerns that are materially higher than ordinary guest ordering flows.

Recommendation:

- Replace in-memory rate limiting with durable, shared rate limiting.
- Require a stronger proof of device or session legitimacy for `match_face`.
- Reassess whether the response should return both identity and payment string directly.
- Add abuse monitoring, anomaly detection, and explicit operational runbooks before public rollout.

### Critical 4: Store-release integration checks are failing now

Evidence:

- Malta validation currently fails because `apple-app-site-association` still contains a placeholder Apple Team ID.
- Rwanda validation currently fails because `ios/Runner/GoogleService-Info-rw.plist` is missing and the Rwanda `apple-app-site-association` also still contains a placeholder Apple Team ID.
- Source guidance already says Rwanda iOS still needs a real Firebase plist: [`README.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/README.md#L86)

Impact:

- Deep-link and platform-release integrity is incomplete.
- Rwanda iOS is not archive-ready.

Recommendation:

- Render and publish final `.well-known` artifacts for both hosts.
- Add the real Rwanda iOS Firebase plist.
- Re-run release validation as a required release gate.

### High 5: Privacy policy and Play declarations do not yet cover BioPay adequately

Evidence:

- Current privacy policy mentions location, camera/file access, notifications, WhatsApp OTP, diagnostics, and retention/deletion email path: [`landing/privacy.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing/privacy.html#L51), [`landing-rw/privacy.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing-rw/privacy.html#L51)
- Current privacy policy does not mention facial embeddings, biometric matching, BioPay owner tokens, abuse reporting, or management codes.
- The in-app BioPay flow does include a consent step and camera-access disclosure: [`biopay_register_screen.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/features/biopay/screens/biopay_register_screen.dart#L81), [`permission_access_dialog.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/shared/widgets/permission_access_dialog.dart#L48)

Impact:

- The product is ahead of its legal/policy materials.
- This is especially risky because BioPay is exactly the sort of feature that triggers closer review.

Recommendation:

- Update public privacy policy before any Play submission that includes BioPay-capable builds.
- Explicitly disclose:
  - face capture and face embeddings
  - what is stored and what is not stored
  - purpose of matching
  - retention and deletion path
  - sharing parties and security controls

### High 6: Sensitive local tokens can fall back to SharedPreferences

Evidence:

- Venue and admin session storage falls back to `SharedPreferences` if secure storage fails: [`auth_repository.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/auth_repository.dart#L185)
- BioPay local owner token storage also falls back to `SharedPreferences`: [`biopay_local_session_store.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/features/biopay/services/biopay_local_session_store.dart#L12)
- Guest order receipt tokens are stored only in `SharedPreferences`: [`order_receipt_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/order_receipt_service.dart#L1)

Impact:

- This is better than plain text files, but weaker than hardware-backed secure storage.
- BioPay owner-token fallback is the most concerning variant.

Recommendation:

- Make secure storage mandatory for privileged and biometric-adjacent session tokens.
- Restrict `SharedPreferences` fallback to non-sensitive dev/test-only cases.

### High 7: Client-side Google Places key exposure is an abuse and cost risk

Evidence:

- Google Places requests are made directly from the client using `GOOGLE_MAPS_API_KEY`: [`google_places_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/google_places_service.dart#L35)
- Discover assistant can fan out to Google Places directly from the app: [`discover_assistant_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/discover_assistant_service.dart#L99)

Impact:

- Even if this key is intended to be public, it still needs strict package, SHA, referrer, and API restrictions.
- If restrictions are weak, this becomes a direct quota and cost-abuse vector.

Recommendation:

- Confirm strong Google Cloud restrictions immediately.
- Consider proxying or tokenizing this call if abuse or quota pressure becomes material.

### Medium 8: Backend authentication is functional, but non-standard and harder to reason about

Evidence:

- Venue session tokens are sent in request bodies when there is no regular user session: [`dinein_api_service.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/core/services/dinein_api_service.dart#L21)
- The backend then validates those custom tokens and rejects unsigned venue sessions: [`dinein-api/index.ts`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/supabase/functions/dinein-api/index.ts#L1503)

Positive evidence:

- Live smoke checks passed for unauthenticated user-role rejection and unauthorized venue mutation rejection in both hosted backends.

Impact:

- The architecture works, but it is more bespoke than a standard header-based auth model.
- This increases maintenance burden and review complexity.

Recommendation:

- Keep the current protections, but document the full auth model as a first-class design artifact.
- Add more explicit negative tests around token scope, expiry, replay, and cross-venue misuse.

### Medium 9: Accessibility posture is incomplete

Evidence:

- The only explicit `Semantics` wrapper found in the Flutter codebase is the shared `PressableScale` control: [`pressable_scale.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/shared/widgets/pressable_scale.dart#L103)
- The app uses many `10px` and `12px` text styles and many truncation patterns across venue and guest surfaces: `rg` findings across venue dashboard, orders, settings, guest menu, venue management, admin venue workflows, and shared widgets
- The app is forced into dark mode at the app root and on iOS: [`main_mt.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/main_mt.dart#L52), [`Info.plist`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/ios/Runner/Info.plist#L45)

Positive evidence:

- Android device semantics dump showed buttons and major text content exposed on the tested guest order-history screen.

Impact:

- The app is not inaccessible by default, but it does not appear to have been systematically audited for screen readers, text scaling, contrast variants, reduced motion, or keyboard-only operation.

Recommendation:

- Run TalkBack and iOS VoiceOver passes on core guest, venue, and admin flows.
- Test with large text and accessibility font scaling.
- Replace fragile truncation and tiny captions in critical flows.

### Medium 10: No true end-to-end integration-test layer exists

Evidence:

- There are 38 test files under `test/`.
- There is no `integration_test/`, `e2e/`, or `test_driver/` directory.

Impact:

- Widget tests cover a fair amount of UI logic, but not true end-to-end runtime behavior across native permissions, deep links, push, OCR, WhatsApp OTP, or BioPay camera flows.

Recommendation:

- Add an integration-test layer for:
  - deep-link routing
  - guest order placement and order history
  - venue OTP login and dashboard notifications
  - permission prompt paths
  - BioPay enrollment and match happy-path and denial-path behavior

### Medium 11: Documentation drift is real and already causing confusion

Evidence:

- `RELEASE_TODAY.md` still describes a migration frontier from March 21 that is already behind the current repo state: [`RELEASE_TODAY.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/RELEASE_TODAY.md#L39)
- Play permissions documentation is stale versus current source and packaged artifacts: [`google_play_submission_permissions.md`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/docs/google_play_submission_permissions.md#L56)
- The public download pages still say iOS distribution can be added later: [`landing/download/index.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing/download/index.html#L227), [`landing-rw/download/index.html`](/Volumes/PRO-G40/DINEIN%20MALTA/landing-rw/download/index.html#L227)

Impact:

- Release operators can make the wrong call from stale documents.
- Public messaging and actual platform readiness are not aligned.

Recommendation:

- Make release docs generated or validated against current artifacts where possible.
- Stop treating manual documents as authoritative unless they are updated as part of CI or release checks.

### Medium 12: Dependency maintenance is lagging in several key packages

Evidence:

- `flutter pub outdated` reports major-version gaps in `camera`, `flutter_local_notifications`, `flutter_secure_storage`, `google_mlkit_face_detection`, and `tflite_flutter`.
- The transitive `js` package is marked discontinued.

Impact:

- This is not an immediate blocker by itself, but it increases future upgrade risk and can hide security or compatibility issues.

Recommendation:

- Plan a dependency refresh sprint after release blockers are fixed.
- Review changelogs carefully for camera, storage, and Firebase packages because those are permission- and runtime-sensitive.

## Category Assessment

### Frontend And UX

Strengths:

- The app structure is coherent and flavor-aware.
- Hardware launch on Android succeeded after building the debug APK.
- Device UI dump showed the app rendering a guest order-history screen with actionable controls.

Weaknesses:

- UI regressions are already showing up in tests.
- The design system uses many small text treatments that are risky under accessibility scaling.
- The app is dark-only, which is a deliberate choice but reduces flexibility and may complicate some accessibility scenarios.

Readiness call:

- Functional UX foundation exists, but current regression state is too unstable for release.

### Accessibility

Strengths:

- Shared tappable control includes semantics, keyboard activation, and minimum touch-target handling.
- Permission dialogs provide explicit, feature-scoped copy.

Weaknesses:

- No evidence of a structured accessibility test pass.
- No integration-test coverage for accessibility.
- Tiny typography and heavy truncation patterns are widespread.

Readiness call:

- Not ready for accessibility-sensitive release without a dedicated pass.

### Backend And API

Strengths:

- Hosted Malta and Rwanda backends both passed live smoke checks.
- Unauthorized venue mutations are rejected.
- Unsigned venue sessions are explicitly rejected.

Weaknesses:

- Several edge functions rely on custom auth and `verify_jwt = false`.
- `dinein-api/index.ts` is extremely large, which hurts reviewability and defect isolation.
- BioPay API is materially more exposed than the rest of the stack.

Readiness call:

- Core ordering backend looks viable.
- BioPay backend is not yet at the same maturity level.

### Database And Data Layer

Strengths:

- BioPay tables are RLS-enabled and locked down to `service_role`.
- Ordering backend has hardening and validation logic in migrations.

Weaknesses:

- Test and schema drift already occurred around BioPay embedding dimensions.
- Release-state documentation about migrations is stale.
- The backend tree contains broader historical modules unrelated to current DineIn scope, which increases operational complexity.

Readiness call:

- Core database posture is acceptable, but migration discipline needs tightening.

### Security

Strengths:

- Hosted smoke tests confirmed some real auth boundaries.
- TLS-backed cloud services and server-side matching architecture are directionally correct.

Weaknesses:

- Open CORS on sensitive function surfaces.
- Durable abuse controls are missing for face match.
- Sensitive local token fallbacks are too permissive.
- Client-side key exposure remains a practical abuse vector.

Readiness call:

- Mixed. Good baseline work exists, but BioPay and token storage issues keep this below production confidence.

### Performance

Observations:

- App boot performs multiple startup initializations in parallel before the first frame: [`main_mt.dart`](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/main_mt.dart#L20)
- The produced Android debug APK is large at about 216 MB, which is normal for debug but confirms the app bundles heavy capability sets.
- The repo’s local `build/` directory is very large, over 5 GB, which is a local hygiene signal rather than a store-size signal.
- There is no evidence in the repo of size budgets, startup budgets, or automated performance regression gates.

Readiness call:

- Performance cannot be signed off robustly from the current evidence set.
- Android vitals, startup timing, scrolling performance, and release bundle size still need explicit measurement.

### QA And UAT

Strengths:

- There is real test coverage.
- Live backend smoke scripts are valuable and useful.
- Release validation scripts exist and caught real issues.

Weaknesses:

- The core Flutter suite is red.
- No true integration-test layer exists.
- No signed-release dry run was completed in this audit.
- No Play pre-launch report evidence is present.

Readiness call:

- Not ready.

## Google Play Readiness

### What is already aligned

- Google Play currently requires new apps and app updates to target Android 15, API 35 or higher, starting August 31, 2025.
- This app currently targets API 36 through the Flutter 3.38.9 Android defaults and therefore exceeds the current target API floor.

Evidence:

- Flutter Android default target is 36: `/Volumes/PRO-G40/Apps/SDKs/flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`
- Official source: `https://support.google.com/googleplay/android-developer/answer/11926878?hl=en`

### What still blocks Play readiness

- Current permission docs do not match current packaged behavior.
- BioPay privacy disclosures are incomplete.
- Store-release integration checks are failing.
- QA evidence is insufficient for a safe first public rollout.

### Data Safety categories that almost certainly need review

Based on code and official Google guidance, the following categories should be reviewed in Play Console for accuracy:

- Phone number
- Photos
- Files and docs
- Crash logs
- Diagnostics
- Device or other IDs

Additional categories that likely require legal and product confirmation rather than blind declaration:

- Purchase history
- User-provided names
- Other user-generated content
- Audio-related declarations if `RECORD_AUDIO` remains in shipped artifacts
- Biometric-adjacent disclosures for BioPay, even though Google’s Data safety taxonomy does not have a dedicated “biometrics” row

Inference note:

- The last bullet is an inference from the app’s BioPay behavior plus Google’s User Data policy, not a direct Google taxonomy label.

### New personal Play developer account gate

If this app will ship from a personal Play developer account created after November 13, 2023, Google requires a closed test with at least 12 opted-in testers for 14 continuous days before production access can be requested.

This is conditional:

- If the account is an older or organizational account, this specific gate may not apply.
- If it is a new personal account, this is a hard publication gate.

Official source:

- `https://support.google.com/googleplay/android-developer/answer/14151465?hl=en`

## What Passed In This Audit

- `flutter analyze`: no blocking analyzer errors found
- Live backend smoke:
  - Malta passed health, venue listing, menu listing, unauthenticated-role rejection, and unauthorized venue-mutation rejection
  - Rwanda passed health, venue listing, menu listing, unauthenticated-role rejection, and unauthorized venue-mutation rejection
- Android debug build:
  - `app-mt-debug.apk` built successfully
- Android hardware smoke:
  - Installed and launched on Pixel 4a
  - App package stayed foregrounded and rendered a guest order-history screen

## Recommended Remediation Plan

### Before Any Store Submission

- Make Flutter and Deno tests green.
- Fix release integration validation for both flavors.
- Rebuild Play submission docs from current merged manifests.
- Update privacy policy for BioPay and actual permission/data behavior.
- Remove unintended Android permissions or explicitly justify and declare them.

### Security Hardening Next

- Replace BioPay in-memory rate limiting with durable shared enforcement.
- Reduce or redesign `match_face` response payloads.
- Remove `SharedPreferences` fallback for privileged tokens.
- Verify Google Maps API key restrictions in production.

### QA And UAT Next

- Add integration tests for guest, venue, admin, and BioPay.
- Run TalkBack and large-font accessibility passes.
- Run at least one signed-release smoke on Android.
- Run Play pre-launch report before production submission.

### After Release Blockers Are Cleared

- Refactor very large edge functions into smaller modules.
- Refresh stale dependencies.
- Prune or clearly isolate historical backend modules and archived trees.

## Final Readiness Verdict

If BioPay were removed from scope and the red tests plus release integration blockers were fixed, this project would be reasonably close to a controlled Play launch for the core dining product.

With BioPay in scope, the bar is higher, and the current app is not yet ready for a public production launch. The main reasons are policy drift, incomplete privacy disclosures, insufficient abuse controls around face matching, and a failing automated QA gate.

## Official Research Sources

- Google Play target API requirements:
  - https://support.google.com/googleplay/android-developer/answer/11926878?hl=en
- Google Play User Data policy:
  - https://support.google.com/googleplay/android-developer/answer/10144311
- Google Play Data safety section guidance:
  - https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Android data-use declaration guidance:
  - https://developer.android.com/privacy-and-security/declare-data-use
- Android permission minimization guidance:
  - https://developer.android.com/privacy-and-security/minimize-permission-requests
- Google Play testing requirements for new personal developer accounts:
  - https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
