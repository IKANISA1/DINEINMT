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
GENERATE_PROFILE_IMAGES="${GENERATE_PROFILE_IMAGES:-true}"
IMAGE_LIMIT="${IMAGE_LIMIT:-$LIMIT}"
FORCE_IMAGE_REGENERATE="${FORCE_IMAGE_REGENERATE:-false}"
IMAGE_SKIP_SEARCH_GROUNDING="${IMAGE_SKIP_SEARCH_GROUNDING:-$SKIP_SEARCH_GROUNDING}"
VENUE_ID="${VENUE_ID:-}"
FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/dinein-api"

build_profile_payload() {
  LIMIT="$LIMIT" \
  OVERWRITE_EXISTING="$OVERWRITE_EXISTING" \
  FORCE_PLACE_REFRESH="$FORCE_PLACE_REFRESH" \
  SKIP_SEARCH_GROUNDING="$SKIP_SEARCH_GROUNDING" \
  GENERATE_PROFILE_IMAGES="$GENERATE_PROFILE_IMAGES" \
  FORCE_IMAGE_REGENERATE="$FORCE_IMAGE_REGENERATE" \
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
    "generateProfileImage": os.environ.get("GENERATE_PROFILE_IMAGES", "true").lower() == "true",
    "forceImageRegenerate": os.environ.get("FORCE_IMAGE_REGENERATE", "false").lower() == "true",
}

venue_id = os.environ.get("VENUE_ID", "").strip()
if venue_id:
    payload["venueId"] = venue_id

print(json.dumps(payload, separators=(",", ":")))
PY
}

build_image_payload() {
  IMAGE_LIMIT="$IMAGE_LIMIT" \
  FORCE_IMAGE_REGENERATE="$FORCE_IMAGE_REGENERATE" \
  IMAGE_SKIP_SEARCH_GROUNDING="$IMAGE_SKIP_SEARCH_GROUNDING" \
  VENUE_ID="$VENUE_ID" \
  python3 - <<'PY'
import json
import os

payload = {
    "action": "backfill_venue_profile_images",
    "limit": int(os.environ.get("IMAGE_LIMIT", "1")),
    "forceRegenerate": os.environ.get("FORCE_IMAGE_REGENERATE", "false").lower() == "true",
    "skipSearchGrounding": os.environ.get("IMAGE_SKIP_SEARCH_GROUNDING", "false").lower() == "true",
}

venue_id = os.environ.get("VENUE_ID", "").strip()
if venue_id:
    payload["venueId"] = venue_id

print(json.dumps(payload, separators=(",", ":")))
PY
}

invoke_action() {
  local payload="$1"
  curl -sS "$FUNCTION_URL" \
    -H 'Content-Type: application/json' \
    -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    --data "$payload"
}

summarize_response() {
  ACTION="$1" RESPONSE="$2" python3 - <<'PY'
import json
import os

action = os.environ["ACTION"]
body = json.loads(os.environ["RESPONSE"])
if "error" in body:
    print(f"error|{body['error']}")
    raise SystemExit(0)

data = body.get("data") or {}
if action == "backfill_venue_profiles":
    print(
        "ok|attempted={}|enriched={}|skipped={}|failed={}|images_generated={}|images_skipped={}|images_failed={}".format(
            data.get("attempted", 0),
            data.get("enriched", 0),
            data.get("skipped", 0),
            data.get("failed", 0),
            data.get("images_generated", data.get("imagesGenerated", 0)),
            data.get("images_skipped", data.get("imagesSkipped", 0)),
            data.get("images_failed", data.get("imagesFailed", 0)),
        )
    )
else:
    print(
        "ok|attempted={}|generated={}|skipped={}|failed={}".format(
            data.get("attempted", 0),
            data.get("generated", 0),
            data.get("skipped", 0),
            data.get("failed", 0),
        )
    )
PY
}

for ((ITERATION = 1; ITERATION <= ITERATIONS; ITERATION += 1)); do
  PROFILE_PAYLOAD="$(build_profile_payload)"
  PROFILE_RESPONSE="$(invoke_action "$PROFILE_PAYLOAD")"
  PROFILE_SUMMARY="$(summarize_response "backfill_venue_profiles" "$PROFILE_RESPONSE")"
  printf 'venue-profile-backfill-iter=%s result=%s at=%s\n' \
    "$ITERATION" \
    "$PROFILE_SUMMARY" \
    "$(date '+%H:%M:%S')"

  if [ "$(printf '%s' "$GENERATE_PROFILE_IMAGES" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
    IMAGE_PAYLOAD="$(build_image_payload)"
    IMAGE_RESPONSE="$(invoke_action "$IMAGE_PAYLOAD")"
    IMAGE_SUMMARY="$(summarize_response "backfill_venue_profile_images" "$IMAGE_RESPONSE")"
    printf 'venue-image-backfill-iter=%s result=%s at=%s\n' \
      "$ITERATION" \
      "$IMAGE_SUMMARY" \
      "$(date '+%H:%M:%S')"
  fi

  if [ "$ITERATION" -lt "$ITERATIONS" ]; then
    sleep "$SLEEP_SEC"
  fi
done
