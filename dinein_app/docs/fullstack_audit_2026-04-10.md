# DINEIN Full-Stack Audit

Date: 2026-04-10

Scope covered:
- Flutter mobile app (`dinein_app`)
- Shared packages (`packages/core`, `packages/db`, `packages/ui`)
- Supabase backend, migrations, and edge functions
- Hosted guest / venue / admin web surfaces and landing sites
- Android release gating and Google Play submission readiness
- Runtime QA/UAT on a physical Android device and live browser smoke checks

Methods used:
- Static analysis: `flutter analyze`, Dart MCP analysis
- Automated tests: `flutter test`, Deno edge-function tests
- Dependency review: `flutter pub outdated`
- Live backend probes: `scripts/smoke_live_backend.sh`
- Android device checks: Flutter tooling + Android MCP + `adb` log capture
- Browser checks: existing Playwright smoke harness against live surfaces

## Executive status

Current release readiness is **not acceptable for Google Play submission**.

Primary blockers:
- Automated Android release gate fails before packaging because `flutter analyze` is red.
- Main Flutter test suite is not green.
- Malta production backend currently reports open database network restrictions.
- Google Play submission metadata and console-side declarations still need manual verification, especially Data safety, app access, and tester-track readiness.

## Severity 1 findings

### 1. Android release gate is red and stops before packaging

Evidence:
- `scripts/build_android_release.sh` validates release credentials, then enforces `flutter analyze` and `flutter test` before building artifacts.
- A real run of `./scripts/build_android_release.sh --flavor mt` stopped during `flutter analyze` with code quality failures, so the release path is blocked before APK/AAB generation.

