#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# build_web_release.sh — Build Flutter web for DineIn PWA deployment
#
# Usage:
#   scripts/build_web_release.sh --flavor mt   # Malta
#   scripts/build_web_release.sh --flavor rw   # Rwanda
#
# Output:  build/web/  (ready to deploy to Cloudflare Pages)
#
# Deployment:
#   MT build → Cloudflare Pages project dinein-mt-pwa → dineinmtg/dineinmtv/dineinmta.ikanisa.com
#   RW build → Cloudflare Pages project dinein-rw-pwa → dineinrwg/dineinrwv/dineinrwa.ikanisa.com
# ═══════════════════════════════════════════════════════════════════════════════

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
materialize_env_script="${project_dir}/scripts/materialize_release_env.sh"

flavor="mt"
env_file=""
skip_checks=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)
      flavor="${2:-}"
      shift 2
      ;;
    --env-file)
      env_file="${2:-}"
      shift 2
      ;;
    --skip-checks)
      skip_checks=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$flavor" in
  mt)
    guest_origin="https://dineinmtg.ikanisa.com"
    mt_guest_origin="https://dineinmtg.ikanisa.com"
    rw_guest_origin="https://dineinrwg.ikanisa.com"
    site_host="dineinmt.ikanisa.com"
    guest_host="dineinmtg.ikanisa.com"
    venue_host="dineinmtv.ikanisa.com"
    admin_host="dineinmta.ikanisa.com"
    landing_source_dir="${project_dir}/../landing"
    ;;
  rw)
    guest_origin="https://dineinrwg.ikanisa.com"
    mt_guest_origin="https://dineinmtg.ikanisa.com"
    rw_guest_origin="https://dineinrwg.ikanisa.com"
    site_host="dineinrw.ikanisa.com"
    guest_host="dineinrwg.ikanisa.com"
    venue_host="dineinrwv.ikanisa.com"
    admin_host="dineinrwa.ikanisa.com"
    landing_source_dir="${project_dir}/../landing-rw"
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

# ── Materialize env file from CI/local environment when provided ───────────
if [[ -f "${materialize_env_script}" ]]; then
  "${materialize_env_script}" --flavor "${flavor}" --output "${env_file}"
fi

# ── Validate env file exists ────────────────────────────────────────────────
if [[ ! -f "${env_file}" ]]; then
  echo "Missing release env file: ${env_file}" >&2
  exit 1
fi

# ── Supabase credential validation (same gate as Android build) ─────────────
supabase_url=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_URL',''))" "${env_file}" 2>/dev/null || true)
supabase_anon_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_ANON_KEY',''))" "${env_file}" 2>/dev/null || true)
web_vapid_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('FCM_WEB_VAPID_KEY',''))" "${env_file}" 2>/dev/null || true)

supabase_cred_ok=true

if [[ -z "${supabase_url}" ]]; then
  echo "⛔ SUPABASE_URL is missing or empty in ${env_file}" >&2
  supabase_cred_ok=false
