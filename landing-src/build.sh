#!/usr/bin/env bash
#
# build.sh — Generate landing/ and landing-rw/ from templates + config.
#
# Usage:  ./build.sh               (builds both countries)
#         ./build.sh mt            (builds Malta only)
#         ./build.sh rw            (builds Rwanda only)
#
# This script replaces {{VAR}} placeholders in templates with values
# from config/*.json, copies shared assets, and applies per-country
# overrides (privacy.html, .well-known/).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

TEMPLATES_DIR="$SCRIPT_DIR/templates"
SHARED_DIR="$SCRIPT_DIR/shared"
CONFIG_DIR="$SCRIPT_DIR/config"
OVERRIDES_DIR="$SCRIPT_DIR/overrides"

# ─── Helpers ───

substitute_template() {
  local template_file="$1"
  local config_file="$2"
  local output_file="$3"
  
  local content
  content="$(cat "$template_file")"
  
  # Read each key-value from JSON config and substitute {{KEY}} → VALUE
  while IFS='=' read -r key value; do
    # Strip quotes from value
    value="${value%\"}"
    value="${value#\"}"
    content="${content//\{\{$key\}\}/$value}"
  done < <(python3 -c "
import json, sys
with open('$config_file') as f:
    config = json.load(f)
for k, v in config.items():
    print(f'{k}={v}')
")
  
  echo "$content" > "$output_file"
}

build_country() {
  local country_code="$1"
  local config_file="$CONFIG_DIR/${country_code}.json"
  
  if [[ ! -f "$config_file" ]]; then
    echo "❌ Config not found: $config_file"
    exit 1
  fi
  
  # Read OUTPUT_DIR from config
  local output_dir
  output_dir="$(python3 -c "import json; print(json.load(open('$config_file'))['OUTPUT_DIR'])")"
  local target_dir="$ROOT_DIR/$output_dir"
  
  local country_name
  country_name="$(python3 -c "import json; print(json.load(open('$config_file'))['COUNTRY'])")"
  
  echo "🏗️  Building $country_name → $output_dir/"
  
  # 1) Ensure output directory exists
  mkdir -p "$target_dir/download" "$target_dir/.well-known"
  
  # 2) Copy shared assets
  cp "$SHARED_DIR/index.css" "$target_dir/index.css"
  cp "$SHARED_DIR/logo.png" "$target_dir/logo.png"
  cp "$SHARED_DIR/app-mockup.png" "$target_dir/app-mockup.png"
  
  # 3) Process templates
  for tmpl in "$TEMPLATES_DIR"/*.tmpl; do
    local basename
    basename="$(basename "$tmpl" .tmpl)"
    substitute_template "$tmpl" "$config_file" "$target_dir/$basename"
  done
  
  # Process download/ templates
  if [[ -d "$TEMPLATES_DIR/download" ]]; then
    for tmpl in "$TEMPLATES_DIR/download"/*.tmpl; do
      local basename
      basename="$(basename "$tmpl" .tmpl)"
      substitute_template "$tmpl" "$config_file" "$target_dir/download/$basename"
    done
  fi
  
  # 4) Copy per-country overrides (privacy.html, .well-known/*)
  local override_dir="$OVERRIDES_DIR/$country_code"
  if [[ -d "$override_dir" ]]; then
    # Copy all override files, preserving directory structure
    find "$override_dir" -type f | while read -r override_file; do
      local rel_path="${override_file#$override_dir/}"
      local dest="$target_dir/$rel_path"
      mkdir -p "$(dirname "$dest")"
      cp "$override_file" "$dest"
    done
  fi
  
  echo "   ✅ $country_name done ($(find "$target_dir" -type f | wc -l | tr -d ' ') files)"
}

# ─── Main ───

if [[ $# -eq 0 ]]; then
  # Build all countries
  for config in "$CONFIG_DIR"/*.json; do
    code="$(basename "$config" .json)"
    build_country "$code"
  done
else
  for code in "$@"; do
    build_country "$code"
  done
fi

echo ""
echo "🎉 Landing page build complete."
