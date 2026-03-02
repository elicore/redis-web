#!/usr/bin/env bash
set -euo pipefail

echo "[deprecated] scripts/start-webdis.sh is deprecated; forwarding to scripts/start-redis-web.sh" >&2
exec "$(dirname "$0")/start-redis-web.sh" "$@"
