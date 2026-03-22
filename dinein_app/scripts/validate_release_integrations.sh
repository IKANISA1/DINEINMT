#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$script_dir/.." && pwd)"

failures=0

require_file() {
  local path="$1"
  local message="$2"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: $message ($path)"
    failures=$((failures + 1))
  fi
}

require_no_placeholder() {
  local path="$1"
  local needle="$2"
  local message="$3"
  if grep -q "$needle" "$path"; then
    echo "FAIL: $message ($path)"
    failures=$((failures + 1))
  fi
}

require_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"
  if ! grep -q "$needle" "$path"; then
    echo "FAIL: $message ($path)"
    failures=$((failures + 1))
  fi
}

android_manifest="$app_root/android/app/src/main/AndroidManifest.xml"
ios_entitlements="$app_root/ios/Runner/Runner.entitlements"
firebase_options="$app_root/lib/firebase_options.dart"
android_google_services="$app_root/android/app/google-services.json"
ios_google_service_info="$app_root/ios/Runner/GoogleService-Info.plist"
asset_links_template="$app_root/docs/release/app-links/assetlinks.json"
apple_app_site_association_template="$app_root/docs/release/app-links/apple-app-site-association"
asset_links="$app_root/../landing/.well-known/assetlinks.json"
apple_app_site_association="$app_root/../landing/.well-known/apple-app-site-association"

require_contains \
  "$android_manifest" \
  'android:host="dineinmalta.com"' \
  'Android app links host is missing.'
require_contains \
  "$android_manifest" \
  'android:pathPrefix="/v/"' \
  'Android app links path prefix is missing.'

require_file "$ios_entitlements" 'iOS associated domains entitlements file is missing.'
if [[ -f "$ios_entitlements" ]]; then
  require_contains \
    "$ios_entitlements" \
    'applinks:dineinmalta.com' \
    'iOS associated domain for dineinmalta.com is missing.'
fi

require_file "$android_google_services" 'Android google-services.json is missing.'
if [[ -f "$android_google_services" ]]; then
  require_no_placeholder \
    "$android_google_services" \
    'REPLACE_WITH_ACTUAL_' \
    'Android Firebase config still contains placeholder values.'
fi

require_file "$ios_google_service_info" 'iOS GoogleService-Info.plist is missing.'
require_no_placeholder \
  "$firebase_options" \
  'REPLACE_WITH_ACTUAL_' \
  'firebase_options.dart still contains placeholder values.'

require_file "$asset_links_template" 'Android assetlinks template is missing.'
require_file \
  "$asset_links" \
  'Generated Android assetlinks file is missing. Run ./scripts/render_app_links.sh.'
if [[ -f "$asset_links" ]]; then
  require_no_placeholder \
    "$asset_links" \
    'REPLACE_WITH_PLAY_APP_SIGNING_SHA256' \
    'assetlinks.json still contains a placeholder certificate fingerprint.'
fi

require_file \
  "$apple_app_site_association_template" \
  'apple-app-site-association template is missing.'
require_file \
  "$apple_app_site_association" \
  'Generated apple-app-site-association file is missing. Run ./scripts/render_app_links.sh.'
if [[ -f "$apple_app_site_association" ]]; then
  require_no_placeholder \
    "$apple_app_site_association" \
    'REPLACE_WITH_APPLE_TEAM_ID' \
    'apple-app-site-association still contains a placeholder Apple Team ID.'
fi

if (( failures > 0 )); then
  echo
  echo "Release integration validation failed with $failures issue(s)."
  exit 1
fi

echo "Release integration validation passed."
