#!/usr/bin/env bash
# Cross-compile stressapptest for one Android ABI.
# Inputs (env): VERSION, UPSTREAM_COMMIT, ABI, TRIPLE, API
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

TOOL="${TOOL:-stressapptest}"
: "${VERSION:?VERSION is required}"
: "${UPSTREAM_COMMIT:?UPSTREAM_COMMIT is required}"
: "${ABI:?ABI is required}"
: "${TRIPLE:?TRIPLE is required}"
: "${API:?API is required}"

case "$ABI" in
  arm64-v8a)   cpu=AARCH64 ;;
  armeabi-v7a) cpu=ARMV7A ;;
  x86_64)      cpu=X86_64 ;;
  *) die "unsupported ABI: ${ABI}" ;;
esac

resolve_ndk
compat_obj="$(build_arc4random_compat "$ABI" "${TC}/bin/clang" "--target=${TRIPLE}${API}")"

work="${RUNNER_TEMP:-/tmp}/stress-builds/${TOOL}-${VERSION}-${ABI}"
src="$(bash "${SCRIPT_DIR}/download-source.sh" "stressapptest/stressapptest" "$UPSTREAM_COMMIT" "$work/source")"
apply_patches "$TOOL" "$src"

export CC="${TC}/bin/clang --target=${TRIPLE}${API}"
export CXX="${TC}/bin/clang++ --target=${TRIPLE}${API}"
export AS="$CC"
export AR="${TC}/bin/llvm-ar"
export RANLIB="${TC}/bin/llvm-ranlib"
export STRIP="$LLVM_STRIP"

log "building ${TOOL} ${VERSION} for ${ABI} (API ${API})"
(
  cd "$src"
  # Upstream refuses to run a build without NDEBUG (it treats it as a DEBUG
  # binary), and sat.cc #errors when NDEBUG is set without CHECKOPTS.  Both
  # normally come from the default-optimization flags we drop because clang
  # does not support the GCC-only -funroll-all-loops.
  ./configure \
    --host="$TRIPLE" \
    --disable-default-optimizations \
    CFLAGS="-O2" \
    CXXFLAGS="-O2" \
    CPPFLAGS="-DSTRESSAPPTEST_CPU_${cpu} -DNDEBUG -DCHECKOPTS" \
    LDFLAGS="-static -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 ${compat_obj}"
  make -j"$(nproc)"
)

binary="${src}/src/stressapptest"
[[ -f "$binary" ]] || die "build did not produce ${binary}"
"$LLVM_STRIP" --strip-all "$binary"

outdir="out/${TOOL}/${ABI}"
mkdir -p "$outdir"
install -m 0755 "$binary" "${outdir}/stressapptest"
log "produced ${outdir}/stressapptest"
