#!/usr/bin/env bash
# Resolve the upstream release to build, and decide whether it can be skipped.
# Usage: resolve-upstream.sh <tool> <owner/repo>
# Inputs (env): INPUT_VERSION, FORCE, GH_TOKEN, GITHUB_OUTPUT, GITHUB_STEP_SUMMARY
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

tool="${1:?usage: resolve-upstream.sh <tool> <owner/repo>}"
repo="${2:?usage: resolve-upstream.sh <tool> <owner/repo>}"
input_version="${INPUT_VERSION:-}"
force="${FORCE:-false}"
output="${GITHUB_OUTPUT:-/dev/null}"

normalize_version() {
  local v="${1#[vV]}"
  printf '%s' "$v"
}

resolve_commit() {
  local ref="$1" sha
  sha="$(gh api "repos/${repo}/commits/${ref}" --jq .sha 2>/dev/null || true)"
  # gh prints JSON error bodies on stdout for 4xx responses; only accept a SHA.
  if [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%s' "$sha"
  fi
  return 0
}

if [[ -n "$input_version" ]]; then
  ref=""
  commit=""
  for candidate in "$input_version" "v${input_version#[vV]}" "V${input_version#[vV]}"; do
    commit="$(resolve_commit "$candidate")"
    if [[ -n "$commit" ]]; then
      ref="$candidate"
      break
    fi
  done
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "cannot resolve upstream ref '${input_version}' in ${repo}"
else
  ref="$(gh api "repos/${repo}/releases/latest" --jq .tag_name 2>/dev/null || true)"
  if [[ -z "$ref" || "$ref" == "null" ]]; then
    ref="$(gh api "repos/${repo}/tags?per_page=1" --jq '.[0].name' 2>/dev/null || true)"
  fi
  [[ -n "$ref" && "$ref" != "null" ]] || die "cannot resolve the latest release of ${repo}"
  commit="$(resolve_commit "$ref")"
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "cannot resolve commit for ${repo} tag ${ref}"
fi

version="$(normalize_version "$ref")"
[[ "$version" =~ ^[0-9A-Za-z._-]+$ ]] || die "unsafe version string: ${version}"
release_tag="${tool}-${version}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 3 --retry-delay 5 \
  -o "${work}/source.tar.gz" \
  "https://github.com/${repo}/archive/${commit}.tar.gz"
source_sha256="$(sha256sum "${work}/source.tar.gz" | awk '{print $1}')"
[[ "$source_sha256" =~ ^[0-9a-f]{64}$ ]] || die "failed to hash the source archive"

skip=false
if [[ "$force" != "true" ]]; then
  assets="$(gh release view "$release_tag" --json assets --jq '.assets[].name' 2>/dev/null || true)"
  if [[ -n "$assets" ]]; then
    expected=()
    for abi in arm64-v8a armeabi-v7a x86_64; do
      expected+=("${tool}-${version}-android-${abi}")
      expected+=("${tool}-${version}-android-${abi}.sha256")
    done
    if [[ "$tool" == "stress-ng" ]]; then
      expected+=("LICENSE-stress-ng")
    else
      expected+=("LICENSE-stressapptest" "NOTICE-stressapptest")
    fi

    missing=false
    for asset in "${expected[@]}"; do
      if ! grep -Fqx "$asset" <<< "$assets"; then
        missing=true
      fi
    done
    if [[ "$missing" == "false" ]]; then
      skip=true
    fi
  fi
fi

{
  printf 'version=%s\n' "$version"
  printf 'upstream_tag=%s\n' "$ref"
  printf 'commit=%s\n' "$commit"
  printf 'release_tag=%s\n' "$release_tag"
  printf 'source_sha256=%s\n' "$source_sha256"
  printf 'skip=%s\n' "$skip"
} >> "$output"

log "${tool}: upstream ${ref} (${commit}) -> release ${release_tag}, skip=${skip}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '### %s\n\n' "$tool"
    printf -- '- Upstream: `%s` tag `%s` commit `%s`\n' "$repo" "$ref" "$commit"
    printf -- '- Release tag: `%s`\n' "$release_tag"
    printf -- '- Source archive SHA256: `%s`\n' "$source_sha256"
    printf -- '- Skipped: `%s`\n' "$skip"
  } >> "$GITHUB_STEP_SUMMARY"
fi
