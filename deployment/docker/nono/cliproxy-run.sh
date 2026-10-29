#!/bin/sh
# Runs inside `nono run` after nono sets HTTP_PROXY / HTTPS_PROXY for the supervised proxy.
# CLIProxyAPI uTLS OAuth/control-plane clients honor requests.proxy-url, not env proxies.
set -eu

CONFIG="/CLIProxyAPI/.staging/config.yaml"
PROXY="${HTTPS_PROXY:-${HTTP_PROXY:-}}"

inject_nono_proxy_into_config() {
  if [ "${CLIPROXY_SKIP_NONO_PROXY_INJECT:-}" = "1" ] || [ "${CLIPROXY_SKIP_NONO_PROXY_INJECT:-}" = "true" ]; then
    return 0
  fi
  if [ -z "$PROXY" ]; then
    return 0
  fi
  if [ ! -f "$CONFIG" ]; then
    return 0
  fi
  # Respect an operator-configured proxy-url (uncommented YAML key).
  if grep -E '^[[:space:]]*proxy-url:' "$CONFIG" >/dev/null 2>&1; then
    return 0
  fi

  tmp="${CONFIG}.tmp.$$"
  # shellcheck disable=SC2016
  awk -v proxy="$PROXY" '
    BEGIN { injected = 0 }
    /^requests:/ {
      print
      if (!injected) {
        print "  proxy-url: \"" proxy "\""
        injected = 1
      }
      in_requests = 1
      next
    }
    in_requests && /^[[:space:]]*proxy-url:/ { next }
    /^[^[:space:]#]/ && !/^[[:space:]]/ { in_requests = 0 }
    { print }
  ' "$CONFIG" > "$tmp"
  mv "$tmp" "$CONFIG"
}

inject_nono_proxy_into_config
exec /CLIProxyAPI/CLIProxyAPI --config "$CONFIG" "$@"
