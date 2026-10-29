# Shared defaults for local CLIProxyAPI smoke tests (source from other scripts).
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLIPROXY_PORT="${CLIPROXY_PORT:-8317}"
CLIPROXY_BASE_URL="${CLIPROXY_BASE_URL:-http://127.0.0.1:${CLIPROXY_PORT}}"
CLIPROXY_MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_KEY:-change-me}"
CLIPROXY_API_KEY_FILE="${CLIPROXY_API_KEY_FILE:-${DEPLOY_DIR}/.cliproxy-test-api-key}"
CLIPROXY_TEST_MODEL="${CLIPROXY_TEST_MODEL:-claude-haiku-5-5}"

load_api_key() {
  if [[ -n "${CLIPROXY_API_KEY:-}" ]]; then
    printf '%s' "$CLIPROXY_API_KEY"
    return 0
  fi
  if [[ -f "$CLIPROXY_API_KEY_FILE" ]]; then
    tr -d '[:space:]' < "$CLIPROXY_API_KEY_FILE"
    return 0
  fi
  echo "Missing client API key. Set CLIPROXY_API_KEY or run: ${DEPLOY_DIR}/scripts/create-api-key.sh" >&2
  return 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}
