#!/usr/bin/env bash
# Build and push CLIProxyAPI + nono sandbox image (requires: docker login).
# ./scripts/build-and-push-image.sh
# ./scripts/build-and-push-image.sh v8.0.47
# CI: SKIP_SUBMODULE_CHECKOUT=1 ./scripts/build-and-push-image.sh v8.0.47
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [git-tag]" >&2
  echo "  No tag: build from CLIProxyAPI submodule HEAD (must be exactly on a git tag)" >&2
  echo "  With tag: checkout submodule + render (local), or build only when SKIP_SUBMODULE_CHECKOUT=1" >&2
  echo "Example: $(basename "$0") v8.0.47" >&2
  echo "Env: DOCKER_IMAGE (default bbkudk/cliproxyapi-secure), NONO_VERSION (default 0.80.0)" >&2
  echo "     DOCKER_PLATFORMS (default linux/amd64,linux/arm64), BUILDX_BUILDER (optional; CI sets this)" >&2
  echo "     SKIP_SUBMODULE_CHECKOUT=1 — use tag for eceasy/cli-proxy-api only (CI; no submodule fetch)" >&2
}

highest_version_tag() {
  if [[ "${SKIP_SUBMODULE_CHECKOUT:-}" == "1" ]]; then
    git ls-remote --tags --refs https://github.com/router-for-me/CLIProxyAPI.git 'v[0-9]*.[0-9]*.[0-9]*' \
      | awk -F/ '{print $NF}' | sort -V | tail -n 1
    return
  fi
  git -C "$SUBMODULE" fetch origin --tags --quiet
  git -C "$SUBMODULE" tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -n 1
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/CLIProxyAPI"
DOCKERFILE="${ROOT}/deployment/docker/Dockerfile.template"
DOCKER_CONTEXT="${ROOT}/deployment/docker"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"
NONO_VERSION="${NONO_VERSION:-0.80.0}"
SKIP_SUBMODULE="${SKIP_SUBMODULE_CHECKOUT:-0}"

if [[ $# -eq 1 ]]; then
  TAG="$1"
  if [[ "$SKIP_SUBMODULE" != "1" ]]; then
    if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
      echo "Submodule not initialized at ${SUBMODULE}." >&2
      echo "Run: git submodule update --init --recursive" >&2
      exit 1
    fi
    "${ROOT}/scripts/checkout-submodule-tag.sh" "$TAG"
  fi
else
  if [[ "$SKIP_SUBMODULE" == "1" ]]; then
    echo "A git tag is required when SKIP_SUBMODULE_CHECKOUT=1." >&2
    usage
    exit 1
  fi
  if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Submodule not initialized at ${SUBMODULE}." >&2
    echo "Run: git submodule update --init --recursive" >&2
    exit 1
  fi
  TAG="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$TAG" ]]; then
    echo "CLIProxyAPI HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/build-and-push-image.sh v8.0.47" >&2
    exit 1
  fi
  "${ROOT}/scripts/render-dockerfile.sh" "$TAG"
fi

if [[ ! "$TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing unsafe tag: ${TAG}" >&2
  exit 1
fi

IMAGE_REF="${DOCKER_IMAGE}:${TAG}"
PLATFORMS="${DOCKER_PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDX_BUILDER:-cliproxyapi-secure-builder}"

if docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  docker buildx use "$BUILDER"
elif [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "Buildx builder ${BUILDER} not found on CI; using current builder." >&2
  docker buildx ls
else
  docker buildx create --name "$BUILDER" --use --driver docker-container
fi

TAGS=(-t "${IMAGE_REF}")
HIGHEST_TAG="$(highest_version_tag)"
if [[ -n "$HIGHEST_TAG" && "$TAG" == "$HIGHEST_TAG" ]]; then
  TAGS+=(-t "${DOCKER_IMAGE}:latest")
fi

docker buildx build \
  --platform "$PLATFORMS" \
  -f "$DOCKERFILE" \
  --build-arg "CLI_PROXY_API_TAG=${TAG}" \
  --build-arg "NONO_VERSION=${NONO_VERSION}" \
  "${TAGS[@]}" \
  --push \
  "$DOCKER_CONTEXT"

echo "Pushed ${IMAGE_REF} (${PLATFORMS})"
if [[ -n "$HIGHEST_TAG" && "$TAG" == "$HIGHEST_TAG" ]]; then
  echo "Pushed ${DOCKER_IMAGE}:latest (${TAG})"
else
  echo "Skipped :latest (newest semver tag is ${HIGHEST_TAG:-none}, built ${TAG})"
fi
