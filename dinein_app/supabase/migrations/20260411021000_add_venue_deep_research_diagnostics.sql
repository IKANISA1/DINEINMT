alter table public.dinein_venues
  add column if not exists deep_research_last_observed_status text,
  add column if not exists deep_research_last_http_status integer,
  add column if not exists deep_research_last_polled_at timestamptz,
  add column if not exists deep_research_last_provider_error text,
  add column if not exists deep_research_debug jsonb;