elif [[ "${supabase_url}" != https://* ]] || [[ "${supabase_url}" != *.supabase.co ]]; then
  echo "⛔ SUPABASE_URL does not look valid: ${supabase_url}" >&2
  supabase_cred_ok=false
fi

if [[ -z "${supabase_anon_key}" ]]; then
  echo "⛔ SUPABASE_ANON_KEY is missing or empty in ${env_file}" >&2
  supabase_cred_ok=false
elif [[ "${supabase_anon_key}" != eyJ* ]]; then
  echo "⛔ SUPABASE_ANON_KEY does not look like a valid JWT" >&2
  supabase_cred_ok=false
fi

if [[ "${supabase_cred_ok}" != "true" ]]; then
  echo "" >&2
  echo "BUILD ABORTED: Supabase credentials in ${env_file} are invalid." >&2
  exit 1
fi

echo "✅ Supabase credentials validated in ${env_file}"
if [[ -z "${web_vapid_key}" ]]; then
  echo "⚠️  FCM_WEB_VAPID_KEY is missing in ${env_file}; venue web push notifications will remain disabled." >&2
fi

cd "${project_dir}"

# ── Optional: analyze + test ────────────────────────────────────────────────
if [[ "${skip_checks}" != "true" ]]; then
  echo "Running flutter analyze..."
  flutter analyze
  echo "Running flutter test..."
  flutter test
fi

# ── Build Flutter Web ───────────────────────────────────────────────────────
echo ""
echo "Building Flutter web (${flavor})..."
echo "  Entry point: ${entrypoint}"
echo "  Env file:    ${env_file}"
echo ""

rm -rf "${project_dir}/build/web"

flutter build web \
  --release \
  --wasm \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  -t "${entrypoint}" \
  --dart-define-from-file="${env_file}"

# ── Post-build: ensure Cloudflare config files are in build output ──────────
build_output="${project_dir}/build/web"

# Copy _headers if not already included by flutter build
if [[ -f "${project_dir}/web/_headers" ]]; then
  cp "${project_dir}/web/_headers" "${build_output}/_headers"
  echo "✅ Copied _headers to build output"
fi

if [[ -f "${project_dir}/web/_worker.js" ]]; then
  cp "${project_dir}/web/_worker.js" "${build_output}/_worker.js"
  python3 - "${build_output}/_worker.js" "${site_host}" "${guest_host}" "${venue_host}" "${admin_host}" <<'PY'
import sys
from pathlib import Path

worker_path = Path(sys.argv[1])
site_host = sys.argv[2]
guest_host = sys.argv[3]
venue_host = sys.argv[4]
admin_host = sys.argv[5]
contents = worker_path.read_text(encoding="utf-8")
contents = contents.replace("__DINEIN_SITE_HOST__", site_host)
contents = contents.replace("__DINEIN_GUEST_HOST__", guest_host)
contents = contents.replace("__DINEIN_VENUE_HOST__", venue_host)
contents = contents.replace("__DINEIN_ADMIN_HOST__", admin_host)
worker_path.write_text(contents, encoding="utf-8")
PY
  echo "✅ Copied host-aware _worker.js to build output"
fi

# _redirects should already be in web/ and copied by flutter build,
# but ensure it's there
if [[ -f "${project_dir}/web/_redirects" ]] && [[ ! -f "${build_output}/_redirects" ]]; then
  cp "${project_dir}/web/_redirects" "${build_output}/_redirects"
  echo "✅ Copied _redirects to build output"
fi

# Ensure auxiliary crawlability files survive the Flutter web build.
for extra_file in robots.txt sitemap.xml; do
  if [[ -f "${project_dir}/web/${extra_file}" ]] && [[ ! -f "${build_output}/${extra_file}" ]]; then
    cp "${project_dir}/web/${extra_file}" "${build_output}/${extra_file}"
    echo "✅ Copied ${extra_file} to build output"
  fi
done

if [[ -d "${project_dir}/web/screenshots" ]]; then
  mkdir -p "${build_output}/screenshots"
  rsync -a "${project_dir}/web/screenshots/" "${build_output}/screenshots/"
  echo "✅ Copied manifest screenshots to build output"
fi

landing_files=(
  "index.css"
  "app-mockup.png"
  "logo.png"
)

if [[ -d "${landing_source_dir}" ]]; then
  for landing_file in "${landing_files[@]}"; do
    if [[ -f "${landing_source_dir}/${landing_file}" ]]; then
      cp "${landing_source_dir}/${landing_file}" "${build_output}/${landing_file}"
    fi
  done
  if [[ -f "${landing_source_dir}/index.html" ]]; then
    mkdir -p "${build_output}/landing"
    cp "${landing_source_dir}/index.html" "${build_output}/landing/index.html"
  fi
  if [[ -f "${landing_source_dir}/privacy.html" ]]; then
    mkdir -p "${build_output}/privacy"
    cp "${landing_source_dir}/privacy.html" "${build_output}/privacy/index.html"
  fi
  if [[ -f "${landing_source_dir}/terms.html" ]]; then
    mkdir -p "${build_output}/terms"
    cp "${landing_source_dir}/terms.html" "${build_output}/terms/index.html"
  fi
  if [[ -d "${landing_source_dir}/download" ]]; then
    rm -rf "${build_output}/download"
    rsync -a "${landing_source_dir}/download/" "${build_output}/download/"
  fi
  echo "✅ Copied landing assets into build output"
fi

python3 - "${build_output}" "${guest_origin}" <<'PY'
import sys
from pathlib import Path

build_dir = Path(sys.argv[1])
guest_origin = sys.argv[2].rstrip("/")

placeholder = "__DINEIN_GUEST_ORIGIN__"
for relative_path in ("index.html", "robots.txt", "sitemap.xml"):
    target = build_dir / relative_path
    if not target.is_file():
        continue
    contents = target.read_text(encoding="utf-8")
    contents = contents.replace(placeholder, guest_origin)
    if placeholder in contents:
        print(f"⛔ {relative_path} still contains unresolved guest-origin placeholders.", file=sys.stderr)
        raise SystemExit(1)
    target.write_text(contents, encoding="utf-8")
PY

python3 \
  "${project_dir}/scripts/prerender_public_routes.py" \
  "${build_output}" \
  "${guest_origin}" \
  "${mt_guest_origin}" \
  "${rw_guest_origin}"

python3 "${project_dir}/scripts/stamp_pwa_bundle.py" "${build_output}"

if ! grep -q 'app-loader' "${build_output}/index.html"; then
  echo "⛔ Built index.html is missing the branded startup loader." >&2
  exit 1
fi

if ! grep -q 'Permissions-Policy: camera=(), microphone=(), geolocation=(self)' "${build_output}/_headers"; then
  echo "⛔ Built _headers is missing the expected geolocation policy." >&2
  exit 1
fi

if ! grep -q '"display": "standalone"' "${build_output}/manifest.json"; then
  echo "⛔ Built manifest.json is missing standalone display mode." >&2
  exit 1
fi

if [[ ! -f "${build_output}/offline.html" ]]; then
  echo "⛔ Built web output is missing offline.html." >&2
  exit 1
fi

if [[ ! -f "${build_output}/landing/index.html" ]]; then
  echo "⛔ Built web output is missing landing/index.html." >&2
  exit 1
fi

if [[ ! -f "${build_output}/robots.txt" ]]; then
  echo "⛔ Built web output is missing robots.txt." >&2
  exit 1
fi

if [[ ! -f "${build_output}/sitemap.xml" ]]; then
  echo "⛔ Built web output is missing sitemap.xml." >&2
  exit 1
fi

for prerendered_route in discover venues; do
  if [[ ! -f "${build_output}/${prerendered_route}/index.html" ]]; then
    echo "⛔ Built web output is missing ${prerendered_route}/index.html prerender." >&2
    exit 1
  fi
done

if grep -q '__DINEIN_GUEST_ORIGIN__' "${build_output}/index.html" "${build_output}/robots.txt" "${build_output}/sitemap.xml"; then
  echo "⛔ Built crawlability files still contain unresolved guest-origin placeholders." >&2
  exit 1
fi

# ── Service worker hygiene ──────────────────────────────────────────────────
if [[ ! -f "${build_output}/custom_sw.js" ]]; then
  echo "⛔ custom_sw.js is missing from build output." >&2
  exit 1
fi

if [[ ! -f "${build_output}/_worker.js" ]]; then
  echo "⛔ _worker.js is missing from build output." >&2
  exit 1
fi

if [[ ! -f "${build_output}/firebase-messaging-sw.js" ]]; then
  echo "⛔ firebase-messaging-sw.js is missing from build output." >&2
  exit 1
fi

if [[ ! -f "${build_output}/pwa-shell-manifest.json" ]]; then
  echo "⛔ pwa-shell-manifest.json is missing from build output." >&2
  exit 1
fi

for screenshot in discover-mobile.png venues-desktop.png; do
  if [[ ! -f "${build_output}/screenshots/${screenshot}" ]]; then
    echo "⛔ Build output is missing manifest screenshot screenshots/${screenshot}." >&2
    exit 1
  fi
done

if [[ ! -d "${build_output}/canvaskit" ]]; then
  echo "⛔ canvaskit/ is missing from build output. Web engine assets must be self-hosted." >&2
  exit 1
fi

if [[ -f "${build_output}/flutter_service_worker.js" ]]; then
  echo "⛔ flutter_service_worker.js should not be shipped when using the custom PWA worker." >&2
  exit 1
fi

if ! grep -q 'custom_sw.js' "${build_output}/index.html"; then
  echo "⛔ index.html is not registering custom_sw.js." >&2
  exit 1
fi

if ! grep -q 'main.dart.js?v=' "${build_output}/flutter_bootstrap.js"; then
  echo "⛔ flutter_bootstrap.js is not requesting a versioned main.dart.js entrypoint." >&2
  exit 1
fi

if [[ -f "${build_output}/main.dart.wasm" ]] && ! grep -q 'main.dart.wasm?v=' "${build_output}/flutter_bootstrap.js"; then
  echo "⛔ flutter_bootstrap.js is not requesting a versioned main.dart.wasm entrypoint." >&2
  exit 1
fi

if [[ -f "${build_output}/main.dart.mjs" ]] && ! grep -q 'main.dart.mjs?v=' "${build_output}/flutter_bootstrap.js"; then
  echo "⛔ flutter_bootstrap.js is not requesting a versioned main.dart.mjs support runtime." >&2
  exit 1
fi

service_worker_registrations=$(grep -o 'serviceWorker\.register' "${build_output}/index.html" | wc -l | tr -d ' ')
if [[ "${service_worker_registrations}" != "1" ]]; then
  echo "⛔ Expected exactly one manual service worker registration in index.html, found ${service_worker_registrations}." >&2
  exit 1
fi

for prerendered_route in discover venues; do
  route_file="${build_output}/${prerendered_route}/index.html"
  if ! grep -q 'hreflang="en-MT"' "${route_file}" || ! grep -q 'hreflang="en-RW"' "${route_file}"; then
    echo "⛔ ${prerendered_route}/index.html is missing hreflang alternates." >&2
    exit 1
  fi
  if grep -q '__DINEIN_PWA_' "${route_file}"; then
    echo "⛔ ${prerendered_route}/index.html still contains unresolved PWA placeholders." >&2
    exit 1
  fi
  if ! grep -q 'custom_sw.js?v=' "${route_file}"; then
    echo "⛔ ${prerendered_route}/index.html is missing the versioned custom service worker registration." >&2
    exit 1
  fi
done

if grep -q '__DINEIN_PWA_' "${build_output}/custom_sw.js"; then
  echo "⛔ custom_sw.js still contains unresolved PWA placeholders." >&2
  exit 1
fi

python3 - "${build_output}" <<'PY'
import gzip
import json
import sys
from pathlib import Path

build_dir = Path(sys.argv[1])
MAIN_JS_GZIP_BUDGET = 1_100_000
MAIN_WASM_GZIP_BUDGET = 1_900_000
MAIN_MJS_GZIP_BUDGET = 60_000
# Keep this slightly above the current paired-country production bundle size so
# routine content additions do not fail deploys on a ~2% overage.
DEFERRED_JS_BUDGET = 3_200_000
main_js = build_dir / "main.dart.js"
if not main_js.is_file():
    print("⛔ main.dart.js is missing from build output.", file=sys.stderr)
    raise SystemExit(1)

main_gzip_size = len(gzip.compress(main_js.read_bytes(), compresslevel=9))
if main_gzip_size > MAIN_JS_GZIP_BUDGET:
    print(
        f"⛔ main.dart.js exceeds the gzip budget: {main_gzip_size} bytes.",
        file=sys.stderr,
    )
    raise SystemExit(1)

main_wasm = build_dir / "main.dart.wasm"
if main_wasm.is_file():
    main_wasm_gzip_size = len(gzip.compress(main_wasm.read_bytes(), compresslevel=9))
    if main_wasm_gzip_size > MAIN_WASM_GZIP_BUDGET:
        print(
            f"⛔ main.dart.wasm exceeds the gzip budget: {main_wasm_gzip_size} bytes.",
            file=sys.stderr,
        )
        raise SystemExit(1)

main_mjs = build_dir / "main.dart.mjs"
if main_mjs.is_file():
    main_mjs_gzip_size = len(gzip.compress(main_mjs.read_bytes(), compresslevel=9))
    if main_mjs_gzip_size > MAIN_MJS_GZIP_BUDGET:
        print(
            f"⛔ main.dart.mjs exceeds the gzip budget: {main_mjs_gzip_size} bytes.",
            file=sys.stderr,
        )
        raise SystemExit(1)

deferred_total = sum(path.stat().st_size for path in build_dir.glob("main.dart.js_*.part.js"))
if deferred_total > DEFERRED_JS_BUDGET:
    print(
        f"⛔ Deferred JavaScript parts exceed the budget: {deferred_total} bytes.",
        file=sys.stderr,
    )
    raise SystemExit(1)

manifest_path = build_dir / "pwa-shell-manifest.json"
manifest = json.loads(manifest_path.read_text())
if "/index.html" not in manifest["resources"] or "/offline.html" not in manifest["resources"]:
    print("⛔ PWA shell manifest is missing the HTML fallback assets.", file=sys.stderr)
    raise SystemExit(1)

web_manifest = json.loads((build_dir / "manifest.json").read_text(encoding="utf-8"))
screenshots = web_manifest.get("screenshots") or []
if len(screenshots) < 2:
    print("⛔ manifest.json is missing install screenshots.", file=sys.stderr)
    raise SystemExit(1)

bootstrap_text = (build_dir / "flutter_bootstrap.js").read_text(encoding="utf-8")
needle = "_flutter.loader.load({"
load_idx = bootstrap_text.rfind(needle)
if load_idx == -1:
    print("⛔ flutter_bootstrap.js is missing the final loader invocation.", file=sys.stderr)
    raise SystemExit(1)
load_call = bootstrap_text[load_idx:]
if "serviceWorkerSettings" in load_call:
    print(
        "⛔ flutter_bootstrap.js still enables Flutter's generated service worker.",
        file=sys.stderr,
    )
    raise SystemExit(1)

if '"useLocalCanvasKit":true' not in bootstrap_text and '"useLocalCanvasKit":!0' not in bootstrap_text:
    print(
        "⛔ flutter_bootstrap.js is not configured to self-host CanvasKit resources.",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(
    f"✅ Bundle budgets passed: main.dart.js.gz={main_gzip_size} bytes, deferred_total={deferred_total} bytes."
)
PY

echo "✅ Verified startup loader, headers, manifest, offline fallback, public-route prerenders, install screenshots, and service workers"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Web build complete (${flavor})"
echo "  Output: ${build_output}"
echo ""
echo "  Deploy to Cloudflare Pages:"
case "$flavor" in
  mt)
    echo "    Custom domains: dineinmtg.ikanisa.com"
    echo "                    dineinmtv.ikanisa.com"
    echo "                    dineinmta.ikanisa.com"
    ;;
  rw)
    echo "    Custom domains: dineinrwg.ikanisa.com"
    echo "                    dineinrwv.ikanisa.com"
    echo "                    dineinrwa.ikanisa.com"
    ;;
esac
echo "═══════════════════════════════════════════════════════"

# ── Size report ─────────────────────────────────────────────────────────────
echo ""
echo "Build size:"
du -sh "${build_output}"
echo ""
echo "Key files:"
ls -lh "${build_output}/main.dart.js" 2>/dev/null || echo "  (using wasm build)"
ls -lh "${build_output}/main.dart.wasm" 2>/dev/null || true
ls -lh "${build_output}/main.dart.mjs" 2>/dev/null || true
ls -lh "${build_output}/flutter_bootstrap.js" 2>/dev/null || true
ls -lh "${build_output}/custom_sw.js" 2>/dev/null || true
ls -lh "${build_output}/pwa-shell-manifest.json" 2>/dev/null || true
