#!/usr/bin/env bash
# List model ids: full CLIProxy catalog (all providers) and/or routable via proxy API today.
# Usage: ./scripts/list-models.sh
# Env:
#   CLIPROXY_LIST_MODELS=catalog|routable|both  (default: both)
#   CLIPROXY_MANAGEMENT_KEY — management API key (default: change-me)
# Requires: create-api-key.sh (or CLIPROXY_API_KEY) when listing routable models
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_command curl
require_command python3

LIST_MODE="${CLIPROXY_LIST_MODELS:-both}"

export CLIPROXY_API_KEY_FILE
if [[ "$LIST_MODE" == "routable" || "$LIST_MODE" == "both" ]]; then
  export CLIPROXY_API_KEY="$(load_api_key)"
fi

python3 - "$LIST_MODE" "$CLIPROXY_BASE_URL" "$CLIPROXY_MANAGEMENT_KEY" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

list_mode, base_url, management_key = sys.argv[1:4]
channels = [
    "claude",
    "gemini",
    "gemini-interactions",
    "vertex",
    "aistudio",
    "codex",
    "kimi",
    "antigravity",
    "xai",
    "devin",
    "meta",
]


def get_json(url, bearer):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {bearer}"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def catalog_ids():
    by_id = {}
    for channel in channels:
        url = f"{base_url.rstrip('/')}/v8/management/routing/model-definitions/{channel}"
        try:
            payload = get_json(url, management_key)
        except urllib.error.HTTPError as err:
            body = err.read().decode("utf-8", errors="replace")
            print(f"warning: skip channel {channel}: HTTP {err.code} {body[:200]}", file=sys.stderr)
            continue
        for model in payload.get("models") or []:
            model_id = (model.get("id") or "").strip()
            if not model_id:
                continue
            by_id.setdefault(model_id, set()).add(channel)
    return by_id


def routable_ids():
    api_key = (os.environ.get("CLIPROXY_API_KEY") or "").strip()
    key_file = os.environ.get("CLIPROXY_API_KEY_FILE", "")
    if not api_key and key_file and os.path.isfile(key_file):
        api_key = open(key_file, encoding="utf-8").read().strip()
    if not api_key:
        print(
            "error: routable list requires CLIPROXY_API_KEY or "
            f"a key file at {key_file or '(unset)'}; run create-api-key.sh",
            file=sys.stderr,
        )
        sys.exit(1)
    url = f"{base_url.rstrip('/')}/v1/models"
    payload = get_json(url, api_key)
    if "error" in payload:
        print(json.dumps(payload, indent=2), file=sys.stderr)
        sys.exit(1)
    return sorted(
        {
            (m.get("id") or "").strip()
            for m in payload.get("data") or []
            if (m.get("id") or "").strip()
        }
    )


def print_section(title, ids):
    print(title, file=sys.stderr)
    for model_id in ids:
        print(model_id)


if list_mode in ("catalog", "both"):
    by_id = catalog_ids()
    catalog_sorted = sorted(by_id)
    if list_mode == "both":
        print_section(f"# Catalog ({len(catalog_sorted)} models, all providers)", catalog_sorted)
    else:
        for model_id in catalog_sorted:
            print(model_id)

if list_mode in ("routable", "both"):
    try:
        routable = routable_ids()
    except SystemExit:
        if list_mode == "both":
            print("warning: skipped routable list (no client API key)", file=sys.stderr)
            raise SystemExit(0)
        raise
    if list_mode == "both":
        print("", file=sys.stderr)
        print_section(f"# Routable now ({len(routable)} models, current credentials)", routable)
    else:
        for model_id in routable:
            print(model_id)
PY
