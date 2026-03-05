#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

ensure_submodules_present
ensure_dist_dirs

"$SCRIPT_DIR/build-compat-artifacts.sh"

work_hiredis_py="$(reset_hiredis_workdir)"
apply_hiredis_patch "$work_hiredis_py"

PYTHON="$(venv_python)"
"$PYTHON" -m pip install --upgrade pip setuptools wheel build

set_hiredis_build_env

(
  cd "$work_hiredis_py"
  "$PYTHON" setup.py build_ext --inplace
)

EXT_PATH="$(find "$work_hiredis_py/hiredis" -maxdepth 1 -type f \( -name '*.so' -o -name '*.dylib' \) | head -n 1)"
if [[ -z "$EXT_PATH" ]]; then
  echo "failed to locate built hiredis extension artifact" >&2
  exit 1
fi

LIBHIREDIS_PATH=""
if [[ -f "$DIST_HIREDIS_DIR/lib/libhiredis.dylib" ]]; then
  LIBHIREDIS_PATH="$DIST_HIREDIS_DIR/lib/libhiredis.dylib"
elif [[ -f "$DIST_HIREDIS_DIR/lib/libhiredis.so" ]]; then
  LIBHIREDIS_PATH="$DIST_HIREDIS_DIR/lib/libhiredis.so"
else
  echo "failed to locate compat libhiredis shared library in $DIST_HIREDIS_DIR/lib" >&2
  exit 1
fi

REQUIRED_SYMS_FILE="$ARTIFACTS_DIR/hiredis-required-symbols.txt"
PROVIDED_SYMS_FILE="$ARTIFACTS_DIR/hiredis-provided-symbols.txt"
MISSING_SYMS_FILE="$ARTIFACTS_DIR/hiredis-missing-symbols.txt"
REPORT_FILE="$ARTIFACTS_DIR/symbol-audit.txt"
UPSTREAM_PROVIDED_SYMS_FILE="$ARTIFACTS_DIR/hiredis-upstream-provided-symbols.txt"
UPSTREAM_MISSING_SYMS_FILE="$ARTIFACTS_DIR/hiredis-missing-vs-upstream-symbols.txt"
UPSTREAM_HEADER_API_FILE="$ARTIFACTS_DIR/hiredis-upstream-header-api.txt"
COMPAT_HEADER_API_FILE="$ARTIFACTS_DIR/hiredis-compat-header-api.txt"
HEADER_MISSING_API_FILE="$ARTIFACTS_DIR/hiredis-missing-header-api.txt"
STRICT_UPSTREAM_PARITY="${STRICT_UPSTREAM_PARITY:-0}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  nm -gU "$EXT_PATH" | awk '/ U /{print $2}' | sed 's/^_//' | sort -u > "$REQUIRED_SYMS_FILE"
  nm -gU "$LIBHIREDIS_PATH" | awk '{print $3}' | sed 's/^_//' | sed '/^$/d' | sort -u > "$PROVIDED_SYMS_FILE"
else
  nm -D --undefined-only "$EXT_PATH" | awk '{print $2}' | sed 's/^_//' | sort -u > "$REQUIRED_SYMS_FILE"
  nm -D --defined-only "$LIBHIREDIS_PATH" | awk '{print $3}' | sed 's/^_//' | sed '/^$/d' | sort -u > "$PROVIDED_SYMS_FILE"
fi

grep -E '^(redis|sds|hi_|hiredis)' "$REQUIRED_SYMS_FILE" > "$REQUIRED_SYMS_FILE.filtered" || true
mv "$REQUIRED_SYMS_FILE.filtered" "$REQUIRED_SYMS_FILE"

comm -23 "$REQUIRED_SYMS_FILE" "$PROVIDED_SYMS_FILE" > "$MISSING_SYMS_FILE"

upstream_hiredis_src="$HIREDIS_PY_DIR/vendor/hiredis"
upstream_hiredis_build="$WORK_DIR/upstream-hiredis"
rm -rf "$upstream_hiredis_build"
cp -R "$upstream_hiredis_src" "$upstream_hiredis_build"

(
  cd "$upstream_hiredis_build"
  make clean >/dev/null 2>&1 || true
  make >/dev/null
)

UPSTREAM_LIBHIREDIS_PATH=""
if [[ -f "$upstream_hiredis_build/libhiredis.dylib" ]]; then
  UPSTREAM_LIBHIREDIS_PATH="$upstream_hiredis_build/libhiredis.dylib"
elif [[ -f "$upstream_hiredis_build/libhiredis.so" ]]; then
  UPSTREAM_LIBHIREDIS_PATH="$upstream_hiredis_build/libhiredis.so"
