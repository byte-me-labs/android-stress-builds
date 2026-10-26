#!/usr/bin/env bash
# Resolve the pinned NDK and expose it to later workflow steps.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

resolve_ndk

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    printf 'NDK_HOME=%s\n' "$NDK_HOME"
    printf 'TC=%s\n' "$TC"
    printf 'LLVM_STRIP=%s\n' "$LLVM_STRIP"
    printf 'LLVM_READELF=%s\n' "$LLVM_READELF"
  } >> "$GITHUB_ENV"
fi
