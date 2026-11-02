#!/usr/bin/env bash
# Parse publish/re-release CLI args. Requires parse-release-tag.sh sourced first.
# Primary:   --app v8.0.52 --nono 0.81.0  → v8.0.52-v0.81.0
# Positional: v8.0.52-v0.81.0 (canonical git + Docker Hub tag)
# No args:   sets RESOLVE_FROM_SUBMODULE=1
set -euo pipefail

resolve_release_tag_args() {
  local app="" nono="" positional=""

  RESOLVE_FROM_SUBMODULE=0
  NONO_VERSION="${NONO_VERSION:-0.81.0}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --app" >&2
          return 1
        fi
        app="$2"
        shift 2
        ;;
      --nono)
        if [[ $# -lt 2 ]]; then
          echo "Missing value for --nono" >&2
          return 1
        fi
        nono="$2"
        shift 2
        ;;
      -h | --help)
        return 2
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        return 1
        ;;
      *)
        if [[ -n "$positional" ]]; then
          echo "Unexpected extra argument: $1 (use --app or a single positional tag)" >&2
          return 1
        fi
        positional="$1"
        shift
        ;;
    esac
  done

  if [[ $# -gt 0 ]]; then
    echo "Unexpected argument: $1" >&2
    return 1
  fi

  if [[ -n "$app" && -n "$positional" ]]; then
    echo "Use --app or a positional tag, not both." >&2
    return 1
  fi

  if [[ -n "$nono" ]]; then
    NONO_VERSION="$nono"
  fi

  if [[ -n "$app" ]]; then
    export NONO_VERSION
    canonical_release_tag "$app" "${NONO_VERSION#v}"
    RELEASE_REF="$DOCKER_TAG"
    export RELEASE_REF
    return 0
  fi

  if [[ -n "$positional" ]]; then
    parse_release_tag "$positional"
    RELEASE_REF="$DOCKER_TAG"
    export RELEASE_REF
    return 0
  fi

  RESOLVE_FROM_SUBMODULE=1
  export RESOLVE_FROM_SUBMODULE NONO_VERSION
  return 0
}
