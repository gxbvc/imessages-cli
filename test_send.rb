#!/usr/bin/env ruby
# frozen_string_literal: true

# Self-check for send_via_applescript's benign-error tolerance and the
# shared --stdin helper used by `send` and `send-group`.
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

puts 'OK: test_send.rb passed'
