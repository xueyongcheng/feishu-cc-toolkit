# Troubleshooting

## `403 Request not allowed` from claude (in chat or `claude -p test`)

The claude child reached Anthropic **without** the proxy. Almost always the
plist lost the wrapper PATH or `PROXY_HTTP`:

```bash
/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" \
  ~/Library/LaunchAgents/ai.lark-channel-bridge.bot.<profile>.plist
```

- First segment of `PATH` should be `~/.lark-channel/bin`. If it's
  `~/.local/bin` (or anything else), a bare `lark-channel-bridge start` rewrote
  the plist. Fix: re-run `scripts/install.sh`.
- `PROXY_HTTP` / `CLAUDE_BIN` keys should be present and correct.

Most common cause: you ran a bare `start` from a proxied shell. Use `restart` or
the installer instead — see [`proxy-split.md`](proxy-split.md).

## Feishu connect fails: `CONNECT` / `could not resolve bot identity`

The bridge is running **with** a proxy. The daemon log shows
`channel: proxy detected`. The daemon must have **no** `http(s)_proxy`. Re-run
`scripts/install.sh` (it strips proxy from the daemon and injects it only into
the claude child).

## In-group @ works, but non-@ messages get no response

Feishu isn't pushing non-@ messages — the daemon log has no intake entry. You're
missing the `im:message.group_msg` scope (+ publish + restart). Bridge-side
`requireMentionInGroup: false` alone is not enough. See
[`group-setup.md`](group-setup.md).

## `app_scope_not_applied` when using bot scopes

You checked the scope but didn't **publish a new app version**. Publish, then
`restart` the bridge.

## Edits to `workspaces.json` keep disappearing

You edited it while the daemon was running and it got written back from memory.
Stop the daemon → edit → `restart`. See [`workspaces.md`](workspaces.md).

## `lark-cli` rejected with an Agent-context error

Run it via the wrapper (`~/.lark-channel/bin/lark-cli`, which strips the proxy),
and clear `OPENCLAW_HOME` / `HERMES_HOME` first if you have them set — otherwise
lark-cli thinks it's running inside an agent context and refuses:

```bash
env -u OPENCLAW_HOME -u HERMES_HOME ~/.lark-channel/bin/lark-cli ...
```

## Daemon dies after a node upgrade

The plist pinned a versioned Cellar node path that no longer exists. Set
`NODE_BIN=/opt/homebrew/opt/node@22/bin/node` (a stable symlink) in `.env` and
re-run `scripts/install.sh`. The installer prefers the stable symlink by default.
