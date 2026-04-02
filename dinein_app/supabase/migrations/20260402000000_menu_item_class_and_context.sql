begin;

create or replace function public.normalize_dinein_menu_item_class(
  raw_class text,
  item_name text,
  item_category text,
  item_description text,
  item_tags text[]
)
returns text
language plpgsql
immutable
as $$
declare
  normalized_class text := lower(btrim(coalesce(raw_class, '')));
  context text := lower(
    concat_ws(
      ' ',
      coalesce(item_name, ''),
      coalesce(item_category, ''),
      coalesce(item_description, ''),
      coalesce(array_to_string(item_tags, ' '), '')
    )
  );
begin
  if normalized_class in ('food', 'drinks') then
    return normalized_class;
  end if;

  if context ~* '(pizza|pasta|burger|fries|chips|salad|soup|sandwich|wrap|shawarma|kebab|falafel|taco|tacos|bowl|bowls|steak|chicken|beef|lamb|pork|fish|seafood|shrimp|prawn|sushi|ramen|noodle|noodles|rice|curry|dessert|cake|cheesecake|ice cream|gelato|pudding|pastry|cookie|waffle|pancake|ftira|pastizzi|rabbit|brochette|brochettes|pilau|matoke|ugali|isombe|matooke|nyama choma|vegetarian|vegan|grilled|fried|roasted|baked|starter|starters|appetizer|appetizers|main|mains|lunch|dinner|breakfast|brunch)' then
    return 'food';
  end if;

  if context ~* '(beer|lager|ale|ipa|stout|porter|pilsner|cider|draft|draught|tap|pint|wine|prosecco|champagne|cocktail|mocktail|martini|mojito|spritz|spirits|whisky|whiskey|vodka|rum|gin|tequila|mezcal|cognac|brandy|liqueur|coffee|espresso|latte|cappuccino|flat white|americano|macchiato|mocha|frappe|cold brew|tea|matcha|chai|juice|lemonade|soda|cola|water|sparkling water|still water|energy drink|smoothie|milkshake|bottle|can|glass)' then
    return 'drinks';
  end if;

  return 'food';
end;
$$;

create or replace function public.sync_dinein_menu_item_class_and_context()
returns trigger
language plpgsql
as $$
declare
  input_class text;
  resolved_class text;
  core_text_changed boolean;
  explicit_class_changed boolean;
  context_fields_touched boolean;
  image_fields_touched boolean;
  current_image_source text;
begin
  input_class := NEW."class";
  resolved_class := public.normalize_dinein_menu_item_class(
    input_class,
    NEW.name,
    NEW.category,
    NEW.description,
    NEW.tags
  );
  NEW."class" := resolved_class;

  if TG_OP = 'INSERT' then
    NEW.menu_context_locked := coalesce(NEW.menu_context_locked, false);
    NEW.menu_context_attempts := coalesce(NEW.menu_context_attempts, 0);
    NEW.menu_context_status := coalesce(
      NEW.menu_context_status,
      case
        when NEW.menu_context is not null then 'ready'
        else 'pending'
      end
    );
    NEW.menu_context_updated_at := coalesce(NEW.menu_context_updated_at, now());
    NEW.image_locked := coalesce(NEW.image_locked, false);
    NEW.image_attempts := coalesce(NEW.image_attempts, 0);
    NEW.image_status := coalesce(
      NEW.image_status,
      case
        when NEW.image_url is not null and btrim(NEW.image_url) <> '' then 'ready'
        else 'pending'
      end
    );
    if NEW.image_url is not null and btrim(NEW.image_url) <> '' and NEW.image_source is null then
      NEW.image_source := 'manual';
    end if;
    NEW.updated_at := coalesce(NEW.updated_at, now());
    return NEW;
  end if;

  core_text_changed :=
    NEW.name is distinct from OLD.name
    or NEW.description is distinct from OLD.description
    or NEW.category is distinct from OLD.category
    or NEW.tags is distinct from OLD.tags;

  explicit_class_changed :=
    input_class is not null
    and public.normalize_dinein_menu_item_class(
      input_class,
      OLD.name,
      OLD.category,
      OLD.description,
      OLD.tags
    ) is distinct from OLD."class";

  context_fields_touched :=
    NEW.menu_context is distinct from OLD.menu_context
    or NEW.menu_context_status is distinct from OLD.menu_context_status
    or NEW.menu_context_error is distinct from OLD.menu_context_error
    or NEW.menu_context_model is distinct from OLD.menu_context_model
    or NEW.menu_context_attempts is distinct from OLD.menu_context_attempts
    or NEW.menu_context_locked is distinct from OLD.menu_context_locked
    or NEW.menu_context_updated_at is distinct from OLD.menu_context_updated_at;

  image_fields_touched :=
    NEW.image_url is distinct from OLD.image_url
    or NEW.image_source is distinct from OLD.image_source
    or NEW.image_status is distinct from OLD.image_status
    or NEW.image_model is distinct from OLD.image_model
    or NEW.image_prompt is distinct from OLD.image_prompt
    or NEW.image_generated_at is distinct from OLD.image_generated_at
    or NEW.image_error is distinct from OLD.image_error
    or NEW.image_attempts is distinct from OLD.image_attempts
    or NEW.image_locked is distinct from OLD.image_locked
    or NEW.image_storage_path is distinct from OLD.image_storage_path;

  if core_text_changed or explicit_class_changed then
    if not coalesce(NEW.menu_context_locked, OLD.menu_context_locked, false)
      and not context_fields_touched
    then
      NEW.menu_context := null;
      NEW.menu_context_status := 'pending';
      NEW.menu_context_error := null;
      NEW.menu_context_model := null;
      NEW.menu_context_attempts := 0;
      NEW.menu_context_updated_at := now();
      NEW.updated_at := now();
    end if;

    current_image_source := coalesce(NEW.image_source, OLD.image_source);
    if current_image_source = 'ai_gemini'
      and not coalesce(NEW.image_locked, OLD.image_locked, false)
      and not image_fields_touched
    then
      NEW.image_url := null;
      NEW.image_source := null;
      NEW.image_status := 'pending';
      NEW.image_model := null;
      NEW.image_prompt := null;
      NEW.image_generated_at := null;
      NEW.image_error := null;
      NEW.image_attempts := 0;
      NEW.image_storage_path := null;
      NEW.updated_at := now();
    end if;
  end if;

  return NEW;
