#!/usr/bin/env bash
# Tag this repo with the CLIProxyAPI submodule tag, push, and publish a GitHub release (triggers CI).
# Requires: gh auth login, push access to origin.
# ./scripts/publish-release.sh
# ./scripts/publish-release.sh v8.0.47
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [git-tag]" >&2
  echo "  No tag: use CLIProxyAPI submodule HEAD (must be exactly on a git tag)" >&2
  echo "  With tag: checkout that tag in CLIProxyAPI, then release" >&2
  echo "Example: $(basename "$0") v8.0.47" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/CLIProxyAPI"
TEMPLATE="${ROOT}/deployment/docker/Dockerfile.template"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"

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
  TAG="$1"
  "${ROOT}/scripts/checkout-submodule-tag.sh" "$TAG"
else
  TAG="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$TAG" ]]; then
    echo "CLIProxyAPI HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/publish-release.sh v8.0.47" >&2
    exit 1
  fi
fi

if ! git -C "$SUBMODULE" rev-parse "refs/tags/${TAG}^{commit}" >/dev/null 2>&1; then
  echo "Tag ${TAG} not found in CLIProxyAPI submodule." >&2
  exit 1
fi

cd "$ROOT"

if git rev-parse "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists in this repository." >&2
  echo "Delete locally/remotely first or choose another tag." >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists on origin." >&2
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
  git commit -m "Pin CLIProxyAPI at ${TAG}"
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

git tag -a "$TAG" -m "Release ${TAG} (CLIProxyAPI ${TAG} + nono sandbox)"
git push origin "$TAG"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
{
  echo "Docker image \`${DOCKER_IMAGE}:${TAG}\` (and \`:latest\` when this is the newest CLIProxyAPI semver tag)."
  echo
  echo "Wraps [eceasy/cli-proxy-api:${TAG}](https://hub.docker.com/r/eceasy/cli-proxy-api) with a nono sandbox layer from this repo."
  echo
  echo "Upstream: [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) at \`${TAG}\`."
  echo "CLIProxyAPI submodule commit: \`$(git -C "$SUBMODULE" rev-parse --short HEAD)\`"
} >"$NOTES_FILE"

gh release create "$TAG" \
  --title "$TAG" \
  --notes-file "$NOTES_FILE"

echo "Published release ${TAG}. CI will push ${DOCKER_IMAGE}:${TAG} to Docker Hub."
