create extension if not exists pg_net;
create extension if not exists pg_cron;

create index if not exists dinein_menu_items_signature_idx
on public.dinein_menu_items (
  lower(trim(name)),
  lower(trim(category)),
  lower(trim(coalesce(description, '')))
);

create index if not exists dinein_menu_items_ai_ready_signature_idx
on public.dinein_menu_items (
  lower(trim(name)),
  lower(trim(category)),
  lower(trim(coalesce(description, ''))),
  updated_at desc
)
where image_status = 'ready'
  and image_source = 'ai_gemini'
  and image_url is not null
  and image_storage_path is not null;

select cron.unschedule(jobid)
from cron.job
where jobname = 'menu-image-backfill-every-5-minutes';

select cron.schedule(
  'menu-image-backfill-every-5-minutes',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://uskfnszcdqpcfrhjxitl.supabase.co/functions/v1/backfill-menu-images',
    body := '{"limit":12}'::jsonb,
    headers := '{"Content-Type":"application/json","x-cron-secret":"MENU_IMAGE_CRON_SECRET"}'::jsonb,
    timeout_milliseconds := 15000
  );
  $$
);
