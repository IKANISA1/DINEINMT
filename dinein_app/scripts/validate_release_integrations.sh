#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$script_dir/.." && pwd)"
flavor="mt"
android_only=false
well_known_dir=""
well_known_dir_overridden=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      flavor="${2:-}"
      shift 2
      ;;
    --android-only)
      android_only=true
      shift
      ;;
    --well-known-dir)
      well_known_dir="${2:-}"
      well_known_dir_overridden=true
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
    expected_host="dineinmt.ikanisa.com"
    expected_android_package="com.dineinmalta.app"
    expected_ios_bundle="com.dineinmalta.app"
    android_google_services="$app_root/android/app/src/mt/google-services.json"
    android_manifest_task=":app:processMtReleaseMainManifest"
    merged_android_manifest="$app_root/build/app/intermediates/merged_manifests/mtRelease/processMtReleaseManifest/AndroidManifest.xml"
    if [[ "$well_known_dir_overridden" != "true" ]]; then
      well_known_dir="$app_root/../landing/.well-known"
    fi
    ;;
  rw)
    expected_host="dineinrw.ikanisa.com"
    expected_android_package="com.dineinrw.app"
    expected_ios_bundle="com.dineinrw.app"
    android_google_services="$app_root/android/app/src/rw/google-services.json"
    android_manifest_task=":app:processRwReleaseMainManifest"
    merged_android_manifest="$app_root/build/app/intermediates/merged_manifests/rwRelease/processRwReleaseManifest/AndroidManifest.xml"
    if [[ "$well_known_dir_overridden" != "true" ]]; then
      well_known_dir="$app_root/../landing-rw/.well-known"
    fi
    ;;
  *)
    echo "Unsupported flavor: $flavor" >&2
    echo "Use --flavor mt or --flavor rw." >&2
    exit 1
    ;;
esac

failures=0

# ── Supabase credential validation in env file ──────────────────────────────
env_file="$app_root/env/release.${flavor}.json"
if [[ ! -f "$env_file" ]]; then
  echo "FAIL: Missing release env file ($env_file)"
  failures=$((failures + 1))
