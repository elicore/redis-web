#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="$ROOT_DIR/crates/redis-web-hiredis-compat"
OUT_DIR="${1:-$ROOT_DIR/target/hiredis-compat-dist}"
UPSTREAM_DIR="$ROOT_DIR/subprojects/redispy-hiredis-compat/vendor/hiredis-py/vendor/hiredis"
BUILD_DIR="$OUT_DIR/.build"
CC_BIN="${CC:-cc}"
HIREDIS_COMPAT_ENABLE_SSL="${HIREDIS_COMPAT_ENABLE_SSL:-1}"

mkdir -p "$OUT_DIR/lib" "$OUT_DIR/include/hiredis" "$OUT_DIR/include/hiredis/adapters" "$OUT_DIR/pkgconfig" "$BUILD_DIR"

cargo build -p redis-web-hiredis-compat --release

if [[ ! -d "$UPSTREAM_DIR" ]]; then
  echo "missing upstream hiredis sources: $UPSTREAM_DIR" >&2
  echo "run: make compat_redispy_bootstrap" >&2
  exit 1
fi

HIREDIS_MAJOR="$(awk '/^#define HIREDIS_MAJOR/{print $3}' "$UPSTREAM_DIR/hiredis.h")"
HIREDIS_SONAME="$(awk '/^#define HIREDIS_SONAME/{print $3}' "$UPSTREAM_DIR/hiredis.h")"
if [[ -z "$HIREDIS_MAJOR" || -z "$HIREDIS_SONAME" ]]; then
  echo "failed to parse hiredis version macros from $UPSTREAM_DIR/hiredis.h" >&2
  exit 1
fi

# Stage upstream-compatible headers.
for hdr in alloc.h async.h hiredis.h net.h read.h sds.h sockcompat.h; do
  cp "$UPSTREAM_DIR/$hdr" "$OUT_DIR/include/hiredis/$hdr"
done
cp -R "$UPSTREAM_DIR/adapters/." "$OUT_DIR/include/hiredis/adapters/"

cp "$CRATE_DIR/pkgconfig/hiredis.pc" "$OUT_DIR/pkgconfig/hiredis.pc"
cp "$CRATE_DIR/pkgconfig/redisweb-hiredis.pc" "$OUT_DIR/pkgconfig/redisweb-hiredis.pc"

