#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
flavor="mt"
release_env_json=""
project_ref="${SUPABASE_PROJECT_REF:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      flavor="${2:-}"
      shift 2
      ;;
    --env-file)
      release_env_json="${2:-}"
      shift 2
      ;;
    --project-ref)
      project_ref="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$release_env_json" ]]; then
  if [[ -f "${project_dir}/env/release.${flavor}.json" ]]; then
    release_env_json="${project_dir}/env/release.${flavor}.json"
  else
    release_env_json="${project_dir}/env/release.json"
  fi
fi

if [[ ! -f "$release_env_json" ]]; then
  echo "Missing release env file: $release_env_json" >&2
  exit 1
fi

extract_release_value() {
  local symbol="$1"
  python3 - "$release_env_json" "$symbol" <<'PY'
from pathlib import Path
import json
import sys

payload = json.loads(Path(sys.argv[1]).read_text())
value = payload.get(sys.argv[2].upper()) or payload.get(sys.argv[2])
if not value:
    raise SystemExit(f"Could not extract {sys.argv[2]} from {sys.argv[1]}")
print(value)
PY
}

derive_project_ref_from_url() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse

host = (urlparse(sys.argv[1]).hostname or "").strip().lower()
ref = host.split(".supabase.co", 1)[0]
if not ref:
    raise SystemExit(f"Could not derive project ref from {sys.argv[1]!r}")
print(ref)
PY
}

supabase_url="${SUPABASE_URL:-$(extract_release_value SUPABASE_URL)}"
supabase_anon_key="${SUPABASE_ANON_KEY:-$(extract_release_value SUPABASE_ANON_KEY)}"
service_role_key="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [[ -z "$project_ref" ]]; then
  project_ref="$(derive_project_ref_from_url "$supabase_url")"
fi

rest_url="${supabase_url%/}/rest/v1"

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

if [[ -z "$service_role_key" ]]; then
  fail "Set SUPABASE_SERVICE_ROLE_KEY before running this readiness check."
fi

call_rest() {
  local path="$1"
  curl -sS \
    "${rest_url}/${path}" \
    -H "apikey: ${service_role_key}" \
    -H "Authorization: Bearer ${service_role_key}" \
    -H 'Accept: application/json'
}

check_table_presence() {
  local table="$1"
  local select_expr="$2"
  local result
  result="$(call_rest "${table}?select=${select_expr}&limit=1")"
  python3 - "$table" "$result" <<'PY'
import json
import sys

table = sys.argv[1]
payload = json.loads(sys.argv[2])
if isinstance(payload, list):
    print("ok")
    raise SystemExit(0)

message = str(payload.get("message", ""))
if "does not exist" in message or "Could not find the table" in message:
    raise SystemExit(f"{table} missing: {message}")
raise SystemExit(f"{table} query failed: {payload}")
PY
}

pick_profile_table() {
  if check_table_presence "dinein_profiles" "id" >/dev/null 2>&1; then
    printf 'dinein_profiles'
    return
  fi
  if check_table_presence "profiles" "id" >/dev/null 2>&1; then
    printf 'profiles'
    return
  fi
  printf ''
}

profile_table="$(pick_profile_table)"
if [[ -n "$profile_table" ]]; then
  pass "profile lookup table available (${profile_table})"
else
  warn "Neither dinein_profiles nor profiles is available; admin OTP will require a configured fallback WhatsApp number."
fi

check_table_presence "venue_whatsapp_otp_challenges" "challenge_id" >/dev/null
pass "venue_whatsapp_otp_challenges table is available"

check_table_presence "bell_requests" "id" >/dev/null
pass "bell_requests table is available"

admin_count=0
admin_with_phone=0
if [[ -n "$profile_table" ]]; then
  admin_rows="$(call_rest "${profile_table}?role=eq.admin&select=id,display_name,whatsapp_number&limit=20")"
  admin_summary="$(python3 - "$admin_rows" <<'PY'
import json
import sys

rows = json.loads(sys.argv[1])
if not isinstance(rows, list):
    raise SystemExit(f"admin query failed: {rows}")

count = len(rows)
with_phone = sum(1 for row in rows if str(row.get("whatsapp_number") or "").strip())
print(f"{count}|{with_phone}")
PY
)"
  IFS='|' read -r admin_count admin_with_phone <<<"$admin_summary"
fi

venue_rows="$(call_rest "dinein_venues?status=eq.active&select=id,name,country,owner_whatsapp_number,phone&limit=500")"
venue_summary="$(python3 - "$venue_rows" <<'PY'
import json
import sys

