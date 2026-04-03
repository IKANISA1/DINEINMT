do $$
declare
  target_relation text;
  is_view boolean;
begin
  select c.relkind = 'v'
    into is_view
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'dinein_menu_items';

  if is_view then
    target_relation := 'public.menu_items';
  else
    target_relation := 'public.dinein_menu_items';
  end if;

  execute format($sql$
    alter table %s
      add column if not exists admin_group_id uuid,
      add column if not exists admin_managed boolean not null default false
  $sql$, target_relation);

  execute format($sql$
    update %s
    set admin_managed = true
    where admin_group_id is not null
      and admin_managed = false
  $sql$, target_relation);

  execute format(
    'alter table %s drop constraint if exists dinein_menu_items_admin_group_consistency_check',
    target_relation
  );

  execute format($sql$
    alter table %s
      add constraint dinein_menu_items_admin_group_consistency_check
      check (
        (admin_group_id is null and admin_managed = false) or
        (admin_group_id is not null and admin_managed = true)
      )
  $sql$, target_relation);

  execute format($sql$
    create index if not exists idx_dinein_menu_items_admin_group
      on %s (admin_group_id)
      where admin_group_id is not null
  $sql$, target_relation);

  execute format($sql$
    create unique index if not exists idx_dinein_menu_items_admin_group_venue
      on %s (venue_id, admin_group_id)
      where admin_group_id is not null
  $sql$, target_relation);

  if is_view then
    execute $sql$
      create or replace view public.dinein_menu_items as
      select
        id,
        venue_id,
        category,
        name,
        description,
        price,
        currency,
        is_available,
        tags_json,
        image_url,
        created_at,
        updated_at,
        ai_image_url,
        category_id,
        sort_order,
        currency_code,
        is_featured,
        dietary_flags,
        allergens,
        add_ons,
        metadata,
        display_order,
        image_source,
        image_status,
        image_model,
        image_error,
        image_attempts,
        image_locked,
        image_storage_path,
        tags,
        image_generated_at,
        image_prompt,
        highlight_rank,
        class,
        menu_context,
        menu_context_status,
        menu_context_error,
        menu_context_model,
        menu_context_attempts,
        menu_context_locked,
        menu_context_updated_at,
        admin_group_id,
        admin_managed
      from public.menu_items;
    $sql$;
  end if;

  execute format($sql$
    comment on column %s.admin_group_id is
      'Shared admin-managed menu group identifier used to sync generic menu fields across assigned venues.'
  $sql$, target_relation);

  execute format($sql$
    comment on column %s.admin_managed is
      'True when the menu item is managed centrally by admin and linked to an admin_group_id.'
  $sql$, target_relation);
end
$$;
