#!/usr/bin/env bash

set -euo pipefail

invocation_dir="$(pwd -P)"
script_path="${BASH_SOURCE[0]}"
if [[ "$script_path" = /* ]]; then
  script_abs_path="$script_path"
else
  script_abs_path="$(
    cd "$invocation_dir/$(dirname "$script_path")" && pwd -P
  )/$(basename "$script_path")"
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

failures=0
script_rel_path="${script_abs_path#"$repo_root"/}"

report_matches() {
  local pattern="$1"
  local message="$2"
  shift 2
  local matches=""
  matches="$(git grep -nI -E -e "$pattern" -- "$@" || true)"
  if [[ -n "$matches" ]]; then
    matches="$(printf '%s\n' "$matches" | grep -v "^${script_rel_path}:" || true)"
  fi
  if [[ -n "$matches" ]]; then
    echo "FAIL: ${message}" >&2
    echo "$matches" >&2
    failures=$((failures + 1))
  fi
}

report_matches \
  '-----BEGIN PRIVATE KEY-----' \
  'Committed private-key material detected.' \
  ':!*.md' ':!*.txt' ':!*.rst' ':!*.example*'

report_matches \
  '"type":[[:space:]]*"service_account"' \
  'Committed Google service-account JSON detected.' \
  ':!*.example.json'

report_matches \
  'postgresql://postgres:[^@[:space:]]+@db\.[^.[:space:]]+\.supabase\.co:5432/postgres' \
  'Committed live Postgres connection string detected.' \
  ':!*.example*' ':!*.md'

report_matches \
  'sbp_[0-9a-f]{40}' \
  'Committed Supabase personal access token detected.' \
  ':!*.example*' ':!*.md'

report_matches \
  '"access_token":[[:space:]]*"eyJ[[:alnum:]_=-]+\.[[:alnum:]_=-]+\.[[:alnum:]_=-]+"' \
  'Committed session JWT detected.' \
  ':!*.example*' ':!*.md'

if (( failures > 0 )); then
  echo >&2
  echo "Repository secret scan failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Repository secret scan passed."
