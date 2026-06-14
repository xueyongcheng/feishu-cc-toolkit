#!/bin/sh
# Proxy-injecting wrapper for `claude`, used by lark-channel-bridge.
#
# Why this exists:
#   @larksuite/channel force-proxies EVERY Feishu request the moment it detects
#   http(s)_proxy in the environment (it ignores no_proxy / all_proxy). Feishu is
#   a domestic CN service, so routing it through an overseas proxy gets the
#   CONNECT tunnel reset. The bridge daemon therefore runs with NO proxy.
#   But `claude` talking to Anthropic REQUIRES the proxy (direct hits a 403
#   geo wall). The two share the same http(s)_proxy var name, so the only clean
#   separation is at the process level — here.
#
# PROXY_HTTP and CLAUDE_BIN are provided by the daemon environment (set in the
# launchd plist by scripts/install.sh). Do not hardcode them.
: "${PROXY_HTTP:?claude.wrapper: PROXY_HTTP not set}"
export http_proxy="$PROXY_HTTP" https_proxy="$PROXY_HTTP"
export HTTP_PROXY="$PROXY_HTTP" HTTPS_PROXY="$PROXY_HTTP"
exec "${CLAUDE_BIN:-$HOME/.local/bin/claude}" "$@"
