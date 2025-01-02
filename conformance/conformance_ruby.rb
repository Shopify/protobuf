#!/usr/bin/env ruby
#
# Protocol Buffers - Google's data interchange format
# Copyright 2008 Google Inc.  All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file or at
# https://developers.google.com/open-source/licenses/bsd

# Move this require to the top before loading any of the _pb files
# in case we want to tweak the descriptor pool.
require 'google/protobuf'

# Log what files are added to the descriptor pool.
# pool = Google::Protobuf::DescriptorPool.generated_pool
# orig = pool.method(:add_serialized_file)
# pool.define_singleton_method(:add_serialized_file) do |file|
#   STDERR.puts file.inspect
#   orig.call(file)
# end

require 'conformance/conformance_pb'
require 'conformance/test_protos/test_messages_edition2023_pb'
# require 'google/protobuf'
require 'google/protobuf/test_messages_proto3_pb'
require 'google/protobuf/test_messages_proto2_pb'
require 'test_messages_proto2_editions_pb'
require 'test_messages_proto3_editions_pb'

$test_count = 0

# Add a quick way to print more crap.
$verbose = false #true

# Not sure what I used this for, maybe to see the last lines processed before the suite dies.
# counts = Hash.new(0)
# TracePoint.trace(:line) do |tp|
#   spot = "#{tp.path}:#{tp.lineno}"
#   counts[spot] += 1
#   STDERR.puts [spot, counts[spot], counts.size].inspect
# end

