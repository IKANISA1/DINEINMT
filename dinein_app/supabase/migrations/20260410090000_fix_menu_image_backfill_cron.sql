DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
  EXCEPTION
    WHEN insufficient_privilege THEN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_extension
        WHERE extname = 'pg_cron'
      ) THEN
        RAISE;
      END IF;
  END;
END;
$$;

-- Remove the broken committed schedule that used the literal
-- "MENU_IMAGE_CRON_SECRET" placeholder in the HTTP headers.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_extension
    WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname = 'menu-image-backfill-every-5-minutes';
  END IF;
END;
$$;

-- Intentionally do not recreate the schedule here.
--
-- Menu image backfill requires a per-environment secret or service-role bearer
-- token, and that credential must not be committed to source control. Provision
-- the cron schedule manually in each environment after deployment.
