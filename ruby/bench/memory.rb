require "google/protobuf"
require_relative "bench_messages_pb"

def initialize_message
  BenchMessages::Message.new(
    bigger_fld_1: "howdy",
    bigger_fld_2: 123,
    bigger_fld_3: { "a" => "1", "b" => "2", "c" => "3" },
    bigger_fld_4: BenchMessages::SubMessage.new(bigger_fld_1: 456),
  )
end

initialize_message
