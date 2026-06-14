# Install from scratch (clean machine, behind a proxy)

End-to-end setup on a machine that has **nothing** yet, for the proxy-split case:
you reach Anthropic through a local HTTP proxy, and Feishu must stay direct.

> **Do you even need this toolkit?** If this machine can reach Anthropic
> **directly** (e.g. outside CN), you don't need the proxy-split part — install
> the [upstream bridge][upstream] alone. This toolkit only earns its keep when a
> proxy is mandatory for Claude but breaks Feishu.

## 0. The make-or-break check first

Everything downstream depends on `claude` being able to reach Anthropic **through
your proxy**. Verify that before anything else:

```bash
HTTPS_PROXY=http://127.0.0.1:6152 https_proxy=http://127.0.0.1:6152 \
  claude -p "say hi"        # must reply — NOT 403, NOT a hang
```

Replace `6152` with your proxy's port. If this 403s or hangs, fix your proxy /
Claude login first; the toolkit can't help until this passes.

## 1. Prerequisites + this toolkit's deps

```bash
node -v                       # need >= 20.12.0
claude --version              # Claude Code installed AND logged in

# Get this toolkit, then let it pull the upstream deps from npm:
git clone https://github.com/xueyongcheng/feishu-cc-toolkit
cd feishu-cc-toolkit
bash scripts/install-deps.sh  # installs zarazhangrui's lark-channel-bridge +
                              # @larksuite/cli from npm (no repo to clone yourself)
```

> You do **not** git-clone the upstream bridge. It's published on npm as
> `lark-channel-bridge`; `install-deps.sh` (or `npm i -g lark-channel-bridge`)
> pulls it for you. Source & credit: [CREDITS.md](../CREDITS.md).

You also need a **local HTTP proxy already running** that can reach Anthropic
(note its address, e.g. `http://127.0.0.1:6152`).

## 2. Bind the Feishu bot — run the wizard WITHOUT proxy

The first run is a QR wizard that talks to **Feishu**, which must stay direct.
Run it in a proxy-stripped shell so the Feishu binding doesn't get proxied:

```bash
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
  lark-channel-bridge run --profile claude --agent claude
```

1. Scan the terminal QR with the Feishu app.
2. **Create a new PersonalAgent app** when prompted (recommended — see note below).
3. Once it says the config was written (`~/.lark-channel/config.json`), press
   `Ctrl-C`. Don't bother testing messages here — `claude` has no proxy in this
   shell and would 403. The wizard's only job is the QR binding.

> **Running on a second machine?** A Feishu app's long connection doesn't like
> being opened from two machines at once — events can get delivered to the wrong
> one. For a trial, **create a separate PersonalAgent app** here (the wizard does
> it) so it's fully isolated from your other machine's bot. If you must reuse the
> same app (`run --app-id cli_xxx`), only run **one** bridge at a time.

## 3. Install the toolkit (proxy-split + daemon)

You already cloned it in Step 1, so from inside the repo:

```bash
cp .env.example .env
$EDITOR .env                  # set PROXY_HTTP to your proxy; set NODE_BIN if you
                              # use nvm / non-Homebrew node (need a stable abs path)
bash scripts/install.sh
```

`install.sh` writes the proxy-split wrappers to `~/.lark-channel/bin`, installs
`ctx.sh` and the `/ctx` command, generates a launchd plist (bridge runs with **no**
proxy; the proxy is injected only into the `claude` child), and loads the daemon.

> Do **not** run a bare `lark-channel-bridge start` after this. It would rewrite
> the plist from your shell env and reintroduce the proxy / drop the wrapper PATH
> (→ 403). The daemon is already managed by the plist `install.sh` generated; use
> `lark-channel-bridge restart` or re-run `install.sh` to apply changes.

## 4. Verify

```bash
lark-channel-bridge status                 # should show a running PID
tail -n 40 ~/.lark-channel/profiles/claude/logs/daemon/daemon-stderr.log
                                           # expect ws/connected + chats-fetched
                                           # and NO 'channel: proxy detected'

# End-to-end proxy check. NOTE: the wrapper gets PROXY_HTTP from the plist, not
# your shell — running it bare errors "PROXY_HTTP not set", which is EXPECTED and
# does NOT mean a broken install. To actually test, set it inline:
PROXY_HTTP=http://127.0.0.1:7897 ~/.lark-channel/bin/claude -p test   # replies, NOT 403
```

> **If `status` shows the job but no PID** (and the daemon log dir is empty): the
> first launch raced the wizard's lock release and exited cleanly. `install.sh`
> already does a `kickstart -k` to handle this, but if it still shows no PID, run
> `lark-channel-bridge restart` once and re-check. This is a one-time first-start
> quirk, not a misconfiguration.

Then in Feishu, **DM the bot** — it should reply via your local Claude Code.
Try `/status`, `/help`, and `/ctx`.

## 5. Groups (optional)

DM works out of the box. For group chats, mention-free delivery, and one
group ↔ one working directory, see [group-setup.md](group-setup.md).

## 6. Trouble?

See [troubleshooting.md](troubleshooting.md) — the common ones are a `403`
(plist lost the wrapper PATH / proxy) and Feishu `CONNECT` failures (the daemon
is running with a proxy it shouldn't have).

## 7. Teardown

```bash
bash scripts/uninstall.sh            # removes wrappers, /ctx, daemon
# your bridge config (~/.lark-channel/config.json, workspaces.json) is kept
```

[upstream]: https://github.com/zarazhangrui/feishu-claude-code-bridge
