#!/usr/bin/env bash
# Rebuild and push an existing release (same Docker tag / composite git tag).
# ./scripts/re-release.sh --app v8.0.47 --nono 0.81.0
# ./scripts/re-release.sh v8.0.52-v0.81.0
# ./scripts/re-release.sh v8.0.52-v0.81.0 --local
# ./scripts/re-release.sh --app v8.0.47 --nono 0.81.0 --retag
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") --app <upstream-tag> [--nono <semver>] [--local | --retag]" >&2
  echo "       $(basename "$0") [<upstream-tag> | <composite-tag>] [--local | --retag]" >&2
  echo "  (default) Queue CI on composite git tag; rebuilds ${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}:<docker-tag> from that tag (use --retag after fixing main)." >&2
  echo "  --local   Build and push on this machine (overwrites same tag on Docker Hub)." >&2
  echo "  --retag   After fixes on main: move composite git tag to HEAD and force-push (triggers tag CI)." >&2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
# shellcheck source=lib/resolve-release-args.sh
source "${ROOT}/scripts/lib/resolve-release-args.sh"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"

MODE="ci"
RESOLVE_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local | --retag)
      MODE="$1"
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

if [[ ${#RESOLVE_ARGS[@]} -eq 0 ]]; then
  usage
  exit 1
fi

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

if [[ "${RESOLVE_FROM_SUBMODULE:-0}" -eq 1 ]]; then
  echo "re-release requires --app or a positional tag." >&2
  usage
  exit 1
fi

RETAG_NAME="$DOCKER_TAG"

if [[ "$MODE" == "--local" ]]; then
  exec "${ROOT}/scripts/build-and-push-image.sh" "$RELEASE_REF"
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

if ! git rev-parse "refs/tags/${DOCKER_TAG}" >/dev/null 2>&1 \
  && ! git ls-remote --exit-code --tags origin "refs/tags/${DOCKER_TAG}" >/dev/null 2>&1; then
  echo "Git tag ${DOCKER_TAG} not found locally or on origin." >&2
  echo "Create it with publish-release.sh, or run with --retag after committing fixes on main." >&2
  exit 1
fi

echo "Starting CI rebuild for ${RELEASE_REF} at git tag ${DOCKER_TAG} → ${DOCKER_IMAGE}:${DOCKER_TAG}"
gh workflow run "Release Docker Image" --ref "$DOCKER_TAG" -f "release=${RELEASE_REF}"
echo "Workflow queued. Watch: gh run watch --workflow release-docker.yml"
