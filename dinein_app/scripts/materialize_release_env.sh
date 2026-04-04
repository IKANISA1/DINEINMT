#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"

flavor=""
output=""
require_secrets=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      flavor="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    --require-secrets)
      require_secrets=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$flavor" in
  mt)
    url_var="SUPABASE_URL_MT"
    anon_var="SUPABASE_ANON_KEY_MT"
    default_country_code="356"
    example_file="${project_dir}/env/release.mt.example.json"
    ;;
  rw)
    url_var="SUPABASE_URL_RW"
    anon_var="SUPABASE_ANON_KEY_RW"
    default_country_code="250"
    example_file="${project_dir}/env/release.rw.example.json"
    ;;
  *)
    echo "Unsupported or missing flavor: ${flavor}" >&2
    echo "Use --flavor mt or --flavor rw." >&2
    exit 1
    ;;
esac

if [[ -z "$output" ]]; then
  output="${project_dir}/env/release.${flavor}.json"
fi

supabase_url="${!url_var:-${SUPABASE_URL:-}}"
supabase_anon_key="${!anon_var:-${SUPABASE_ANON_KEY:-}}"

if [[ "$require_secrets" == "true" ]]; then
  if [[ -z "$supabase_url" ]]; then
    echo "Missing ${url_var} for flavor ${flavor}." >&2
    exit 1
  fi
  if [[ -z "$supabase_anon_key" ]]; then
    echo "Missing ${anon_var} for flavor ${flavor}." >&2
    exit 1
  fi
fi

if [[ -z "$supabase_url" && -z "$supabase_anon_key" ]]; then
  exit 0
fi

if [[ -z "$supabase_url" || -z "$supabase_anon_key" ]]; then
  echo "Both Supabase values are required to materialize ${output}." >&2
  echo "Provide ${url_var} and ${anon_var}, or SUPABASE_URL and SUPABASE_ANON_KEY." >&2
  exit 1
fi

base_file="$output"
if [[ ! -f "$base_file" ]]; then
  base_file="$example_file"
fi

python3 - "$base_file" "$output" "$supabase_url" "$supabase_anon_key" "$default_country_code" <<'PY'
import json
import sys
from pathlib import Path

base_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
supabase_url = sys.argv[3]
supabase_anon_key = sys.argv[4]
default_country_code = sys.argv[5]

data = {}
if base_path.is_file():
    data = json.loads(base_path.read_text(encoding="utf-8"))

data.setdefault("WHATSAPP_OTP_FUNCTION_NAME", "whatsapp-otp")
data.setdefault("DEFAULT_WHATSAPP_COUNTRY_CODE", default_country_code)
data.setdefault("WHATSAPP_OTP_ALLOW_LOCAL_MOCK", "false")
data["SUPABASE_URL"] = supabase_url
data["SUPABASE_ANON_KEY"] = supabase_anon_key

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

echo "Materialized ${output##${project_dir}/} for flavor ${flavor}"
