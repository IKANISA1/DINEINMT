#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL to the project base URL}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY to the service role JWT}"

LIMIT="${LIMIT:-1}"
ITERATIONS="${ITERATIONS:-1}"
SLEEP_SEC="${SLEEP_SEC:-60}"
OVERWRITE_EXISTING="${OVERWRITE_EXISTING:-false}"
FORCE_PLACE_REFRESH="${FORCE_PLACE_REFRESH:-false}"
SKIP_SEARCH_GROUNDING="${SKIP_SEARCH_GROUNDING:-false}"
VENUE_ID="${VENUE_ID:-}"
FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/dinein-api"

build_payload() {
  LIMIT="$LIMIT" \
  OVERWRITE_EXISTING="$OVERWRITE_EXISTING" \
  FORCE_PLACE_REFRESH="$FORCE_PLACE_REFRESH" \
  SKIP_SEARCH_GROUNDING="$SKIP_SEARCH_GROUNDING" \
  VENUE_ID="$VENUE_ID" \
  python3 - <<'PY'
import json
import os

payload = {
    "action": "backfill_venue_profiles",
    "limit": int(os.environ.get("LIMIT", "1")),
    "overwriteExisting": os.environ.get("OVERWRITE_EXISTING", "false").lower() == "true",
    "forcePlaceRefresh": os.environ.get("FORCE_PLACE_REFRESH", "false").lower() == "true",
    "skipSearchGrounding": os.environ.get("SKIP_SEARCH_GROUNDING", "false").lower() == "true",
}

venue_id = os.environ.get("VENUE_ID", "").strip()
if venue_id:
    payload["venueId"] = venue_id

print(json.dumps(payload, separators=(",", ":")))
PY
}

summarize_response() {
  RESPONSE="$1" python3 - <<'PY'
import json
import os

body = json.loads(os.environ["RESPONSE"])
if "error" in body:
    print(f"error|{body['error']}")
    raise SystemExit(0)

data = body.get("data") or {}
print(
    "ok|attempted={}|enriched={}|skipped={}|failed={}".format(
        data.get("attempted", 0),
        data.get("enriched", 0),
        data.get("skipped", 0),
        data.get("failed", 0),
    )
)
PY
}

for ((ITERATION = 1; ITERATION <= ITERATIONS; ITERATION += 1)); do
  PAYLOAD="$(build_payload)"
  RESPONSE="$(
    curl -sS "$FUNCTION_URL" \
      -H 'Content-Type: application/json' \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      --data "$PAYLOAD"
  )"

  SUMMARY="$(summarize_response "$RESPONSE")"
  printf 'venue-backfill-iter=%s result=%s at=%s\n' \
    "$ITERATION" \
    "$SUMMARY" \
    "$(date '+%H:%M:%S')"

  if [ "$ITERATION" -lt "$ITERATIONS" ]; then
    sleep "$SLEEP_SEC"
  fi
done
