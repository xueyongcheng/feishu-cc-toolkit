#!/usr/bin/env bash
set -euo pipefail

# Remove toolkit-installed files and unload the daemon.
# Leaves your bridge config (config.json, workspaces.json, profiles, logs) intact.
# Usage: scripts/uninstall.sh [profile]   (default profile: claude)

PROFILE="${1:-claude}"
LARK_HOME="${LARK_CHANNEL_HOME:-$HOME/.lark-channel}"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/ai.lark-channel-bridge.bot.$PROFILE" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/ai.lark-channel-bridge.bot.$PROFILE.plist"
rm -f "$LARK_HOME/bin/claude" "$LARK_HOME/bin/lark-cli" "$LARK_HOME/ctx.sh"
rm -f "$HOME/.claude/commands/ctx.md"

echo "Removed toolkit files for profile '$PROFILE'."
echo "Left intact: $LARK_HOME/config.json, workspaces.json, profiles/, logs/."
