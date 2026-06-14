# Workspace binding (chat → working directory)

How each chat gets pinned to a working directory, and the one footgun that will
silently wipe your edits.

## Where the binding lives

`~/.lark-channel/profiles/<profile>/workspaces.json`:

```jsonc
{
  "chats": {
    "<chat_id>": { "cwd": "/abs/path/to/project" }   // per-chat pin
  },
  "named": {
    "myproj": "/abs/path/to/project"                 // NOTE: bare path string
  }
}
```

- `chats` maps a `chat_id` to `{ "cwd": ... }`. Set in-chat with `/cd <path>`.
  Permanent, survives restarts.
- `named` maps a name to a **bare path string** (different shape from `chats` —
  don't write `{cwd}` here). Use `/ws use <name>` in a chat to bind it, `/ws` to
  list, `/ws save <name>` to store the current cwd.

`sessions.json` is **not** where cwd lives — it's only the "currently active
session" pointer. Don't pre-seed cwd there: an entry with a cwd but no sessionId
is ignored/cleaned by the bridge, and the first message still lands in the
default working dir.

## Pre-binding before a group exists

Chicken-and-egg: you can't write a `chats` entry without a `chat_id`, and you
don't have the `chat_id` until the group exists. Solution: pre-fill `named` with
a batch of names → paths. After creating the group, one `/ws use <name>` in it
binds the cwd and resets the session to that dir — no need to go back and fill in
the `chat_id`.

## The footgun: edit the file with the daemon running

The bridge `load()`s the **entire** `workspaces.json` into memory at startup
(a `WorkspaceStore`). Every later `/cd`, `/ws save`, `/ws use` writes the **whole
in-memory copy back** to the file. So if you hand-edit the file while the daemon
is running, your edit gets **clobbered** by the next write-back.

**Correct procedure:** stop the daemon → edit → start (start re-reads from disk).

But "start" has its own trap — do **not** use a bare `lark-channel-bridge start`,
which rewrites the plist from your shell env and reintroduces the proxy / drops
the wrapper PATH (→ 403, see [`proxy-split.md`](proxy-split.md)). Either:

1. `lark-channel-bridge restart` (reuses the plist, re-reads disk — safest), or
2. re-run this toolkit's `scripts/install.sh` (regenerates the plist correctly).

After either, re-check the plist `PATH` first segment is the wrapper dir, then
`~/.lark-channel/bin/claude -p test` to confirm no 403.

## cwd ≠ topic scope

The cwd only decides where file operations land and which `CLAUDE.md` loads. It
does **not** fence what the agent will talk about — ask about something stored
elsewhere and it'll still answer across projects. To narrow scope, name the
project in your question.
