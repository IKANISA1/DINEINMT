# Legacy SACCO Migrations (Archived)

These 47 migration files are from the SACCO+ project that previously shared this
Supabase instance. They have been archived because:

1. They are already applied to the production database
2. They are not relevant to the DineIn application
3. They create tables/functions for institutions, banks, wallets, reconciliation,
   SMS pipelines, and other SACCO-specific schemas

**DO NOT DELETE** — these may be needed if the database is recreated from scratch
or if the SACCO project is revived.

If you need to recreate the full database from scratch, move these files back to
the parent `migrations/` directory first.
