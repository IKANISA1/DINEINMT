# Workspace Guardrails

## UI/Frontend Freeze

- Do not change any UI, frontend, screen layout, styling, spacing, typography, colors, icons, imagery, motion, or visual structure unless the user explicitly requests a UI or design update in that task.
- Treat all existing screens and designs as locked by default.
- Do not make "small visual improvements", cleanup tweaks, responsive refinements, copy polish, or component restyling unless explicitly requested.
- If a requested change could affect the visible UI, pause and ask for confirmation unless the user clearly asked for that visual change.
- Prefer fixes that preserve the exact current appearance.

## Scope Discipline

- Backend, data, integration, performance, and bug-fix work is allowed only if it does not alter the visible UI.
- When a functional fix requires a visible UI change, do not proceed without explicit user approval.

## ⛔ CRITICAL BLOCKER — Supabase Credentials for APK / AAB Builds

> **This rule is NON-NEGOTIABLE and must be enforced every time an APK or AAB is created.**

Before **any** Android release artifact (APK or AAB) is built:

1. **`SUPABASE_URL`** and **`SUPABASE_ANON_KEY`** MUST be set to real, non-placeholder values in the environment file used by `--dart-define-from-file`.
2. The build script (`scripts/build_android_release.sh`) performs an automated check and will **abort** if either value is missing, empty, or contains a placeholder (e.g. `your-project`, `your-anon-key`).
3. **Never** produce a release APK/AAB with placeholder or empty Supabase credentials — the resulting binary will crash on first launch.
4. When the agent or user runs `flutter build apk`, `flutter build appbundle`, or the build script, **always verify** the env file first.

### Expected env file locations
| Flavor | Env file |
|--------|----------|
| Malta (`mt`) | `env/release.mt.json` |
| Rwanda (`rw`) | `env/release.rw.json` |
| Generic | `env/release.json` |

### What constitutes a valid value
- `SUPABASE_URL` must start with `https://` and end with `.supabase.co`.
- `SUPABASE_ANON_KEY` must be a non-empty JWT string (starts with `eyJ`).

### Enforcement layers
- **Build script gate** — `scripts/build_android_release.sh` validates before building.
- **Release validation** — `scripts/validate_release_integrations.sh` checks env file contents.
- **Runtime fail-fast** — `SupabaseConfig.initialize()` throws `StateError` if values are missing.

**If any layer detects missing or placeholder Supabase credentials, the build MUST stop and the agent MUST report the issue before proceeding.**
