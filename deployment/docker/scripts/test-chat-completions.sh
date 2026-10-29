#!/usr/bin/env bash
# Smoke test: OpenAI-compatible POST /v1/chat/completions
# Usage: ./scripts/test-chat-completions.sh [model]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_command curl
require_command python3

api_key="$(load_api_key)"
model="${1:-$CLIPROXY_TEST_MODEL}"
prompt="${CLIPROXY_TEST_PROMPT:-Reply with exactly: haiku-5-5-ok}"

body="$(python3 -c "import json; print(json.dumps({'model':'${model}','max_tokens':64,'messages':[{'role':'user','content':'''${prompt}'''}]}))")"

response="$(curl -sS -X POST "${CLIPROXY_BASE_URL}/v1/chat/completions" \
  -H "Authorization: Bearer ${api_key}" \
  -H "Content-Type: application/json" \
  -d "$body")"

printf '%s\n' "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'error' in d:
    print(json.dumps(d, indent=2))
    sys.exit(1)
try:
    text = d['choices'][0]['message']['content']
except (KeyError, IndexError, TypeError) as e:
    print(json.dumps(d, indent=2))
    raise SystemExit(f'unexpected response shape: {e}') from e
print(text)
"
