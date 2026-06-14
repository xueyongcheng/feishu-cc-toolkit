#!/usr/bin/env bash
set -euo pipefail

# feishu-cc-toolkit installer.
#
# Installs the proxy-split wrappers, ctx.sh, the /ctx slash command, and a
# launchd daemon that runs lark-channel-bridge WITHOUT proxy while injecting the
# proxy only into the `claude` child. See docs/proxy-split.md for the why.
#
# Safe to re-run: it reloads the daemon from the generated plist. It does NOT
# run a bare `lark-channel-bridge start`, which would rewrite the plist from the
# current shell env and bake a proxy into the bridge (the 403 footgun).

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LARK_HOME="${LARK_CHANNEL_HOME:-$HOME/.lark-channel}"
WRAPPER_DIR="$LARK_HOME/bin"

# ---- load config ----
if [ -f "$REPO/.env" ]; then
  set -a; . "$REPO/.env"; set +a
else
  echo "ERROR: $REPO/.env not found. Copy .env.example -> .env and fill it."; exit 1
fi

PROFILE="${PROFILE:-claude}"
PROXY_HTTP="${PROXY_HTTP:-}"
[ -n "$PROXY_HTTP" ] || { echo "ERROR: PROXY_HTTP not set in .env"; exit 1; }

# ---- detect binaries (never pick our own wrapper dir) ----
detect() { command -v "$1" 2>/dev/null | grep -v "^$WRAPPER_DIR/" | head -1; }
CLAUDE_BIN="${CLAUDE_BIN:-$(detect claude || true)}"
LARK_CLI_BIN="${LARK_CLI_BIN:-$(detect lark-cli || true)}"
BRIDGE_BIN="${BRIDGE_BIN:-$(detect lark-channel-bridge || true)}"
NODE_BIN="${NODE_BIN:-}"
if [ -z "$NODE_BIN" ]; then
  # Prefer a STABLE symlink over a pinned Cellar path (survives node upgrades).
  for c in /opt/homebrew/opt/node@22/bin/node /opt/homebrew/bin/node "$(command -v node || true)"; do
    [ -n "$c" ] && [ -x "$c" ] && { NODE_BIN="$c"; break; }
  done
fi

for v in CLAUDE_BIN LARK_CLI_BIN BRIDGE_BIN NODE_BIN; do
  eval "val=\${$v:-}"
  if [ -z "$val" ] || [ ! -x "$val" ]; then
    echo "ERROR: $v not found or not executable: '${val:-}'. Set it explicitly in .env."; exit 1
  fi
done
NODE_DIR="$(dirname "$NODE_BIN")"

echo "Installing with:"
printf '  %-12s = %s\n' PROFILE "$PROFILE" PROXY_HTTP "$PROXY_HTTP" \
  CLAUDE_BIN "$CLAUDE_BIN" LARK_CLI_BIN "$LARK_CLI_BIN" \
  BRIDGE_BIN "$BRIDGE_BIN" NODE_BIN "$NODE_BIN"

# ---- install wrappers + ctx + slash command ----
mkdir -p "$WRAPPER_DIR" "$LARK_HOME/profiles/$PROFILE/logs/daemon" "$HOME/.claude/commands"
install -m 0755 "$REPO/bin/claude.wrapper.sh"   "$WRAPPER_DIR/claude"
install -m 0755 "$REPO/bin/lark-cli.wrapper.sh" "$WRAPPER_DIR/lark-cli"
install -m 0755 "$REPO/scripts/ctx.sh"          "$LARK_HOME/ctx.sh"
install -m 0644 "$REPO/commands/ctx.md"         "$HOME/.claude/commands/ctx.md"

# ---- generate launchd plist from template ----
PLIST="$HOME/Library/LaunchAgents/ai.lark-channel-bridge.bot.$PROFILE.plist"
sed -e "s#__PROFILE__#$PROFILE#g" \
    -e "s#__NODE_BIN__#$NODE_BIN#g" \
    -e "s#__NODE_DIR__#$NODE_DIR#g" \
    -e "s#__BRIDGE_BIN__#$BRIDGE_BIN#g" \
    -e "s#__WRAPPER_DIR__#$WRAPPER_DIR#g" \
    -e "s#__LARK_CHANNEL_HOME__#$LARK_HOME#g" \
    -e "s#__PROXY_HTTP__#$PROXY_HTTP#g" \
    -e "s#__CLAUDE_BIN__#$CLAUDE_BIN#g" \
    -e "s#__LARK_CLI_BIN__#$LARK_CLI_BIN#g" \
    "$REPO/launchd/ai.lark-channel-bridge.bot.profile.plist.template" > "$PLIST"
echo "Wrote $PLIST"

# ---- (re)load daemon ----
UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/ai.lark-channel-bridge.bot.$PROFILE" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "Loaded daemon ai.lark-channel-bridge.bot.$PROFILE"

cat <<EOF

Done. Verify:
  1. lark-channel-bridge status
  2. tail -n 40 "$LARK_HOME/profiles/$PROFILE/logs/daemon/daemon-stderr.log"
       expect: 'ws/connected' + 'chats-fetched', and NO 'channel: proxy detected'
  3. "$WRAPPER_DIR/claude" -p test        # end-to-end; must NOT return a 403
EOF
