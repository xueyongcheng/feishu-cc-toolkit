#!/bin/sh
# Report the context usage of the CURRENT Feishu/Claude-Code session.
# Run on demand by the `claude` running inside lark-channel-bridge.
#
# How it works: claude writes a `usage` block into the session transcript (JSONL)
# every turn. We take the last main-chain assistant turn's
#   input + cache_read + cache_creation
# tokens (= current context footprint) and compare against the model window.
python3 - "$CLAUDE_CODE_SESSION_ID" <<'PY'
import json, os, sys, glob
sid = sys.argv[1] if len(sys.argv) > 1 else ''
base = os.path.expanduser('~/.claude/projects')
if not sid:
    print('Cannot determine current session: CLAUDE_CODE_SESSION_ID is missing.'); raise SystemExit
hits = glob.glob(f'{base}/*/{sid}.jsonl')
if not hits:
    print('No transcript for this session yet — likely the first message of a new session.'); raise SystemExit
f = max(hits, key=os.path.getmtime)
last, model = None, None
for line in open(f, encoding='utf-8', errors='replace'):
    try: d = json.loads(line)
    except: continue
    if d.get('isSidechain'): continue          # ignore sub-agent side chains
    m = d.get('message', {}) or {}
    u = m.get('usage')
    if u and m.get('role') == 'assistant':
        last, model = u, m.get('model', model)
if not last:
    print('No usage recorded in this session yet (just started).'); raise SystemExit
used = (last.get('input_tokens', 0)
        + last.get('cache_read_input_tokens', 0)
        + last.get('cache_creation_input_tokens', 0))
# Native `claude` (incl. via the bridge) defaults to a large window; assume 1M
# unless the model is a known small-window one. Bump up if usage exceeds the guess.
ml = (model or '').lower()
if any(k in ml for k in ['glm', 'deepseek-v3', 'deepseek-r1']): limit = 131072
elif any(k in ml for k in ['qwen', 'kimi']):                    limit = 262144
else:                                                           limit = 1000000
if used > limit: limit = 1000000
pct = used / limit * 100
filled = max(0, min(10, int(pct / 10)))
bar = '█' * filled + '░' * (10 - filled)
if   pct < 50: tip = 'plenty left'
elif pct < 70: tip = 'over half — keep an eye on it'
elif pct < 85: tip = 'getting high — consider /new soon (save anything valuable first)'
else:          tip = 'near the limit — strongly consider /new'
print(f'context {bar} {pct:.0f}%   ~{used:,} / {limit:,} tokens')
print(f'model {model} | {tip}')
PY
