# Group setup & mention-free delivery

Notes for running the bridge in Feishu **group chats** (vs. 1:1 DM). DM needs
none of this — a bot always receives DMs.

## Allowing a group

`access.allowedChats` empty = **all chats allowed**. Just add the bot to the
group and it works. (This is separate from mention-free delivery below: allowing
is "is this chat permitted", mention-free is "will Feishu even push non-@
messages".)

## Mention-free delivery (both sides required)

By default a Feishu group only delivers **@bot** messages to the bot. To let the
bot see every message, you need **both** of:

1. **Bridge side** — set `requireMentionInGroup: false` for the profile (in
   `config.json`, or `/config` in chat; restart to apply).
2. **Feishu side (easy to miss)** — in the Feishu open platform, grant the app
   `im:message.group_msg` ("read all messages in groups") **and publish a new
   version**, then `restart` the bridge so the long connection re-subscribes.

Doing only (1) does nothing: the bridge config says `false` but Feishu still
won't push non-@ messages, and you won't even see an intake entry in the log.

**Diagnosis:** in-group @ works but non-@ gets no response *and* the log shows no
intake → you're missing (2).

> Only do this for **private** groups (just you + bot). For groups with other
> people, keep `requireMentionInGroup: true` so the bot doesn't react to
> everything.

## Letting the bot create/manage groups

To have the bot create groups and read members, grant the app these scopes **and
publish** (checking the scope without publishing is not enough — you'll get
`app_scope_not_applied` until you publish + restart):

- `im:chat`, `im:chat:readonly`, `im:chat.group_info:readonly`,
  `im:chat.members:read`

Then (via `lark-cli`, with the bot identity configured):

```
lark-cli im +chat-create --as bot --name "CC·foo" --type private \
  --users <ou_...> --owner <ou_...> --set-bot-manager      # returns chat_id
lark-cli im +chat-list --as bot                            # list groups
lark-cli im chat.members get --params '{"chat_id":"..."}'  # read members
lark-cli im +chat-update --chat-id <id> --name "CC·bar"    # rename
```

Note the two arg styles: `+chat-*` subcommands use individual flags, while
`chat.members get` uses a `--params` JSON blob. Don't mix them.

## A clean topology

One business line ↔ one group ↔ one working directory. This keeps chat→cwd
routing simple and keeps each project's context (and any memory the agent
writes) from bleeding across projects. See [`workspaces.md`](workspaces.md) for
how the cwd binding works.

> Placeholders like `<ou_...>` are Feishu `open_id`s — find your own in the
> daemon log: `intake.sender` is the human, `ws.connected` is the bot itself.
