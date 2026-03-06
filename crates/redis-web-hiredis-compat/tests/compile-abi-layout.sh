#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CRATE_DIR="$ROOT_DIR/crates/redis-web-hiredis-compat"
DIST_DIR="$ROOT_DIR/target/hiredis-compat-dist"

"$ROOT_DIR/scripts/build-hiredis-compat.sh" "$DIST_DIR"

RPATH_FLAG="-Wl,-rpath,$DIST_DIR/lib"

cc \
  -I"$DIST_DIR/include" \
  "$CRATE_DIR/tests/fixtures/abi_layout.c" \
  -L"$DIST_DIR/lib" \
  "$RPATH_FLAG" \
  -lhiredis \
  -o "$DIST_DIR/abi_layout"

if [[ "$(uname -s)" == "Darwin" ]]; then
  DYLD_LIBRARY_PATH="$DIST_DIR/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$DIST_DIR/abi_layout"
else
  LD_LIBRARY_PATH="$DIST_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$DIST_DIR/abi_layout"
fi

echo "ABI layout fixture passed"
