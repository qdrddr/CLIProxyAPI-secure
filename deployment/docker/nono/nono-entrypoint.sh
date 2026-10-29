#!/bin/sh
set -eu

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
  echo "On the host: docker compose down && rm -rf config.yaml cli-proxy-api.config.yaml" >&2
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
  set -- ./CLIProxyAPI --config "${CONFIG_STAGE}" "$@"
fi

# NONO_RUN_ARGS: optional extra nono run flags before "--" (word-split; unset or empty = no extra flags).
# shellcheck disable=SC2086
exec nono run --profile "${NONO_PROFILE:-claude}" ${NONO_RUN_ARGS:-} -- "$@"
