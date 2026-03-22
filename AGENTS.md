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
