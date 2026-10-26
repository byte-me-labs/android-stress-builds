#!/usr/bin/env bash
# Assemble release assets (licenses) and generate the Release notes.
# Usage: prepare-release.sh <tool> <owner/repo> <version> <distdir> <notes-file>
# Inputs (env): UPSTREAM_TAG, UPSTREAM_COMMIT, SOURCE_SHA256, NDK_VERSION
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

tool="${1:?usage: prepare-release.sh <tool> <owner/repo> <version> <distdir> <notes-file>}"
repo="${2:?usage: prepare-release.sh <tool> <owner/repo> <version> <distdir> <notes-file>}"
version="${3:?usage: prepare-release.sh <tool> <owner/repo> <version> <distdir> <notes-file>}"
dist="${4:?usage: prepare-release.sh <tool> <owner/repo> <version> <distdir> <notes-file>}"
notes="${5:?usage: prepare-release.sh <tool> <owner/repo> <version> <distdir> <notes-file>}"

upstream_tag="${UPSTREAM_TAG:?UPSTREAM_TAG is required}"
commit="${UPSTREAM_COMMIT:?UPSTREAM_COMMIT is required}"
source_sha256="${SOURCE_SHA256:?SOURCE_SHA256 is required}"
ndk_version="${NDK_VERSION:-30.0.16248370}"

[[ -d "$dist" ]] || die "missing dist directory: ${dist}"
for abi in arm64-v8a armeabi-v7a x86_64; do
  [[ -f "${dist}/${tool}-${version}-android-${abi}" ]] ||
    die "missing artifact for ${abi}"
done

case "$tool" in
  stress-ng)
    license="GPL-2.0-or-later"
    binname="stress-ng"
    example="stress-ng --cpu 2 --timeout 30s --metrics-brief"
    min_other="Android 8.0 (API 26)"
    notice_bullet=""
    abi_bullet=$'\n- `armeabi-v7a` and `x86_64` are built at API 26 because bionic only declares `quotactl()` and the SysV `shm*()` calls from that level; `arm64-v8a` uses API 29 for static TLS alignment.'
    cp "${SCRIPT_DIR}/../licenses/stress-ng-GPL-2.0.txt" "${dist}/LICENSE-stress-ng"
    ;;
  stressapptest)
    license="Apache-2.0"
    binname="stressapptest"
    example="stressapptest -s 30 -M 512"
    min_other="Android 7.0 (API 24)"
    notice_bullet=$'\n- Apache-2.0 NOTICE: see `NOTICE-stressapptest`.'
    abi_bullet=$'\n- `arm64-v8a` is built at API 29 for static TLS alignment; the other ABIs use API 24.'
    cp "${SCRIPT_DIR}/../licenses/stressapptest-Apache-2.0.txt" "${dist}/LICENSE-stressapptest"
    cp "${SCRIPT_DIR}/../licenses/stressapptest-NOTICE" "${dist}/NOTICE-stressapptest"
    ;;
  *)
    die "unknown tool: ${tool}"
    ;;
esac

cat > "$notes" <<EOF
# ${tool} ${version} for Android

Fully static Android binaries built from the upstream release below.

| Field | Value |
|---|---|
| Tool | \`${tool}\` ${version} |
| Upstream release | https://github.com/${repo}/releases/tag/${upstream_tag} |
| Upstream commit | \`${commit}\` |
| Source archive SHA256 | \`${source_sha256}\` |
| Build date | $(date -u +%Y-%m-%dT%H:%M:%SZ) |
| NDK | ${ndk_version} |
| License | ${license} (see \`LICENSE-${tool}\`) |

## Artifacts

| ABI | Minimum Android | File |
|---|---|---|
| arm64-v8a | Android 10 (API 29) | \`${tool}-${version}-android-arm64-v8a\` |
| armeabi-v7a | ${min_other} | \`${tool}-${version}-android-armeabi-v7a\` |
| x86_64 | ${min_other} | \`${tool}-${version}-android-x86_64\` |

Each ABI is published as the bare executable, with a matching \`.sha256\`. Verify and run:

\`\`\`sh
# verify (run in the directory containing the executable and its .sha256 file)
sha256sum -c ${tool}-${version}-android-arm64-v8a.sha256
chmod +x ${tool}-${version}-android-arm64-v8a

# run from an adb shell; static binaries do not run from the app sandbox
adb push ${tool}-${version}-android-arm64-v8a /data/local/tmp/${binname}
adb shell chmod 755 /data/local/tmp/${binname}
adb shell /data/local/tmp/${binname} ...
\`\`\`

Example:

\`\`\`sh
${example}
\`\`\`

## Notes

- Binaries are fully static **ET_EXEC** (not PIE) with no \`PT_INTERP\` and no \`DT_NEEDED\`.
- Run them from \`adb shell\` or \`/data/local/tmp\`; they are not intended to be launched from an app sandbox or an exec shim that requires \`ET_DYN\`.
- Some stressors require root or specific capabilities. See the upstream documentation for the full list.
- The executables include a small \`getrandom(2)\`-based \`arc4random(3)\` compatibility layer, so they also run on kernels older than 4.14 where the NDK r30 static libc would abort with \`arc4random data MADV_WIPEONFORK failed\`.
- Source for the corresponding binary is available from the upstream commit above; the local build scripts live in this repository.${notice_bullet}${abi_bullet}
EOF

log "release notes written to ${notes}"
