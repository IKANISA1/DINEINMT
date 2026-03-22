#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"

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
  if [[ -f "${project_dir}/env/release.${flavor}.json" ]]; then
    env_file="${project_dir}/env/release.${flavor}.json"
  else
    env_file="${project_dir}/env/release.json"
  fi
fi

entrypoint="lib/main_${flavor}.dart"
scheme="$flavor"
archive_path="build/ios/archive/Runner.xcarchive"
ipa_path="build/ios/ipa"

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

require_file "${env_file}" "release env file"
require_file "${flavor_plist}" "iOS Firebase plist for ${flavor}"

cd "${project_dir}"

if [[ "${skip_checks}" != "true" ]]; then
  flutter analyze
  flutter test
fi

(
  cd ios
  pod install
)

flutter build ipa \
  --release \
  --flavor "${scheme}" \
  -t "${entrypoint}" \
  --dart-define-from-file="${env_file}"

echo
echo "iOS release artifacts (${flavor})"
ls -lh "${archive_path}" "${ipa_path}"