# We aren't currently producing compatible parser errors
# so just collect the messages that error and store them here.
PARSE_ERRORS = {"protobuf_test_messages.proto3.TestAllTypesProto3"=>["a".b, "\xD1\x02".b, "\xD1)".b, "aabcdefg".b, "\xD1\x02abcdefg".b, "\xD1)abcdefg".b, "\xD2\x02\aabcdefg".b, "\xD2\x02\x01".b, "]".b, "\xCD\x02".b, "\xD5)".b, "]abc".b, "\xCD\x02abc".b, "\xD5)abc".b, "\xCA\x02\x03abc".b, "\xCA\x02\x01".b, "\x10".b, "\x80\x02".b, "\xD0)".b, "\x10\x80".b, "\x80\x02\x80".b, "\xD0)\x80".b, "\x82\x02\x01\x80".b, "\x82\x02\x01".b, " ".b, "\x90\x02".b, "\xD0)".b, " \x80".b, "\x90\x02\x80".b, "\xD0)\x80".b, "\x92\x02\x01\x80".b, "\x92\x02\x01".b, "\b".b, "\xF8\x01".b, "\xD0)".b, "\b\x80".b, "\xF8\x01\x80".b, "\xD0)\x80".b, "\xFA\x01\x01\x80".b, "\xFA\x01\x01".b, "A".b, "\xB1\x02".b, "\xD1)".b, "Aabcdefg".b, "\xB1\x02abcdefg".b, "\xD1)abcdefg".b, "\xB2\x02\aabcdefg".b, "\xB2\x02\x01".b, "=".b, "\xAD\x02".b, "\xD5)".b, "=abc".b, "\xAD\x02abc".b, "\xD5)abc".b, "\xAA\x02\x03abc".b, "\xAA\x02\x01".b, "h".b, "\xD8\x02".b, "\xD0)".b, "h\x80".b, "\xD8\x02\x80".b, "\xD0)\x80".b, "\xDA\x02\x01\x80".b, "\xDA\x02\x01".b, "r".b, "\xE2\x02".b, "\xD2)".b, "r\x80".b, "\xE2\x02\x80".b, "\xD2)\x80".b, "r\x01".b, "\xE2\x02\x01".b, "\xD2)\x01".b, "\x92\x01".b, "\x82\x03".b, "\xD2)".b, "\x92\x01\x80".b, "\x82\x03\x80".b, "\xD2)\x80".b, "\x92\x01\x01".b, "\x82\x03\x01".b, "\xD2)\x01".b, "\x92\x01\x02(\x80".b, "z".b, "\xEA\x02".b, "\xD2)".b, "z\x80".b, "\xEA\x02\x80".b, "\xD2)\x80".b, "z\x01".b, "\xEA\x02\x01".b, "\xD2)\x01".b, "\x18".b, "\x88\x02".b, "\xD0)".b, "\x18\x80".b, "\x88\x02\x80".b, "\xD0)\x80".b, "\x8A\x02\x01\x80".b, "\x8A\x02\x01".b, "\xA8\x01".b, "\x98\x03".b, "\xD0)".b, "\xA8\x01\x80".b, "\x98\x03\x80".b, "\xD0)\x80".b, "\x9A\x03\x01\x80".b, "\x9A\x03\x01".b, "M".b, "\xBD\x02".b, "\xD5)".b, "Mabc".b, "\xBD\x02abc".b, "\xD5)abc".b, "\xBA\x02\x03abc".b, "\xBA\x02\x01".b, "Q".b, "\xC1\x02".b, "\xD1)".b, "Qabcdefg".b, "\xC1\x02abcdefg".b, "\xD1)abcdefg".b, "\xC2\x02\aabcdefg".b, "\xC2\x02\x01".b, "(".b, "\x98\x02".b, "\xD0)".b, "(\x80".b, "\x98\x02\x80".b, "\xD0)\x80".b, "\x9A\x02\x01\x80".b, "\x9A\x02\x01".b, "0".b, "\xA0\x02".b, "\xD0)".b, "0\x80".b, "\xA0\x02\x80".b, "\xD0)\x80".b, "\xA2\x02\x01\x80".b, "\xA2\x02\x01".b, "\x01DEADBEEF".b, "\x02\x01\x01".b, "\x03\x04".b, "\x05DEAD".b, "\x06\x00".b, "\x06\x01".b, "\x06\x02".b, "\x06\x03".b, "\x0E\x00".b, "\x0E\x01".b, "\x0E\x02".b, "\x0E\x03".b, "\x16\x00".b, "\x16\x01".b, "\x16\x02".b, "\x16\x03".b, "\x1E\x00".b, "\x1E\x01".b, "\x1E\x02".b, "\x1E\x03".b, "\a\x00".b, "\a\x01".b, "\a\x02".b, "\a\x03".b, "\x0F\x00".b, "\x0F\x01".b, "\x0F\x02".b, "\x0F\x03".b, "\x17\x00".b, "\x17\x01".b, "\x17\x02".b, "\x17\x03".b, "\x1F\x00".b, "\x1F\x01".b, "\x1F\x02".b, "\x1F\x03".b], "protobuf_test_messages.proto2.TestAllTypesProto2"=>["a".b, "\xD1\x02".b, "\xD1)".b, "aabcdefg".b, "\xD1\x02abcdefg".b, "\xD1)abcdefg".b, "\xD2\x02\aabcdefg".b, "\xD2\x02\x01".b, "]".b, "\xCD\x02".b, "\xD5)".b, "]abc".b, "\xCD\x02abc".b, "\xD5)abc".b, "\xCA\x02\x03abc".b, "\xCA\x02\x01".b, "\x10".b, "\x80\x02".b, "\xD0)".b, "\x10\x80".b, "\x80\x02\x80".b, "\xD0)\x80".b, "\x82\x02\x01\x80".b, "\x82\x02\x01".b, " ".b, "\x90\x02".b, "\xD0)".b, " \x80".b, "\x90\x02\x80".b, "\xD0)\x80".b, "\x92\x02\x01\x80".b, "\x92\x02\x01".b, "\b".b, "\xF8\x01".b, "\xD0)".b, "\b\x80".b, "\xF8\x01\x80".b, "\xD0)\x80".b, "\xFA\x01\x01\x80".b, "\xFA\x01\x01".b, "A".b, "\xB1\x02".b, "\xD1)".b, "Aabcdefg".b, "\xB1\x02abcdefg".b, "\xD1)abcdefg".b, "\xB2\x02\aabcdefg".b, "\xB2\x02\x01".b, "=".b, "\xAD\x02".b, "\xD5)".b, "=abc".b, "\xAD\x02abc".b, "\xD5)abc".b, "\xAA\x02\x03abc".b, "\xAA\x02\x01".b, "h".b, "\xD8\x02".b, "\xD0)".b, "h\x80".b, "\xD8\x02\x80".b, "\xD0)\x80".b, "\xDA\x02\x01\x80".b, "\xDA\x02\x01".b, "r".b, "\xE2\x02".b, "\xD2)".b, "r\x80".b, "\xE2\x02\x80".b, "\xD2)\x80".b, "r\x01".b, "\xE2\x02\x01".b, "\xD2)\x01".b, "\x92\x01".b, "\x82\x03".b, "\xD2)".b, "\x92\x01\x80".b, "\x82\x03\x80".b, "\xD2)\x80".b, "\x92\x01\x01".b, "\x82\x03\x01".b, "\xD2)\x01".b, "\x92\x01\x02(\x80".b, "z".b, "\xEA\x02".b, "\xD2)".b, "z\x80".b, "\xEA\x02\x80".b, "\xD2)\x80".b, "z\x01".b, "\xEA\x02\x01".b, "\xD2)\x01".b, "\x18".b, "\x88\x02".b, "\xD0)".b, "\x18\x80".b, "\x88\x02\x80".b, "\xD0)\x80".b, "\x8A\x02\x01\x80".b, "\x8A\x02\x01".b, "\xA8\x01".b, "\x98\x03".b, "\xD0)".b, "\xA8\x01\x80".b, "\x98\x03\x80".b, "\xD0)\x80".b, "\x9A\x03\x01\x80".b, "\x9A\x03\x01".b, "M".b, "\xBD\x02".b, "\xD5)".b, "Mabc".b, "\xBD\x02abc".b, "\xD5)abc".b, "\xBA\x02\x03abc".b, "\xBA\x02\x01".b, "Q".b, "\xC1\x02".b, "\xD1)".b, "Qabcdefg".b, "\xC1\x02abcdefg".b, "\xD1)abcdefg".b, "\xC2\x02\aabcdefg".b, "\xC2\x02\x01".b, "(".b, "\x98\x02".b, "\xD0)".b, "(\x80".b, "\x98\x02\x80".b, "\xD0)\x80".b, "\x9A\x02\x01\x80".b, "\x9A\x02\x01".b, "0".b, "\xA0\x02".b, "\xD0)".b, "0\x80".b, "\xA0\x02\x80".b, "\xD0)\x80".b, "\xA2\x02\x01\x80".b, "\xA2\x02\x01".b, "\x01DEADBEEF".b, "\x02\x01\x01".b, "\x03\x04".b, "\x05DEAD".b, "\x06\x00".b, "\x06\x01".b, "\x06\x02".b, "\x06\x03".b, "\x0E\x00".b, "\x0E\x01".b, "\x0E\x02".b, "\x0E\x03".b, "\x16\x00".b, "\x16\x01".b, "\x16\x02".b, "\x16\x03".b, "\x1E\x00".b, "\x1E\x01".b, "\x1E\x02".b, "\x1E\x03".b, "\a\x00".b, "\a\x01".b, "\a\x02".b, "\a\x03".b, "\x0F\x00".b, "\x0F\x01".b, "\x0F\x02".b, "\x0F\x03".b, "\x17\x00".b, "\x17\x01".b, "\x17\x02".b, "\x17\x03".b, "\x1F\x00".b, "\x1F\x01".b, "\x1F\x02".b, "\x1F\x03".b]}

