# Fix: picture and audio attachments over SMS/MMS

Date: 2026-09-27. Status: fixed in the CLI and verified with live sends. No iPhone or Mac setting change is needed.

## Problem

`imessages-cli send "+18177455827" --sms --file <path>` returned `ok:true`, but the Twilio number never received the file. Plain-text `--sms` sends from the same Mac arrived. The Mac sends SMS through the iPhone (Text Message Forwarding, sender `+18176685828`).

## Root cause

imagent (the Messages daemon that does the send) runs in a sandbox. It cannot read files outside its own folders, for example `/tmp` or `~/projects`. The old CLI passed the original path to `send POSIX file "..."`. imagent then failed to open the file, and Messages marked the message as failed. It never reached the iPhone.

osascript still exited 0, because the AppleScript `send` command returns when Messages queues the message, before the file is read. The CLI only checked the osascript exit status, so it returned `ok:true`.

The bug is not specific to SMS. The same failure shows on iMessage and RCS file sends from `/tmp` and `~/projects` (see the table below). It is likely also the cause of the old "VCF attachments don't send" note in AGENTS.md.

## Evidence

1. **chat.db rows for the two failed sends on 2026-09-27** (read-only). The task notes said `error` was null. The rows show `error=4` and `is_sent=0`:

   | message | time | service | is_sent | error | transfer_state | attachment.filename |
   |---|---|---|---|---|---|---|
   | 184121 | 07:02:07 | SMS | 0 | 4 | 6 | `/tmp/ehr-e2e/memo2.m4a` |
   | 184136 | 09:36:27 | SMS | 0 | 4 | 6 | `~/projects/tap/ehr/evals/fixtures/sample-id.jpg` |

   `transfer_state` 5 means finished and 6 means failed. Every good outgoing SMS/RCS file (1,201 SMS and 617 RCS rows) has `transfer_state=5` and a filename under `~/Library/Messages/Attachments/...`. The failed rows kept the original outside path.

2. **The same pattern on other services.** Every outgoing attachment since 2025-12 with `transfer_state=6` has a path in `/tmp` or `~/projects`: SMS (`/tmp/nad-*.png`, 2026-08-24), RCS (`/tmp/nad-card-*.png`, 2026-08-26), and iMessage (`/tmp/bailey-v6/*.pdf`, `/tmp/trigate-*.zip`, `~/projects/gxb/logo/*`, `~/projects/bellabot/bellabot.vcf`, and others). The iMessage failures use `error` codes 3, 25, and 39.

3. **Unified log for test send 1** (`log show --last 3m`): imagent logged this eight times:
   `imagent[841] (libcopyfile.dylib) open on /tmp/imsg-sms-test/t1.jpg: Operation not permitted`

4. **Other tools.** steipete/imsg (`Sources/IMsgCore/MessageSender.swift`, `stageAttachment`) copies every file to `~/Library/Messages/Attachments/imsg/<UUID>/<name>` before its AppleScript `send`, for this reason.

Things that were checked and are not the cause:
- **MMS Messaging on the iPhone.** It is on. After the fix, MMS from the same iPhone arrives at Twilio.
- **File type and size.** jpg, png, and m4a all arrive after the fix. The iPhone converts m4a audio to `audio/amr` for MMS.
- **Text and file in one message.** They do not need to be. The CLI sends the caption as one SMS and the file as a separate MMS, and both arrive.

## Fix (imessages-cli)

1. **Staging.** `stage_attachment` copies each `--file` to `~/Library/Messages/Attachments/imessages-cli/<uuid>/<basename>`. The AppleScript sends that copy. This applies to `send` (all services) and `send-group`. After a send, `attachment.filename` points at the staged copy, so the CLI keeps it. Deleting it would break the image in the Messages history.
2. **Confirmation.** Before a file send, the CLI records `MAX(message.ROWID)`. After osascript, `confirm_send` checks chat.db once per second for new outgoing messages to that handle or chat:
   - done: `is_sent=1`, `error=0`, and `transfer_state=5` on each real file, for the expected number of messages (files plus one if there is a caption). The CLI returns `ok:true` with a `confirmed` array.
   - failed: any `error != 0` or `transfer_state=6`. The CLI returns `ok:false`, `code: SEND_FAILED`, and the row states in `details`.
   - still pending after `--wait SECONDS` (default 60): `ok:false`, `code: SEND_UNCONFIRMED`. The error text says to check `imessages-cli thread` before a retry, so the file is not sent twice.
   - Link-preview rows (`*.pluginPayloadAttachment`) are ignored, because they can stay at `transfer_state=0` after a good send.
