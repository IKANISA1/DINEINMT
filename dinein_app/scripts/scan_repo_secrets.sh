#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

failures=0

report_matches() {
  local pattern="$1"
  local message="$2"
  shift 2
  local matches=""
  matches="$(git grep -nI -E -e "$pattern" -- "$@" || true)"
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

if (( failures > 0 )); then
  echo >&2
  echo "Repository secret scan failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Repository secret scan passed."
