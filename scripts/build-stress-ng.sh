#!/usr/bin/env bash
# Cross-compile stress-ng for one Android ABI.
# Inputs (env): VERSION, UPSTREAM_COMMIT, ABI, TRIPLE, API
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

TOOL="${TOOL:-stress-ng}"
: "${VERSION:?VERSION is required}"
: "${UPSTREAM_COMMIT:?UPSTREAM_COMMIT is required}"
: "${ABI:?ABI is required}"
: "${TRIPLE:?TRIPLE is required}"
: "${API:?API is required}"

resolve_ndk
compat_obj="$(build_arc4random_compat "$ABI" "${TC}/bin/${TRIPLE}${API}-clang")"

work="${RUNNER_TEMP:-/tmp}/stress-builds/${TOOL}-${VERSION}-${ABI}"
src="$(bash "${SCRIPT_DIR}/download-source.sh" "stress-ng/stress-ng" "$UPSTREAM_COMMIT" "$work/source")"
apply_patches "$TOOL" "$src"

# Neutralise host pkg-config lookups (the Makefile probes libnl unconditionally).
export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="${work}/empty-pkgconfig"
mkdir -p "$PKG_CONFIG_LIBDIR"

log "building ${TOOL} ${VERSION} for ${ABI} (API ${API})"
(
  cd "$src"
  make cleanconfig >/dev/null 2>&1 || true
  make clean >/dev/null 2>&1 || true

  STATIC=1 \
  CC="${TC}/bin/${TRIPLE}${API}-clang" \
  CXX="${TC}/bin/${TRIPLE}${API}-clang++" \
  LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 ${compat_obj}" \
  make -j"$(nproc)" \
    LIB_ACL= LIB_AIO= LIB_APPARMOR= LIB_BSD= LIB_CRYPT= \
    LIB_EGL= LIB_GBM= LIB_GLES2= LIB_GMP= LIB_IPSEC_MB= \
    LIB_JPEG= LIB_JUDY= LIB_KMOD= LIB_MD= LIB_MPFR= \
    LIB_SCTP= LIB_XXHASH= LIB_LZMA= LIB_NL= LIB_GENL=
)

binary="${src}/stress-ng"
[[ -f "$binary" ]] || die "build did not produce ${binary}"
"$LLVM_STRIP" --strip-all "$binary"

outdir="out/${TOOL}/${ABI}"
mkdir -p "$outdir"
install -m 0755 "$binary" "${outdir}/stress-ng"
log "produced ${outdir}/stress-ng"
