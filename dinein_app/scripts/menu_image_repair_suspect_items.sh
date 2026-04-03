#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL to the Postgres connection string}"
: "${SUPABASE_URL:?Set SUPABASE_URL to the project base URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY to the service role JWT}"

PARTITION="${PARTITION:-all}"
SLEEP_SEC="${SLEEP_SEC:-0.2}"
PROGRESS_EVERY="${PROGRESS_EVERY:-10}"
VENUE_ID="${VENUE_ID:-}"
MAX_ITEMS="${MAX_ITEMS:-0}"
DRY_RUN="${DRY_RUN:-false}"
CONTEXT_FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/enrich-menu-item-context"
IMAGE_FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/generate-menu-item-image"

case "$PARTITION" in
  all)
    PARTITION_SQL="true"
    ;;
  even)
    PARTITION_SQL="mod(ascii(left(replace(i.id::text, '-', ''), 1)), 2) = 0"
    ;;
  odd)
    PARTITION_SQL="mod(ascii(left(replace(i.id::text, '-', ''), 1)), 2) = 1"
    ;;
  *)
    echo "Unsupported PARTITION: $PARTITION" >&2
    exit 1
    ;;
esac

IDS_FILE="$(mktemp)"
trap 'rm -f "$IDS_FILE"' EXIT

psql "$DATABASE_URL" -v venue_id="$VENUE_ID" -At <<SQL > "$IDS_FILE"
  select i.id
  from public.dinein_menu_items i
  where i.image_locked = false
    and (${PARTITION_SQL})
    and (
      nullif(:'venue_id', '') is null
      or i.venue_id = nullif(:'venue_id', '')
    )
    and (
      i.image_url is null
      or i.image_status = 'failed'
      or (
        i.image_source = 'ai_gemini'
        and (
          i.image_prompt is null
          or (
            coalesce(i.class, '') = 'drinks'
            and i.image_prompt not ilike '%THIS IS A DRINK%'
          )
          or (
            coalesce(i.class, '') = 'food'
            and i.image_prompt not ilike '%THIS IS FOOD%'
          )
          or (
            i.menu_context is not null
            and coalesce(i.menu_context ->> 'class', '') not in (
              '',
              coalesce(i.class, '')
            )
          )
        )
      )
      or (
        lower(
          concat_ws(
            ' ',
            coalesce(i.name, ''),
            coalesce(i.category, ''),
            coalesce(i.description, ''),
            coalesce(array_to_string(i.tags, ' '), '')
          )
        ) ~ '(drink|drinks|beverage|beer|lager|ale|stout|porter|wine|prosecco|champagne|cocktail|mocktail|whisky|whiskey|bourbon|scotch|gin|rum|vodka|tequila|mezcal|brandy|cognac|liqueur|coffee|espresso|latte|tea|juice|smoothie|milkshake|cola|coke|sprite|fanta|kinnie|red bull|monster|johnnie walker|red label|black label|blue label|bombay sapphire|bacardi|smirnoff|hennessy|baileys|jameson|jack daniels)'
        and coalesce(i.class, '') <> 'drinks'
      )
    )
  order by i.updated_at asc nulls first, i.id;
SQL

if [ "${MAX_ITEMS}" -gt 0 ] 2>/dev/null; then
  head -n "${MAX_ITEMS}" "$IDS_FILE" > "${IDS_FILE}.limited"
  mv "${IDS_FILE}.limited" "$IDS_FILE"
fi

TOTAL="$(grep -cve '^$' "$IDS_FILE" || true)"
SUCCESS=0
FAILED=0
START="$(date +%s)"

printf 'menu-image-repair partition=%s total=%s venue_id=%s dry_run=%s\n' \
  "$PARTITION" \
  "$TOTAL" \
  "${VENUE_ID:-all}" \
  "$DRY_RUN"

INDEX=0
while IFS= read -r ID; do
  [ -z "$ID" ] && continue
  INDEX=$((INDEX + 1))

  if [ "$DRY_RUN" = "true" ]; then
    printf 'dry-run %s/%s %s\n' "$INDEX" "$TOTAL" "$ID"
    continue
  fi

  CONTEXT_RESPONSE="$(
    curl -sS "$CONTEXT_FUNCTION_URL" \
      -H 'Content-Type: application/json' \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      --data "{\"itemId\":\"${ID}\",\"forceRefresh\":true}"
  )"

  if printf '%s' "$CONTEXT_RESPONSE" | rg -q '"error"'; then
    FAILED=$((FAILED + 1))
    printf 'context-error %s/%s %s %s\n' \
      "$INDEX" \
      "$TOTAL" \
      "$ID" \
      "$(printf '%s' "$CONTEXT_RESPONSE" | tr '\n' ' ' | cut -c1-220)"
    sleep "$SLEEP_SEC"
    continue
  fi

  IMAGE_RESPONSE="$(
    curl -sS "$IMAGE_FUNCTION_URL" \
      -H 'Content-Type: application/json' \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      --data "{\"itemId\":\"${ID}\",\"forceRegenerate\":true}"
  )"

  if printf '%s' "$IMAGE_RESPONSE" | rg -q '"error"'; then
    FAILED=$((FAILED + 1))
    printf 'image-error %s/%s %s %s\n' \
      "$INDEX" \
      "$TOTAL" \
      "$ID" \
      "$(printf '%s' "$IMAGE_RESPONSE" | tr '\n' ' ' | cut -c1-220)"
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
printf 'menu-image-repair finished success=%s failed=%s elapsed=%ss partition=%s\n' \
  "$SUCCESS" \
  "$FAILED" \
  "$((END - START))" \
  "$PARTITION"
