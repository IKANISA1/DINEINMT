begin;

alter table public.dinein_menu_items
  add column if not exists image_source text,
  add column if not exists image_status text not null default 'pending',
  add column if not exists image_model text,
  add column if not exists image_prompt text,
  add column if not exists image_generated_at timestamptz,
  add column if not exists image_error text,
  add column if not exists image_attempts integer not null default 0,
  add column if not exists image_locked boolean not null default false,
  add column if not exists image_storage_path text;

alter table public.dinein_menu_items
  drop constraint if exists dinein_menu_items_image_source_check;

alter table public.dinein_menu_items
  add constraint dinein_menu_items_image_source_check
  check (
    image_source is null
    or image_source in ('manual', 'ai_gemini')
  );

alter table public.dinein_menu_items
  drop constraint if exists dinein_menu_items_image_status_check;

alter table public.dinein_menu_items
  add constraint dinein_menu_items_image_status_check
  check (
    image_status in ('pending', 'generating', 'ready', 'failed')
  );

update public.dinein_menu_items
set
  image_source = case
    when image_source is not null then image_source
    when image_url is not null and btrim(image_url) <> '' then 'manual'
    else null
  end,
  image_status = case
    when image_url is not null and btrim(image_url) <> '' then 'ready'
    when image_status is null or btrim(image_status) = '' then 'pending'
    else image_status
  end,
  image_error = case
    when image_url is not null and btrim(image_url) <> '' then null
    else image_error
  end,
  image_generated_at = case
    when image_generated_at is null
      and image_url is not null
      and btrim(image_url) <> '' then now()
    else image_generated_at
  end;

create index if not exists dinein_menu_items_image_status_idx
  on public.dinein_menu_items (venue_id, image_status);

create index if not exists dinein_menu_items_missing_image_idx
  on public.dinein_menu_items (venue_id, image_locked, image_status);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'menu-images',
  'menu-images',
  true,
  10485760,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

commit;
