# Scripts

Requires **Docker**; release paths need **`gh`** and **`docker login`**.

| Script | Purpose |
|--------|---------|
| [`checkout-submodule-tag.sh`](checkout-submodule-tag.sh) | Optional: checkout **CLIProxyAPI** submodule at a tag; pin `Dockerfile.template`; render `Dockerfile`. |
| [`render-dockerfile.sh`](render-dockerfile.sh) | Write gitignored `deployment/docker/Dockerfile` from template. |
| [`build-and-push-image.sh`](build-and-push-image.sh) | Multi-arch (`linux/amd64`, `linux/arm64`) build/push to `bbkudk/cliproxyapi-secure:<tag>`. CI: `SKIP_SUBMODULE_CHECKOUT=1`. |
| [`publish-release.sh`](publish-release.sh) | Git tag + GitHub release → CI push. |
| [`re-release.sh`](re-release.sh) | Rebuild an existing tag (`--local` or GitHub Actions). |

```bash
./scripts/build-and-push-image.sh v8.0.47
./scripts/publish-release.sh v8.0.47
./scripts/re-release.sh v8.0.47 --local
```
