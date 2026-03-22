create extension if not exists pg_net;
create extension if not exists pg_cron;

-- Intentionally left as a no-op.
--
-- The venue profile backfill job requires a per-project secret or service-role
-- bearer token in the HTTP headers. That credential must not be committed to
-- source control, so the actual cron schedule must be provisioned manually in
-- each environment after deployment.
