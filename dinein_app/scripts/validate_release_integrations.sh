#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "$script_dir/.." && pwd)"
materialize_env_script="$app_root/scripts/materialize_release_env.sh"
icon_validation_script="$app_root/scripts/validate_icon_assets.py"
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
    expected_firebase_project_number="1074154147498"
    expected_firebase_project_id="gen-lang-client-0172279957"
    expected_firebase_storage_bucket="gen-lang-client-0172279957.firebasestorage.app"
    expected_android_package="com.dineinmalta.app"
    expected_android_app_id="1:1074154147498:android:1dd401b016b8c501dc4ad3"
    expected_ios_bundle="com.dineinmalta.app"
    expected_ios_app_id="1:1074154147498:ios:f9338408dab88c45dc4ad3"
    android_google_services="$app_root/android/app/src/mt/google-services.json"
    android_manifest_task=":app:processMtReleaseMainManifest"
    merged_android_manifest="$app_root/build/app/intermediates/merged_manifests/mtRelease/processMtReleaseManifest/AndroidManifest.xml"
    if [[ "$well_known_dir_overridden" != "true" ]]; then
      well_known_dir="$app_root/../landing/.well-known"
    fi
    ;;
  rw)
    expected_host="dineinrw.ikanisa.com"
    expected_firebase_project_number="1074154147498"
    expected_firebase_project_id="gen-lang-client-0172279957"
    expected_firebase_storage_bucket="gen-lang-client-0172279957.firebasestorage.app"
    expected_android_package="com.dineinrw.app"
    expected_android_app_id="1:1074154147498:android:cbd8a51892a2ee93dc4ad3"
    expected_ios_bundle="com.dineinrw.app"
    expected_ios_app_id="1:1074154147498:ios:a44ce46db3c51bfcdc4ad3"
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
if [[ -f "$materialize_env_script" ]]; then
  "$materialize_env_script" --flavor "$flavor" --output "$env_file"
fi

if [[ ! -f "$env_file" ]]; then
  echo "FAIL: Missing release env file ($env_file)"
  failures=$((failures + 1))
else
  sb_url=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_URL',''))" "$env_file" 2>/dev/null || true)
  sb_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_ANON_KEY',''))" "$env_file" 2>/dev/null || true)
  web_vapid_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('FCM_WEB_VAPID_KEY',''))" "$env_file" 2>/dev/null || true)

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

  if [[ -z "$web_vapid_key" ]]; then
    echo "WARN: FCM_WEB_VAPID_KEY is missing in $env_file; venue web push notifications will remain disabled."
  fi
fi
# ─────────────────────────────────────────────────────────────────────────────

if [[ -f "$icon_validation_script" ]]; then
  if ! python3 "$icon_validation_script"; then
    failures=$((failures + 1))
  fi
else
  echo "FAIL: Missing icon validation script ($icon_validation_script)"
  failures=$((failures + 1))
fi

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
web_headers="$app_root/web/_headers"
web_index="$app_root/web/index.html"
web_manifest="$app_root/web/manifest.json"
web_offline="$app_root/web/offline.html"
web_robots="$app_root/web/robots.txt"
web_sitemap="$app_root/web/sitemap.xml"
web_push_worker="$app_root/web/firebase-messaging-sw.js"
web_screenshots_dir="$app_root/web/screenshots"

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
  require_contains \
    "$android_google_services" \
    "$expected_android_app_id" \
    "Android Firebase app id for $expected_android_package is missing."
  require_contains \
    "$android_google_services" \
    "\"project_number\": \"$expected_firebase_project_number\"" \
    "Android Firebase project number is missing or incorrect."
  require_contains \
    "$android_google_services" \
    "\"project_id\": \"$expected_firebase_project_id\"" \
    "Android Firebase project id is missing or incorrect."
  require_contains \
    "$android_google_services" \
    "\"storage_bucket\": \"$expected_firebase_storage_bucket\"" \
    "Android Firebase storage bucket is missing or incorrect."
