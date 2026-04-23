# DineIn UAT Matrix

Reviewed: 2026-04-22

## Coverage Grid

| Country | Role | Platform | Critical Paths |
| --- | --- | --- | --- |
| Malta | Guest | Android / iOS / Web / PWA | QR entry, venue browse, menu, cart, order, status |
| Malta | Venue | Android / iOS / Web / PWA | OTP login, order handling, menu update, notifications |
| Malta | Admin | Android / iOS / Web / PWA | OTP login, venue oversight, catalog/admin order views |
| Rwanda | Guest | Android / iOS / Web / PWA | QR entry, venue browse, menu, cart, order, status, MoMo USSD handoff |
| Rwanda | Venue | Android / iOS / Web / PWA | OTP login, order handling, menu update, notifications |
| Rwanda | Admin | Android / iOS / Web / PWA | OTP login, venue oversight, catalog/admin order views |

## Mandatory Scenarios

1. App starts cleanly from cold launch and deep link entry.
2. Guest can enter a venue, browse menu items, add to cart, and place an order.
3. Guest can view order status and revisit order history.
4. Venue user can sign in through WhatsApp OTP and manage incoming orders.
5. Venue user can update venue profile and menu data.
6. Admin can access oversight screens and view global venue/order state.
7. Push registration and notification settings behave correctly for venue/admin.
8. Session expiry, retry paths, and low-network behavior are acceptable.

## Blocker Classification

- `P0`: broken critical path, bad auth boundary, data loss, crash, or release-packaging failure
- `P1`: important workflow degraded but workaround exists
- `P2`: cosmetic, copy, or non-critical operational rough edge