else
  sb_url=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_URL',''))" "$env_file" 2>/dev/null || true)
  sb_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_ANON_KEY',''))" "$env_file" 2>/dev/null || true)

  if [[ -z "$sb_url" ]] || echo "$sb_url" | grep -qiE 'your-project|your-malta|your-rwanda|placeholder'; then
    echo "FAIL: SUPABASE_URL is missing or contains a placeholder in $env_file"
    failures=$((failures + 1))
  elif [[ "$sb_url" != https://* ]] || [[ "$sb_url" != *.supabase.co ]]; then
    echo "FAIL: SUPABASE_URL does not match expected format (https://*.supabase.co) in $env_file"
    failures=$((failures + 1))
  fi

  if [[ -z "$sb_key" ]] || echo "$sb_key" | grep -qiE 'your-.*-key|placeholder|anon-key$'; then
    echo "FAIL: SUPABASE_ANON_KEY is missing or contains a placeholder in $env_file"
    failures=$((failures + 1))
  elif [[ "$sb_key" != eyJ* ]]; then
    echo "FAIL: SUPABASE_ANON_KEY does not look like a valid JWT in $env_file"
    failures=$((failures + 1))
  fi
fi
# ─────────────────────────────────────────────────────────────────────────────

(
  cd "$app_root/android"
  ./gradlew "$android_manifest_task" >/dev/null
)

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
ios_entitlements="$app_root/ios/Runner/Runner.${flavor}.entitlements"
firebase_options="$app_root/lib/firebase_options.dart"
ios_google_service_info="$app_root/ios/Runner/GoogleService-Info-${flavor}.plist"
ios_scheme="$app_root/ios/Runner.xcodeproj/xcshareddata/xcschemes/${flavor}.xcscheme"
ios_project="$app_root/ios/Runner.xcodeproj/project.pbxproj"
asset_links_template="$app_root/docs/release/app-links/assetlinks.json"
apple_app_site_association_template="$app_root/docs/release/app-links/apple-app-site-association"
asset_links="$well_known_dir/assetlinks.json"
apple_app_site_association="$well_known_dir/apple-app-site-association"

require_contains \
  "$android_manifest" \
  '${appLinkHost}' \
  'Android app links host is missing.'
require_contains \
  "$android_manifest" \
  'android:pathPrefix="/v/"' \
  'Android app links path prefix is missing.'
require_file "$merged_android_manifest" 'Merged Android release manifest is missing.'
if [[ -f "$merged_android_manifest" ]]; then
  require_no_placeholder \
    "$merged_android_manifest" \
    'android.permission.READ_PHONE_STATE' \
    'Merged Android manifest still packages READ_PHONE_STATE.'
  require_no_placeholder \
    "$merged_android_manifest" \
    'android.permission.RECORD_AUDIO' \
    'Merged Android manifest still packages RECORD_AUDIO.'
  require_no_placeholder \
    "$merged_android_manifest" \
    'android.permission.READ_EXTERNAL_STORAGE' \
    'Merged Android manifest still packages READ_EXTERNAL_STORAGE.'
  require_no_placeholder \
    "$merged_android_manifest" \
    'android.permission.WRITE_EXTERNAL_STORAGE' \
    'Merged Android manifest still packages WRITE_EXTERNAL_STORAGE.'
  if [[ "$flavor" == "mt" ]]; then
    require_no_placeholder \
      "$merged_android_manifest" \
      'android.permission.CAMERA' \
      'Merged Android manifest still packages CAMERA for Malta.'
  else
    require_contains \
      "$merged_android_manifest" \
      'android.permission.CAMERA' \
      'Merged Android manifest is missing CAMERA for Rwanda.'
  fi
fi

require_file "$ios_entitlements" 'iOS associated domains entitlements file is missing.'
if [[ "$android_only" != "true" && -f "$ios_entitlements" ]]; then
  require_contains \
    "$ios_entitlements" \
    "$expected_host" \
    "iOS associated domain for $expected_host is missing."
fi

require_file "$ios_scheme" 'iOS flavor scheme is missing.'
if [[ -f "$ios_project" ]]; then
  require_contains \
    "$ios_project" \
    "Debug-${flavor}" \
    "iOS Debug-${flavor} build configuration is missing."
  require_contains \
    "$ios_project" \
    "Release-${flavor}" \
    "iOS Release-${flavor} build configuration is missing."
  require_contains \
    "$ios_project" \
    "Profile-${flavor}" \
    "iOS Profile-${flavor} build configuration is missing."
fi

require_file "$android_google_services" 'Android google-services.json is missing.'
if [[ -f "$android_google_services" ]]; then
  require_no_placeholder \
    "$android_google_services" \
    'REPLACE_WITH_ACTUAL_' \
    'Android Firebase config still contains placeholder values.'
  require_contains \
    "$android_google_services" \
    "$expected_android_package" \
    "Android Firebase config for $expected_android_package is missing."
fi

if [[ "$android_only" != "true" ]]; then
  require_file "$ios_google_service_info" 'iOS GoogleService-Info.plist is missing.'
  if [[ -f "$ios_google_service_info" ]]; then
    require_contains \
      "$ios_google_service_info" \
      "$expected_ios_bundle" \
      "iOS Firebase config for $expected_ios_bundle is missing."
  fi
  require_no_placeholder \
    "$firebase_options" \
    'REPLACE_WITH_ACTUAL_' \
    'firebase_options.dart still contains placeholder values.'
fi

require_file "$asset_links_template" 'Android assetlinks template is missing.'
require_file \
  "$asset_links" \
  'Generated Android assetlinks file is missing. Run ./scripts/render_app_links.sh.'
if [[ -f "$asset_links" ]]; then
  require_contains \
    "$asset_links" \
    "$expected_android_package" \
    "assetlinks.json is missing $expected_android_package."
  require_no_placeholder \
    "$asset_links" \
    'REPLACE_WITH_PLAY_APP_SIGNING_SHA256' \
    'assetlinks.json still contains a placeholder certificate fingerprint.'
fi

require_file \
  "$apple_app_site_association_template" \
  'apple-app-site-association template is missing.'
if [[ "$android_only" != "true" ]]; then
  require_file \
    "$apple_app_site_association" \
    'Generated apple-app-site-association file is missing. Run ./scripts/render_app_links.sh.'
fi
if [[ "$android_only" != "true" && -f "$apple_app_site_association" ]]; then
  if [[ "$android_only" != "true" ]]; then
    require_contains \
      "$apple_app_site_association" \
      "$expected_ios_bundle" \
      "apple-app-site-association is missing $expected_ios_bundle."
  fi
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
