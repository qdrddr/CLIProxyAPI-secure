#!/usr/bin/env bash
# ./scripts/checkout-submodule-tag.sh v8.0.9
# https://github.com/router-for-me/CLIProxyAPI/releases
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <tag>" >&2
  echo "Example: $(basename "$0") v8.0.9" >&2
  echo "Checks out <tag> in CLIProxyAPI and renders deployment/docker/Dockerfile from Dockerfile.template." >&2
}

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  usage
  exit 1
fi

TAG="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/CLIProxyAPI"

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "CLIProxyAPI submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

cd "$SUBMODULE"
git reset --hard
git clean -fd
git fetch origin --tags
git fetch origin

if ! git rev-parse "refs/tags/${TAG}^{commit}" >/dev/null 2>&1; then
  echo "Tag ${TAG} not found in CLIProxyAPI (after fetch)." >&2
  exit 1
fi

git checkout "$TAG"

TEMPLATE="${ROOT}/deployment/docker/Dockerfile.template"
if [[ -f "$TEMPLATE" ]] && grep -q '^ARG CLI_PROXY_API_TAG=' "$TEMPLATE"; then
  if sed --version >/dev/null 2>&1; then
    sed -i "s/^ARG CLI_PROXY_API_TAG=.*/ARG CLI_PROXY_API_TAG=${TAG}/" "$TEMPLATE"
  else
    sed -i '' "s/^ARG CLI_PROXY_API_TAG=.*/ARG CLI_PROXY_API_TAG=${TAG}/" "$TEMPLATE"
  fi
fi

"${ROOT}/scripts/render-dockerfile.sh" "$TAG"

echo "Checked out ${TAG} ($(git rev-parse --short HEAD)) in CLIProxyAPI"