else
  echo "failed to locate upstream libhiredis shared library in $upstream_hiredis_build" >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  nm -gU "$UPSTREAM_LIBHIREDIS_PATH" | awk '{print $3}' | sed 's/^_//' | sed '/^$/d' | sort -u > "$UPSTREAM_PROVIDED_SYMS_FILE"
else
  nm -D --defined-only "$UPSTREAM_LIBHIREDIS_PATH" | awk '{print $3}' | sed 's/^_//' | sed '/^$/d' | sort -u > "$UPSTREAM_PROVIDED_SYMS_FILE"
fi

grep -E '^(redis|sds|hi_|hiredis)' "$UPSTREAM_PROVIDED_SYMS_FILE" > "$UPSTREAM_PROVIDED_SYMS_FILE.filtered" || true
mv "$UPSTREAM_PROVIDED_SYMS_FILE.filtered" "$UPSTREAM_PROVIDED_SYMS_FILE"

comm -23 "$UPSTREAM_PROVIDED_SYMS_FILE" "$PROVIDED_SYMS_FILE" > "$UPSTREAM_MISSING_SYMS_FILE"

extract_header_api() {
  local out_file="$1"
  shift
  perl -0777 -ne '
    s{/\*.*?\*/}{}gs;
    s{//.*$}{}mg;
    while (/\b((?:redis|sds|hi_|hiredis)[A-Za-z0-9_]*)\s*\(/g) {
      print "$1\n";
    }
  ' "$@" | sort -u > "$out_file"
}

upstream_headers=(
  "$upstream_hiredis_src/alloc.h"
  "$upstream_hiredis_src/hiredis.h"
  "$upstream_hiredis_src/read.h"
  "$upstream_hiredis_src/sds.h"
)
compat_headers=(
  "$REPO_ROOT/crates/redis-web-hiredis-compat/include/hiredis/alloc.h"
  "$REPO_ROOT/crates/redis-web-hiredis-compat/include/hiredis/hiredis.h"
  "$REPO_ROOT/crates/redis-web-hiredis-compat/include/hiredis/read.h"
  "$REPO_ROOT/crates/redis-web-hiredis-compat/include/hiredis/sds.h"
)

extract_header_api "$UPSTREAM_HEADER_API_FILE" "${upstream_headers[@]}"
extract_header_api "$COMPAT_HEADER_API_FILE" "${compat_headers[@]}"
comm -23 "$UPSTREAM_HEADER_API_FILE" "$COMPAT_HEADER_API_FILE" > "$HEADER_MISSING_API_FILE"

{
  echo "compat library: $LIBHIREDIS_PATH"
  echo "upstream library: $UPSTREAM_LIBHIREDIS_PATH"
  echo "extension: $EXT_PATH"
  echo "required symbols file: $REQUIRED_SYMS_FILE"
  echo "provided symbols file: $PROVIDED_SYMS_FILE"
  echo "missing symbols file: $MISSING_SYMS_FILE"
  echo "upstream provided symbols file: $UPSTREAM_PROVIDED_SYMS_FILE"
  echo "missing upstream symbols file: $UPSTREAM_MISSING_SYMS_FILE"
  echo "upstream header api file: $UPSTREAM_HEADER_API_FILE"
  echo "compat header api file: $COMPAT_HEADER_API_FILE"
  echo "missing header api file: $HEADER_MISSING_API_FILE"
} > "$REPORT_FILE"

if [[ -s "$MISSING_SYMS_FILE" ]]; then
  cat "$REPORT_FILE"
  echo
  echo "Missing compat symbols:"
  cat "$MISSING_SYMS_FILE"
  exit 1
fi

echo "Symbol audit passed"
cat "$REPORT_FILE"

echo
echo "Upstream parity summary (informational):"
echo "- missing upstream-exported symbols in compat: $(wc -l < "$UPSTREAM_MISSING_SYMS_FILE" | tr -d ' ')"
echo "- missing upstream header API names in compat headers: $(wc -l < "$HEADER_MISSING_API_FILE" | tr -d ' ')"

if [[ "$STRICT_UPSTREAM_PARITY" == "1" ]]; then
  if [[ -s "$UPSTREAM_MISSING_SYMS_FILE" || -s "$HEADER_MISSING_API_FILE" ]]; then
    echo
    echo "STRICT_UPSTREAM_PARITY=1 and upstream parity gaps were found." >&2
    if [[ -s "$UPSTREAM_MISSING_SYMS_FILE" ]]; then
      echo "Missing upstream-exported symbols:" >&2
      cat "$UPSTREAM_MISSING_SYMS_FILE" >&2
    fi
    if [[ -s "$HEADER_MISSING_API_FILE" ]]; then
      echo "Missing upstream header API names:" >&2
      cat "$HEADER_MISSING_API_FILE" >&2
    fi
    exit 1
  fi
fi
