#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
env_file="${project_dir}/env/release.json"
key_properties="${project_dir}/android/key.properties"

skip_checks=false
if [[ "${1:-}" == "--skip-checks" ]]; then
  skip_checks=true
fi

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

flutter build apk --release --dart-define-from-file=env/release.json
flutter build appbundle --release --dart-define-from-file=env/release.json

echo
echo "Release artifacts"
ls -lh build/app/outputs/flutter-apk/app-release.apk \
  build/app/outputs/bundle/release/app-release.aab
echo
shasum -a 256 \
  build/app/outputs/flutter-apk/app-release.apk \
  build/app/outputs/bundle/release/app-release.aab
