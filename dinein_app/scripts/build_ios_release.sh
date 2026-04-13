#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
materialize_env_script="${project_dir}/scripts/materialize_release_env.sh"

skip_checks=false
flavor="mt"
env_file=""
no_codesign=false

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
    --no-codesign)
      no_codesign=true
      shift
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
scheme="$flavor"
archive_path="build/ios/archive/Runner.xcarchive"
ipa_path="build/ios/ipa"
app_path="build/ios/iphoneos/Runner.app"

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "${path}" ]]; then
    echo "Missing ${label}: ${path}" >&2
    exit 1
  fi
}

flavor_plist="${project_dir}/ios/Runner/GoogleService-Info-${flavor}.plist"
if [[ "$flavor" == "mt" && ! -f "$flavor_plist" ]]; then
  flavor_plist="${project_dir}/ios/Runner/GoogleService-Info.plist"
fi

if [[ -f "${materialize_env_script}" ]]; then
  "${materialize_env_script}" --flavor "${flavor}" --output "${env_file}"
fi

require_file "${env_file}" "release env file"
require_file "${flavor_plist}" "iOS Firebase plist for ${flavor}"

cd "${project_dir}"

if [[ "${skip_checks}" != "true" ]]; then
  flutter analyze
  flutter test
fi

echo "Using env file: ${env_file}"

(
  cd ios
  pod install
)

if [[ "${no_codesign}" == "true" ]]; then
  flutter build ios \
    --release \
    --flavor "${scheme}" \
    -t "${entrypoint}" \
    --dart-define-from-file="${env_file}" \
    --no-codesign
else
  flutter build ipa \
    --release \
    --flavor "${scheme}" \
    -t "${entrypoint}" \
    --dart-define-from-file="${env_file}"
fi

echo
echo "iOS release artifacts (${flavor})"
if [[ "${no_codesign}" == "true" ]]; then
  ls -lh "${app_path}"
else
  ls -lh "${archive_path}" "${ipa_path}"
fi
