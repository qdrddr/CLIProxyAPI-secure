#!/usr/bin/env bash
# Pin submodule, tag, and GitHub release. Sourced by publish-release.sh (not executed directly).
set -euo pipefail

prepare_cliproxyapi_release_tree() {
  local root="$1"
  local base_tag="$2"
  local submodule_rel="${3:-CLIProxyAPI}"
  local template="${root}/deployment/docker/Dockerfile.template"

  "${root}/scripts/checkout-submodule-tag.sh" "$base_tag"
  cd "$root"

  local commit_pin=false
  if ! git diff --quiet -- "$submodule_rel"; then
    commit_pin=true
  fi
  if [[ -f "$template" ]] && ! git diff --quiet -- "$template"; then
    commit_pin=true
  fi

  if [[ "$commit_pin" == true ]]; then
    git add "$submodule_rel"
    if [[ -f "$template" ]]; then
      git add "$template"
    fi
    git commit -m "Pin CLIProxyAPI at ${base_tag}"
  fi

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes. Commit or stash before releasing." >&2
    return 1
  fi
}

push_branch_if_ahead() {
  local branch upstream local_sha remote_sha
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" == "HEAD" ]]; then
    return 0
  fi
  upstream="$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null || true)"
  if [[ -n "$upstream" ]]; then
    local_sha="$(git rev-parse HEAD)"
    remote_sha="$(git rev-parse "$upstream" 2>/dev/null || true)"
    if [[ -n "$remote_sha" && "$local_sha" != "$remote_sha" ]]; then
      echo "Pushing ${branch} so the release tag points at commits on GitHub..."
      git push origin "HEAD:${branch}"
    fi
  else
    echo "Branch ${branch} has no upstream; pushing HEAD to origin..."
    git push origin HEAD
  fi
}

tag_exists_locally_or_remote() {
  local tag="$1"
  if git rev-parse "refs/tags/${tag}" >/dev/null 2>&1; then
    return 0
  fi
  if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

push_release_git_tag() {
  local release_tag="$1"
  local tag_message="$2"
  local force_retag="${3:-0}"

  if [[ "$force_retag" == 1 ]]; then
    git tag -fa "$release_tag" -m "$tag_message"
    git push origin "refs/tags/${release_tag}" --force
    echo "Force-pushed tag ${release_tag}."
  else
    git tag -a "$release_tag" -m "$tag_message"
    git push origin "$release_tag"
    echo "Pushed tag ${release_tag}."
  fi
}

publish_github_release() {
  local release_tag="$1"
  local notes_file="$2"
  local force_retag="${3:-0}"

  if gh release view "$release_tag" >/dev/null 2>&1; then
    if [[ "$force_retag" == 1 ]]; then
      gh release delete "$release_tag" --yes
      gh release create "$release_tag" \
        --title "$release_tag" \
        --notes-file "$notes_file"
      echo "Recreated GitHub release ${release_tag}."
    else
      gh release edit "$release_tag" \
        --title "$release_tag" \
        --notes-file "$notes_file"
      echo "Updated GitHub release ${release_tag}."
    fi
  else
    gh release create "$release_tag" \
      --title "$release_tag" \
      --notes-file "$notes_file"
    echo "Created GitHub release ${release_tag}."
  fi
}
