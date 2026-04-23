-- Legacy identity foundation for the Rwanda rollout.
-- IMPORTANT: apply this migration only to the Rwanda Supabase project
-- (project ref: kczghhipbyykluuiiunp).

begin;

create extension if not exists vector;

create or replace function public.legacy_identity_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.legacy_identity_profiles (
  id uuid primary key default gen_random_uuid(),
  legacy_identity_id text not null unique
    check (legacy_identity_id ~ '^[0-9]{6}$'),
  display_name text not null
    check (char_length(btrim(display_name)) between 2 and 80),
  ussd_string text not null,
  ussd_normalized text not null,
  recipient_phone_e164 text
    check (
      recipient_phone_e164 is null
      or recipient_phone_e164 ~ '^\+2507[0-9]{8}$'
    ),
  status text not null default 'active'
    check (status in ('pending', 'active', 'suspended', 'deleted')),
  consent_version integer not null
    check (consent_version > 0),
  consent_at timestamptz not null default timezone('utc', now()),
  owner_token_version integer not null default 1
    check (owner_token_version > 0),
  management_code_hash text not null,
  management_code_hint text
    check (
      management_code_hint is null
      or management_code_hint ~ '^[0-9]{2}$'
    ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'legacy_identity_profiles'
      and column_name = 'manage_code_hash'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'legacy_identity_profiles'
      and column_name = 'management_code_hash'
  ) then
    execute 'alter table public.legacy_identity_profiles rename column manage_code_hash to management_code_hash';
  end if;
end $$;

alter table public.legacy_identity_profiles
  add column if not exists recipient_phone_e164 text,
  add column if not exists management_code_hash text,
  add column if not exists management_code_hint text;

comment on table public.legacy_identity_profiles is
  'Historical Rwanda payee registry for the retired identity flow. Do not apply this schema to the Malta project.';

comment on column public.legacy_identity_profiles.ussd_normalized is
  'Canonical Rwanda MTN MoMo receive-money USSD string for the retired identity flow.';

comment on column public.legacy_identity_profiles.owner_token_version is
  'Rotated whenever retired identity ownership credentials are re-issued or invalidated.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'legacy_identity_profiles_recipient_phone_e164_check'
      and conrelid = 'public.legacy_identity_profiles'::regclass
  ) then
    execute $sql$
      alter table public.legacy_identity_profiles
        add constraint legacy_identity_profiles_recipient_phone_e164_check
        check (
          recipient_phone_e164 is null
          or recipient_phone_e164 ~ '^\+2507[0-9]{8}$'
        )
    $sql$;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'legacy_identity_profiles_management_code_hint_check'
      and conrelid = 'public.legacy_identity_profiles'::regclass
  ) then
    execute $sql$
      alter table public.legacy_identity_profiles
        add constraint legacy_identity_profiles_management_code_hint_check
        check (
          management_code_hint is null
          or management_code_hint ~ '^[0-9]{2}$'
        )
    $sql$;
  end if;
end $$;

drop trigger if exists set_legacy_identity_profiles_updated_at
  on public.legacy_identity_profiles;
create trigger set_legacy_identity_profiles_updated_at
before update on public.legacy_identity_profiles
for each row
execute function public.legacy_identity_set_updated_at();

create unique index if not exists uq_legacy_identity_profiles_ussd_normalized_active
  on public.legacy_identity_profiles (ussd_normalized)
  where status in ('pending', 'active', 'suspended');

create unique index if not exists uq_legacy_identity_profiles_phone_active
  on public.legacy_identity_profiles (recipient_phone_e164)
  where recipient_phone_e164 is not null
    and status in ('pending', 'active', 'suspended');

create index if not exists idx_legacy_identity_profiles_status_created_at
  on public.legacy_identity_profiles (status, created_at desc);

create table if not exists public.legacy_identity_face_embeddings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    references public.legacy_identity_profiles(id) on delete cascade,
  embedding vector(128) not null,
  model_version text not null,
  quality_score double precision
    check (
      quality_score is null
      or (quality_score >= 0 and quality_score <= 1)
    ),
  source text not null default 'enrollment'
    check (source in ('enrollment', 're_enrollment')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.legacy_identity_face_embeddings
  add column if not exists source text not null default 'enrollment';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'legacy_identity_face_embeddings_source_check'
      and conrelid = 'public.legacy_identity_face_embeddings'::regclass
  ) then
    execute $sql$
      alter table public.legacy_identity_face_embeddings
        add constraint legacy_identity_face_embeddings_source_check
        check (source in ('enrollment', 're_enrollment'))
    $sql$;
  end if;
end $$;

comment on table public.legacy_identity_face_embeddings is
  'Historical Rwanda identity embeddings. Raw face images must never be persisted.';

create unique index if not exists uq_legacy_identity_face_embeddings_profile_active
  on public.legacy_identity_face_embeddings (profile_id)
  where is_active;

create index if not exists idx_legacy_identity_face_embeddings_profile_created_at
  on public.legacy_identity_face_embeddings (profile_id, created_at desc);

create index if not exists idx_legacy_identity_face_embeddings_model_version
  on public.legacy_identity_face_embeddings (model_version);

create index if not exists idx_legacy_identity_face_embeddings_embedding_cosine
  on public.legacy_identity_face_embeddings
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 64);

