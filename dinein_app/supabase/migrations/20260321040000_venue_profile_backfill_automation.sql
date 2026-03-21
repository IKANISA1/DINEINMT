create extension if not exists pg_net;
create extension if not exists pg_cron;

select cron.unschedule(jobid)
from cron.job
where jobname = 'venue-profile-backfill-every-15-minutes';

select cron.schedule(
  'venue-profile-backfill-every-15-minutes',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://uskfnszcdqpcfrhjxitl.supabase.co/functions/v1/dinein-api',
    body := '{"action":"backfill_venue_profiles","limit":4}'::jsonb,
    headers := '{"Content-Type":"application/json","x-cron-secret":"VENUE_ENRICHMENT_CRON_SECRET"}'::jsonb,
    timeout_milliseconds := 20000
  );
  $$
);
