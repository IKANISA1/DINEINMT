create extension if not exists pg_cron;

-- Remove the broken committed schedule that used the literal
-- "MENU_IMAGE_CRON_SECRET" placeholder in the HTTP headers.
select cron.unschedule(jobid)
from cron.job
where jobname = 'menu-image-backfill-every-5-minutes';

-- Intentionally do not recreate the schedule here.
--
-- Menu image backfill requires a per-environment secret or service-role bearer
-- token, and that credential must not be committed to source control. Provision
-- the cron schedule manually in each environment after deployment.
