# ui_pkg

## Responsibility
The `ui_pkg` is the single source of truth for the DineIn "Soft Liquid Glass" design system, component library, and interaction tokens.

## Boundaries
- **In-Scope**: Visual components (e.g., `DineInImage`, `RoleSwitchFooter`, `AdaptiveGlassSurface`), Theme definitions (`AppColors`, `AppTypography`), and high-level layout primitives.
- **Out-of-Scope**: Database interaction, state management of business entities, raw platform capability integrations (like camera or secure storage).

## Usage
All permanent guest, venue, and admin interfaces must source their structural and thematic primitives from this package. It is the repo's UI/UX source of truth and must not drift from the established design system.
