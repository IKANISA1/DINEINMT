#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
key_properties="${project_dir}/android/key.properties"
materialize_env_script="${project_dir}/scripts/materialize_release_env.sh"

skip_checks=false
flavor="mt"
env_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-checks)
      skip_checks=true
      shift
      ;;
    --flavor)
      flavor="${2:-}"
      shift 2
      ;;
    --env-file)
      env_file="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$flavor" in
  mt|rw)
    ;;
  *)
    echo "Unsupported flavor: $flavor" >&2
    echo "Use --flavor mt or --flavor rw." >&2
    exit 1
    ;;
esac

if [[ -z "$env_file" ]]; then
  env_file="${project_dir}/env/release.${flavor}.json"
fi

entrypoint="lib/main_${flavor}.dart"
apk_path="build/app/outputs/flutter-apk/app-${flavor}-release.apk"
bundle_path="build/app/outputs/bundle/${flavor}Release/app-${flavor}-release.aab"

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "${path}" ]]; then
    echo "Missing ${label}: ${path}" >&2
    exit 1
  fi
}

has_env_signing() {
  [[ -n "${ANDROID_KEYSTORE_FILE:-}" ]] &&
    [[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ]] &&
    [[ -n "${ANDROID_KEY_ALIAS:-}" ]] &&
    [[ -n "${ANDROID_KEY_PASSWORD:-}" ]]
}

if [[ -f "${materialize_env_script}" ]]; then
  "${materialize_env_script}" --flavor "${flavor}" --output "${env_file}"
fi

require_file "${env_file}" "release env file"

if [[ ! -f "${key_properties}" ]] && ! has_env_signing; then
  echo "Missing Android release signing configuration." >&2
  echo "Provide android/key.properties or all ANDROID_KEY* environment variables." >&2
  exit 1
fi

cd "${project_dir}"

# ── Supabase credential validation (CRITICAL BLOCKER) ───────────────────────
# Ensures SUPABASE_URL and SUPABASE_ANON_KEY are set to real values in the
# env file before building.  A release APK/AAB with placeholder or empty
# credentials will crash on first launch.  This gate is non-negotiable.

supabase_url=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_URL',''))" "${env_file}" 2>/dev/null || true)
supabase_anon_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_ANON_KEY',''))" "${env_file}" 2>/dev/null || true)

supabase_cred_ok=true

if [[ -z "${supabase_url}" ]]; then
  echo "⛔ SUPABASE_URL is missing or empty in ${env_file}" >&2
  supabase_cred_ok=false
elif [[ "${supabase_url}" != https://* ]] || [[ "${supabase_url}" != *.supabase.co ]]; then
  echo "⛔ SUPABASE_URL does not look valid (must start with https:// and end with .supabase.co): ${supabase_url}" >&2
  supabase_cred_ok=false
elif echo "${supabase_url}" | grep -qiE 'your-project|your-malta|your-rwanda|placeholder'; then
  echo "⛔ SUPABASE_URL contains a placeholder value: ${supabase_url}" >&2
  supabase_cred_ok=false
fi

if [[ -z "${supabase_anon_key}" ]]; then
  echo "⛔ SUPABASE_ANON_KEY is missing or empty in ${env_file}" >&2
  supabase_cred_ok=false
elif [[ "${supabase_anon_key}" != eyJ* ]]; then
  echo "⛔ SUPABASE_ANON_KEY does not look like a valid JWT (must start with 'eyJ'): ${supabase_anon_key:0:10}…" >&2
  supabase_cred_ok=false
elif echo "${supabase_anon_key}" | grep -qiE 'your-.*-key|placeholder|anon-key$'; then
  echo "⛔ SUPABASE_ANON_KEY contains a placeholder value in ${env_file}" >&2
  supabase_cred_ok=false
fi

if [[ "${supabase_cred_ok}" != "true" ]]; then
  echo "" >&2
  echo "BUILD ABORTED: Supabase credentials in ${env_file} are invalid." >&2
  echo "Update SUPABASE_URL and SUPABASE_ANON_KEY with real project values before building." >&2
  exit 1
fi

echo "✅ Supabase credentials validated in ${env_file}"
# ─────────────────────────────────────────────────────────────────────────────

if [[ "${skip_checks}" != "true" ]]; then
  flutter analyze
  flutter test
fi

echo "Using env file: ${env_file}"

flutter build apk \
  --release \
  --flavor "${flavor}" \
  -t "${entrypoint}" \
  --dart-define-from-file="${env_file}"
flutter build appbundle \
  --release \
  --flavor "${flavor}" \
  -t "${entrypoint}" \
  --dart-define-from-file="${env_file}"

echo
echo "Release artifacts (${flavor})"
ls -lh "${apk_path}" "${bundle_path}"
echo
shasum -a 256 \
  "${apk_path}" \
  "${bundle_path}"
