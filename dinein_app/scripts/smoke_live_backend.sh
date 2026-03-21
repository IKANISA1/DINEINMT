#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
release_env_json="${project_dir}/env/release.json"
project_ref="${SUPABASE_PROJECT_REF:-uskfnszcdqpcfrhjxitl}"

extract_release_value() {
  local symbol="$1"
  python3 - "$release_env_json" "$symbol" <<'PY'
from pathlib import Path
import sys
import json

config_path = Path(sys.argv[1])
symbol = sys.argv[2]
payload = json.loads(config_path.read_text())
value = payload.get(symbol.upper()) or payload.get(symbol)
if not value:
    raise SystemExit(f"Could not extract {symbol} from {config_path}")
print(value)
PY
}

supabase_url="${SUPABASE_URL:-$(extract_release_value SUPABASE_URL)}"
supabase_anon_key="${SUPABASE_ANON_KEY:-$(extract_release_value SUPABASE_ANON_KEY)}"
functions_url="${supabase_url%/}/functions/v1/dinein-api"

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  printf 'WARN %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

call_api() {
  local payload="$1"
  curl -sS \
    -X POST \
    "${functions_url}" \
    -H "apikey: ${supabase_anon_key}" \
    -H 'Content-Type: application/json' \
    --data "${payload}" \
    -w $'\n%{http_code}'
}

parse_json_field() {
  local body="$1"
  local expr="$2"
  python3 - "$body" "$expr" <<'PY'
import json
import sys

body = json.loads(sys.argv[1])
expr = sys.argv[2]

if expr == "health":
    ok = body.get("data", {}).get("ok")
    if ok is not True:
        raise SystemExit("health.ok != true")
    print("ok")
elif expr == "venues":
    data = body.get("data")
    if not isinstance(data, list) or not data:
        raise SystemExit("venues list is empty")
    first = data[0]
    venue_id = first.get("id")
    venue_name = first.get("name", "")
    if not venue_id:
        raise SystemExit("first venue is missing id")
    print(f"{len(data)}|{venue_id}|{venue_name}")
elif expr == "menu_items":
    data = body.get("data")
    if not isinstance(data, list):
        raise SystemExit("menu items response is not a list")
    print(str(len(data)))
elif expr == "auth_error":
    message = body.get("error")
    if message != "Authentication is required.":
        raise SystemExit(f"unexpected auth error: {message!r}")
    print(message)
elif expr == "venue_session_error":
    message = body.get("error")
    allowed = {
        "Venue session is not authorized for this venue.",
        "Unsigned venue sessions are no longer accepted. Please log in again.",
    }
    if message not in allowed:
        raise SystemExit(f"unexpected venue-session error: {message!r}")
    print(message)
else:
    raise SystemExit(f"unknown expr: {expr}")
PY
}

run_check() {
  local label="$1"
  local payload="$2"
  local expected_status="$3"
  local parse_expr="$4"

  local result
  result="$(call_api "${payload}")"
  local status="${result##*$'\n'}"
  local body="${result%$'\n'*}"

  if [[ "${status}" != "${expected_status}" ]]; then
    fail "${label} returned HTTP ${status}: ${body}"
  fi

  parse_json_field "${body}" "${parse_expr}"
}

echo "Live backend smoke check"
echo "Project ref: ${project_ref}"
echo "Functions URL: ${functions_url}"
echo

run_check 'health' '{"action":"health"}' '200' 'health' >/dev/null
pass 'dinein-api health endpoint returned ok'

venue_meta="$(run_check 'get_venues' '{"action":"get_venues"}' '200' 'venues')"
IFS='|' read -r venue_count first_venue_id first_venue_name <<<"${venue_meta}"
pass "get_venues returned ${venue_count} venues"

menu_count="$(run_check \
  'get_menu_items' \
  "{\"action\":\"get_menu_items\",\"venueId\":\"${first_venue_id}\"}" \
  '200' \
  'menu_items'
)"
pass "get_menu_items responded for ${first_venue_name:-first venue} (${menu_count} items)"

run_check \
  'get_user_role' \
  '{"action":"get_user_role","userId":"00000000-0000-0000-0000-000000000000"}' \
  '401' \
  'auth_error' \
  >/dev/null
pass 'unauthenticated get_user_role is rejected'

run_check \
  'update_venue' \
  "{\"action\":\"update_venue\",\"venueId\":\"${first_venue_id}\",\"updates\":{\"status\":\"active\"},\"venue_session\":{\"venue_id\":\"${first_venue_id}\",\"contact_phone\":\"+35699999999\"}}" \
  '403' \
  'venue_session_error' \
  >/dev/null
pass 'unauthorized venue mutation is rejected'

if command -v supabase >/dev/null 2>&1; then
  ssl_output="$(supabase --experimental ssl-enforcement get --project-ref "${project_ref}" -o json 2>/dev/null || true)"
  if [[ -n "${ssl_output}" ]]; then
    ssl_enabled="$(python3 - "${ssl_output}" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
print(str(payload.get("currentConfig", {}).get("database", False)).lower())
PY
)"
    if [[ "${ssl_enabled}" == "true" ]]; then
      pass 'database SSL enforcement is enabled'
    else
      warn 'database SSL enforcement is disabled'
    fi
  else
    warn 'could not read ssl-enforcement settings from Supabase CLI'
  fi

  restrictions_output="$(supabase --experimental network-restrictions get --project-ref "${project_ref}" 2>/dev/null || true)"
  if [[ -n "${restrictions_output}" ]]; then
    if grep -q '0.0.0.0/0' <<<"${restrictions_output}" || grep -q '::/0' <<<"${restrictions_output}"; then
      warn 'database network restrictions are still open to all IPv4/IPv6 ranges'
    else
      pass 'database network restrictions are not open to the world'
    fi
  else
    warn 'could not read network restriction settings from Supabase CLI'
  fi
else
  warn 'supabase CLI not found; skipped project settings checks'
fi
