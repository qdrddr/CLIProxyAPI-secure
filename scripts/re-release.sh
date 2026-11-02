#!/usr/bin/env bash
# Rebuild and push an existing release tag (no new git tag or GitHub release).
# ./scripts/re-release.sh v8.0.47          # CI workflow_dispatch on main
# ./scripts/re-release.sh v8.0.47 --local  # docker build & push on this machine
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <git-tag> [--local]" >&2
  echo "  <git-tag> upstream or composite (e.g. v8.0.47 or v8.0.47-0.81.0)" >&2
  echo "Example: $(basename "$0") v8.0.47-0.81.0 --local" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

TAG="$1"
MODE="${2:-ci}"

if [[ "$MODE" != "--local" && "$MODE" != "ci" ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"
NONO_VERSION="${NONO_VERSION:-0.81.0}"
parse_release_tag "$TAG"

if [[ "$MODE" == "--local" ]]; then
  exec "${ROOT}/scripts/build-and-push-image.sh" "$TAG"
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/" >&2
  exit 1
fi

cd "$ROOT"
BRANCH="${RERELEASE_BRANCH:-main}"

echo "Starting CI rebuild for ${TAG} on ${BRANCH} → ${DOCKER_IMAGE}:${DOCKER_TAG}"
gh workflow run "Release Docker Image" --ref "$BRANCH" -f "tag=${TAG}"
echo "Workflow queued. Watch: gh run watch --workflow release-docker.yml"
