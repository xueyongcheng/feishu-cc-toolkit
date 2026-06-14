#!/bin/sh
# Keep Feishu API traffic DIRECT even when lark-cli is invoked by the proxied
# `claude` child (which exports http(s)_proxy). Strips every proxy var and
# flags lark-cli to skip proxying, so bot-identity / chat calls don't get
# routed through the overseas proxy and reset.
#
# LARK_CLI_BIN is provided by the daemon environment (set in the plist).
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
export LARK_CLI_NO_PROXY=1
exec "${LARK_CLI_BIN:-/opt/homebrew/bin/lark-cli}" "$@"
