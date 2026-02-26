# imessages

CLI for reading and sending iMessages on macOS. Reads directly from the Messages SQLite database for fast queries, and uses AppleScript for sending.

## Requirements

- macOS with Full Disk Access granted to your terminal (for reading `~/Library/Messages/chat.db`)
- Ruby (via rbenv or system)
- Messages.app (for sending via AppleScript)

## Setup

```bash
cd ~/tools/imessages
bundle install
ln -sf ~/tools/imessages/imessages ~/bin/imessages
```

## Usage

### List recent conversation threads

```bash
imessages threads                          # 20 most recent threads
imessages threads --limit 10               # Limit results
imessages threads --since "2025-01-01"     # Only threads with messages after date
```

### View messages with a contact

```bash
imessages thread "+18175551234"            # By phone number
imessages thread "Justin Genco"            # By contact name (Contacts.app lookup)
imessages thread "ricky"                   # By alias (from aliases.yml)
imessages thread "ricky" --limit 100       # More messages
imessages thread "ricky" --since "2025-06-01"
```

### Search messages

```bash
imessages search "dinner"                  # Search all messages
imessages search "dinner" --limit 10       # Limit results
imessages search "dinner" --from "ricky"   # Filter by sender
```

### Send a message

```bash
imessages send "+18175551234" "Hello!"     # By phone number
imessages send "Justin Genco" "Hey!"       # By contact name
imessages send "ricky" "What's up?"        # By alias
imessages send "ricky" --sms "Hey!"        # Send as SMS/RCS (for Android contacts)
```

#### Sending messages with dollar signs or special characters

Use `--stdin` to pipe the message via stdin. This avoids bash shell expansion which eats `$` signs (e.g., `$23` becomes `3`):

```bash
echo 'Party packages start at $219' | imessages send "+18175551234" --stdin
```

Note: Messages.app will briefly activate when sending.

### Group chats

```bash
imessages chats --limit 10                 # List all chats (DMs + groups)
imessages chat 1054 --limit 20             # View messages in a specific chat
imessages send-group 1054 "Hello everyone" # Send to a group chat
```

### Contact lookup

```bash
imessages contacts "Justin"                # Search Contacts.app
imessages aliases                          # Show configured aliases
```

## Aliases

Create `aliases.yml` in the tool directory for quick contact shortcuts:

```yaml
# Simple format
mom: "+18175551234"

# Detailed format
justin:
  phone: "+16823012552"
  name: "Justin Genco"
```

Aliases are checked before Contacts.app, so they also serve as disambiguation (e.g., "ricky" → Ricky Bureau, not Ricky Mouser).

The `aliases.yml` file is gitignored since it contains personal information.

## Output

All commands output JSON to stdout with `{ok: true, data: ...}` on success or `{ok: false, error: ..., code: ...}` on failure. Pipe through `python3 -m json.tool` for pretty-printing.

## How it works

- **Reading**: Direct SQLite queries against `~/Library/Messages/chat.db` (read-only)
- **Sending**: AppleScript via `osascript` to Messages.app
- **Contact resolution**: AppleScript queries to Contacts.app, with alias file override
- **Name resolution**: Phone numbers in message threads are resolved to contact names via Contacts.app
