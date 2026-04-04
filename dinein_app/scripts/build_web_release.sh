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
#   MT build → Cloudflare Pages → dineinmtg/dineinmtv/dineinmta.ikanisa.com
#   RW build → Cloudflare Pages → dineinrwg/dineinrwv/dineinrwa.ikanisa.com
# ═══════════════════════════════════════════════════════════════════════════════

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"

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
  mt|rw) ;;
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

# ── Validate env file exists ────────────────────────────────────────────────
if [[ ! -f "${env_file}" ]]; then
  echo "Missing release env file: ${env_file}" >&2
  exit 1
fi

# ── Supabase credential validation (same gate as Android build) ─────────────
supabase_url=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_URL',''))" "${env_file}" 2>/dev/null || true)
supabase_anon_key=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('SUPABASE_ANON_KEY',''))" "${env_file}" 2>/dev/null || true)

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
  --pwa-strategy=none \
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

# _redirects should already be in web/ and copied by flutter build,
# but ensure it's there
if [[ -f "${project_dir}/web/_redirects" ]] && [[ ! -f "${build_output}/_redirects" ]]; then
  cp "${project_dir}/web/_redirects" "${build_output}/_redirects"
  echo "✅ Copied _redirects to build output"
fi

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

# ── Service worker hygiene ──────────────────────────────────────────────────
if [[ ! -f "${build_output}/custom_sw.js" ]]; then
  echo "⛔ custom_sw.js is missing from build output." >&2
  exit 1
fi

if [[ ! -f "${build_output}/pwa-shell-manifest.json" ]]; then
  echo "⛔ pwa-shell-manifest.json is missing from build output." >&2
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

service_worker_registrations=$(grep -o 'serviceWorker\.register' "${build_output}/index.html" | wc -l | tr -d ' ')
if [[ "${service_worker_registrations}" != "1" ]]; then
  echo "⛔ Expected exactly one manual service worker registration in index.html, found ${service_worker_registrations}." >&2
  exit 1
fi

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
main_js = build_dir / "main.dart.js"
if not main_js.is_file():
    print("⛔ main.dart.js is missing from build output.", file=sys.stderr)
    raise SystemExit(1)

main_gzip_size = len(gzip.compress(main_js.read_bytes(), compresslevel=9))
if main_gzip_size > 1_100_000:
    print(
        f"⛔ main.dart.js exceeds the gzip budget: {main_gzip_size} bytes.",
        file=sys.stderr,
    )
    raise SystemExit(1)

deferred_total = sum(path.stat().st_size for path in build_dir.glob("main.dart.js_*.part.js"))
if deferred_total > 1_250_000:
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

print(
    f"✅ Bundle budgets passed: main.dart.js.gz={main_gzip_size} bytes, deferred_total={deferred_total} bytes."
)
PY

echo "✅ Verified startup loader, headers, manifest, offline fallback, precache manifest, and single custom service worker"

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
ls -lh "${build_output}/flutter_bootstrap.js" 2>/dev/null || true
ls -lh "${build_output}/custom_sw.js" 2>/dev/null || true
ls -lh "${build_output}/pwa-shell-manifest.json" 2>/dev/null || true
