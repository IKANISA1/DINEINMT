# Rollback Checklist

Reviewed: 2026-04-22

## Trigger Conditions

- production crash on startup
- broken ordering or venue auth path
- failed migration rollout
- invalid store/runtime configuration
- notification or session regression affecting operations

## Rollback Steps

1. Stop further rollout and freeze new release promotion.
2. Repoint clients or deployments to the last known good build and backend revision.
3. Restore prior release env/config values if the incident is configuration-driven.
4. Revert non-destructive forward-only app/backend changes where safe.
5. Validate guest ordering, venue login, and admin oversight on the restored version.
6. Record incident timeline, user impact, and exact rollback commit/build identifiers.

## Aftercare

1. Keep the bad release blocked from re-promotion.
2. Open remediation tasks for root cause, regression test gap, and release-process gap.
3. Do not resume rollout until rehearsal and smoke checks are re-run successfully.
