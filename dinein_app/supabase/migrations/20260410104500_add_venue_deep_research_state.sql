alter table public.dinein_venues
  add column if not exists deep_research_status text,
  add column if not exists deep_research_summary text,
  add column if not exists deep_research_sources jsonb,
  add column if not exists deep_research_error text,
  add column if not exists deep_research_interaction_id text,
  add column if not exists deep_research_updated_at timestamptz,
  add column if not exists deep_research_attempts integer not null default 0,
  add column if not exists deep_research_model text;

update public.dinein_venues
set
  deep_research_status = coalesce(nullif(trim(deep_research_status), ''), 'pending'),
  deep_research_attempts = coalesce(deep_research_attempts, 0)
where deep_research_status is distinct from coalesce(nullif(trim(deep_research_status), ''), 'pending')
   or deep_research_attempts is null;
