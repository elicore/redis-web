#!/usr/bin/env bash
set -euo pipefail

ALLOWLIST_FILE=".github/rename-webdis-allowlist.txt"

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "Missing allowlist: $ALLOWLIST_FILE" >&2
  exit 1
fi

mapfile -t patterns < <(grep -v '^\s*$' "$ALLOWLIST_FILE")
mapfile -t matches < <(rg -n "webdis" --hidden --glob '!.git/*' --glob '!target/*' || true)

violations=()
for match in "${matches[@]}"; do
  file="${match%%:*}"
  allowed=false
  for pattern in "${patterns[@]}"; do
    if [[ "$file" =~ $pattern ]]; then
      allowed=true
      break
    fi
  done

  if [[ "$allowed" == false ]]; then
    violations+=("$match")
  fi
done

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "Found non-allowlisted references to 'webdis':" >&2
  for v in "${violations[@]}"; do
    echo "  $v" >&2
  done
  exit 1
fi

echo "Rename guard passed: all 'webdis' references are allowlisted compatibility usage."
