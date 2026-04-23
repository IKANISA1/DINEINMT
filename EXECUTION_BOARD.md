# Execution Board

Reviewed: 2026-04-23

This board reflects the current verified repo state after the latest
stabilization and validation pass.

## Closed This Pass

- Full Flutter suite is deterministic and green.
- `flutter analyze` is green.
- Split Supabase function Deno tests and type-checks are green.
- Compatibility-only `dinein-api` Deno checks and tests are green.
- Release validation now matches the current no-direct-camera Android policy.
- Full release integration validation passed for both `mt` and `rw` when
  `.well-known` app-link artifacts are rendered from env inputs.
- A true local `supabase db reset --local` is now green after repairing four
  migration/config defects in the active reset chain.
- The quarantined historical migration archive was fully deleted from the repo
  and removed from active documentation.
- Global Flutter test bootstrap is now explicit for widget binding only; secure
  storage mocking remains file-local by design because the suite uses two
  different storage harness styles.

## P1

| ID | Task | Owner | Status | Command To Verify | Blocking Dependency |
| --- | --- | --- | --- | --- | --- |
| P1-01 | Render and publish production app-link artifacts with the real Play App Signing SHA-256 fingerprints and Apple Team IDs for both flavors. | Release | external | `PLAY_APP_SIGNING_SHA256_MT=... APPLE_TEAM_ID_MT=... ./dinein_app/scripts/render_app_links.sh --flavor mt` and `PLAY_APP_SIGNING_SHA256_RW=... APPLE_TEAM_ID_RW=... ./dinein_app/scripts/render_app_links.sh --flavor rw` | Release signing/team secrets are not available in the local environment |
| P1-02 | Split the current worktree into reviewable commits instead of one broad multi-surface diff. | Repo Maintainer | open | `git diff --stat` | None |

## Verified Now

- `cd dinein_app && flutter analyze`
- `cd dinein_app && flutter test`
- `cd dinein_app/supabase/functions && deno test --allow-all whatsapp-otp/index_test.ts _shared/admin-profile_test.ts _shared/http_test.ts _shared/menu-image_test.ts _shared/menu-item-context_test.ts _shared/phone_test.ts _shared/signed-jwt_test.ts _shared/venue-profile-image_test.ts _shared/gemini-image-config_test.ts _shared/google-places_test.ts _shared/whatsapp_test.ts && deno check whatsapp-otp/index.ts core-api/index.ts menu-api/index.ts venue-api/index.ts orders-api/index.ts admin-api/index.ts`
- `cd dinein_app && PLAY_APP_SIGNING_SHA256_MT=11:22:... APPLE_TEAM_ID_MT=ABCDE12345 ./scripts/validate_release_integrations.sh --flavor mt`
- `cd dinein_app && PLAY_APP_SIGNING_SHA256_RW=11:22:... APPLE_TEAM_ID_RW=ABCDE12345 ./scripts/validate_release_integrations.sh --flavor rw`
- `cd dinein_app && supabase db reset --local`

## Notes

- Release validation no longer requires checked-in `.well-known` files; it can
  render temporary app-link artifacts from env inputs during validation.
- Production deployment still requires the real signing fingerprints and Apple
  team IDs before the final `.well-known` artifacts can be published.
- Historical identity and SMS-ingest references remain only in explicit cleanup
  migrations; they are not part of the active runtime product surface.
- The Android release Supabase credential gate in
  `dinein_app/scripts/build_android_release.sh` remains mandatory and was not
  bypassed.
