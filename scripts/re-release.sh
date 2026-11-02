#!/usr/bin/env bash
# Rebuild and push an existing release (same Docker tag / composite git tag).
# ./scripts/re-release.sh v8.0.47-0.81.0              # CI from main (workflow_dispatch)
# ./scripts/re-release.sh v8.0.47-0.81.0 --local      # docker build & push locally
# ./scripts/re-release.sh v8.0.47-0.81.0 --retag      # move git tag to HEAD, force-push → tag CI
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <git-tag> [--local | --retag]" >&2
  echo "  <git-tag> upstream or composite (e.g. v8.0.47 or v8.0.47-0.81.0)" >&2
  echo "  (default) Queue CI on main; rebuilds ${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}:<docker-tag> from current main." >&2
  echo "  --local   Build and push on this machine (overwrites same tag on Docker Hub)." >&2
  echo "  --retag   After fixes on main: move composite git tag to HEAD and force-push (triggers tag CI)." >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

TAG="$1"
MODE="${2:-ci}"

if [[ "$MODE" != "--local" && "$MODE" != "ci" && "$MODE" != "--retag" ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"
NONO_VERSION="${NONO_VERSION:-0.81.0}"
parse_release_tag "$TAG"

# Composite releases use the docker tag as the git tag; legacy upstream-only tags use DOCKER_TAG.
RETAG_NAME="$DOCKER_TAG"

if [[ "$MODE" == "--local" ]]; then
  exec "${ROOT}/scripts/build-and-push-image.sh" "$TAG"
fi

cd "$ROOT"

if [[ "$MODE" == "--retag" ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Commit or stash changes before --retag." >&2
    exit 1
  fi

  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$BRANCH" != "HEAD" ]]; then
    UPSTREAM="$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null || true)"
    if [[ -n "$UPSTREAM" ]]; then
      LOCAL="$(git rev-parse HEAD)"
      REMOTE="$(git rev-parse "$UPSTREAM" 2>/dev/null || true)"
      if [[ -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
        echo "Pushing ${BRANCH} before retagging..."
        git push origin "HEAD:${BRANCH}"
      fi
    fi
  fi

  git tag -fa "$RETAG_NAME" -m "Rebuild ${RETAG_NAME} at $(git rev-parse --short HEAD)"
  git push origin "refs/tags/${RETAG_NAME}" --force
  echo "Force-pushed tag ${RETAG_NAME}. Tag-push CI will rebuild ${DOCKER_IMAGE}:${DOCKER_TAG}."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/" >&2
  exit 1
fi

BRANCH="${RERELEASE_BRANCH:-main}"

echo "Starting CI rebuild for ${TAG} on ${BRANCH} → ${DOCKER_IMAGE}:${DOCKER_TAG}"
gh workflow run "Release Docker Image" --ref "$BRANCH" -f "tag=${TAG}"
echo "Workflow queued. Watch: gh run watch --workflow release-docker.yml"
