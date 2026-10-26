#!/usr/bin/env bash
# Assert that a built binary is a fully static, 16 KB-aligned ET_EXEC for its ABI.
# Usage: verify-static.sh <binary> <abi>
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

binary="${1:?usage: verify-static.sh <binary> <abi>}"
abi="${2:?usage: verify-static.sh <binary> <abi>}"

resolve_ndk
[[ -s "$binary" ]] || die "missing or empty binary: ${binary}"

file_output="$(file -b "$binary")"
log "file: ${file_output}"
grep -q 'statically linked' <<< "$file_output" || die "not statically linked: ${file_output}"
if grep -q 'dynamically linked' <<< "$file_output"; then
  die "dynamically linked: ${file_output}"
fi

case "$abi" in
  arm64-v8a)
    grep -q 'ARM aarch64' <<< "$file_output" || die "expected arm64, got: ${file_output}"
    ;;
  armeabi-v7a)
    grep -q 'aarch64' <<< "$file_output" && die "expected armv7, got: ${file_output}"
    grep -qE 'ARM,|ARM ' <<< "$file_output" || die "expected armv7, got: ${file_output}"
    ;;
  x86_64)
    grep -q 'x86-64' <<< "$file_output" || die "expected x86_64, got: ${file_output}"
    ;;
  *)
    die "unsupported ABI: ${abi}"
    ;;
esac

header="$("$LLVM_READELF" -h "$binary")"
grep -qE 'Type:[[:space:]]+EXEC([[:space:]]|$)' <<< "$header" ||
  die "expected ET_EXEC (static binaries are not PIE): ${header}"

if "$LLVM_READELF" -l "$binary" | grep -q 'INTERP'; then
  die "binary has PT_INTERP; a static binary must not have one"
fi

if "$LLVM_READELF" -d "$binary" 2>/dev/null | grep -q '(NEEDED)'; then
  die "binary has DT_NEEDED entries; it is not fully static"
fi

aligns="$("$LLVM_READELF" -lW "$binary" | awk '/^[[:space:]]*LOAD[[:space:]]/ {print $NF}')"
[[ -n "$aligns" ]] || die "no LOAD segments found"

while IFS= read -r align; do
  [[ "$align" =~ ^0x[0-9a-fA-F]+$ ]] || die "cannot parse LOAD alignment: ${align}"
  (( align >= 16384 )) || die "LOAD segment alignment ${align} is below 16 KB"
done <<< "$aligns"

log "verified ${binary}: static ET_EXEC, no PT_INTERP/DT_NEEDED, LOAD align >= 0x4000"
