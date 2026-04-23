# core_pkg

## Responsibility
The `core_pkg` acts as the foundational cross-cutting package for the DineIn mono-repo. It is intentionally free of any visual UI logic or data-access models.

## Boundaries
- **In-Scope**: Shared utilities, Enums, configuration values (e.g. `CountryConfig`), cross-platform deep-linking strings, and base constants.
- **Out-of-Scope**: Database clients, Flutter Widgets, UI tokens (colors, fonts), and specific business implementations such as order flow handlers.

## Usage
Import constants or enums from `core_pkg` to enforce a single source of truth across `db_pkg`, `ui_pkg`, and the guest, venue, and admin surfaces inside `dinein_app`.
