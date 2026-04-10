#!/usr/bin/env bash
set -euo pipefail

project_ref=""
detect_current_ip=false
dry_run=false
append=false
ipv4_cidrs=()
ipv6_cidrs=()

usage() {
  cat <<'EOF'
Usage: harden_supabase_db_network.sh --project-ref <ref> [options]

Options:
  --project-ref <ref>      Supabase project ref to update.
  --detect-current-ip      Add the current machine public IPv4/IPv6 as /32 and /128 CIDRs.
  --ipv4-cidr <cidr>       Add an explicit IPv4 CIDR. Repeat as needed.
  --ipv6-cidr <cidr>       Add an explicit IPv6 CIDR. Repeat as needed.
  --append                 Append to existing restrictions instead of replacing them.
  --dry-run                Print the resolved CIDRs and CLI command without applying changes.
  -h, --help               Show this help.

Examples:
  ./scripts/harden_supabase_db_network.sh \
    --project-ref uskfnszcdqpcfrhjxitl \
    --detect-current-ip

  ./scripts/harden_supabase_db_network.sh \
    --project-ref uskfnszcdqpcfrhjxitl \
    --ipv4-cidr 203.0.113.10/32 \
    --ipv6-cidr 2001:db8::10/128
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-ref)
      project_ref="${2:-}"
      shift 2
      ;;
    --detect-current-ip)
      detect_current_ip=true
      shift
      ;;
    --ipv4-cidr)
      ipv4_cidrs+=("${2:-}")
      shift 2
      ;;
    --ipv6-cidr)
      ipv6_cidrs+=("${2:-}")
      shift 2
      ;;
    --append)
      append=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$project_ref" ]]; then
  echo "Missing required --project-ref." >&2
  usage >&2
  exit 1
fi

if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI is required but was not found in PATH." >&2
  exit 1
fi

if [[ "$detect_current_ip" == "true" ]]; then
  current_ipv4="$(curl -4 -fsS --max-time 5 https://api.ipify.org || true)"
  current_ipv6="$(curl -6 -fsS --max-time 5 https://api64.ipify.org || true)"

  if [[ -n "$current_ipv4" ]]; then
    ipv4_cidrs+=("${current_ipv4}/32")
  fi
  if [[ -n "$current_ipv6" ]]; then
    ipv6_cidrs+=("${current_ipv6}/128")
  fi
fi

if [[ ${#ipv4_cidrs[@]} -eq 0 && ${#ipv6_cidrs[@]} -eq 0 ]]; then
  echo "No CIDRs resolved. Pass --detect-current-ip and/or explicit --ipv4-cidr/--ipv6-cidr values." >&2
  exit 1
fi

validated_cidrs="$(
  python3 - "${ipv4_cidrs[@]}" -- "${ipv6_cidrs[@]}" <<'PY'
import ipaddress
import sys

args = sys.argv[1:]
separator = args.index("--")
ipv4 = args[:separator]
ipv6 = args[separator + 1:]
validated = []

for raw in ipv4 + ipv6:
    network = ipaddress.ip_network(raw, strict=False)
    validated.append(str(network))

print("\n".join(dict.fromkeys(validated)))
PY
)"
resolved_cidrs=()
while IFS= read -r cidr; do
  [[ -n "$cidr" ]] || continue
  resolved_cidrs+=("$cidr")
done <<<"$validated_cidrs"

if [[ ${#resolved_cidrs[@]} -eq 0 ]]; then
  echo "No valid CIDRs remained after validation." >&2
  exit 1
fi

cmd=(
  supabase
  --experimental
  network-restrictions
  update
  --project-ref "$project_ref"
  --yes
)

if [[ "$append" == "true" ]]; then
  cmd+=(--append)
fi

for cidr in "${resolved_cidrs[@]}"; do
  cmd+=(--db-allow-cidr "$cidr")
done

echo "Resolved DB allowlist for ${project_ref}:"
for cidr in "${resolved_cidrs[@]}"; do
  echo "  - ${cidr}"
done

if [[ "$dry_run" == "true" ]]; then
  echo
  printf 'Dry run command:'
  printf ' %q' "${cmd[@]}"
  echo
  exit 0
fi

"${cmd[@]}"
echo
supabase --experimental network-restrictions get --project-ref "$project_ref"
