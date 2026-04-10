#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
key_properties="${project_dir}/android/key.properties"
materialize_env_script="${project_dir}/scripts/materialize_release_env.sh"
icon_validation_script="${project_dir}/scripts/validate_icon_assets.py"

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

reset_flutter_build_cache() {
  local cache_dir="${project_dir}/.dart_tool/flutter_build"
  if [[ -d "${cache_dir}" ]]; then
    echo "Resetting Flutter build cache (${cache_dir})"
    rm -rf "${cache_dir}"
  fi
}

stop_gradle_daemons() {
  local gradle_dir="${project_dir}/android"
  if [[ -x "${gradle_dir}/gradlew" ]]; then
    (
      cd "${gradle_dir}"
      ./gradlew --stop >/dev/null 2>&1 || true
    )
  fi
}

configure_gradle_runtime() {
  local profile="${1:-default}"
  case "${profile}" in
    constrained)
      export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1 -Dorg.gradle.jvmargs=-Xmx4G\\ -XX:MaxMetaspaceSize=1G\\ -XX:ReservedCodeCacheSize=256m\\ -XX:+HeapDumpOnOutOfMemoryError"
      ;;
    *)
      export GRADLE_OPTS="-Dorg.gradle.daemon=false"
      ;;
  esac
}

build_flutter_artifact() {
  local label="$1"
  shift

  local attempt=1
  local max_attempts=2
  local build_log
  build_log="$(mktemp)"

  while (( attempt <= max_attempts )); do
    if (( attempt > 1 )); then
      echo "Retrying ${label} with constrained Gradle settings (attempt ${attempt}/${max_attempts})"
      reset_flutter_build_cache
      stop_gradle_daemons
      configure_gradle_runtime constrained
      sleep 2
    fi

    if "$@" 2>&1 | tee "${build_log}"; then
      rm -f "${build_log}"
      return 0
    fi

    if ! grep -q "Gradle build daemon disappeared unexpectedly" "${build_log}" || (( attempt == max_attempts )); then
      rm -f "${build_log}"
      return 1
    fi

    echo "Transient Gradle daemon failure detected while building ${label}; retrying..."
    attempt=$((attempt + 1))
  done

  rm -f "${build_log}"
  return 1
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
require_file "${icon_validation_script}" "icon validation script"

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

python3 "${icon_validation_script}"

if [[ "${skip_checks}" != "true" ]]; then
  flutter analyze
  flutter test
fi

echo "Using env file: ${env_file}"
reset_flutter_build_cache
stop_gradle_daemons
configure_gradle_runtime default

build_flutter_artifact "APK" flutter build apk \
  --release \
  --flavor "${flavor}" \
  -t "${entrypoint}" \
  --dart-define-from-file="${env_file}"
build_flutter_artifact "AAB" flutter build appbundle \
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
