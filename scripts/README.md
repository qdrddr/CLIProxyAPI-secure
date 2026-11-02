# Scripts

Requires **Docker**; release paths need **`gh`** and **`docker login`**.

| Script | Purpose |
|--------|---------|
| [`lib/parse-release-tag.sh`](lib/parse-release-tag.sh) | Parse canonical refs (`v8.0.52-v0.81.0`); build tags with `canonical_release_tag`. |
| [`lib/resolve-release-args.sh`](lib/resolve-release-args.sh) | CLI parsing for `--app` / `--nono` and positional canonical tags. |
| [`checkout-submodule-tag.sh`](checkout-submodule-tag.sh) | Optional: checkout **CLIProxyAPI** submodule at a tag; pin `Dockerfile.template`; render `Dockerfile`. |
| [`render-dockerfile.sh`](render-dockerfile.sh) | Write gitignored `deployment/docker/Dockerfile` from template. |
| [`build-and-push-image.sh`](build-and-push-image.sh) | Multi-arch build/push to `bbkudk/cliproxyapi-secure:<canonical-tag>`. CI: `SKIP_SUBMODULE_CHECKOUT=1`. |
| [`publish-release.sh`](publish-release.sh) | Canonical git tag + GitHub release → CI push. |
| [`re-release.sh`](re-release.sh) | Rebuild an existing tag (`--local` or GitHub Actions). |

## Release

Git tag and Docker Hub tag are the same string: **`v{app}-v{nono}`** (e.g. `v8.0.52-v0.81.0`).

```bash
./scripts/publish-release.sh --app v8.0.52 --nono 0.81.0
./scripts/publish-release.sh v8.0.52-v0.81.0

git tag -a v8.0.52-v0.81.0 -m "CLIProxyAPI v8.0.52 + nono 0.81.0"
git push origin v8.0.52-v0.81.0

./scripts/re-release.sh v8.0.52-v0.81.0 --local
./scripts/re-release.sh --app v8.0.52 --nono 0.81.0
./scripts/re-release.sh v8.0.52-v0.81.0              # CI checks out git tag v8.0.52-v0.81.0
./scripts/re-release.sh v8.0.52-v0.81.0 --retag      # force-move git tag → tag-push CI
```
