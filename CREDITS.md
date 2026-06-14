# Credits

`feishu-cc-toolkit` is a **companion layer** built on top of — not a fork of —
the upstream Feishu ↔ Claude Code bridge:

- **lark-channel-bridge** by [zarazhangrui](https://github.com/zarazhangrui/feishu-claude-code-bridge)
  — MIT License. This toolkit installs it as a dependency (`npm i -g lark-channel-bridge`)
  and does **not** redistribute any of its code.

## What this toolkit adds (its own code, MIT)

- **Proxy-split** wrappers + installer — lets the bridge work for users who must
  reach Anthropic (Claude) through an outbound proxy, while keeping Feishu API
  traffic direct. The upstream bridge breaks in that setup because the Feishu SDK
  force-proxies every request once it detects `http(s)_proxy`. See
  [`docs/proxy-split.md`](docs/proxy-split.md).
- **`/ctx`** — a context-usage readout for the Feishu entry point, which has no
  built-in progress bar. See [`scripts/ctx.sh`](scripts/ctx.sh) and
  [`commands/ctx.md`](commands/ctx.md).
- An **operations playbook** (`docs/`) covering group setup, mention-free message
  delivery, workspace binding, and proxy / 403 troubleshooting — the hard-won bits
  that aren't obvious from the upstream README.

## On secrets

Every Feishu app credential, `open_id`, `chat_id`, proxy port and filesystem path
in this repo is **configuration**, not committed data — see [`.env.example`](.env.example).
Nothing here contains a real secret. The Feishu app secret is read by `lark-cli`
from your own secret store and must never enter this repo.
