# feishu-cc-toolkit

Talk to your local Claude Code from Feishu, **even when Anthropic is only
reachable through a proxy**. This is a companion layer on top of
[zarazhangrui's `lark-channel-bridge`][upstream] (the Feishu ↔ Claude Code bridge)
— not a fork. It installs the upstream from npm and sits on top, adding the
pieces that make it work in a proxied, China-network setup, plus a one-command
install.

> 中文文档见 [README.zh.md](README.zh.md)。Bridge core © zarazhangrui, MIT — see [CREDITS.md](CREDITS.md).

## What it solves (on top of zara's bridge)

[zara's `lark-channel-bridge`][upstream] is a great bridge, but it assumes a setup
that doesn't hold for everyone. This toolkit closes those gaps without forking it:

| Problem with the bridge alone | What this toolkit adds |
|---|---|
| **Behind an outbound proxy it can't connect.** Claude needs the proxy to reach Anthropic, but the Feishu SDK force-proxies every Feishu call the moment it sees `http(s)_proxy` — and Feishu (a CN service) breaks through an overseas proxy (`CONNECT` reset / bot-identity errors), while Claude *without* the proxy hits a `403`. | **Proxy-split**: the bridge runs with no proxy (Feishu stays direct); the proxy is injected only into the `claude` child. → [docs/proxy-split.md](docs/proxy-split.md) |
| **No way to see context usage from Feishu.** The Feishu entry has no progress bar, so you can't tell how full the session is. | **`/ctx`** — reports `used / window` tokens for the active session. |
| **Setup is fiddly and easy to re-break.** Hand-built proxy wrappers, a launchd plist, a node-version-pinned daemon, and a `start` command that silently re-breaks the proxy. | **One-command install**: `install-deps.sh` pulls the upstream from npm; `install.sh` wires the wrappers + plist + daemon the safe way and auto-recovers the first-start race. |
| **The operational gotchas aren't written down.** Group setup, mention-free delivery, workspace binding, 403/`CONNECT` debugging. | An **ops playbook** in [docs/](docs/) — [groups & mention-free](docs/group-setup.md), [workspaces](docs/workspaces.md), [troubleshooting](docs/troubleshooting.md). |

## Who this is for

You run Claude Code from Feishu via `lark-channel-bridge`, and you **must reach
Anthropic through an outbound HTTP proxy** while Feishu (a domestic CN service)
must stay **direct**. The bridge alone breaks in that setup; this toolkit fixes it
cleanly. If you don't need a proxy, you may only want the `/ctx` command and the docs.

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
