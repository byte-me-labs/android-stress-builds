#!/usr/bin/env bash
# Shared helpers for the Android stress-builds CI and local builds.
set -euo pipefail

NDK_VERSION="${NDK_VERSION:-30.0.16248370}"
NDK_ZIP_URL="${NDK_ZIP_URL:-https://dl.google.com/android/repository/android-ndk-r30-linux.zip}"
NDK_SHA1="${NDK_SHA1:-5107f898313790e449e87eee2183d9a20602dee9}"

COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

# Compile the arc4random compatibility object and print its path.  The static
# libc in NDK r30 aborts on kernels without MADV_WIPEONFORK (Linux < 4.14);
# see compat/arc4random.c.
# Usage: build_arc4random_compat <abi> <compiler> [compiler-args...]
build_arc4random_compat() {
  local abi="$1"
  shift
  local root obj
  root="$(cd -- "${COMMON_DIR}/.." && pwd)"
  obj="${root}/out/compat/${abi}/arc4random.o"
  mkdir -p -- "$(dirname -- "$obj")"
  log "compiling arc4random compatibility object for ${abi}"
  "$@" -O2 -fno-builtin -c "${root}/compat/arc4random.c" -o "$obj"
  printf '%s\n' "$obj"
}

ndk_is_version() {
  local dir="$1"
  [[ -n "$dir" && -f "$dir/source.properties" ]] &&
    grep -q "^Pkg.Revision = ${NDK_VERSION}$" "$dir/source.properties"
}

# Apply repository-owned patches in lexical order, if any exist.
apply_patches() {
  local tool="$1" src="$2"
  local dir="${COMMON_DIR}/../patches/${tool}"
  local patchfile
  shopt -s nullglob
  for patchfile in "${dir}"/*.patch; do
    log "applying $(basename "$patchfile")"
    patch -p1 -d "$src" < "$patchfile"
  done
  shopt -u nullglob
}

# Locate the pinned NDK. Prefer a preinstalled copy; fall back to a verified
# download. Sets NDK_HOME, TC, LLVM_STRIP and LLVM_READELF.
resolve_ndk() {
  if [[ -n "${NDK_HOME:-}" ]] && ndk_is_version "${NDK_HOME:-}"; then
    :
  else
    local candidates=(
      "${ANDROID_NDK_HOME:-}"
      "${ANDROID_NDK_ROOT:-}"
      "/usr/local/lib/android/sdk/ndk/${NDK_VERSION}"
      "${RUNNER_TEMP:-/tmp}/android-ndk-${NDK_VERSION}"
      "${RUNNER_TEMP:-/tmp}/android-ndk-${NDK_VERSION}/android-ndk-r30"
      "${PWD}/.ndk/android-ndk-${NDK_VERSION}"
      "${PWD}/.ndk/android-ndk-${NDK_VERSION}/android-ndk-r30"
    )
    NDK_HOME=""
    local d
    for d in "${candidates[@]}"; do
      if ndk_is_version "$d"; then
        NDK_HOME="$d"
        break
      fi
    done

    if [[ -z "$NDK_HOME" ]]; then
      local base="${RUNNER_TEMP:-${PWD}/.ndk}"
      local zip="${base}/android-ndk-r30-linux.zip"
      local dest="${base}/android-ndk-${NDK_VERSION}"
      log "NDK ${NDK_VERSION} not found; downloading ${NDK_ZIP_URL}"
      mkdir -p "$base" "$dest"
      curl -fL --retry 3 --retry-delay 5 -o "$zip" "$NDK_ZIP_URL"
      printf '%s  %s\n' "$NDK_SHA1" "$zip" | sha1sum -c -
      unzip -q -o "$zip" -d "$dest"
      NDK_HOME="${dest}/android-ndk-r30"
      ndk_is_version "$NDK_HOME" || die "downloaded NDK is not ${NDK_VERSION}"
    fi
  fi

  export NDK_HOME
  TC="${NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
  export TC
  LLVM_STRIP="${TC}/bin/llvm-strip"
  LLVM_READELF="${TC}/bin/llvm-readelf"
  export LLVM_STRIP LLVM_READELF
  log "using NDK ${NDK_VERSION} at ${NDK_HOME}"
}
