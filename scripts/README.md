# Scripts

Requires **Docker**; release paths need **`gh`** and **`docker login`**.

| Script | Purpose |
|--------|---------|
| [`lib/parse-release-tag.sh`](lib/parse-release-tag.sh) | Parse upstream or composite refs (`v8.0.47`, `v8.0.47-0.81.0`). |
| [`lib/resolve-release-args.sh`](lib/resolve-release-args.sh) | CLI parsing for `--app` / `--nono` and legacy positional tags. |
| [`checkout-submodule-tag.sh`](checkout-submodule-tag.sh) | Optional: checkout **CLIProxyAPI** submodule at a tag; pin `Dockerfile.template`; render `Dockerfile`. |
| [`render-dockerfile.sh`](render-dockerfile.sh) | Write gitignored `deployment/docker/Dockerfile` from template. |
| [`build-and-push-image.sh`](build-and-push-image.sh) | Multi-arch build/push to `bbkudk/cliproxyapi-secure:<composite-tag>`. CI: `SKIP_SUBMODULE_CHECKOUT=1`. |
| [`publish-release.sh`](publish-release.sh) | Composite git tag + GitHub release → CI push. |
| [`re-release.sh`](re-release.sh) | Rebuild an existing tag (`--local` or GitHub Actions). |

## Release

```bash
# Primary
./scripts/publish-release.sh --app v8.0.47 --nono 0.81.0

# Legacy positional (upstream or composite)
./scripts/publish-release.sh v8.0.47
./scripts/publish-release.sh v8.0.47-0.81.0

# Tag-only (CI runs on push; release auto-created after build if missing)
git tag -a v8.0.47-0.81.0 -m "CLIProxyAPI v8.0.47 + nono 0.81.0"
git push origin v8.0.47-0.81.0

./scripts/re-release.sh v8.0.47-0.81.0 --local

# Same composite tag after a fix on main (overwrites Docker Hub tag)
./scripts/re-release.sh --app v8.0.47 --nono 0.81.0
./scripts/re-release.sh v8.0.47-0.81.0              # CI checks out git tag v8.0.47-0.81.0
./scripts/re-release.sh v8.0.47-0.81.0 --retag      # force-move git tag → tag-push CI
```

Legacy upstream-only git tags (e.g. `v8.0.47`) still trigger CI via **GitHub Release published**; Docker Hub tag remains `v8.0.47-0.81.0` when `NONO_VERSION=0.81.0`.
