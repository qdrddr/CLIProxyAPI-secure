#!/usr/bin/env bash
# Render deployment/docker/Dockerfile from Dockerfile.template (optional snapshot for inspection).
# Compose and build-and-push-image.sh use Dockerfile.template + build-arg directly.
# ./scripts/render-dockerfile.sh
# ./scripts/render-dockerfile.sh v8.0.9
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [cli-proxy-api-git-tag]" >&2
  echo "  No tag: use CLIProxyAPI submodule HEAD (must be exactly on a git tag)" >&2
  echo "Example: $(basename "$0") v8.0.9" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/CLIProxyAPI"

if [[ $# -eq 1 ]]; then
  TAG="$1"
else
  if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
    echo "CLIProxyAPI submodule not initialized at ${SUBMODULE}." >&2
    echo "Run: git submodule update --init --recursive" >&2
    exit 1
  fi
  TAG="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$TAG" ]]; then
    echo "CLIProxyAPI HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: $(basename "$0") v8.0.9" >&2
    exit 1
  fi
  echo "Using CLIProxyAPI submodule tag: ${TAG}"
fi

if [[ ! "$TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing unsafe tag: ${TAG}" >&2
  exit 1
fi

TEMPLATE="${ROOT}/deployment/docker/Dockerfile.template"
OUT="${ROOT}/deployment/docker/Dockerfile"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template not found: ${TEMPLATE}" >&2
  exit 1
fi

if ! grep -q '^ARG CLI_PROXY_API_TAG=' "$TEMPLATE"; then
  echo "Template missing ARG CLI_PROXY_API_TAG= line: ${TEMPLATE}" >&2
  exit 1
fi

sed "s/^ARG CLI_PROXY_API_TAG=.*/ARG CLI_PROXY_API_TAG=${TAG}/" "$TEMPLATE" >"$OUT"

echo "Rendered ${OUT} (eceasy/cli-proxy-api:${TAG})"
