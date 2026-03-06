#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

sentinel_py="$tmp_dir/verify-sentinel.py"
cat > "$sentinel_py" <<'PY'
#!/usr/bin/env python3
import sys
print("verify sentinel invoked", file=sys.stderr)
raise SystemExit(42)
PY
chmod +x "$sentinel_py"

echo "[1/2] VERIFY_HIREDIS_ACTIVE=0 should skip runtime verify script"
VERIFY_HIREDIS_ACTIVE=0 \
VERIFY_HIREDIS_SCRIPT="$sentinel_py" \
  "$SCRIPT_DIR/setup-test-env.sh"

echo "[2/2] VERIFY_HIREDIS_ACTIVE=1 should invoke runtime verify script"
set +e
VERIFY_HIREDIS_ACTIVE=1 \
VERIFY_HIREDIS_SCRIPT="$sentinel_py" \
  "$SCRIPT_DIR/setup-test-env.sh"
status=$?
set -e

if [[ $status -ne 42 ]]; then
  echo "expected sentinel verify script to fail with exit 42, got: $status" >&2
  exit 1
fi

echo "setup-test-env verification gating regression check passed"
