# feishu-cc-toolkit

A companion layer for the [Feishu ↔ Claude Code bridge][upstream] that makes it
work **behind an outbound proxy**, adds a **context-usage readout**, and ships
an **operations playbook** for groups, mention-free delivery, and workspace
binding.

> 中文文档见 [README.zh.md](README.zh.md)。

This is **not** a fork. It installs the upstream [`lark-channel-bridge`][upstream]
as a dependency and sits on top of it. The bridge core is zarazhangrui's MIT
work — see [CREDITS.md](CREDITS.md).

## Who this is for

You run Claude Code from Feishu via `lark-channel-bridge`, and you **must reach
Anthropic through an outbound HTTP proxy** while Feishu (a domestic CN service)
must stay **direct**. The upstream bridge breaks in that setup; this toolkit
fixes it cleanly. If you don't need a proxy, you may only want the `/ctx` command
and the docs.

## What it adds

- **Proxy-split** — bridge runs with no proxy (Feishu direct); the proxy is
  injected only into the `claude` child. Solves `CONNECT` / bot-identity failures
  on one side and Anthropic `403` on the other. → [docs/proxy-split.md](docs/proxy-split.md)
- **`/ctx`** — context-usage readout for the Feishu entry, which has no progress
  bar. Reports `current / window` tokens for the active session.
- **Operations playbook** — [group setup & mention-free delivery](docs/group-setup.md),
  [workspace binding](docs/workspaces.md), [troubleshooting](docs/troubleshooting.md).

## Install

> Clean machine with nothing set up, or behind a proxy? Follow the full chain in
> [docs/install-from-scratch.md](docs/install-from-scratch.md). The quick version:

```bash
# 0. Get this toolkit
git clone https://github.com/xueyongcheng/feishu-cc-toolkit && cd feishu-cc-toolkit

# 1. Pull the upstream deps from npm (zara's bridge + lark-cli). No repo to clone.
bash scripts/install-deps.sh

# 2. Bind a Feishu bot (interactive QR — can't be automated)
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
  lark-channel-bridge run --profile claude --agent claude

# 3. Configure + install the toolkit
cp .env.example .env    # set PROXY_HTTP
bash scripts/install.sh
```

> The upstream bridge isn't vendored or cloned — it's the npm package
> `lark-channel-bridge`, which `install-deps.sh` pulls for you. Source & credit:
> [CREDITS.md](CREDITS.md). Full clean-machine walkthrough:
> [docs/install-from-scratch.md](docs/install-from-scratch.md).

The installer writes the proxy-split wrappers to `~/.lark-channel/bin`, installs
`ctx.sh` and the `/ctx` command, generates a launchd plist with the wrapper dir
first on `PATH` and the proxy isolated to the claude child, and loads the daemon.
Re-run it any time config changes. `scripts/uninstall.sh` reverses it (your
bridge config is left intact).

## Verify

```bash
lark-channel-bridge status                 # running, with a PID
# The wrapper gets PROXY_HTTP from the plist, not your shell. Running it bare
# errors "PROXY_HTTP not set" (expected, not a broken install) — set it inline:
PROXY_HTTP=http://127.0.0.1:7897 ~/.lark-channel/bin/claude -p test   # replies, NOT a 403
```

The daemon log should show `ws/connected` + `chats-fetched` and **no**
`channel: proxy detected`. If `status` shows the job but no PID right after
install, run `lark-channel-bridge restart` once (a first-start race — see
[docs/troubleshooting.md](docs/troubleshooting.md)).

## Platform

macOS (launchd) for the daemon. The wrappers and `ctx.sh` are plain POSIX `sh` /
`python3` and are portable; only the install/daemon path is macOS-specific.

## License

MIT — see [LICENSE](LICENSE). Upstream bridge: MIT, [zarazhangrui][upstream].

[upstream]: https://github.com/zarazhangrui/feishu-claude-code-bridge
