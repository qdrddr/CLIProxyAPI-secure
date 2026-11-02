#!/usr/bin/env bash
# Parse upstream-only or composite release refs: v8.0.47 or v8.0.47-0.81.0
# Sets and exports BASE_TAG, NONO_VERSION, GIT_TAG, DOCKER_TAG.
set -euo pipefail

parse_release_tag() {
  local ref="$1"
  local default_nono="${NONO_VERSION_DEFAULT:-0.81.0}"

  if [[ "$ref" =~ ^(v[0-9]+\.[0-9]+\.[0-9]+)-v?([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    BASE_TAG="${BASH_REMATCH[1]}"
    NONO_VERSION="${BASH_REMATCH[2]}"
    GIT_TAG="$ref"
    DOCKER_TAG="$ref"
  else
    BASE_TAG="$ref"
    NONO_VERSION="${NONO_VERSION:-$default_nono}"
    GIT_TAG="$ref"
    DOCKER_TAG="${BASE_TAG}-${NONO_VERSION}"
  fi

  export BASE_TAG NONO_VERSION GIT_TAG DOCKER_TAG
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <tag-ref>" >&2
    exit 1
  fi
  parse_release_tag "$1"
  printf 'BASE_TAG=%s\n' "$BASE_TAG"
  printf 'NONO_VERSION=%s\n' "$NONO_VERSION"
  printf 'GIT_TAG=%s\n' "$GIT_TAG"
  printf 'DOCKER_TAG=%s\n' "$DOCKER_TAG"
fi
