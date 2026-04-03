create table if not exists public.dinein_guest_analytics_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  country text not null default 'MT' check (country in ('MT', 'RW')),
  event_name text not null,
  session_id text not null,
  route text,
  venue_id uuid references public.dinein_venues(id) on delete set null,
  menu_item_id uuid references public.dinein_menu_items(id) on delete set null,
  order_id uuid references public.dinein_orders(id) on delete set null,
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
