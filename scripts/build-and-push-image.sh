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
  echo "Example: $(basename "$0") v8.0.47  # pushes bbkudk/cliproxyapi-secure:v8.0.47-0.81.0" >&2
  echo "         $(basename "$0") v8.0.47-0.81.0  # composite git/docker tag" >&2
  echo "Env: DOCKER_IMAGE (default bbkudk/cliproxyapi-secure), NONO_VERSION (default 0.81.0)" >&2
  echo "     DOCKER_PLATFORMS (default linux/amd64,linux/arm64), BUILDX_BUILDER (optional; CI sets this)" >&2
  echo "     SKIP_SUBMODULE_CHECKOUT=1 — use tag for eceasy/cli-proxy-api only (CI; no submodule fetch)" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
SUBMODULE="${ROOT}/CLIProxyAPI"
DOCKERFILE="${ROOT}/deployment/docker/Dockerfile.template"
DOCKER_CONTEXT="${ROOT}/deployment/docker"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cliproxyapi-secure}"
NONO_VERSION="${NONO_VERSION:-0.81.0}"
SKIP_SUBMODULE="${SKIP_SUBMODULE_CHECKOUT:-0}"

if [[ $# -eq 1 ]]; then
  parse_release_tag "$1"
  if [[ "$SKIP_SUBMODULE" != "1" ]]; then
    if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
      echo "Submodule not initialized at ${SUBMODULE}." >&2
      echo "Run: git submodule update --init --recursive" >&2
      exit 1
    fi
    "${ROOT}/scripts/checkout-submodule-tag.sh" "$BASE_TAG"
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
  upstream_tag="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$upstream_tag" ]]; then
    echo "CLIProxyAPI HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/build-and-push-image.sh v8.0.47" >&2
    exit 1
  fi
  parse_release_tag "$upstream_tag"
  "${ROOT}/scripts/render-dockerfile.sh" "$BASE_TAG"
fi

if [[ ! "$BASE_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing unsafe tag: ${BASE_TAG}" >&2
  exit 1
fi

if [[ ! "$NONO_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing unsafe NONO_VERSION: ${NONO_VERSION}" >&2
  exit 1
fi

IMAGE_REF="${DOCKER_IMAGE}:${DOCKER_TAG}"
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

docker buildx build \
  --platform "$PLATFORMS" \
  -f "$DOCKERFILE" \
  --build-arg "CLI_PROXY_API_TAG=${BASE_TAG}" \
  --build-arg "NONO_VERSION=${NONO_VERSION}" \
  -t "${IMAGE_REF}" \
  --push \
  "$DOCKER_CONTEXT"

echo "Pushed ${IMAGE_REF} (${PLATFORMS}; base ${BASE_TAG}, nono ${NONO_VERSION})"
