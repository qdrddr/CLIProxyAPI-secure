#!/usr/bin/env bash
# Pin upstream, push canonical git tag, publish GitHub release (tag push triggers Docker CI).
# Requires: gh auth login, push access to origin.
#
# ./scripts/publish-release.sh --app v8.0.52 --nono 0.81.0
# ./scripts/publish-release.sh v8.0.52-v0.81.0
# ./scripts/publish-release.sh v8.0.52-v0.81.0 --force
# gh workflow run publish-release.yml -f release=v8.0.52-v0.81.0
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") --app <upstream-tag> [--nono <semver>] [--force]" >&2
  echo "       $(basename "$0") <release-name> [--force]" >&2
  echo "  release-name  Canonical git tag, Docker tag, and GitHub release title (e.g. v8.0.52-v0.81.0)" >&2
  echo "  --app   Upstream app tag (e.g. v8.0.52); --nono defaults to 0.81.0 or NONO_VERSION" >&2
  echo "  --force Re-point an existing tag at HEAD, recreate the release, and trigger CI" >&2
  echo "  No args: use CLIProxyAPI submodule HEAD (must be exactly on a git tag)" >&2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
# shellcheck source=lib/resolve-release-args.sh
source "${ROOT}/scripts/lib/resolve-release-args.sh"
# shellcheck source=lib/publish-git-release.sh
source "${ROOT}/scripts/lib/publish-git-release.sh"
SUBMODULE="${ROOT}/CLIProxyAPI"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"

FORCE_RETAG=0
RESOLVE_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE_RETAG=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      RESOLVE_ARGS+=("$1")
      shift
      ;;
  esac
done

set +e
resolve_release_tag_args "${RESOLVE_ARGS[@]}"
rc=$?
set -e
if [[ "$rc" -eq 2 ]]; then
  usage
  exit 0
elif [[ "$rc" -ne 0 ]]; then
  usage
  exit 1
fi

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "CLIProxyAPI submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/" >&2
  exit 1
fi

if [[ "${RESOLVE_FROM_SUBMODULE:-0}" -eq 1 ]]; then
  upstream_tag="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$upstream_tag" ]]; then
    echo "CLIProxyAPI HEAD is not exactly on a git tag." >&2
    echo "Pass --app v8.0.52 or a positional release name." >&2
    exit 1
  fi
  export NONO_VERSION
  canonical_release_tag "$upstream_tag" "${NONO_VERSION#v}"
else
  prepare_cliproxyapi_release_tree "$ROOT" "$BASE_TAG"
fi

RELEASE_TAG="$DOCKER_TAG"

if ! git -C "$SUBMODULE" rev-parse "refs/tags/${BASE_TAG}^{commit}" >/dev/null 2>&1; then
  echo "Tag ${BASE_TAG} not found in CLIProxyAPI submodule." >&2
  exit 1
fi

cd "$ROOT"

if tag_exists_locally_or_remote "$RELEASE_TAG"; then
  if [[ "$FORCE_RETAG" -ne 1 ]]; then
    echo "Release/tag ${RELEASE_TAG} already exists." >&2
    echo "Use ./scripts/publish-release.sh ${RELEASE_TAG} --force or re-release.sh --retag to rebuild." >&2
    exit 1
  fi
  echo "Retagging ${RELEASE_TAG} at $(git rev-parse --short HEAD)..."
fi

push_branch_if_ahead

TAG_MESSAGE="Release ${RELEASE_TAG} (CLIProxyAPI ${BASE_TAG} + nono ${NONO_VERSION})"
if [[ "$FORCE_RETAG" -eq 1 ]]; then
  TAG_MESSAGE="Rebuild ${RELEASE_TAG} at $(git rev-parse --short HEAD)"
fi

push_release_git_tag "$RELEASE_TAG" "$TAG_MESSAGE" "$FORCE_RETAG"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
{
  echo "Docker image \`${DOCKER_IMAGE}:${RELEASE_TAG}\`."
  echo
  echo "Wraps [eceasy/cli-proxy-api:${BASE_TAG}](https://hub.docker.com/r/eceasy/cli-proxy-api) with nono ${NONO_VERSION} sandbox layer from this repo."
  echo
  echo "Upstream: [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) at \`${BASE_TAG}\`."
  echo "CLIProxyAPI submodule commit: \`$(git -C "$SUBMODULE" rev-parse --short HEAD)\`"
} >"$NOTES_FILE"

publish_github_release "$RELEASE_TAG" "$NOTES_FILE" "$FORCE_RETAG"

echo "Published release ${RELEASE_TAG}. Tag push will run Release Docker Image → ${DOCKER_IMAGE}:${RELEASE_TAG}"
