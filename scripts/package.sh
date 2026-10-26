#!/usr/bin/env bash
# Stage one binary as <tool>-<version>-android-<abi> plus its .sha256.
# Usage: package.sh <tool> <version> <abi> <binary> <outdir>
# The executable is published as-is; no archive is created.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

tool="${1:?usage: package.sh <tool> <version> <abi> <binary> <outdir>}"
version="${2:?usage: package.sh <tool> <version> <abi> <binary> <outdir>}"
abi="${3:?usage: package.sh <tool> <version> <abi> <binary> <outdir>}"
binary="${4:?usage: package.sh <tool> <version> <abi> <binary> <outdir>}"
outdir="${5:?usage: package.sh <tool> <version> <abi> <binary> <outdir>}"

[[ -f "$binary" ]] || die "missing binary: ${binary}"
[[ "$version" =~ ^[0-9A-Za-z._-]+$ ]] || die "unsafe version: ${version}"

mkdir -p "$outdir"
name="${tool}-${version}-android-${abi}"
install -m 0755 "$binary" "${outdir}/${name}"

(
  cd "$outdir"
  sha256sum "$name" > "${name}.sha256"
)

log "staged ${outdir}/${name} ($(stat -c %s "${outdir}/${name}") bytes)"
