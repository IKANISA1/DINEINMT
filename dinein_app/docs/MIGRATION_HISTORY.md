# Migration History — DineIn Malta

This document classifies all Supabase migrations in the `supabase/migrations/` directory. The project evolved from a SACCO (Savings & Credit Cooperative) system to the current DineIn application. Both generations of migrations live in the same directory because Supabase tracks applied migrations by filename.

> **Never delete executed migrations.** Supabase's `schema_migrations` table tracks filenames. Removing files causes schema drift and breaks `supabase db diff` and future migrations.

---

## Era 1: SACCO (47 files)

These migrations set up tables and policies for a cooperative financial management system (institutions, members, contributions, ledgers, SMS pipelines, etc.). They are **not used by the DineIn application** but remain in the directory because they were already applied to the database.

| Range | Count | Purpose |
|-------|-------|---------|
| `20260102000000` – `20260102000009` | 10 | Initial schema, profiles, admins, institutions, banks, payment ledger |
| `20260106000002` | 1 | Wallet/NFC cleanup |
| `20260107000000` – `20260107900000` | 14 | Consolidated redesign, settings, dashboard, transactions, reconciliation, groups, reports, SMS, security |
| `20260108120000` – `20260108190000` | 4 | Production fixes, auth trigger, transaction views |
| `20260109000000` | 1 | Comprehensive cleanup |
| `20260110000000` – `20260110000003` | 4 | SMS gateway devices, settings cleanup |
| `20260111000000` – `20260111000004` | 5 | Group leaders, contributions, cron, group config |
| `20260112000000` – `20260112000002` | 3 | RLS policies, indexes, query optimizations |
| `20260113000000` – `20260114000000` | 2 | Index optimization and verification |
| `20260115000000` – `20260115000002` | 3 | Role simplification (Staff/Admin) |

**Total: 47 files**

### SACCO Tables (for reference)

These tables exist in the database but are not referenced by any DineIn code:

- `institutions`, `banks`
- `groups`, `group_members`, `group_settings`
- `contributions`, `contribution_periods`
- `payment_ledger`, `transactions`, `reconciliation_records`
- `sms_messages`, `sms_gateway_devices`
- `settings`, `app_settings`
- Various materialized views and functions for SACCO reports

---

## Era 2: DineIn (47 files)

These are the active migrations for the DineIn dine-in ordering system.

| Range | Count | Purpose |
|-------|-------|---------|
| `20260301*` – `20260307*` | 14 | Foundation: venues, menus, orders, profiles, venue access, bell system |
| `20260308*` – `20260318*` | 8 | Menu images, OCR pipelines, analytics, admin tools |
| `20260319*` – `20260321*` | 11 | Order security, image backfill, venue enrichment, normalization |
| `20260322000100` – `20260322014000` | 13 | Release hardening, bell/storage policies, order numbers, profile images, push notifications |
| `20260322020000` – `20260325140000` | 3 | BioPay (Rwanda-only biometric payments) |
| `20260402*` – `20260403*` | 4 | Menu item context, venue access, admin menu groups, guest analytics |

**Total: 47 files** (this count will grow as features are added)

### Key DineIn Tables

- `dinein_venues`, `dinein_venue_access`
- `dinein_menu_items`, `dinein_menu_categories`
- `dinein_orders`, `dinein_order_items`
- `dinein_bell_requests`
- `dinein_profiles`
- `dinein_push_registrations`
- `dinein_admin_managed_menu_groups`
- `dinein_guest_analytics_events`
- `dinein_biopay_*` (Rwanda-only)

---

## Cleanup Plan

When a migration cleanup is desired:

1. **Squash SACCO migrations** into a single `20260101000000_sacco_legacy.sql` (requires staging test)
2. **Drop unused SACCO tables/functions** via a new DineIn migration (after confirming zero references)
3. **Both steps require a staging dry-run** before production

> This cleanup is deferred until a dedicated maintenance window. The SACCO tables do not affect DineIn performance or correctness — they are simply unused schema artifacts.
