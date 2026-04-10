# Plan: Add Attachment Support to imessages-cli

## Goal

Add the ability to send image/file attachments via iMessage, both for 1:1 and group chats.

## Current State

- `imessages send <contact> <message>` — text only
- `imessages send-group <chat_id> <message>` — text only
- Reading attachments already works (thread/chat commands return `attachments` array with filename, mime_type, bytes)
- Send uses AppleScript `send "text" to targetBuddy`

## AppleScript Approach

macOS Messages.app supports sending files via AppleScript using `POSIX file`:

```applescript
tell application "Messages"
  set targetService to 1st account whose service type = iMessage
  set targetBuddy to participant "+15551234567" of targetService
  send POSIX file "/path/to/image.png" to targetBuddy
end tell
```

This already works — we used it manually during testing. It just needs to be wired into the CLI.

## Implementation

### 1. Add `--attachment` / `--file` flag to `send` and `send-group`

```bash
# Send attachment with optional text message
imessages send <contact> "optional caption" --file /path/to/image.png
imessages send <contact> --file /path/to/image.png   # attachment only, no text

# Multiple attachments
imessages send <contact> "check these out" --file /tmp/a.png --file /tmp/b.jpg

# Group chat
imessages send-group <chat_id> "here's the file" --file /path/to/doc.pdf
```

### 2. Changes to `cmd_send`

In the main Ruby script (`imessages`):

- Add `--file` option (repeatable) to the `send` OptionParser
- Validate each file exists and is readable before sending
- For each file, generate an AppleScript `send POSIX file "..." to targetBuddy` line
- If both text and files are provided, send text first, then files (separate AppleScript send calls)
- Return `attachments: [...]` in the success response listing what was sent

### 3. Changes to `cmd_send_group`

Same pattern as `cmd_send` but targeting the group chat.

### 4. Update help text and AGENTS.md

Add `--file` to usage examples and document the new capability.

## Edge Cases

- **File not found**: error with `FILE_NOT_FOUND` code before attempting send
- **No text + no file**: error with `USAGE` code
- **Large files**: Messages.app handles size limits itself; we just pass the path
- **File types**: Any file type Messages supports (images, PDFs, videos, etc.)

## Testing

```bash
# Text + image
imessages send "+15551234567" "Here's a screenshot" --file /tmp/screenshot.png

# Image only
imessages send "+15551234567" --file /tmp/photo.jpg

# Multiple files
imessages send "+15551234567" "Two files" --file /tmp/a.png --file /tmp/b.png

# Group
imessages send-group 42 "Meeting notes" --file /tmp/notes.pdf
```

## Estimated Effort

Small change — ~30 lines of Ruby. The AppleScript part already works; this is just plumbing the CLI flag through.
