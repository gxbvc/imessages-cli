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
echo 'Costs $23' | imessages-cli send-group <chat_id> --stdin  # Pipe message from stdin
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
- **VCF attachments didn't send** (before 2026-09-27): `.vcf` files showed "(!)" in Messages.app. The failed rows had the same sandbox cause as below (file in `~/projects`, `transfer_state=6`). Not retested since the staging fix.

## Media over SMS/MMS (regression note, 2026-09-27)

- **Bug**: `send --sms --file /tmp/x.jpg` returned `ok:true`, but nothing reached the phone. imagent (the Messages daemon) is sandboxed and logs `open on /tmp/x.jpg: Operation not permitted`. chat.db then shows `message.error=4`, `is_sent=0`, `attachment.transfer_state=6`, and `attachment.filename` still at the original path. It affected iMessage and RCS file sends from `/tmp` and `~/projects` too.
- **Fix**: the CLI copies each file to `~/Library/Messages/Attachments/imessages-cli/<uuid>/` before it sends. Do not delete those copies, because `attachment.filename` points at them. Then it polls chat.db. Success is `is_sent=1`, `error=0`, and `transfer_state=5` on every new outgoing message. `SEND_FAILED` means Messages marked it failed. `SEND_UNCONFIRMED` means it was still pending after `--wait` (default 60 s). Check `imessages-cli thread <contact>` before you retry, so you do not send twice.
- **Send media over SMS**: `imessages-cli send +1XXXXXXXXXX "caption" --sms --file /path/a.jpg`. The caption goes as its own SMS, then the file as an MMS. The iPhone converts `.m4a` audio to `audio/amr` for MMS.
- **Verify on the receiving side** (GXB Twilio test number only, never a live number or a person): `twilio api:core:messages:list --to +18177977334 --from +18176685828 --limit 5 -o json`. Look for an `MM...` sid with `numMedia` of 1. Get the content type with `twilio api:core:messages:media:list --message-sid MM... -o json`.
- **Self-check**: `ruby test_send.rb` covers the failed, pending, and sent states. Details: `plans/fix-sms-attachments.md`.
