#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL to the Postgres connection string}"

ITERATIONS="${ITERATIONS:-1}"
SLEEP_SEC="${SLEEP_SEC:-60}"

read -r -d '' UPDATE_SQL <<'SQL' || true
with source_images as (
  select distinct on (
    lower(trim(name)),
    lower(trim(category)),
    lower(trim(coalesce(description, ''))),
    lower(trim(coalesce(class, '')))
  )
    lower(trim(name)) as name_key,
    lower(trim(category)) as category_key,
    lower(trim(coalesce(description, ''))) as description_key,
    lower(trim(coalesce(class, ''))) as class_key,
    image_url,
    image_storage_path,
    image_model,
    image_prompt,
    image_generated_at
  from public.dinein_menu_items
  where image_status = 'ready'
    and image_source = 'ai_gemini'
    and image_url is not null
    and image_storage_path is not null
  order by
    lower(trim(name)),
    lower(trim(category)),
    lower(trim(coalesce(description, ''))),
    lower(trim(coalesce(class, ''))),
    updated_at desc nulls last,
    created_at desc
),
updated as (
  update public.dinein_menu_items target
  set
    image_url = source.image_url,
    image_storage_path = source.image_storage_path,
    image_source = 'ai_gemini',
    image_status = 'ready',
    image_model = source.image_model,
    image_prompt = coalesce(target.image_prompt, source.image_prompt),
    image_generated_at = coalesce(target.image_generated_at, source.image_generated_at, now()),
    image_error = null,
    image_attempts = greatest(coalesce(target.image_attempts, 0), 1),
    updated_at = now()
  from source_images source
  where target.image_locked = false
    and (target.image_url is null or btrim(target.image_url) = '')
    and lower(trim(target.name)) = source.name_key
    and lower(trim(target.category)) = source.category_key
    and lower(trim(coalesce(target.description, ''))) = source.description_key
    and lower(trim(coalesce(target.class, ''))) = source.class_key
  returning target.id
)
select count(*) from updated;
SQL

COUNTS_SQL="select count(*) filter (where image_status='ready'), count(*) filter (where image_status='pending'), count(*) filter (where image_status='failed'), count(*) filter (where image_status='generating') from public.dinein_menu_items;"

for ((ITERATION = 1; ITERATION <= ITERATIONS; ITERATION += 1)); do
  UPDATED="$(psql "$DATABASE_URL" -At -c "$UPDATE_SQL")"
  COUNTS="$(psql "$DATABASE_URL" -At -F '|' -c "$COUNTS_SQL")"
  printf 'fanout-iter=%s updated=%s counts=%s at=%s\n' \
    "$ITERATION" \
    "$UPDATED" \
    "$COUNTS" \
    "$(date '+%H:%M:%S')"

  if [ "$ITERATION" -lt "$ITERATIONS" ]; then
    sleep "$SLEEP_SEC"
  fi
done
