require 'benchmark/ips'
require 'google/protobuf'
require_relative './bench_messages_pb'

Benchmark.ips do |x|
  x.report("standard alloc (baseline)") do
    BenchMessage.allocate
  end

  x.report("alloc with fieldcache") do
    BenchMessage.alloc_with_field_cache
  end

  x.compare!
end
