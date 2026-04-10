# imessages-cli

CLI for reading and sending iMessages. Reads from `~/Library/Messages/chat.db` (SQLite) for queries, AppleScript for sending.

Use the `imessages-cli` binary in PATH. For `send`, **do not** use `--text` or `--phone` flags — usage is positional: `imessages-cli send <contact> [message]`.

## Commands

```bash
imessages-cli threads [--limit 20] [--since DATE]       # List conversation threads (1:1, sorted by recency)
imessages-cli thread <contact> [--limit 50] [--since D]  # Message history with a contact
imessages-cli search <query> [--limit 20] [--from C]     # Full-text search across messages
imessages-cli send <contact> "message"                    # Send a message (1:1)
imessages-cli send <contact> "message" --sms             # Send as SMS/RCS directly (for Android contacts)
imessages-cli send <contact> --file /path/to/image.png    # Send attachment only
imessages-cli send <contact> "caption" --file /tmp/a.png  # Text + attachment
imessages-cli send <contact> "hi" --file a.png --file b.jpg  # Multiple attachments
echo 'Costs $23' | imessages-cli send <contact> --stdin  # Pipe message from stdin (use for $ signs or special chars)
imessages-cli send-group <chat_id> "message"              # Send to a group chat
imessages-cli send-group <chat_id> --file /path/to/doc.pdf  # Attachment to group
imessages-cli chats [--limit 20]                          # List all chats (DMs + groups)
imessages-cli chat <chat_id> [--limit 50] [--since D]     # Messages in a specific chat
imessages-cli contacts <query>                             # Search Contacts.app by name
imessages-cli aliases                                      # Show configured aliases
```

## Contact Resolution

`<contact>` can be:
1. **Phone number**: `+15551234567` — used directly (preferred; see phone numbers in `~/AGENTS.md` Frequent Contacts)
2. **Contact name**: `"Jane Doe"` — searched in Contacts.app. If ambiguous, returns all matches with phone numbers.

## Output

JSON to stdout. `{ok: true, data: ...}` on success, `{ok: false, error: ..., code: ...}` on failure.

Threads include `contact_name` resolved from Contacts.app. Group chats include `sender_name` for each message.

## Notes

- **Read-only DB access**: never writes to chat.db
- **Send activates Messages.app**: AppleScript briefly brings Messages to foreground
- **Group chat IDs**: get these from `imessages-cli chats`; use with `chat` and `send-group`
- **Attachments**: message objects include `attachments` array with filename, mime_type, bytes when present
- **Dollar signs in messages**: bash eats `$` in double-quoted args (e.g., `"$23"` → `"3"`). Use `--stdin` to pipe the message: `echo 'Costs $23' | imessages-cli send <contact> --stdin`
- **VCF attachments don't send**: AppleScript-based sending fails silently for `.vcf` (vCard) files — the message shows "(!)" in Messages.app. Drag-and-drop in the Messages UI works fine. This may affect other non-media file types too.
