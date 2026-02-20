# imessages

CLI for reading and sending iMessages. Reads from `~/Library/Messages/chat.db` (SQLite) for queries, AppleScript for sending.

## Commands

```bash
imessages threads [--limit 20] [--since DATE]       # List conversation threads (1:1, sorted by recency)
imessages thread <contact> [--limit 50] [--since D]  # Message history with a contact
imessages search <query> [--limit 20] [--from C]     # Full-text search across messages
imessages send <contact> "message"                    # Send a message (1:1)
imessages send-group <chat_id> "message"              # Send to a group chat
imessages chats [--limit 20]                          # List all chats (DMs + groups)
imessages chat <chat_id> [--limit 50] [--since D]     # Messages in a specific chat
imessages contacts <query>                             # Search Contacts.app by name
imessages aliases                                      # Show configured aliases
```

## Contact Resolution

`<contact>` can be:
1. **Phone number**: `+18175551234` — used directly
2. **Alias**: `ricky` — resolved via `aliases.yml` (checked first, disambiguates common names)
3. **Contact name**: `"Justin Genco"` — searched in Contacts.app. If ambiguous, returns all matches with phone numbers.

## Aliases

Stored in `~/tools/imessages/aliases.yml` (gitignored). Format:

```yaml
justin:
  phone: "+16823012552"
  name: "Justin Genco"
ricky:
  phone: "+12144152357"
  name: "Ricky Bureau"
```

## Output

JSON to stdout. `{ok: true, data: ...}` on success, `{ok: false, error: ..., code: ...}` on failure.

Threads include `contact_name` resolved from Contacts.app. Group chats include `sender_name` for each message.

## Notes

- **Read-only DB access**: never writes to chat.db
- **Send activates Messages.app**: AppleScript briefly brings Messages to foreground
- **Group chat IDs**: get these from `imessages chats`; use with `chat` and `send-group`
- **Attachments**: message objects include `attachments` array with filename, mime_type, bytes when present
