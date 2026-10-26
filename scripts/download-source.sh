#!/usr/bin/env bash
# Download and extract an upstream source archive by commit SHA.
# Usage: download-source.sh <owner/repo> <40-hex-commit> <empty-dest-dir>
# Prints the extracted source directory on stdout.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

repo="${1:?usage: download-source.sh <owner/repo> <commit> <dest>}"
commit="${2:?usage: download-source.sh <owner/repo> <commit> <dest>}"
dest="${3:?usage: download-source.sh <owner/repo> <commit> <dest>}"

[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "invalid repo: $repo"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "invalid commit SHA: $commit"

rm -rf "$dest"
mkdir -p "$dest/src"

archive="${dest}/source.tar.gz"
url="https://github.com/${repo}/archive/${commit}.tar.gz"
log "downloading ${url}"
curl -fsSL --retry 3 --retry-delay 5 -o "$archive" "$url"

sha256sum "$archive" | awk '{print $1}' > "${dest}/source.sha256"
log "source sha256: $(cat "${dest}/source.sha256")"

tar -xzf "$archive" -C "${dest}/src" --strip-components=1
printf '%s\n' "${dest}/src"
