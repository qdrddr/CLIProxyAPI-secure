# Local API smoke tests

Run from `deployment/docker` with the stack up (`docker compose up -d`).

| Script | Purpose |
|--------|---------|
| [`create-api-key.sh`](create-api-key.sh) | Mint a client key via management API; writes [`.cliproxy-test-api-key`](../.cliproxy-test-api-key) |
| [`list-models.sh`](list-models.sh) | Full catalog (all providers) + routable models for current credentials |
| [`list-haiku-models.sh`](list-haiku-models.sh) | Alias for `list-models.sh` |
| [`test-chat-completions.sh`](test-chat-completions.sh) | `POST /v1/chat/completions` (OpenAI-compatible) |
| [`test-messages.sh`](test-messages.sh) | `POST /v1/messages` (Anthropic-native) |

```bash
cd deployment/docker
./scripts/create-api-key.sh
./scripts/list-models.sh
./scripts/test-chat-completions.sh
./scripts/test-messages.sh
```

Environment (optional):

- `CLIPROXY_BASE_URL` — default `http://127.0.0.1:8317`
- `CLIPROXY_MANAGEMENT_KEY` — default `change-me` (must match `management.secret-key` in `config.yaml`)
- `CLIPROXY_API_KEY` — skip reading `.cliproxy-test-api-key`
- `CLIPROXY_TEST_MODEL` — default `claude-haiku-5-5`
- `CLIPROXY_LIST_MODELS` — `both` (default), `catalog`, or `routable`