3. Text-only sends are unchanged. They do not wait on chat.db.

Changed files: `imessages`, `test_send.rb`, `AGENTS.md` (regression note), `README.md`, and this plan.

## Test sends

All sends went to the GXB Twilio test number `+18177977334` only. Total: 7 CLI calls (9 messages). Images are solid-color or noise test images made with vips, and the audio is a `say` voice clip. Twilio check: `twilio api:core:messages:list --to +18177977334 --from +18176685828 --limit 5 -o json`.

| # | Command (all to +18177977334) | CLI result | chat.db | Twilio |
|---|---|---|---|---|
| 1 | old CLI: `--sms --file /tmp/.../t1.jpg` (control) | `ok:true` (false) | 184175: is_sent 0, error 4, ts 6 | nothing received |
| 2 | fixed: `--sms --file t2.jpg` | `ok:true`, confirmed in 5.5 s | 184176: is_sent 1, error 0, ts 5 | `MM6e45…` numMedia 1, image/jpeg |
| 3 | fixed: `"caption" --sms --file t3.jpg` | `ok:true`, 2 confirmed | 184179 text, 184180 ts 5 | `SM19609…` body only, `MMbff3…` numMedia 1, image/jpeg |
| 4 | fixed: `--sms --file memo.m4a` (42 KB AAC) | `ok:true` | 184181 ts 5 | `MMaab4…` numMedia 1, audio/amr |
| 5 | fixed: `send-group 762 --file t5.jpg` (1:1 SMS chat) | `ok:true` | 184182 ts 5 | `MM666d…` numMedia 1 |
| 6 | fixed: `--sms --file t6.png` (112 KB) | `ok:true` | 184183 ts 5 | `MMcafa…` numMedia 1, image/png |
| 7 | fixed, after the last code edit: `"… https://gxb.vc" --sms --file t7.jpg` | `ok:true`, 2 confirmed | 184184 text, 184185 ts 5 | `SM2167…` body, `MM8b1e…` numMedia 1 |

Failure path: `confirm_send` run against the real failed row 184175 (read-only, no send) returns `{"ok":false,"code":"SEND_FAILED",...}` with exit 1. `ruby test_send.rb` covers failed, pending, missing, and sent rows, and the link-preview filter. It passes.

## Human steps

None are required. MMS Messaging is on and works.

- The EHR at `+18177455827` was not sent anything during this work. To rerun the QA step that failed, send again with the fixed CLI. The original paths (`/tmp/ehr-e2e/memo2.m4a`, `~/projects/.../sample-id.jpg`) are fine now, because the CLI copies them first.
- Voice memos arrive at Twilio as `audio/amr`, not `audio/x-m4a`. The EHR's inbound media handler must accept `audio/amr`.

## Residual risks

- iMessage file sends now also wait for confirmation (up to 60 s). This was not tested live, because the test number is SMS-only. chat.db shows 8,607 good outgoing iMessage files with `transfer_state=5`, so the same rule should hold.
- If Messages is slow (large video, weak cellular signal on the iPhone), a good send can return `SEND_UNCONFIRMED`. Use `--wait 180` for large files.
- Staged copies stay in `~/Library/Messages/Attachments/imessages-cli/`. The CLI does not remove them. I did not check whether Messages removes them when the conversation is deleted.
- The confirmation matches new outgoing rows by handle or chat. If the user also sends to the same contact from the Messages UI during the wait, that message is counted too.
- `.vcf` sends were not retested.