rows = json.loads(sys.argv[1])
if not isinstance(rows, list):
    raise SystemExit(f"venue query failed: {rows}")

count = len(rows)
with_owner_phone = sum(1 for row in rows if str(row.get("owner_whatsapp_number") or "").strip())
print(f"{count}|{with_owner_phone}")
PY
)"
IFS='|' read -r venue_count venue_with_owner_phone <<<"$venue_summary"
if [[ "$venue_count" -lt 1 ]]; then
  fail "No active venues found."
fi
pass "active venue lookup returns ${venue_count} venue row(s)"
if [[ "$venue_with_owner_phone" -lt 1 ]]; then
  fail "No active venues have owner_whatsapp_number configured."
fi
pass "active venues with owner WhatsApp numbers: ${venue_with_owner_phone}"

required_local_secrets=(
  DINEIN_ADMIN_SESSION_SECRET
  DINEIN_VENUE_SESSION_SECRET
  WHATSAPP_ACCESS_TOKEN
  WHATSAPP_PHONE_NUMBER_ID
)

case "$flavor" in
  rw)
    required_local_secrets+=(DEFAULT_WHATSAPP_COUNTRY_CODE DINEIN_ADMIN_WHATSAPP_NUMBER_RW)
    admin_secret_candidates=(DINEIN_ADMIN_WHATSAPP_NUMBER_RW DINEIN_ADMIN_WHATSAPP_NUMBER)
    ;;
  mt)
    required_local_secrets+=(DEFAULT_WHATSAPP_COUNTRY_CODE DINEIN_ADMIN_WHATSAPP_NUMBER_MT)
    admin_secret_candidates=(DINEIN_ADMIN_WHATSAPP_NUMBER_MT DINEIN_ADMIN_WHATSAPP_NUMBER)
    ;;
  *)
    warn "Unsupported flavor ${flavor} for local secret hints."
    admin_secret_candidates=(DINEIN_ADMIN_WHATSAPP_NUMBER)
    ;;
esac

missing_local_secret=false
admin_local_secret_available=false
for secret_name in "${required_local_secrets[@]}"; do
  if [[ " ${admin_secret_candidates[*]} " == *" ${secret_name} "* ]] && [[ -n "${!secret_name:-}" ]]; then
    admin_local_secret_available=true
  fi
  if [[ -z "${!secret_name:-}" ]]; then
    missing_local_secret=true
    warn "Local env does not expose ${secret_name}; verify the remote function secret separately if you deploy from another environment."
  fi
done

remote_admin_secret_available=false
if command -v supabase >/dev/null 2>&1; then
  secrets_output="$(supabase secrets list --project-ref "${project_ref}" 2>/dev/null || true)"
  if [[ -n "$secrets_output" ]]; then
    pass "Supabase secrets list is reachable for project ${project_ref}"
    for required_secret in "${required_local_secrets[@]}"; do
      if grep -q "${required_secret}" <<<"$secrets_output"; then
        pass "remote secret present: ${required_secret}"
      else
        fail "remote secret missing: ${required_secret}"
      fi
    done
    for admin_secret in "${admin_secret_candidates[@]}"; do
      if grep -q "${admin_secret}" <<<"$secrets_output"; then
        remote_admin_secret_available=true
      fi
    done
    missing_local_secret=false
  else
    warn "Could not read remote Supabase secrets for ${project_ref}; using local env checks only."
  fi
fi

if [[ "$admin_count" -lt 1 ]]; then
  if [[ "$remote_admin_secret_available" == "true" || "$admin_local_secret_available" == "true" ]]; then
    warn "No admin profiles found; admin OTP will rely on the configured fallback WhatsApp number."
  else
    fail "No admin profiles found and no admin WhatsApp fallback secret is configured."
  fi
else
  pass "admin profile lookup returns ${admin_count} admin row(s)"
  if [[ "$admin_with_phone" -lt 1 ]]; then
    warn "admin profiles exist but none currently stores whatsapp_number; OTP will rely on configured admin fallback phone."
  else
    pass "admin profile data includes ${admin_with_phone} stored WhatsApp number(s)"
  fi
fi

if [[ "$missing_local_secret" == "false" ]]; then
  pass "OTP runtime secret checks passed"
fi

flavor_upper="$(printf '%s' "$flavor" | tr '[:lower:]' '[:upper:]')"

echo
echo "Readiness check completed for ${flavor_upper} (${project_ref})"
