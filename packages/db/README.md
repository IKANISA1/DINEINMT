# db_pkg

## Responsibility
The `db_pkg` contains the strictly typed data models and Supabase interaction signatures used across the DineIn platform.

## Boundaries
- **In-Scope**: Dart data models (e.g., `Order`, `MenuItem`, `VenueProfile`, `AuthSession`), serialization helpers, and edge-function payload typings.
- **Out-of-Scope**: UI components, visual formatting, global configuration strings.

## Usage
Data models extend `Equatable` to ensure consistent state comparison in the app's reactive Riverpod architecture. This package depends on `core_pkg` to access shared Enums and Statuses to map backend integer states to Dart enums safely.