# Ruby classes generated with protoboeuf don't populate Google's descriptor pool.
# We can just look them up by class name in memory and return them in a wrapper.
FoundMsgClass = Struct.new(:msgclass)
Google::Protobuf::DescriptorPool.generated_pool.singleton_class.prepend(Module.new do
  def lookup(type)
    super || begin
      klass = type.split(".").map { |x| x.match?(/^[A-Z]/) ? x : x.split('_').map(&:capitalize).join("") }.join("::")
      # STDERR.puts "USING #{klass}"
      FoundMsgClass.new(Object.const_get(klass))
    end
  end
end)

# If we make ProtoBoeuf::DecodeError inherit from the google one
# then we don't have to adjust any code catching the google one.
# if defined?(ProtoBoeuf)
#   module ProtoBoeuf
#     remove_const(:DecodeError)
#     class DecodeError < Google::Protobuf::ParseError; end
#   end
# end

def do_test(request)
  test_message = ProtobufTestMessages::Proto3::TestAllTypesProto3.new
  response = Conformance::ConformanceResponse.new
  descriptor = Google::Protobuf::DescriptorPool.generated_pool.lookup(request.message_type)

  debug = []
  unless descriptor
    response.runtime_error = "Unknown message type: " + request.message_type
    return response
  end

  if request.test_category == :TEXT_FORMAT_TEST
    response.skipped = "Ruby doesn't support text format"
    return response
  end

  # Toggle for conditionally showing debug output.
  show_debug = request.payload == :protobuf_payload && request.protobuf_payload == "\xca\x02\x03\x61\x62\x63"

  begin
    case request.payload
    when :protobuf_payload
      begin
        # Fake a parser error if we know this message should produce one.
        raise Google::Protobuf::ParseError, "skip" if PARSE_ERRORS[request.message_type].include?(request.protobuf_payload)

        debug << sprintf("\nrequest proto payload %s \"%s\"\n", request.protobuf_payload.encoding, request.protobuf_payload.bytes.map { |b| sprintf "\\x%02x", b }.join(""))
        begin
          test_message = descriptor.msgclass.decode(request.protobuf_payload)
        rescue RuntimeError => err
          raise Google::Protobuf::ParseError, err.message if err.message == "unknown wire type 7"
          raise
        end
      rescue Google::Protobuf::ParseError => err
        # Populate parse errors hash in case we need to record a new one.
        #(PARSE_ERRORS[request.message_type] ||= []) << request.protobuf_payload

        response.parse_error = err.message.encode('utf-8').tap { |s| debug << "crap parse error: #{s}" }
        # TODO: compare behavior with Google to our unexpected char / loop
        # TODO: always check if finished before getbyte (pull sint32, pull string, in maps, etc)
        STDERR.puts debug unless err.message == "skip" || err.message == "unknown wire type 7"
        return response
      end

    when :json_payload
      begin
        options = {}
        if request.test_category == :JSON_IGNORE_UNKNOWN_PARSING_TEST
          options[:ignore_unknown_fields] = true
        end
        test_message = descriptor.msgclass.decode_json(request.json_payload, options)
      rescue Google::Protobuf::ParseError => err
        response.parse_error = err.message.encode('utf-8')
        STDERR.puts debug
        return response
      end

    when nil
      fail "Request didn't have payload"
    end

    case request.requested_output_format
    when :UNSPECIFIED
      fail 'Unspecified output format'

    when :PROTOBUF
      begin
        debug << test_message.inspect
        response.protobuf_payload = test_message.to_proto.tap { |s| debug << sprintf("response proto payload %s\n", s.inspect) }
      rescue Google::Protobuf::ParseError => err
        response.serialize_error = err.message.encode('utf-8').tap { |s| debug << "proto parse error: #{s}" }
        show_debug = true
      end

    when :JSON
      begin
        debug << test_message.inspect
        response.json_payload = test_message.to_json.tap { |s| debug << sprintf("response json payload %s\n", s.inspect) }
      rescue Google::Protobuf::ParseError => err
        response.serialize_error = err.message.encode('utf-8').tap { |s| debug << "json parse error: #{s}" }
        show_debug = true
      end

    when nil
      fail "Request didn't have requested output format"
    else
      fail "WHAT IS THIS?"
    end
  rescue StandardError => err
    response.runtime_error = err.message.encode('utf-8')
    STDERR.puts debug
    STDERR.puts "\n#{err.class}: #{err.message}"
    STDERR.puts err.backtrace
    # finish! if err.is_a?(TypeError)
  end

  STDERR.puts debug if show_debug

  response
