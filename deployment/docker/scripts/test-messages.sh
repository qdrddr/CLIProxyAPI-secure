#!/usr/bin/env bash
# Smoke test: Anthropic-native POST /v1/messages
# Usage: ./scripts/test-messages.sh [model]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_command curl
require_command python3

api_key="$(load_api_key)"
model="${1:-$CLIPROXY_TEST_MODEL}"
prompt="${CLIPROXY_TEST_PROMPT:-Say: messages-api-ok}"

body="$(python3 -c "import json; print(json.dumps({'model':'${model}','max_tokens':32,'messages':[{'role':'user','content':'''${prompt}'''}]}))")"

response="$(curl -sS -X POST "${CLIPROXY_BASE_URL}/v1/messages" \
  -H "Authorization: Bearer ${api_key}" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d "$body")"

printf '%s\n' "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('type') == 'error' or 'error' in d:
    print(json.dumps(d, indent=2))
    sys.exit(1)
try:
    text = d['content'][0]['text']
except (KeyError, IndexError, TypeError) as e:
    print(json.dumps(d, indent=2))
    raise SystemExit(f'unexpected response shape: {e}') from e
print(text)
"
