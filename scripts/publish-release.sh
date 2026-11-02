#!/usr/bin/env bash
# Tag this repo with a composite ref, push, and publish a GitHub release (triggers CI).
# Requires: gh auth login, push access to origin.
# ./scripts/publish-release.sh
# ./scripts/publish-release.sh v8.0.47
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [upstream-git-tag]" >&2
  echo "  No tag: use CLIProxyAPI submodule HEAD (must be exactly on a git tag)" >&2
  echo "  With tag: checkout that tag in CLIProxyAPI, then release composite tag" >&2
  echo "Example: NONO_VERSION=0.81.0 $(basename "$0") v8.0.47  # creates v8.0.47-0.81.0" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
SUBMODULE="${ROOT}/CLIProxyAPI"
TEMPLATE="${ROOT}/deployment/docker/Dockerfile.template"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"
NONO_VERSION="${NONO_VERSION:-0.81.0}"

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "CLIProxyAPI submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  parse_release_tag "$1"
  "${ROOT}/scripts/checkout-submodule-tag.sh" "$BASE_TAG"
else
  upstream_tag="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$upstream_tag" ]]; then
    echo "CLIProxyAPI HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/publish-release.sh v8.0.47" >&2
    exit 1
  fi
  parse_release_tag "$upstream_tag"
fi

RELEASE_TAG="$DOCKER_TAG"

if ! git -C "$SUBMODULE" rev-parse "refs/tags/${BASE_TAG}^{commit}" >/dev/null 2>&1; then
  echo "Tag ${BASE_TAG} not found in CLIProxyAPI submodule." >&2
  exit 1
fi

cd "$ROOT"

if git rev-parse "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
  echo "Tag ${RELEASE_TAG} already exists in this repository." >&2
  echo "Delete locally/remotely first or choose another tag." >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
  echo "Tag ${RELEASE_TAG} already exists on origin." >&2
  exit 1
fi

commit_pin=false
if ! git diff --quiet -- CLIProxyAPI; then
  commit_pin=true
fi
if [[ -f "$TEMPLATE" ]] && ! git diff --quiet -- "$TEMPLATE"; then
  commit_pin=true
fi

if [[ "$commit_pin" == true ]]; then
  git add CLIProxyAPI
  if [[ -f "$TEMPLATE" ]]; then
    git add "$TEMPLATE"
  fi
  git commit -m "Pin CLIProxyAPI at ${BASE_TAG}"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree has uncommitted changes. Commit or stash before releasing." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "HEAD" ]]; then
  UPSTREAM="$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null || true)"
  if [[ -n "$UPSTREAM" ]]; then
    LOCAL="$(git rev-parse HEAD)"
    REMOTE="$(git rev-parse "$UPSTREAM" 2>/dev/null || true)"
    if [[ -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
      echo "Pushing ${BRANCH} so the release tag points at commits on GitHub..."
      git push origin "HEAD:${BRANCH}"
    fi
  else
    echo "Branch ${BRANCH} has no upstream; pushing HEAD to origin..."
    git push origin HEAD
  fi
fi

git tag -a "$RELEASE_TAG" -m "Release ${RELEASE_TAG} (CLIProxyAPI ${BASE_TAG} + nono ${NONO_VERSION})"
git push origin "$RELEASE_TAG"

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

gh release create "$RELEASE_TAG" \
  --title "$RELEASE_TAG" \
  --notes-file "$NOTES_FILE"

echo "Published release ${RELEASE_TAG}. CI will push ${DOCKER_IMAGE}:${RELEASE_TAG} to Docker Hub."
