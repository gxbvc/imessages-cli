#!/usr/bin/env ruby
# frozen_string_literal: true

# Self-check for send_via_applescript's benign-error tolerance, the
# shared --stdin helper used by `send` and `send-group`, and the chat.db
# confirmation that turns a failed attachment send into ok:false.
# Run: ruby test_send.rb

ARGV.replace(['aliases'])
begin
  load File.expand_path('imessages', __dir__)
rescue SystemExit
end

raise 'FAIL: -1712 (AppleEvent timeout) should be treated as benign' unless benign_send_error?('execution error: timeout (-1712)')
raise 'FAIL: -609 (dropped connection) should be treated as benign' unless benign_send_error?('execution error: connection invalid (-609)')
raise 'FAIL: real errors must not be swallowed' if benign_send_error?('execution error: Cant get participant "+15551234567" of application "Messages" (-1728)')
raise 'FAIL: nil stderr must not be benign' if benign_send_error?(nil)

ARGV.replace(['leftover positional'])
raise 'FAIL: positional arg should be read when --stdin is not set' unless read_message_arg(stdin: false) == 'leftover positional'

require 'stringio'
old_stdin = $stdin
$stdin = StringIO.new("piped body\n")
raise 'FAIL: --stdin should read from $stdin' unless read_message_arg(stdin: true) == "piped body\n"
$stdin = old_stdin

# confirm_send: the 2026-09-27 SMS failure looked like this in chat.db
# (osascript exited 0, but imagent could not read the /tmp file).
stuck = { id: 1, service: 'SMS', is_sent: false, error: 4, attachments: [{ name: 'a.jpg', transfer_state: 6 }] }
sent = { id: 2, service: 'SMS', is_sent: true, error: 0, attachments: [{ name: 'a.jpg', transfer_state: 5 }] }
pending = { id: 3, service: 'SMS', is_sent: false, error: 0, attachments: [{ name: 'a.jpg', transfer_state: 0 }] }
raise 'FAIL: error=4 / transfer_state=6 must count as failed' unless message_failed?(stuck)
raise 'FAIL: sent MMS must count as done' unless message_done?(sent) && !message_failed?(sent)
raise 'FAIL: pending MMS must not count as done' if message_done?(pending) || message_failed?(pending)

def run_confirm(rows)
  define_method(:outgoing_messages_since) { |*_a, **_k| rows }
  out = StringIO.new
  $stdout = out
  confirm_send(0, expected: 1, wait: 0, handle: '+15551234567')
  :returned
rescue SystemExit
  JSON.parse(out.string)['code']
ensure
  $stdout = STDOUT
end

raise 'FAIL: stuck send must return SEND_FAILED' unless run_confirm([stuck]) == 'SEND_FAILED'
raise 'FAIL: pending send must return SEND_UNCONFIRMED' unless run_confirm([pending]) == 'SEND_UNCONFIRMED'
raise 'FAIL: missing row must return SEND_UNCONFIRMED' unless run_confirm([]) == 'SEND_UNCONFIRMED'
raise 'FAIL: sent MMS must be confirmed' unless run_confirm([sent]) == :returned
raise 'FAIL: link-preview payloads must not count as files' if real_attachment?('ABC.pluginPayloadAttachment')
raise 'FAIL: a real file must count' unless real_attachment?('memo.m4a')
raise 'FAIL: a text-only row has no file' if real_attachment?(nil)

puts 'OK: test_send.rb passed'
