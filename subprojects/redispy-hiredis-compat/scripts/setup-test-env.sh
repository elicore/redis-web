#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_submodules_present
ensure_dist_dirs

"$SCRIPT_DIR/build-hiredis-wheel.sh"

PYTHON="$(venv_python)"
"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install -r "$REDIS_PY_DIR/dev_requirements.txt"

WHEEL_PATH="$(latest_hiredis_wheel)"
if [[ -z "$WHEEL_PATH" ]]; then
  echo "no hiredis wheel found in $WHEELS_DIR" >&2
  exit 1
fi

"$PYTHON" -m pip install --force-reinstall "$WHEEL_PATH"
"$PYTHON" -m pip install -e "$REDIS_PY_DIR"

set_hiredis_build_env

VERIFY_HIREDIS_ACTIVE="${VERIFY_HIREDIS_ACTIVE:-0}"
if [[ "$VERIFY_HIREDIS_ACTIVE" == "1" ]]; then
  VERIFY_HIREDIS_HOST="${VERIFY_HIREDIS_HOST:-127.0.0.1}"
  VERIFY_HIREDIS_PORT="${VERIFY_HIREDIS_PORT:-6379}"
  VERIFY_HIREDIS_DB="${VERIFY_HIREDIS_DB:-0}"
  VERIFY_HIREDIS_SCRIPT="${VERIFY_HIREDIS_SCRIPT:-$SCRIPT_DIR/verify-hiredis-active.py}"
  "$PYTHON" "$VERIFY_HIREDIS_SCRIPT" \
    --host "$VERIFY_HIREDIS_HOST" \
    --port "$VERIFY_HIREDIS_PORT" \
    --db "$VERIFY_HIREDIS_DB"
fi

echo "Test environment ready: $VENV_DIR"