fi

if [[ "$android_only" != "true" ]]; then
  require_file "$ios_google_service_info" 'iOS GoogleService-Info.plist is missing.'
  if [[ -f "$ios_google_service_info" ]]; then
    require_contains \
      "$ios_google_service_info" \
      "$expected_ios_bundle" \
      "iOS Firebase config for $expected_ios_bundle is missing."
    require_contains \
      "$ios_google_service_info" \
      "$expected_ios_app_id" \
      "iOS Firebase app id for $expected_ios_bundle is missing."
    require_contains \
      "$ios_google_service_info" \
      "<string>$expected_firebase_project_number</string>" \
      "iOS Firebase project number is missing or incorrect."
    require_contains \
      "$ios_google_service_info" \
      "<string>$expected_firebase_project_id</string>" \
      "iOS Firebase project id is missing or incorrect."
    require_contains \
      "$ios_google_service_info" \
      "<string>$expected_firebase_storage_bucket</string>" \
      "iOS Firebase storage bucket is missing or incorrect."
  fi
  require_no_placeholder \
    "$firebase_options" \
    'REPLACE_WITH_ACTUAL_' \
    'firebase_options.dart still contains placeholder values.'
  require_contains \
    "$firebase_options" \
    "projectId: '$expected_firebase_project_id'" \
    'firebase_options.dart is missing the expected Firebase project id.'
  require_contains \
    "$firebase_options" \
    "messagingSenderId: '$expected_firebase_project_number'" \
    'firebase_options.dart is missing the expected Firebase project number.'
  require_contains \
    "$firebase_options" \
    "storageBucket: '$expected_firebase_storage_bucket'" \
    'firebase_options.dart is missing the expected Firebase storage bucket.'
fi

require_file "$asset_links_template" 'Android assetlinks template is missing.'
require_file "$web_headers" 'Web headers config is missing.'
require_file "$web_index" 'Web index.html is missing.'
require_file "$web_manifest" 'Web manifest.json is missing.'
require_file "$web_offline" 'Offline fallback page is missing.'
require_file "$web_robots" 'Web robots.txt is missing.'
require_file "$web_sitemap" 'Web sitemap.xml is missing.'
require_file "$web_push_worker" 'Firebase Messaging web service worker is missing.'
require_file "$web_screenshots_dir/discover-mobile.png" 'Manifest mobile screenshot is missing.'
require_file "$web_screenshots_dir/venues-desktop.png" 'Manifest desktop screenshot is missing.'
require_file "${app_root}/web/custom_sw.js" 'Custom web service worker is missing.'
require_file "${app_root}/web/flutter_bootstrap.js" 'Custom flutter_bootstrap.js is missing.'
if [[ -f "$web_headers" ]]; then
  require_contains \
    "$web_headers" \
    'Permissions-Policy: camera=(), microphone=(), geolocation=()' \
    'Web headers are missing the geolocation permissions policy.'
fi
if [[ -f "$web_index" ]]; then
  require_contains \
    "$web_index" \
    'app-loader' \
    'Web index.html is missing the branded startup loader.'
  require_contains \
    "$web_index" \
    'beforeinstallprompt' \
    'Web index.html is missing the install prompt bridge.'
  require_contains \
    "$web_index" \
    'custom_sw.js' \
    'Web index.html is missing the custom service worker registration.'
  require_contains \
    "$web_index" \
    'firebase-messaging-sw.js' \
    'Web index.html is missing the Firebase Messaging service worker registration.'
fi
if [[ -f "$web_manifest" ]]; then
  require_contains \
    "$web_manifest" \
    '"display": "standalone"' \
    'Web manifest is missing standalone display mode.'
  require_contains \
    "$web_manifest" \
    '"shortcuts"' \
    'Web manifest is missing launcher shortcuts.'
  require_contains \
    "$web_manifest" \
    '"screenshots"' \
    'Web manifest is missing install screenshots.'
fi
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
