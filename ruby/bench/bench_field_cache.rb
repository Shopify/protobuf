require 'benchmark/ips'
require 'google/protobuf'
require_relative './bench_messages_pb'

def assert_equal(val1, val2)
  raise "Assertion failed: #{val1.inspect} != #{val2.inspect}" unless val1 == val2
end

message = BenchMessage.new(field_1: "howdy", field_2: 123)

Benchmark.ips do |x|
  x.report("AbstractMessage#[string]") do
    assert_equal message["field_1"], "howdy"
    assert_equal message["field_2"], 123
  end

  x.report("AbstractMessage.get(symbol)") do
    assert_equal message.get(:field_1), "howdy"
    assert_equal message.get(:field_2), 123
  end

  x.compare!
end