OPENSSL_CFLAGS=""
OPENSSL_LIBS=""
resolve_openssl() {
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists openssl; then
    OPENSSL_CFLAGS="$(pkg-config --cflags openssl)"
    OPENSSL_LIBS="$(pkg-config --libs openssl)"
    return 0
  fi

  local include_dir="${OPENSSL_INCLUDE_DIR:-}"
  local lib_dir="${OPENSSL_LIB_DIR:-}"

  if [[ -n "${OPENSSL_DIR:-}" ]]; then
    include_dir="${include_dir:-$OPENSSL_DIR/include}"
    lib_dir="${lib_dir:-$OPENSSL_DIR/lib}"
  fi

  if [[ -z "$include_dir" || -z "$lib_dir" ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
      for prefix in \
        /opt/homebrew/opt/openssl@3 \
        /opt/homebrew/opt/openssl \
        /usr/local/opt/openssl@3 \
        /usr/local/opt/openssl; do
        if [[ -d "$prefix/include" && -d "$prefix/lib" ]]; then
          include_dir="$prefix/include"
          lib_dir="$prefix/lib"
          break
        fi
      done
    fi
  fi

  if [[ -n "$include_dir" && -n "$lib_dir" ]]; then
    OPENSSL_CFLAGS="-I$include_dir"
    OPENSSL_LIBS="-L$lib_dir -lssl -lcrypto"
    return 0
  fi

  return 1
}

core_sources=(
  alloc.c
  dict.c
  hiredis.c
  net.c
  read.c
  sds.c
  sockcompat.c
  async.c
)
core_objects=()
for src in "${core_sources[@]}"; do
  obj="$BUILD_DIR/${src%.c}.o"
  "$CC_BIN" -O2 -fPIC -I"$UPSTREAM_DIR" -c "$UPSTREAM_DIR/$src" -o "$obj"
  core_objects+=("$obj")
done

ar rcs "$OUT_DIR/lib/libhiredis.a" "${core_objects[@]}"
cp "$OUT_DIR/lib/libhiredis.a" "$OUT_DIR/lib/libredisweb_hiredis.a"

if [[ "$OSTYPE" == darwin* ]]; then
  core_shared="$OUT_DIR/lib/libhiredis.${HIREDIS_SONAME}.dylib"
  "$CC_BIN" -dynamiclib \
    -Wl,-install_name,libhiredis.${HIREDIS_SONAME}.dylib \
    -o "$core_shared" "${core_objects[@]}"
  ln -sf "libhiredis.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libhiredis.${HIREDIS_MAJOR}.dylib"
  ln -sf "libhiredis.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libhiredis.dylib"

  cp "$core_shared" "$OUT_DIR/lib/libredisweb_hiredis.${HIREDIS_SONAME}.dylib"
  ln -sf "libredisweb_hiredis.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libredisweb_hiredis.${HIREDIS_MAJOR}.dylib"
  ln -sf "libredisweb_hiredis.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libredisweb_hiredis.dylib"
else
  core_shared="$OUT_DIR/lib/libhiredis.so.${HIREDIS_SONAME}"
  "$CC_BIN" -shared \
    -Wl,-soname,libhiredis.so.${HIREDIS_MAJOR} \
    -o "$core_shared" "${core_objects[@]}"
  ln -sf "libhiredis.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libhiredis.so.${HIREDIS_MAJOR}"
  ln -sf "libhiredis.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libhiredis.so"

  cp "$core_shared" "$OUT_DIR/lib/libredisweb_hiredis.so.${HIREDIS_SONAME}"
  ln -sf "libredisweb_hiredis.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libredisweb_hiredis.so.${HIREDIS_MAJOR}"
  ln -sf "libredisweb_hiredis.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libredisweb_hiredis.so"
fi

if [[ "$HIREDIS_COMPAT_ENABLE_SSL" == "1" ]]; then
  if ! resolve_openssl; then
    echo "SSL parity requested but OpenSSL was not found (set OPENSSL_DIR or OPENSSL_{INCLUDE,LIB}_DIR)." >&2
    exit 1
  fi

  cp "$UPSTREAM_DIR/hiredis_ssl.h" "$OUT_DIR/include/hiredis/hiredis_ssl.h"
  cp "$CRATE_DIR/pkgconfig/hiredis_ssl.pc" "$OUT_DIR/pkgconfig/hiredis_ssl.pc"
  cp "$CRATE_DIR/pkgconfig/redisweb-hiredis-ssl.pc" "$OUT_DIR/pkgconfig/redisweb-hiredis-ssl.pc"

  ssl_obj="$BUILD_DIR/ssl.o"
  "$CC_BIN" -O2 -fPIC -I"$UPSTREAM_DIR" $OPENSSL_CFLAGS -c "$UPSTREAM_DIR/ssl.c" -o "$ssl_obj"

  ar rcs "$OUT_DIR/lib/libhiredis_ssl.a" "$ssl_obj"
  cp "$OUT_DIR/lib/libhiredis_ssl.a" "$OUT_DIR/lib/libredisweb_hiredis_ssl.a"

  if [[ "$OSTYPE" == darwin* ]]; then
    ssl_shared="$OUT_DIR/lib/libhiredis_ssl.${HIREDIS_SONAME}.dylib"
    "$CC_BIN" -dynamiclib \
      -Wl,-install_name,libhiredis_ssl.${HIREDIS_SONAME}.dylib \
      -L"$OUT_DIR/lib" -lhiredis \
      -o "$ssl_shared" "$ssl_obj" $OPENSSL_LIBS
    ln -sf "libhiredis_ssl.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libhiredis_ssl.${HIREDIS_MAJOR}.dylib"
    ln -sf "libhiredis_ssl.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libhiredis_ssl.dylib"

    cp "$ssl_shared" "$OUT_DIR/lib/libredisweb_hiredis_ssl.${HIREDIS_SONAME}.dylib"
    ln -sf "libredisweb_hiredis_ssl.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libredisweb_hiredis_ssl.${HIREDIS_MAJOR}.dylib"
    ln -sf "libredisweb_hiredis_ssl.${HIREDIS_SONAME}.dylib" "$OUT_DIR/lib/libredisweb_hiredis_ssl.dylib"
  else
    ssl_shared="$OUT_DIR/lib/libhiredis_ssl.so.${HIREDIS_SONAME}"
    "$CC_BIN" -shared \
      -Wl,-soname,libhiredis_ssl.so.${HIREDIS_MAJOR} \
      -L"$OUT_DIR/lib" -lhiredis \
      -o "$ssl_shared" "$ssl_obj" $OPENSSL_LIBS
    ln -sf "libhiredis_ssl.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libhiredis_ssl.so.${HIREDIS_MAJOR}"
    ln -sf "libhiredis_ssl.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libhiredis_ssl.so"

    cp "$ssl_shared" "$OUT_DIR/lib/libredisweb_hiredis_ssl.so.${HIREDIS_SONAME}"
    ln -sf "libredisweb_hiredis_ssl.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libredisweb_hiredis_ssl.so.${HIREDIS_MAJOR}"
    ln -sf "libredisweb_hiredis_ssl.so.${HIREDIS_SONAME}" "$OUT_DIR/lib/libredisweb_hiredis_ssl.so"
  fi
fi

echo "Built hiredis compatibility artifacts in: $OUT_DIR"