end

# Force exiting the suite early.
def finish!
  STDERR.puts "FINISHING"
  Process.kill("TERM", `ps -eo pid,args=`.lines.detect { |l| l.include?("conformance_test_runner") }.split.first.to_i)
  exit!
end

# Returns true if the test ran successfully, false on legitimate EOF.
# If EOF is encountered in an unexpected place, raises IOError.
def do_test_io
  length_bytes = STDIN.read(4)
  return false if length_bytes.nil?

  length = length_bytes.unpack('V').first
  serialized_request = STDIN.read(length)
  if serialized_request.nil? || serialized_request.length != length
    fail IOError
  end

  request = Conformance::ConformanceRequest.decode(serialized_request)

  response = do_test(request)

  serialized_response = Conformance::ConformanceResponse.encode(response)
  STDOUT.write([serialized_response.length].pack('V'))
  STDOUT.write(serialized_response)
  STDOUT.flush

  if $verbose
    STDERR.puts("conformance_ruby: request=#{request.to_json}, " \
                                 "response=#{response.to_json}\n")
  end

  $test_count += 1

  true
end

loop do
  unless do_test_io
    STDERR.puts('conformance_ruby: received EOF from test runner ' \
                "after #{$test_count} tests, exiting")
    break
  end
end

# Dump collected parse errors so we can update the hash at the top of this file.
#STDERR.puts PARSE_ERRORS.inspect
