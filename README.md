# CLIProxyAPI-secure

Docker image that wraps **[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)** ([`eceasy/cli-proxy-api`](https://hub.docker.com/r/eceasy/cli-proxy-api)) in a thin **[nono](https://github.com/nolabs-ai/nono)** sandbox. The API binary and config stay upstream; this repo adds the entrypoint, Landlock-friendly staging, and network profiles.

Published as **`bbkudk/cliproxyapi-secure:<tag>`** (tag matches the upstream CLIProxyAPI release, e.g. `v8.0.47`).

## Quick start

```bash
cd deployment/docker
docker compose up -d
```

API: `http://localhost:8317` · Management UI: `http://localhost:8081/management.html`

Copy `deployment/docker/config.example.yaml` to `config.yaml`, set your management secret, and point compose at it if needed (`CLI_PROXY_CONFIG_PATH=./config.yaml`).

## More

- Build, release, and scripts: [`scripts/README.md`](scripts/README.md)
- Compose and nono profiles: [`deployment/docker/`](deployment/docker/)

The **CLIProxyAPI** git submodule is optional reference only; CI builds from the Hub base image tag, not the submodule checkout.
