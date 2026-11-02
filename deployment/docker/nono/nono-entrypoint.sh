#!/bin/sh
# Baked into bbkudk/cliproxyapi-secure: nono-cli wraps CLIProxyAPI (no separate nono init/sidecar).
# Docker Desktop: `nono run` supervises the process and sets HTTP(S)_PROXY for egress filtering.
# Talos/K8s (Landlock): set NONO_K8S_PROXY=1 — in-container `nono proxy` filters egress; app listens directly.
set -eu

nono_k8s_proxy_enabled() {
  case "${NONO_K8S_PROXY:-}" in 1|true|yes|TRUE|YES) return 0 ;; esac
  return 1
}

start_nono_filter_proxy() {
  PROXY_PORT="${NONO_PROXY_PORT:-18318}"
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  nono proxy --port "${PROXY_PORT}" --profile "${NONO_PROFILE:-claude}" --no-auth &
  export HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}"
  export HTTPS_PROXY="${HTTP_PROXY}"
  export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost,10.0.0.0/8,192.168.0.0/16,.svc,.cluster.local}"
}

STAGE=/CLIProxyAPI/.staging
AUTH_STAGE="${STAGE}/auths"
CONFIG_STAGE="${STAGE}/config.yaml"

mkdir -p "${STAGE}" "${AUTH_STAGE}"

# Bind mounts are applied before PID 1 starts, but Landlock cannot read them reliably.
# Stage config and auth material into the image tree (unsandboxed) before launching nono.
if [ -f /CLIProxyAPI/config.yaml ]; then
  cp /CLIProxyAPI/config.yaml "${CONFIG_STAGE}"
elif [ -d /CLIProxyAPI/config.yaml ]; then
  echo "WARNING: /CLIProxyAPI/config.yaml is a directory (bad bind mount). Using config.example.yaml from the image." >&2
  echo "On the host: docker compose down && rm -rf config.yaml" >&2
  echo "  cp config.example.yaml config.yaml && export CLI_PROXY_CONFIG_PATH=./config.yaml" >&2
  cp /CLIProxyAPI/config.example.yaml "${CONFIG_STAGE}"
else
  cp /CLIProxyAPI/config.example.yaml "${CONFIG_STAGE}"
fi

if [ -d /root/.cli-proxy-api ]; then
  cp -a /root/.cli-proxy-api/. "${AUTH_STAGE}/" 2>/dev/null || true
fi

if grep -q 'auth-dir:' "${CONFIG_STAGE}"; then
  sed -i "s|^\\([[:space:]]*auth-dir:\\).*|\1 \"${AUTH_STAGE}\"|" "${CONFIG_STAGE}" 2>/dev/null \
    || sed -i '' "s|^\\([[:space:]]*auth-dir:\\).*|\1 \"${AUTH_STAGE}\"|" "${CONFIG_STAGE}"
fi

inject_config=false
case "$1" in
  ./CLIProxyAPI|/CLIProxyAPI/CLIProxyAPI)
    inject_config=true
    ;;
esac

if [ "$inject_config" = true ]; then
  shift
  set -- /usr/local/bin/cliproxy-run.sh "$@"
fi

if nono_k8s_proxy_enabled; then
  start_nono_filter_proxy
  exec "$@"
fi

# NONO_RUN_ARGS: optional extra nono run flags before "--" (word-split; unset or empty = no extra flags).
# shellcheck disable=SC2086
exec nono run --profile "${NONO_PROFILE:-claude}" ${NONO_RUN_ARGS:-} -- "$@"
