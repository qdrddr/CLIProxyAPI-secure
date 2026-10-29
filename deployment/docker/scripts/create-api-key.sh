#!/usr/bin/env bash
# Mint a non-template client API key via the management API (enables /v1/* proxy routes).
# Usage: ./scripts/create-api-key.sh
# Env: CLIPROXY_BASE_URL, CLIPROXY_MANAGEMENT_KEY, CLIPROXY_API_KEY_FILE
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_command curl
require_command openssl

TEST_KEY="cliproxy-local-test-$(openssl rand -hex 8)"

response="$(curl -sS -X PUT "${CLIPROXY_BASE_URL}/v8/management/config/access/api-keys" \
  -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
  -H "Content-Type: application/json" \
  -d "[\"${TEST_KEY}\"]")"

if ! printf '%s' "$response" | grep -q '"status"[[:space:]]*:[[:space:]]*"ok"'; then
  echo "Failed to set api-keys: ${response}" >&2
  exit 1
fi

printf '%s\n' "$TEST_KEY" >"$CLIPROXY_API_KEY_FILE"
chmod 600 "$CLIPROXY_API_KEY_FILE" 2>/dev/null || true

echo "Saved client API key to ${CLIPROXY_API_KEY_FILE}"
echo "KEY=${TEST_KEY}"
