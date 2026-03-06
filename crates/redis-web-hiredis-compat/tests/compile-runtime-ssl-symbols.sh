#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT_DIR="$ROOT_DIR/target/hiredis-compat-dist"
FIXTURE_C="$ROOT_DIR/crates/redis-web-hiredis-compat/tests/fixtures/runtime_ssl_symbols.c"
BIN_OUT="$OUT_DIR/runtime-ssl-symbols-fixture"

"$ROOT_DIR/scripts/build-hiredis-compat.sh" "$OUT_DIR"

if [[ ! -f "$OUT_DIR/lib/libhiredis_ssl.dylib" && ! -f "$OUT_DIR/lib/libhiredis_ssl.so" ]]; then
  echo "SSL compat library not found under $OUT_DIR/lib" >&2
  exit 1
fi

export PKG_CONFIG_PATH="$OUT_DIR/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
CFLAGS="-I$OUT_DIR/include/hiredis -I$OUT_DIR/include"
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists openssl; then
  OPENSSL_LIBS="$(pkg-config --libs openssl)"
else
  OPENSSL_LIBS="-lssl -lcrypto"
fi
LIBS="-lhiredis_ssl -lhiredis $OPENSSL_LIBS"
RPATH_FLAG="-Wl,-rpath,$OUT_DIR/lib"

cc -O2 -Wall -Wextra $CFLAGS "$FIXTURE_C" -o "$BIN_OUT" -L"$OUT_DIR/lib" "$RPATH_FLAG" $LIBS

if [[ "$(uname -s)" == "Darwin" ]]; then
  DYLD_LIBRARY_PATH="$OUT_DIR/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" "$BIN_OUT"
else
  LD_LIBRARY_PATH="$OUT_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$BIN_OUT"
fi
