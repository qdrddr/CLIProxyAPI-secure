#!/usr/bin/env bash
# Canonical release refs only: v8.0.52-v0.81.0 (git tag == Docker Hub tag).
# Sets and exports BASE_TAG, NONO_VERSION, GIT_TAG, DOCKER_TAG.
set -euo pipefail

CANONICAL_TAG_RE='^(v[0-9]+\.[0-9]+\.[0-9]+)-v([0-9]+\.[0-9]+\.[0-9]+)$'

canonical_release_tag() {
  local base="$1"
  local nono="$2"
  nono="${nono#v}"

  if [[ ! "$base" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid app tag: ${base} (expected vX.Y.Z)" >&2
    return 1
  fi
  if [[ ! "$nono" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid nono version: ${nono}" >&2
    return 1
  fi

  BASE_TAG="$base"
  NONO_VERSION="$nono"
  DOCKER_TAG="${BASE_TAG}-v${NONO_VERSION}"
  GIT_TAG="$DOCKER_TAG"
  export BASE_TAG NONO_VERSION GIT_TAG DOCKER_TAG
}

parse_release_tag() {
  local ref="$1"

  if [[ "$ref" =~ $CANONICAL_TAG_RE ]]; then
    BASE_TAG="${BASH_REMATCH[1]}"
    NONO_VERSION="${BASH_REMATCH[2]}"
    GIT_TAG="$ref"
    DOCKER_TAG="$ref"
    export BASE_TAG NONO_VERSION GIT_TAG DOCKER_TAG
    return 0
  fi

  echo "Invalid release tag: ${ref}" >&2
  echo "Expected canonical form v{app}-v{nono} (e.g. v8.0.52-v0.81.0)." >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <canonical-tag>" >&2
    exit 1
  fi
  parse_release_tag "$1"
  printf 'BASE_TAG=%s\n' "$BASE_TAG"
  printf 'NONO_VERSION=%s\n' "$NONO_VERSION"
  printf 'GIT_TAG=%s\n' "$GIT_TAG"
  printf 'DOCKER_TAG=%s\n' "$DOCKER_TAG"
fi