create table if not exists public.legacy_identity_match_audit (
  id uuid primary key default gen_random_uuid(),
  matched_profile_id uuid
    references public.legacy_identity_profiles(id) on delete set null,
  similarity double precision,
  result text not null
    check (result in ('matched', 'no_match', 'rate_limited', 'rejected', 'error')),
  client_install_id text,
  ip_hash text,
  device_label text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.legacy_identity_match_audit
  add column if not exists details jsonb not null default '{}'::jsonb;

create index if not exists idx_legacy_identity_match_audit_created_at
  on public.legacy_identity_match_audit (created_at desc);

create index if not exists idx_legacy_identity_match_audit_profile_created_at
  on public.legacy_identity_match_audit (matched_profile_id, created_at desc);

create table if not exists public.legacy_identity_enrollment_audit (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid
    references public.legacy_identity_profiles(id) on delete set null,
  event_type text not null,
  client_install_id text,
  ip_hash text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_legacy_identity_enrollment_audit_created_at
  on public.legacy_identity_enrollment_audit (created_at desc);

create index if not exists idx_legacy_identity_enrollment_audit_profile_created_at
  on public.legacy_identity_enrollment_audit (profile_id, created_at desc);

create table if not exists public.legacy_identity_abuse_reports (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    references public.legacy_identity_profiles(id) on delete cascade,
  reason text not null,
  notes text,
  status text not null default 'open'
    check (status in ('open', 'resolved', 'dismissed')),
  client_install_id text,
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.legacy_identity_abuse_reports
  add column if not exists status text not null default 'open',
  add column if not exists resolution_notes text,
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'legacy_identity_abuse_reports_status_check'
      and conrelid = 'public.legacy_identity_abuse_reports'::regclass
  ) then
    execute $sql$
      alter table public.legacy_identity_abuse_reports
        add constraint legacy_identity_abuse_reports_status_check
        check (status in ('open', 'resolved', 'dismissed'))
    $sql$;
  end if;
end $$;

drop trigger if exists set_legacy_identity_abuse_reports_updated_at
  on public.legacy_identity_abuse_reports;
create trigger set_legacy_identity_abuse_reports_updated_at
before update on public.legacy_identity_abuse_reports
for each row
execute function public.legacy_identity_set_updated_at();

create index if not exists idx_legacy_identity_abuse_reports_profile_status
  on public.legacy_identity_abuse_reports (profile_id, status, created_at desc);

alter table public.legacy_identity_profiles enable row level security;
alter table public.legacy_identity_face_embeddings enable row level security;
alter table public.legacy_identity_match_audit enable row level security;
alter table public.legacy_identity_enrollment_audit enable row level security;
alter table public.legacy_identity_abuse_reports enable row level security;

revoke all on public.legacy_identity_profiles from anon, authenticated;
revoke all on public.legacy_identity_face_embeddings from anon, authenticated;
revoke all on public.legacy_identity_match_audit from anon, authenticated;
revoke all on public.legacy_identity_enrollment_audit from anon, authenticated;
revoke all on public.legacy_identity_abuse_reports from anon, authenticated;

grant all on public.legacy_identity_profiles to service_role;
grant all on public.legacy_identity_face_embeddings to service_role;
grant all on public.legacy_identity_match_audit to service_role;
grant all on public.legacy_identity_enrollment_audit to service_role;
grant all on public.legacy_identity_abuse_reports to service_role;

create or replace function public.generate_legacy_identity_id()
returns text
language plpgsql
as $$
declare
  candidate text;
begin
  loop
    candidate := lpad(((random() * 999999)::int)::text, 6, '0');
    exit when not exists (
      select 1
      from public.legacy_identity_profiles
      where legacy_identity_id = candidate
    );
  end loop;

  return candidate;
end;
$$;

create or replace function public.match_legacy_identity_embedding(
  query_embedding vector,
  limit_count integer default 3
)
returns table (
  profile_id uuid,
  legacy_identity_id text,
  display_name text,
  ussd_string text,
  similarity double precision,
  model_version text
)
language sql
stable
as $$
  select
    profile.id as profile_id,
    profile.legacy_identity_id,
    profile.display_name,
    profile.ussd_string,
    1 - (embedding.embedding <=> query_embedding) as similarity,
    embedding.model_version
  from public.legacy_identity_face_embeddings embedding
  join public.legacy_identity_profiles profile
    on profile.id = embedding.profile_id
  where embedding.is_active = true
    and profile.status = 'active'
  order by embedding.embedding <=> query_embedding asc
  limit greatest(1, least(coalesce(limit_count, 3), 10));
$$;

create or replace function public.find_duplicate_legacy_identity_profile(
  query_embedding vector,
  similarity_threshold double precision default 0.90
)
returns table (
  profile_id uuid,
  legacy_identity_id text,
  display_name text,
  similarity double precision
)
language sql
stable
as $$
  select
    profile.id as profile_id,
    profile.legacy_identity_id,
    profile.display_name,
    1 - (embedding.embedding <=> query_embedding) as similarity
  from public.legacy_identity_face_embeddings embedding
  join public.legacy_identity_profiles profile
    on profile.id = embedding.profile_id
  where embedding.is_active = true
    and profile.status in ('pending', 'active', 'suspended')
    and 1 - (embedding.embedding <=> query_embedding) >= similarity_threshold
  order by embedding.embedding <=> query_embedding asc
  limit 1;
$$;

revoke all on function public.legacy_identity_set_updated_at() from public;
revoke all on function public.generate_legacy_identity_id() from public, anon, authenticated;
revoke all on function public.match_legacy_identity_embedding(vector, integer) from public, anon, authenticated;
revoke all on function public.find_duplicate_legacy_identity_profile(vector, double precision) from public, anon, authenticated;

grant execute on function public.generate_legacy_identity_id() to service_role;
grant execute on function public.match_legacy_identity_embedding(vector, integer) to service_role;
grant execute on function public.find_duplicate_legacy_identity_profile(vector, double precision) to service_role;

commit;