Relevant code:
- [scripts/build_android_release.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/build_android_release.sh#L84)
- [scripts/build_android_release.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/build_android_release.sh#L128)
- [scripts/build_android_release.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/build_android_release.sh#L135)

Impact:
- The store artifact pipeline is not releasable under the project’s own enforced quality gate.

### 2. Compile-time test fixtures are stale against the current production model API

Evidence:
- `admin_dashboard_screen_test.dart` still constructs `Venue` with a removed named argument and uses a removed enum value.
- `menu_screen_test.dart` overrides `CartNotifier` with outdated method signatures.

Relevant code:
- [admin_dashboard_screen_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/features/admin/dashboard/admin_dashboard_screen_test.dart#L23)
- [admin_dashboard_screen_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/features/admin/dashboard/admin_dashboard_screen_test.dart#L32)
- [admin_dashboard_screen_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/features/admin/dashboard/admin_dashboard_screen_test.dart#L42)
- [menu_screen_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/features/guest/menu/menu_screen_test.dart#L10)
- [menu_screen_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/features/guest/menu/menu_screen_test.dart#L28)
- [menu_screen_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/features/guest/menu/menu_screen_test.dart#L32)

Impact:
- The test suite no longer protects current behavior in these flows.
- This is a process failure as much as a code failure: production interfaces changed without synchronized test maintenance.

### 3. Widget/UAT regression exists in the venue menu editor flow

Evidence:
- `flutter test` reports the widget test expectation for manual-image state no longer matches the rendered UI.

Relevant code:
- [venue_menu_editor_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/flows/venue_menu_editor_test.dart#L17)
- [venue_menu_editor_test.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/test/flows/venue_menu_editor_test.dart#L56)

Impact:
- Either the UX copy/state contract changed without updating tests, or the intended behavior regressed.
- This is exactly the kind of breakage that produces false confidence during release sign-off.

### 4. Malta hosted database surface appears too exposed at the network perimeter

Evidence:
- `scripts/smoke_live_backend.sh --flavor mt` passed core API and auth checks, but reported:
  - database SSL enforcement enabled
  - database network restrictions open to all IPv4/IPv6 ranges

Relevant code used to perform the check:
- [smoke_live_backend.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/smoke_live_backend.sh)

Impact:
- This increases attack surface and weakens the backend security posture.
- RLS and auth are in place, but public network exposure is still unnecessary risk for a production database.

## Severity 2 findings

### 5. Automated test coverage is concentrated in the app layer and effectively absent in shared packages

Evidence:
- `dinein_app/test` contains 65 test files.
- Shared package coverage is effectively missing:
  - `packages/core` has a minimal passing test surface
  - `packages/db` has no meaningful test suite
  - `packages/ui` has no meaningful test suite

Impact:
- Reusable business logic, models, and UI primitives can drift without fast feedback.
- The stale test failures above are consistent with weak ownership of shared-contract testing.

### 6. Android cold-start and render performance need dedicated profiling before release

Evidence observed on physical device:
- App launches and navigates successfully, but startup logcat showed:
  - skipped frames on launch
  - graphics allocator / hardware buffer warnings
  - swap-behavior warnings from the renderer

Impact:
- This is not a release blocker by itself, but it is a strong pre-vitals warning.
- On lower-tier devices, this can become user-perceived jank or ANR-adjacent behavior.

### 7. Release integration validation is not reliably completing in this environment

Evidence:
- `validate_release_integrations.sh` passed icon validation, then stalled in the Gradle release-manifest task path for both flavors.
- Prior runs also emitted repeated `Invalid depfile` warnings from Flutter build outputs.

Relevant code:
- [validate_release_integrations.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/validate_release_integrations.sh#L123)
- [validate_release_integrations.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/validate_release_integrations.sh#L184)

Impact:
- This weakens confidence in deterministic local/CI release validation.
- The underlying issue looks more like build tooling/cache instability than a manifest correctness failure, but it still needs cleanup.

### 8. Web surfaces are live and functional, but there are quality warnings worth treating as pre-release defects

Evidence from live Playwright smoke:
- All checked surfaces returned `200` and routed correctly.
- Browser console still showed:
  - GPU/WebGL `ReadPixels` stall warnings on guest web
  - missing Noto font warning on admin login

Impact:
- These are not catastrophic, but they are visible quality debt on externally facing surfaces.
- The font warning is especially avoidable and reflects incomplete asset/font coverage.

### 9. Deep-link handling requires a clean-device verification pass before store submission

Evidence:
- A live venue link (`https://dineinmt.ikanisa.com/v/...`) opened Chrome instead of the installed Malta app on the audited device.
- The package diagnostics also showed domain verification metadata existed, while user selection state for the host on that device was disabled.

Impact:
- This is not enough evidence to call it a code defect.
- It is enough evidence to treat app-link behavior as a required release-UAT item on a clean device or after resetting link-handling state.

## Severity 3 findings

### 10. The app is hard-forced into dark mode on both Flutter and iOS

Evidence:
- Flutter app root sets only dark theme and hard-locks `ThemeMode.dark`.
- iOS `Info.plist` also hard-locks interface style to `Dark`.

Relevant code:
- [app_entry.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/app_entry.dart#L58)
- [app_entry.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/app_entry.dart#L61)
- [app_entry.dart](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/lib/app_entry.dart#L63)
- [Info.plist](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/ios/Runner/Info.plist#L56)

Impact:
- This may be intentional brand direction, but it removes system-theme adaptability and can become an accessibility/support issue.
- I am flagging it as a product decision to confirm, not as an automatic defect.

### 11. Some analyzer warnings indicate small but real cleanup debt

Evidence:
- Unused variables / parameters in app code.
- Unused import and unused helper in a venue test.
- Unused helper in `packages/db`.

Impact:
- Low risk individually.
- Combined with stale tests, these are symptoms of release hygiene drifting.

## Security and backend posture

Positive signals:
- Live MT and RW backends responded successfully.
- Unauthenticated role lookup was rejected.
- Unauthorized venue mutation was rejected.
- Edge-function test suites passed for:
  - `dinein-api`
  - `whatsapp-otp`
  - `biopay-api`
- Supabase runtime bootstrap has explicit fail-fast protection for missing configuration.
- Release env scripts correctly prevent shipping placeholder Supabase credentials.

Relevant code:
- [validate_release_integrations.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/validate_release_integrations.sh#L78)
- [build_android_release.sh](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/scripts/build_android_release.sh#L84)

Open concerns:
- Malta DB network restrictions are open.
- WhatsApp OTP readiness script could not be completed because `SUPABASE_SERVICE_ROLE_KEY` was not available in the shell environment used for the audit.

## Google Play readiness

### What is already aligned

- `targetSdk` is sourced from Flutter/Gradle and the installed package reports target SDK 36.
- Flavor-specific package IDs and app-link hosts are wired correctly.
- Android packaging explicitly sets `useLegacyPackaging = false`, which is the correct direction for 16 KB-aligned native packaging.

Relevant code:
- [build.gradle.kts](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/android/app/build.gradle.kts#L67)
- [build.gradle.kts](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/android/app/build.gradle.kts#L75)
- [build.gradle.kts](/Volumes/PRO-G40/DINEIN%20MALTA/dinein_app/android/app/build.gradle.kts#L84)

### What still blocks or needs confirmation

1. The build gate must be green.
2. A real release AAB should be produced and checked with `bundletool dump config` and `zipalign -c -P 16 -v 4`.
3. Data safety declarations must match actual app + SDK behavior for both packages.
4. Privacy policies must remain synchronized with each flavor’s real permissions and data usage.
5. Any login-restricted surfaces used during review must have reusable Play Console app-access credentials and instructions.
6. If the Play developer account is a new personal account, closed-testing requirements may apply before production.

### Official Google Play / Android references checked

- Target API level requirements:
  - Google says new apps and updates must target Android 15 (API 35) or higher from 2025-08-31.
  - Source: <https://support.google.com/googleplay/android-developer/answer/11926878?hl=en>
- 16 KB page-size requirement:
  - Google says starting 2025-11-01, new apps and updates targeting Android 15+ must support 16 KB page sizes.
  - Source: <https://developer.android.com/guide/practices/page-sizes>
- Data safety:
  - Google requires all published apps except internal-test-only apps to complete the Data safety form and provide a privacy policy.
  - Source: <https://support.google.com/googleplay/android-developer/answer/10787469?hl=en>
- Sensitive permissions:
  - Google requires sensitive permissions to be necessary for promoted core functionality and requested in context.
  - Source: <https://support.google.com/googleplay/android-developer/answer/16558241>
- App access:
  - If parts of the app are restricted by login or other authentication, Google requires review instructions and usable credentials in Play Console.
  - Sources:
    - <https://support.google.com/googleplay/android-developer/answer/9859455?hl=en-AE>
    - <https://support.google.com/googleplay/android-developer/answer/15748846?hl=en-PH>
- New personal developer accounts:
  - Google requires a closed test with at least 12 opted-in testers for 14 continuous days before production access.
  - Source: <https://support.google.com/googleplay/android-developer/answer/14151465?hl=en>

## UAT summary

What passed during live checks:
- Malta app installed and launched on physical Android hardware.
- Core guest landing and settings navigation were functional.
- Guest, venue, and admin live web routes returned successfully.
- Landing pages for both countries loaded with expected branding and content.
- MT and RW live backend smoke checks passed core health and authorization probes.

What still needs explicit sign-off:
- End-to-end order placement and payment path per country
- OTP flows under real production credentials
- Venue/admin authenticated flows with reusable review accounts
- Deep-link opening on a clean Android device
- Low-end device performance pass
- Tablet / foldable / large-screen behavior if those form factors are in scope

## Recommended next actions

1. Fix the red analyzer/test blockers first and do not attempt store submission before the gate is green.
2. Lock down Malta production DB network restrictions.
3. Stabilize `validate_release_integrations.sh` so it completes deterministically for both flavors.
4. Produce signed release AABs for both packages and verify 16 KB alignment explicitly.
5. Audit the Play Console Data safety answers against actual permissions, SDKs, web push, analytics, notifications, OTP, and Rwanda BioPay behavior.
6. Prepare permanent Play review credentials and app-access instructions for any restricted surfaces.
7. Run a clean release-UAT matrix on:
   - one fresh Android device
   - one slower Android device
   - one iPhone
   - Chrome / Safari guest web

## Bottom line

The product is materially closer to release-ready than the older March audit suggested. The live backend is functional, privacy URLs exist, Malta permissions are lean, and Rwanda camera usage is correctly flavor-scoped.

As of 2026-04-10, the red release gates called out earlier in this audit have been remediated:
- `flutter analyze` passes for `dinein_app`, `packages/core`, `packages/db`, and `packages/ui`.
- `flutter test` passes for the app, and added regression coverage now protects shared country config, DB model serialization, and shared widget contracts.
- `scripts/validate_release_integrations.sh` now passes deterministically for both Malta and Rwanda Android builds.
- Signed release artifacts were rebuilt successfully for both flavors:
  - Malta APK SHA-256: `5cb51f9bcb89f2233c785471d0f8acb6a630d748eec1004089475e1066285b71`
  - Malta AAB SHA-256: `7ab7308988917427c747adf18fb47fed369eab0810cf45854b6cf211e56a664b`
  - Rwanda APK SHA-256: `ae60551c27dd342a2f728f1524d05af43cf9738ec9d2818f8301d80596fd04ab`
  - Rwanda AAB SHA-256: `95d4fb5442a7e3ae7e162d196cf16cb510b82908fa81be0e6f6623ea7be4abcd`
- Release APK alignment checks pass for both flavors with `zipalign -c -P 16 -v 4`.
- Malta production DB network restrictions were tightened from world-open access to explicit IPv4/IPv6 allowlists and revalidated through the live smoke suite.
- MT and RW web release builds complete successfully and verify startup loader, headers, manifest, offline fallback, public-route prerenders, service workers, and install screenshots.

The remaining non-code blockers are narrower:
- Play Console Data safety, app access credentials, and review instructions still require human/operator confirmation against the final release process.
- Headless emulator capture for the Rwanda runtime smoke returned black frames even on the launcher, so visual proof for that one pass is limited to process/activity evidence rather than usable screenshots.

Infrastructure status after the final remediation pass:
- Rwanda DB network restrictions were tightened to explicit IPv4/IPv6 operator CIDRs and are no longer world-open.
- Rwanda DB SSL enforcement is now enabled and confirmed through the live smoke suite.

With those caveats, the repository itself is now in a materially stronger release state than this audit originally recorded.