end;
$$;

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
      add column if not exists class text,
      add column if not exists menu_context jsonb,
      add column if not exists menu_context_status text not null default 'pending',
      add column if not exists menu_context_error text,
      add column if not exists menu_context_model text,
      add column if not exists menu_context_attempts integer not null default 0,
      add column if not exists menu_context_locked boolean not null default false,
      add column if not exists menu_context_updated_at timestamptz
  $sql$, target_relation);

  execute format(
    'alter table %s drop constraint if exists dinein_menu_items_class_check',
    target_relation
  );

  execute format($sql$
    alter table %s
      add constraint dinein_menu_items_class_check
      check (class is null or class in ('food', 'drinks'))
  $sql$, target_relation);

  execute format(
    'alter table %s drop constraint if exists dinein_menu_items_menu_context_status_check',
    target_relation
  );

  execute format($sql$
    alter table %s
      add constraint dinein_menu_items_menu_context_status_check
      check (menu_context_status in ('pending', 'researching', 'ready', 'failed'))
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
        menu_context_updated_at
      from public.menu_items;
    $sql$;
  end if;

  execute format(
    'drop trigger if exists trg_dinein_menu_items_class_context on %s',
    target_relation
  );

  execute format($sql$
    create trigger trg_dinein_menu_items_class_context
    before insert or update on %s
    for each row
    execute function public.sync_dinein_menu_item_class_and_context()
  $sql$, target_relation);

  execute 'drop index if exists dinein_menu_items_signature_idx';
  execute format($sql$
    create index if not exists dinein_menu_items_signature_idx
    on %s (
      lower(trim(name)),
      lower(trim(category)),
      lower(trim(coalesce(description, ''))),
      coalesce(lower(trim(class)), '')
    )
  $sql$, target_relation);

  execute 'drop index if exists dinein_menu_items_ai_ready_signature_idx';
  execute format($sql$
    create index if not exists dinein_menu_items_ai_ready_signature_idx
    on %s (
      lower(trim(name)),
      lower(trim(category)),
      lower(trim(coalesce(description, ''))),
      coalesce(lower(trim(class)), ''),
      updated_at desc
    )
    where image_status = 'ready'
      and image_source = 'ai_gemini'
      and image_url is not null
      and image_storage_path is not null
  $sql$, target_relation);

  execute format(
    'create index if not exists dinein_menu_items_class_idx on %s (venue_id, class)',
    target_relation
  );

  execute format(
    'create index if not exists dinein_menu_items_menu_context_status_idx on %s (venue_id, menu_context_status, menu_context_locked, class)',
    target_relation
  );

  execute format($sql$
    create index if not exists dinein_menu_items_menu_context_queue_idx
    on %s (venue_id, class, updated_at desc)
    where menu_context_locked = false
      and menu_context_status in ('pending', 'failed')
  $sql$, target_relation);
end
$$;

commit;
