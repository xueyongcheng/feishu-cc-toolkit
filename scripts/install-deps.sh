#!/usr/bin/env bash
set -euo pipefail

# Install the upstream dependencies this toolkit sits on top of. Both come from
# npm — you do NOT need to git-clone any upstream repo; npm pulls them for you.
#
#   - lark-channel-bridge   the Feishu <-> Claude Code bridge, by zarazhangrui (MIT)
#                           https://github.com/zarazhangrui/feishu-claude-code-bridge
#   - @larksuite/cli        the bridge shells out to it for bot identity (hard dep)
#
# This does NOT install Claude Code itself or a proxy — see docs/install-from-scratch.md
# for the full prerequisite list.

command -v node >/dev/null 2>&1 || { echo "ERROR: node not found. Install Node >= 20.12 first."; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "ERROR: need Node >= 20.12.0 (have $(node -v))."; exit 1
fi

echo "Installing upstream deps globally via npm:"
echo "  lark-channel-bridge  (zarazhangrui, MIT) + @larksuite/cli"
npm i -g lark-channel-bridge @larksuite/cli

echo
echo "Installed:"
command -v lark-channel-bridge >/dev/null 2>&1 && echo "  lark-channel-bridge: $(command -v lark-channel-bridge)" || echo "  WARNING: lark-channel-bridge still not on PATH"
command -v lark-cli           >/dev/null 2>&1 && echo "  lark-cli:            $(command -v lark-cli)"           || echo "  WARNING: lark-cli still not on PATH"

cat <<'EOF'

Next steps (the QR binding is interactive and can't be automated):
  1. Bind a Feishu bot:
       env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
         lark-channel-bridge run --profile claude --agent claude
     Scan the QR, create a NEW PersonalAgent app, then Ctrl-C once config is written.
  2. Configure + install this toolkit:
       cp .env.example .env   # set PROXY_HTTP
       bash scripts/install.sh

Full guide: docs/install-from-scratch.md
EOF
