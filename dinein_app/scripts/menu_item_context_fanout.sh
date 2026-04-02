#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL to the Postgres connection string}"
: "${SUPABASE_URL:?Set SUPABASE_URL to the project base URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY to the service role JWT}"

PARTITION="${PARTITION:-all}"
SLEEP_SEC="${SLEEP_SEC:-0.2}"
PROGRESS_EVERY="${PROGRESS_EVERY:-10}"
FORCE_REFRESH="${FORCE_REFRESH:-false}"
FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/enrich-menu-item-context"

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
  with pending_items as (
    select
      id
    from public.dinein_menu_items r
    where r.menu_context_locked = false
      and (
        r.class is null
        or r.menu_context is null
        or r.menu_context_status in ('pending', 'failed')
      )
      and ${PARTITION_SQL}
  )
  select id
  from pending_items
  order by id;
" > "$IDS_FILE"

TOTAL="$(grep -cve '^$' "$IDS_FILE" || true)"
SUCCESS=0
FAILED=0
START="$(date +%s)"

printf 'menu-item-context-fanout partition=%s total=%s force_refresh=%s\n' \
  "$PARTITION" \
  "$TOTAL" \
  "$FORCE_REFRESH"

INDEX=0
while IFS= read -r ID; do
  [ -z "$ID" ] && continue
  INDEX=$((INDEX + 1))
  if [ "$FORCE_REFRESH" = "true" ]; then
    PAYLOAD="{\"itemId\":\"${ID}\",\"forceRefresh\":true}"
  else
    PAYLOAD="{\"itemId\":\"${ID}\"}"
  fi

  RESPONSE="$(
    curl -sS "$FUNCTION_URL" \
      -H 'Content-Type: application/json' \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      --data "${PAYLOAD}"
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
printf 'menu-item-context-fanout finished success=%s failed=%s elapsed=%ss partition=%s\n' \
  "$SUCCESS" \
  "$FAILED" \
  "$((END - START))" \
  "$PARTITION"
