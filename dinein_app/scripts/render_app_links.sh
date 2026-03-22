#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$script_dir/.." && pwd)"
template_dir="$app_root/docs/release/app-links"
site_root="$app_root/../landing"
well_known_dir="$site_root/.well-known"
flavor="mt"

play_sha="${PLAY_APP_SIGNING_SHA256:-}"
apple_team_id="${APPLE_TEAM_ID:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      flavor="${2:-}"
      shift 2
      ;;
    --output-dir)
      well_known_dir="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$flavor" in
  mt)
    android_package_id="com.dineinmalta.app"
    ios_bundle_id="com.dineinmalta.app"
    ;;
  rw)
    android_package_id="com.dineinrw.app"
    ios_bundle_id="com.dineinrw.app"
    ;;
  *)
    echo "Unsupported flavor: $flavor" >&2
    echo "Use --flavor mt or --flavor rw." >&2
    exit 1
    ;;
esac

if [[ -z "$play_sha" || -z "$apple_team_id" ]]; then
  cat <<'EOF'
Usage:
  PLAY_APP_SIGNING_SHA256="AA:BB:..." APPLE_TEAM_ID="ABCDE12345" ./scripts/render_app_links.sh --flavor mt
  PLAY_APP_SIGNING_SHA256="AA:BB:..." APPLE_TEAM_ID="ABCDE12345" ./scripts/render_app_links.sh --flavor rw --output-dir ../landing-rw/.well-known

This renders deployable app-link artifacts into:
  landing/.well-known/assetlinks.json
  landing/.well-known/apple-app-site-association
EOF
  exit 1
fi

if [[ ! "$play_sha" =~ ^([A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}$ ]]; then
  echo "PLAY_APP_SIGNING_SHA256 must be the colon-separated SHA-256 fingerprint from Play App Signing."
  exit 1
fi

if [[ ! "$apple_team_id" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "APPLE_TEAM_ID must be the 10-character Apple Developer Team ID."
  exit 1
fi

play_sha_upper="$(printf '%s' "$play_sha" | tr '[:lower:]' '[:upper:]')"

mkdir -p "$well_known_dir"

sed \
  -e "s/REPLACE_WITH_PLAY_APP_SIGNING_SHA256/${play_sha_upper}/g" \
  -e "s/REPLACE_WITH_ANDROID_PACKAGE_ID/${android_package_id}/g" \
  "$template_dir/assetlinks.json" > "$well_known_dir/assetlinks.json"

sed \
  -e "s/REPLACE_WITH_APPLE_TEAM_ID/${apple_team_id}/g" \
  -e "s/REPLACE_WITH_IOS_BUNDLE_ID/${ios_bundle_id}/g" \
  "$template_dir/apple-app-site-association" \
  > "$well_known_dir/apple-app-site-association"

echo "Rendered app-link artifacts:"
echo "  flavor: $flavor"
echo "  $well_known_dir/assetlinks.json"
echo "  $well_known_dir/apple-app-site-association"
