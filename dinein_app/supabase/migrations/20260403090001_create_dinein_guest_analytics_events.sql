-- Analytics events table — works on both MT (dinein_* = tables) and RW (dinein_* = views over base tables).
-- FK constraints are omitted intentionally because the target tables differ between MT and RW schemas.
-- Data integrity is enforced at the application layer.

create table if not exists public.dinein_guest_analytics_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  country text not null default 'MT' check (country in ('MT', 'RW')),
  event_name text not null,
  session_id text not null,
  route text,
  venue_id uuid,
  menu_item_id uuid,
  order_id uuid,
  user_id uuid references auth.users(id) on delete set null,
  user_agent text,
  referrer text,
  details jsonb not null default '{}'::jsonb
);

create index if not exists idx_dinein_guest_analytics_events_created_at
  on public.dinein_guest_analytics_events(created_at desc);

create index if not exists idx_dinein_guest_analytics_events_event_name
  on public.dinein_guest_analytics_events(event_name);

create index if not exists idx_dinein_guest_analytics_events_session_id
  on public.dinein_guest_analytics_events(session_id);

create index if not exists idx_dinein_guest_analytics_events_venue_id
  on public.dinein_guest_analytics_events(venue_id);

alter table public.dinein_guest_analytics_events enable row level security;
