#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL to the Postgres connection string}"
: "${SUPABASE_URL:?Set SUPABASE_URL to the project base URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY to the service role JWT}"

PARTITION="${PARTITION:-all}"
SLEEP_SEC="${SLEEP_SEC:-0.2}"
PROGRESS_EVERY="${PROGRESS_EVERY:-10}"
FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/generate-menu-item-image"

case "$PARTITION" in
  all)
    PARTITION_SQL="true"
    ;;
  even)
    PARTITION_SQL="mod(ascii(left(replace(r.id::text, '-', ''), 1)), 2) = 0"
    ;;
  odd)
    PARTITION_SQL="mod(ascii(left(replace(r.id::text, '-', ''), 1)), 2) = 1"
    ;;
  *)
    echo "Unsupported PARTITION: $PARTITION" >&2
    exit 1
    ;;
esac

IDS_FILE="$(mktemp)"
trap 'rm -f "$IDS_FILE"' EXIT

psql "$DATABASE_URL" -At -c "
  with ready_signatures as (
    select distinct
      lower(trim(name)) || '|' || lower(trim(category)) || '|' ||
      lower(trim(coalesce(description, ''))) || '|' ||
      lower(trim(coalesce(class, ''))) as sig
    from public.dinein_menu_items
    where image_status = 'ready'
      and image_source = 'ai_gemini'
      and image_url is not null
  ),
  ranked as (
    select
      id,
      lower(trim(name)) || '|' || lower(trim(category)) || '|' ||
      lower(trim(coalesce(description, ''))) || '|' ||
      lower(trim(coalesce(class, ''))) as sig,
      row_number() over (
        partition by
          lower(trim(name)),
          lower(trim(category)),
          lower(trim(coalesce(description, ''))),
          lower(trim(coalesce(class, '')))
        order by id
      ) as rn
    from public.dinein_menu_items
  )
  select id
  from ranked r
  left join ready_signatures s on s.sig = r.sig
  where r.rn = 1
    and s.sig is null
    and ${PARTITION_SQL}
  order by id;
" > "$IDS_FILE"

TOTAL="$(grep -cve '^$' "$IDS_FILE" || true)"
SUCCESS=0
FAILED=0
START="$(date +%s)"

printf 'representative-generator partition=%s total=%s\n' "$PARTITION" "$TOTAL"

INDEX=0
while IFS= read -r ID; do
  [ -z "$ID" ] && continue
  INDEX=$((INDEX + 1))
  RESPONSE="$(
    curl -sS "$FUNCTION_URL" \
      -H 'Content-Type: application/json' \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      --data "{\"itemId\":\"${ID}\"}"
  )"

  if printf '%s' "$RESPONSE" | rg -q '"error"'; then
    FAILED=$((FAILED + 1))
    printf 'error %s/%s %s %s\n' \
      "$INDEX" \
      "$TOTAL" \
      "$ID" \
      "$(printf '%s' "$RESPONSE" | tr '\n' ' ' | cut -c1-220)"
  else
    SUCCESS=$((SUCCESS + 1))
    if [ $((INDEX % PROGRESS_EVERY)) -eq 0 ] || [ "$INDEX" -eq "$TOTAL" ]; then
      NOW="$(date +%s)"
      printf 'progress %s/%s success=%s failed=%s elapsed=%ss partition=%s\n' \
        "$INDEX" \
        "$TOTAL" \
        "$SUCCESS" \
        "$FAILED" \
        "$((NOW - START))" \
        "$PARTITION"
    fi
  fi

  sleep "$SLEEP_SEC"
done < "$IDS_FILE"

END="$(date +%s)"
printf 'representative-generator finished success=%s failed=%s elapsed=%ss partition=%s\n' \
  "$SUCCESS" \
  "$FAILED" \
  "$((END - START))" \
  "$PARTITION"
