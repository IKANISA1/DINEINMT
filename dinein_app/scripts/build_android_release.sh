#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
key_properties="${project_dir}/android/key.properties"

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

require_file "${env_file}" "release env file"

if [[ ! -f "${key_properties}" ]] && ! has_env_signing; then
  echo "Missing Android release signing configuration." >&2
  echo "Provide android/key.properties or all ANDROID_KEY* environment variables." >&2
  exit 1
fi

cd "${project_dir}"

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
