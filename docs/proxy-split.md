# Proxy-split: running the bridge behind an outbound proxy

This is the core problem `feishu-cc-toolkit` solves. If you don't need an
outbound proxy to reach Anthropic, you may not need this toolkit at all — the
upstream bridge works fine on its own.

## Symptom

With `http_proxy` / `https_proxy` exported, `lark-channel-bridge` fails to reach
Feishu:

```
Proxy connection ended before receiving CONNECT response
could not resolve bot identity via /open-apis/bot/v3/info
```

…and the daemon log shows `channel: proxy detected`.

## Root cause

Two services with opposite proxy needs are forced to share the same env vars:

- **Feishu** (`@larksuite/channel`, the SDK the bridge depends on) will
  unconditionally wrap **every** Feishu request in an axios proxy the moment it
  sees `http(s)_proxy`. It reads **only** `http(s)_proxy` — it ignores `no_proxy`
  **and** `all_proxy`. Feishu is a domestic CN service, so forcing it through an
  overseas proxy gets the CONNECT tunnel reset. A `NO_PROXY` allowlist does
  nothing here.
- **Claude** (`claude` → Anthropic) **must** use the proxy (a direct connection
  hits a 403 geo wall). It honors `http(s)_proxy` but **not** `all_proxy` (a
  socks-only `all_proxy` still 403s).

Both read the same `http(s)_proxy` variable name, so you cannot separate them
with env-var allowlists. The only clean boundary is **per-process**.

## The fix

Run the **bridge daemon with no proxy** (Feishu connects directly — it's
domestic, so it works), and inject the proxy **only into the `claude` child**:

- `bin/claude.wrapper.sh` → installed as `~/.lark-channel/bin/claude`. Exports
  `http(s)_proxy=$PROXY_HTTP`, then `exec`s the real `claude`.
- `bin/lark-cli.wrapper.sh` → installed as `~/.lark-channel/bin/lark-cli`. Clears
  every proxy var and sets `LARK_CLI_NO_PROXY=1`, so when the proxied claude
  child shells out to `lark-cli` (bot identity / chat calls) those go direct.
- The launchd plist puts `~/.lark-channel/bin` **first** on `PATH` (bridge calls
  the wrappers) and carries **no** `http(s)_proxy` of its own. `PROXY_HTTP`,
  `CLAUDE_BIN`, `LARK_CLI_BIN` live in the plist's `EnvironmentVariables` and are
  consumed by the wrappers.

`scripts/install.sh` wires all of this up from your `.env`.

## Why not just `lark-channel-bridge start`?

A bare `start` **rewrites the plist from your current shell environment**. That
(a) bakes whatever `http(s)_proxy` your terminal has into the bridge → Feishu
breaks again, and (b) drops the wrapper dir from the front of `PATH` → the claude
child runs the real binary with no proxy → **403 Request not allowed**.

So: after editing config, prefer `lark-channel-bridge restart` (reuses the
existing plist), or re-run `scripts/install.sh` (regenerates the plist
correctly). Never a bare `start` from a proxied shell.

## Verifying

- `lark-channel-bridge status` → running.
- Daemon log shows `ws/connected` + `chats-fetched`, and **no**
  `channel: proxy detected`.
- The plist's `EnvironmentVariables:PATH` first segment is your wrapper dir, and
  there is no `http(s)_proxy` key.
- `~/.lark-channel/bin/claude -p test` → returns a reply, **not** a 403.

> The port in `.env` (`PROXY_HTTP`) is whatever your local proxy listens on.
> If it ever changes, update `.env` and re-run `scripts/install.sh`.
