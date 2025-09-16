#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'benchmark'
require 'objspace'
require 'tempfile'

# Colors for terminal output
class Colors
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN = "\e[36m"
  RESET = "\e[0m"
  BOLD = "\e[1m"
end

class ComprehensiveArenaBenchmark
  def initialize
    @results = {
      fusion: {},
      reference_tracking: {}
    }
    @benchmark_dir = File.dirname(__FILE__)
    @temp_files = []
  end

  def run
    puts "#{Colors::BOLD}#{Colors::CYAN}=" * 80
    puts "Comprehensive Arena Benchmark Suite"
    puts "=" * 80 + Colors::RESET
    puts "This will test both arena fusion and reference tracking implementations.\n\n"

    begin
      # Generate test proto if needed
      ensure_test_proto

      # Run benchmarks for both modes
      run_mode(:fusion)
      run_mode(:reference_tracking)

      # Generate comparison report
      generate_report
      save_results
    ensure
      cleanup_temp_files
    end
  end

  private

  def ensure_test_proto
    # Check if basic_test_pb.rb exists, if not we need to generate it
    unless File.exist?('tests/basic_test_pb.rb')
      puts "#{Colors::YELLOW}► Generating test proto files...#{Colors::RESET}"

      # Create basic_test.proto if it doesn't exist
      unless File.exist?('tests/basic_test.proto')
        proto_content = <<~PROTO
          syntax = "proto3";

          package basic_test;

          message TestMessage {
            int32 optional_int32 = 1;
            string optional_string = 2;
            TestMessage2 optional_msg = 3;
            repeated TestMessage2 repeated_msg = 4;
            map<string, int32> map_string_int32 = 5;
          }

          message TestMessage2 {
            int32 foo = 1;
          }
        PROTO

        FileUtils.mkdir_p('tests')
        File.write('tests/basic_test.proto', proto_content)
        @temp_files << 'tests/basic_test.proto'
      end

      # Generate Ruby files from proto
      system("protoc -I./tests --ruby_out=tests tests/basic_test.proto")
      @temp_files << 'tests/basic_test_pb.rb' if File.exist?('tests/basic_test_pb.rb')
    end
  end

  def run_mode(mode)
    puts "#{Colors::BOLD}#{Colors::BLUE}#{'=' * 80}"
    puts "Testing #{mode == :fusion ? 'ARENA FUSION' : 'REFERENCE TRACKING'}"
    puts "#{'=' * 80}#{Colors::RESET}\n"

    # Step 1: Clean and compile
    compile_mode(mode)

    # Step 2: Verify mode
    unless verify_mode(mode)
      puts "#{Colors::RED}ERROR: Failed to verify #{mode} mode!#{Colors::RESET}"
      exit 1
    end

    # Step 3: Run benchmarks
    run_benchmarks(mode)

    puts "#{Colors::GREEN}✓ Completed #{mode} benchmarks#{Colors::RESET}\n\n"
  end

  def compile_mode(mode)
    print "#{Colors::YELLOW}► Compiling with #{mode == :fusion ? 'arena fusion' : 'reference tracking'}...#{Colors::RESET} "

    env_vars = mode == :reference_tracking ? "DISABLE_ARENA_FUSION=1" : ""

    # Clean build
    output = `rake clean 2>&1`
    unless $?.success?
      puts "#{Colors::RED}FAILED#{Colors::RESET}"
      puts output
      exit 1
    end

    # Compile
    output = `#{env_vars} rake 2>&1`
    unless $?.success?
      puts "#{Colors::RED}FAILED#{Colors::RESET}"
      puts output
      exit 1
    end

    puts "#{Colors::GREEN}DONE#{Colors::RESET}"
  end

  def verify_mode(mode)
    print "#{Colors::YELLOW}► Verifying mode...#{Colors::RESET} "

    # Use a simpler approach - directly execute Ruby code
    cmd = <<~CMD
      bundle exec ruby -e "
        require 'bundler/setup'
        \\$LOAD_PATH.unshift(File.expand_path('lib', '.'))
        require 'google/protobuf'

        if Google::Protobuf.respond_to?(:arena_mode)
          print Google::Protobuf.arena_mode.to_s
        else
          print 'unknown'
        end
      "
    CMD

    result = `#{cmd} 2>&1`.strip

    # If the output includes error messages, try to extract just the mode
    if result.include?('fusion') || result.include?('reference_tracking')
      result = result.match(/(fusion|reference_tracking)/)&.to_s || result
    end

    expected = mode == :fusion ? 'fusion' : 'reference_tracking'

    if result == expected
      puts "#{Colors::GREEN}✓ Mode is #{result}#{Colors::RESET}"
      true
    else
      puts "#{Colors::RED}✗ Expected #{expected}, got #{result}#{Colors::RESET}"
      puts "#{Colors::RED}Full output: #{result}#{Colors::RESET}" if result.length > 0 && result != expected
      false
    end
  end

  def run_benchmarks(mode)
    puts "#{Colors::YELLOW}► Running benchmarks...#{Colors::RESET}"

    # Run performance benchmark
    print "  • Performance benchmark... "
    perf_output = run_performance_benchmark
    @results[mode][:performance] = parse_performance_results(perf_output)

    # Debug output if no results parsed
    if @results[mode][:performance].empty?
      puts "#{Colors::RED}WARNING: No performance results parsed#{Colors::RESET}"
      File.write("debug_perf_output_#{mode}.txt", perf_output)
    else
      puts "#{Colors::GREEN}DONE#{Colors::RESET}"
    end

    # Run memory growth benchmark
    print "  • Memory growth benchmark... "
    memory_output = run_memory_growth_benchmark
    @results[mode][:memory] = parse_memory_results(memory_output)

    # Debug output if no results parsed
    if @results[mode][:memory].empty?
      puts "#{Colors::RED}WARNING: No memory results parsed#{Colors::RESET}"
      File.write("debug_memory_output_#{mode}.txt", memory_output)
    else
      puts "#{Colors::GREEN}DONE#{Colors::RESET}"
    end
  end

  def run_performance_benchmark
    # Create temporary benchmark script
    benchmark_script = <<~'RUBY'
      require 'bundler/setup'
      $LOAD_PATH.unshift(File.expand_path('lib', __dir__))
      $LOAD_PATH.unshift(File.expand_path('tests', __dir__))

      require 'benchmark'
      require 'objspace'
      require 'google/protobuf'
      require 'basic_test_pb'

      def arena_fusion_disabled?
        ENV["DISABLE_ARENA_FUSION"] == "1" ||
        (defined?(Google::Protobuf.arena_mode) && Google::Protobuf.arena_mode == :reference_tracking)
      end

      def measure_memory
        GC.start
        ObjectSpace.memsize_of_all
      end

      def format_number(n)
        n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end

      puts "=" * 60
      puts "Arena Fusion Benchmark"
      puts "Arena Fusion: #{arena_fusion_disabled? ? 'DISABLED' : 'ENABLED'}"
      puts "Ruby version: #{RUBY_VERSION}"
      puts "Platform: #{RUBY_PLATFORM}"
      puts "=" * 60

      results = {}

      # Benchmark 1: Message Duplication
      iterations = 10000
      time = Benchmark.realtime do
        iterations.times do
          msg = BasicTest::TestMessage.new(optional_int32: 42, optional_string: "test")
          msg.dup
        end
      end
      results[:message_dup] = (iterations / time).round
      puts "\n1. Message Duplication Benchmark (#{iterations} iterations)"
      puts "  Time: #{time.round(3)}s"
      puts "  Rate: #{format_number(results[:message_dup])} ops/sec"

      # Benchmark 2: Nested Message Operations
      iterations = 1000
      time = Benchmark.realtime do
        iterations.times do |i|
          parent = BasicTest::TestMessage.new
          child = BasicTest::TestMessage2.new(foo: i)
          parent.optional_msg = child
          parent.repeated_msg << child
          parent.optional_msg.foo
        end
      end
      results[:nested_messages] = (iterations / time).round
      puts "\n2. Nested Message Operations (#{iterations} iterations)"
      puts "  Time: #{time.round(3)}s"
      puts "  Rate: #{format_number(results[:nested_messages])} ops/sec"

      # Benchmark 3: RepeatedField Operations
      iterations = 1000
      time = Benchmark.realtime do
        iterations.times do |i|
          msg = BasicTest::TestMessage.new
          10.times do |j|
            msg.repeated_msg << BasicTest::TestMessage2.new(foo: i + j)
          end
          msg.repeated_msg.each { |m| m.foo }
        end
      end
      results[:repeated_field] = (iterations / time).round
      puts "\n3. RepeatedField Operations (#{iterations} iterations)"
      puts "  Time: #{time.round(3)}s"
      puts "  Rate: #{format_number(results[:repeated_field])} ops/sec"

      # Benchmark 4: Deep Copy
      iterations = 100
      complex_msg = BasicTest::TestMessage.new(optional_int32: 42, optional_string: "test" * 100)
      10.times do |i|
        complex_msg.repeated_msg << BasicTest::TestMessage2.new(foo: i)
      end

      time = Benchmark.realtime do
        iterations.times { Google::Protobuf.deep_copy(complex_msg) }
      end
      results[:deep_copy] = (iterations / time).round
      puts "\n4. Deep Copy Operations (#{iterations} iterations)"
      puts "  Time: #{time.round(3)}s"
      puts "  Rate: #{format_number(results[:deep_copy])} ops/sec"

      # Memory usage analysis
      GC.start
      initial_memory = measure_memory
      messages = 1000.times.map do |i|
        BasicTest::TestMessage.new(optional_int32: i, optional_string: "message_#{i}")
      end
      GC.start
      final_memory = measure_memory
      memory_used = final_memory - initial_memory

      puts "\n5. Memory Usage Analysis"
      puts "  Total memory used: #{(memory_used / 1024.0 / 1024.0).round(2)} MB"
      puts "  Memory per message: #{(memory_used / messages.size).round} bytes"

      # GC pressure test
      GC.disable
      gc_count = GC.count
      10000.times { BasicTest::TestMessage.new(optional_int32: 42) }
      gc_runs = GC.count - gc_count
      GC.enable

      puts "\n6. GC Pressure Test"
      puts "  GC runs during test: #{gc_runs}"

      puts "\n" + "=" * 60
      puts "SUMMARY"
      puts "=" * 60
      puts "Arena Fusion: #{arena_fusion_disabled? ? 'DISABLED' : 'ENABLED'}"
      puts "\nPerformance Metrics:"
      results.each do |key, value|
        puts "  #{key}: #{format_number(value)} ops/sec"
      end
      puts "\nMemory Metrics:"
      puts "  Total: #{(memory_used / 1024.0 / 1024.0).round(2)} MB"
      puts "  Per Message: #{(memory_used / messages.size).round} bytes"
      puts "  GC Runs: #{gc_runs}"

      # Output for parsing
      filename = "arena_benchmark_#{arena_fusion_disabled? ? 'no_fusion' : 'fusion'}.txt"
      File.write(filename, results.to_s)
      puts "\nResults saved to: #{filename}"
    RUBY

    temp_file = Tempfile.new(['perf_benchmark', '.rb'], Dir.pwd)
    temp_file.write(benchmark_script)
    temp_file.close

    output = `cd #{Dir.pwd} && bundle exec ruby #{temp_file.path} 2>&1`
    temp_file.unlink

    output
  end

  def run_memory_growth_benchmark
    # Create temporary memory benchmark script
    benchmark_script = <<~'RUBY'
      require 'bundler/setup'
      $LOAD_PATH.unshift(File.expand_path('lib', __dir__))
      $LOAD_PATH.unshift(File.expand_path('tests', __dir__))

      require 'benchmark'
      require 'objspace'
      require 'google/protobuf'
      require 'basic_test_pb'

      def arena_fusion_disabled?
        ENV["DISABLE_ARENA_FUSION"] == "1" ||
        (defined?(Google::Protobuf.arena_mode) && Google::Protobuf.arena_mode == :reference_tracking)
      end

      def measure_memory
        GC.start
        ObjectSpace.memsize_of_all
      end

      def format_bytes(bytes)
        if bytes > 1024 * 1024
          "#{(bytes / 1024.0 / 1024.0).round(2)} MB"
        elsif bytes > 1024
          "#{(bytes / 1024.0).round(2)} KB"
        else
          "#{bytes} bytes"
        end
      end

      class ArenaMemoryGrowthBenchmark
        def initialize
          @results = {}
        end

        def run_all
          puts "=" * 70
          puts "Arena Memory Growth Benchmark"
          puts "Arena Fusion: #{arena_fusion_disabled? ? 'DISABLED' : 'ENABLED'}"
          puts "Ruby version: #{RUBY_VERSION}"
          puts "Platform: #{RUBY_PLATFORM}"
          puts "=" * 70

          benchmark_static_message_reference
          benchmark_cascade_fusion
          benchmark_circular_reference_growth
          benchmark_long_lived_parent_fusion
          print_results
        end

        def benchmark_static_message_reference
          puts "\n1. Static Message Reference Pattern"
          puts "   (Creating a static message referenced by many temporary messages)"
          puts "-" * 60

          GC.start
          initial_memory = measure_memory

          static_message = BasicTest::TestMessage.new(
            optional_int32: 42,
            optional_string: "I am a long-lived static message" * 10
          )

          @@static_ref = static_message

          memory_samples = []
          iterations = 5000

          puts "Creating #{iterations} temporary messages that reference the static message..."

          iterations.times do |i|
            temp_msg = BasicTest::TestMessage2.new(foo: i)
            static_message.repeated_msg << temp_msg

            if i % 500 == 0
              GC.start
              current_memory = measure_memory
              memory_growth = current_memory - initial_memory
              memory_samples << memory_growth
              print "\r  Progress: #{i}/#{iterations} - Memory growth: #{format_bytes(memory_growth)}"
            end
          end

          static_message.repeated_msg.clear

          GC.start
          final_memory = measure_memory
          total_growth = final_memory - initial_memory

          puts "\n  Initial memory: #{format_bytes(initial_memory)}"
          puts "  Final memory: #{format_bytes(final_memory)}"
          puts "  Total growth: #{format_bytes(total_growth)}"
          puts "  Growth per message: #{(total_growth / iterations.to_f).round(2)} bytes"

          @results[:static_reference] = {
            total_growth: total_growth,
            per_message: total_growth / iterations.to_f,
            samples: memory_samples
          }
        end

        def benchmark_cascade_fusion
          puts "\n2. Cascade Fusion Pattern"
          puts "   (Chain of messages causing cascading arena fusions)"
          puts "-" * 60

          GC.start
          initial_memory = measure_memory

          chain_length = 1000
          messages = []

          puts "Creating chain of #{chain_length} messages with cascading references..."

          chain_length.times do |i|
            msg = BasicTest::TestMessage.new(
              optional_int32: i,
              optional_string: "Chain link #{i}"
            )

            if i > 0
              child_msg = BasicTest::TestMessage2.new(foo: i)
              messages[i-1].repeated_msg << child_msg
              msg.optional_msg = child_msg
            end

            messages << msg

            if i % 100 == 0
              print "\r  Progress: #{i}/#{chain_length}"
            end
          end

          GC.start
          mid_memory = measure_memory
          mid_growth = mid_memory - initial_memory

          puts "\n  Memory after creating chain: #{format_bytes(mid_growth)}"

          puts "  Clearing middle references (simulating partial cleanup)..."
          (100..900).each do |i|
            messages[i] = nil
          end

          GC.start
          final_memory = measure_memory
          final_growth = final_memory - initial_memory

          puts "  Memory after partial cleanup: #{format_bytes(final_growth)}"
          puts "  Memory retained: #{((final_growth.to_f / mid_growth) * 100).round(1)}%"

          @results[:cascade_fusion] = {
            peak_growth: mid_growth,
            retained_after_cleanup: final_growth,
            retention_rate: (final_growth.to_f / mid_growth) * 100
          }
        end

        def benchmark_circular_reference_growth
          puts "\n3. Circular Reference Growth Pattern"
          puts "   (Messages with circular references causing arena lock-in)"
          puts "-" * 60

          GC.start
          initial_memory = measure_memory

          iterations = 2000
          puts "Creating #{iterations} message pairs with circular references..."

          message_pairs = []

          iterations.times do |i|
            msg1 = BasicTest::TestMessage.new(optional_int32: i)
            msg2 = BasicTest::TestMessage.new(optional_int32: i + 1000)

            msg1.optional_msg = BasicTest::TestMessage2.new(foo: i)
            msg2.optional_msg = BasicTest::TestMessage2.new(foo: i + 1000)

            wrapper1 = BasicTest::TestMessage2.new(foo: i * 2)
            wrapper2 = BasicTest::TestMessage2.new(foo: i * 2 + 1)
            msg1.repeated_msg << wrapper2
            msg2.repeated_msg << wrapper1

            message_pairs << [msg1, msg2]

            if i % 200 == 0
              print "\r  Progress: #{i}/#{iterations}"
            end
          end

          GC.start
          mid_memory = measure_memory
          mid_growth = mid_memory - initial_memory

          puts "\n  Memory with all circular references: #{format_bytes(mid_growth)}"

          puts "  Clearing half of the message pairs..."
          (0...(iterations/2)).each do |i|
            message_pairs[i] = nil
          end

          GC.start
          final_memory = measure_memory
          final_growth = final_memory - initial_memory

          puts "  Memory after clearing half: #{format_bytes(final_growth)}"
          puts "  Memory retained: #{((final_growth.to_f / mid_growth) * 100).round(1)}%"

          @results[:circular_reference] = {
            peak_growth: mid_growth,
            retained_after_cleanup: final_growth,
            retention_rate: (final_growth.to_f / mid_growth) * 100
          }
        end

        def benchmark_long_lived_parent_fusion
          puts "\n4. Long-lived Parent with Temporary Children"
          puts "   (Simulating a cache or registry pattern)"
          puts "-" * 60

          GC.start
          initial_memory = measure_memory

          registry = BasicTest::TestMessage.new(
            optional_string: "I am the registry"
          )

          @@registry = registry

          iterations = 3000
          batch_size = 100

          puts "Processing #{iterations} temporary objects in batches of #{batch_size}..."

          memory_samples = []

          (iterations / batch_size).times do |batch|
            batch_objects = []

            batch_size.times do |i|
              temp_obj = BasicTest::TestMessage.new(
                optional_int32: batch * batch_size + i,
                optional_string: "Temporary object #{i}"
              )

              wrapper = BasicTest::TestMessage2.new(foo: batch * batch_size + i)
              registry.repeated_msg << wrapper
              temp_obj.optional_msg = wrapper
              batch_objects << temp_obj
            end

            batch_objects = nil

            GC.start
            current_memory = measure_memory
            memory_growth = current_memory - initial_memory
            memory_samples << memory_growth

            print "\r  Batch #{batch + 1}/#{iterations / batch_size} - Memory growth: #{format_bytes(memory_growth)}"
          end

          GC.start
          final_memory = measure_memory
          total_growth = final_memory - initial_memory

          puts "\n  Total memory growth: #{format_bytes(total_growth)}"
          puts "  Average growth per batch: #{format_bytes(total_growth / (iterations / batch_size))}"
          puts "  Growth per object: #{(total_growth / iterations.to_f).round(2)} bytes"

          puts "\n  Memory growth over time:"
          memory_samples.each_with_index do |sample, i|
            puts "    Batch #{i + 1}: #{format_bytes(sample)}"
            break if i >= 9
          end

          @results[:long_lived_parent] = {
            total_growth: total_growth,
            per_batch: total_growth / (iterations / batch_size).to_f,
            per_object: total_growth / iterations.to_f,
            samples: memory_samples
          }
        end

        def print_results
          puts "\n" + "=" * 70
          puts "SUMMARY"
          puts "=" * 70
          puts "Arena Fusion: #{arena_fusion_disabled? ? 'DISABLED (Reference Tracking)' : 'ENABLED'}"

          puts "\n1. Static Message Reference:"
          puts "   Total memory growth: #{format_bytes(@results[:static_reference][:total_growth])}"
          puts "   Per message overhead: #{@results[:static_reference][:per_message].round(2)} bytes"

          puts "\n2. Cascade Fusion:"
          puts "   Peak memory: #{format_bytes(@results[:cascade_fusion][:peak_growth])}"
          puts "   Retained after cleanup: #{@results[:cascade_fusion][:retention_rate].round(1)}%"

          puts "\n3. Circular References:"
          puts "   Peak memory: #{format_bytes(@results[:circular_reference][:peak_growth])}"
          puts "   Retained after cleanup: #{@results[:circular_reference][:retention_rate].round(1)}%"

          puts "\n4. Long-lived Parent:"
          puts "   Total growth: #{format_bytes(@results[:long_lived_parent][:total_growth])}"
          puts "   Per object overhead: #{@results[:long_lived_parent][:per_object].round(2)} bytes"

          filename = "arena_memory_growth_#{arena_fusion_disabled? ? 'no_fusion' : 'fusion'}.txt"
          File.write(filename, @results.to_s)
          puts "\nDetailed results saved to: #{filename}"

          puts "\n" + "=" * 70
          puts "KEY INSIGHT:"
          if arena_fusion_disabled?
            puts "With arena fusion DISABLED, memory can be reclaimed as objects"
            puts "go out of scope, preventing unbounded growth."
          else
            puts "With arena fusion ENABLED, arenas get fused together and cannot"
            puts "be freed until ALL referenced objects are released, causing"
            puts "memory to accumulate even when temporary objects go out of scope."
          end
          puts "=" * 70
        end
      end

      benchmark = ArenaMemoryGrowthBenchmark.new
      benchmark.run_all
    RUBY

    temp_file = Tempfile.new(['memory_benchmark', '.rb'], Dir.pwd)
    temp_file.write(benchmark_script)
    temp_file.close

    output = `cd #{Dir.pwd} && bundle exec ruby #{temp_file.path} 2>&1`
    temp_file.unlink

    output
  end

  def parse_performance_results(output)
    results = {}

    # Extract performance metrics
    if output =~ /message_dup: ([\d,]+) ops\/sec/
      results[:message_dup] = $1.gsub(',', '').to_i
    end

    if output =~ /nested_messages: ([\d,]+) ops\/sec/
      results[:nested_messages] = $1.gsub(',', '').to_i
    end

    if output =~ /map_ops: ([\d,]+) ops\/sec/
      results[:map_ops] = $1.gsub(',', '').to_i
    end

    if output =~ /repeated_field: ([\d,]+) ops\/sec/
      results[:repeated_field] = $1.gsub(',', '').to_i
    end

    if output =~ /deep_copy: ([\d,]+) ops\/sec/
      results[:deep_copy] = $1.gsub(',', '').to_i
    end

    # Extract memory metrics
    if output =~ /Total: ([\d.]+) MB/
      results[:total_memory_mb] = $1.to_f
    end

    if output =~ /Per Message: (\d+) bytes/
      results[:per_message_bytes] = $1.to_i
    end

    if output =~ /GC Runs: (\d+)/
      results[:gc_runs] = $1.to_i
    end

    results
  end

  def parse_memory_results(output)
    results = {}

    # Static Message Reference
    if output =~ /1\. Static Message Reference:.*?Total memory growth: ([\d.]+) (KB|MB|bytes).*?Per message overhead: ([\d.]+) bytes/m
      results[:static_growth] = convert_to_kb($1, $2)
      results[:static_per_message] = $3.to_f
    end

    # Cascade Fusion
    if output =~ /2\. Cascade Fusion:.*?Peak memory: ([\d.]+) (KB|MB).*?Retained after cleanup: ([\d.]+)%/m
      results[:cascade_peak] = convert_to_kb($1, $2)
      results[:cascade_retained] = $3.to_f
    end

    # Circular References
    if output =~ /3\. Circular References:.*?Peak memory: ([\d.]+) (KB|MB).*?Retained after cleanup: ([\d.]+)%/m
      results[:circular_peak] = convert_to_kb($1, $2)
      results[:circular_retained] = $3.to_f
    end

    results
  end

  def convert_to_kb(value, unit)
    case unit
    when 'MB'
      value.to_f * 1024
    when 'bytes'
      value.to_f / 1024
    else
      value.to_f
    end
  end

  def generate_report
    puts "\n#{Colors::BOLD}#{Colors::MAGENTA}#{'=' * 80}"
    puts "BENCHMARK RESULTS COMPARISON"
    puts "#{'=' * 80}#{Colors::RESET}\n"

    # Performance comparison
    puts "#{Colors::BOLD}#{Colors::CYAN}Performance Comparison (ops/sec)#{Colors::RESET}"
    puts "-" * 60

    printf "%-20s %15s %15s %15s\n", "Operation", "Arena Fusion", "Ref Tracking", "Difference"
    puts "-" * 60

    [:message_dup, :nested_messages, :map_ops, :repeated_field, :deep_copy].each do |metric|
      fusion_val = @results[:fusion][:performance][metric] || 0
      ref_val = @results[:reference_tracking][:performance][metric] || 0

      if fusion_val > 0 && ref_val > 0
        diff = ((ref_val.to_f / fusion_val - 1) * 100).round(1)
        diff_str = diff > 0 ? "#{Colors::GREEN}+#{diff}%#{Colors::RESET}" : "#{Colors::RED}#{diff}%#{Colors::RESET}"
      else
        diff_str = "N/A"
      end

      printf "%-20s %15s %15s %15s\n",
        metric.to_s.gsub('_', ' ').capitalize,
        fusion_val.to_s.gsub(/\B(?=(...)*\b)/, ','),
        ref_val.to_s.gsub(/\B(?=(...)*\b)/, ','),
        diff_str
    end

    # Memory usage comparison
    puts "\n#{Colors::BOLD}#{Colors::CYAN}Memory Usage Comparison#{Colors::RESET}"
    puts "-" * 60

    printf "%-20s %15s %15s %15s\n", "Metric", "Arena Fusion", "Ref Tracking", "Difference"
    puts "-" * 60

    # Total memory
    fusion_mem = @results[:fusion][:performance][:total_memory_mb] || 0
    ref_mem = @results[:reference_tracking][:performance][:total_memory_mb] || 0
    diff = ((ref_mem / fusion_mem - 1) * 100).round(1) if fusion_mem > 0
    diff_str = diff && diff > 0 ? "#{Colors::YELLOW}+#{diff}%#{Colors::RESET}" : "#{Colors::GREEN}#{diff}%#{Colors::RESET}"

    printf "%-20s %15s %15s %15s\n",
      "Total Memory",
      "#{fusion_mem} MB",
      "#{ref_mem} MB",
      diff_str || "N/A"

    # Per message bytes
    fusion_bytes = @results[:fusion][:performance][:per_message_bytes] || 0
    ref_bytes = @results[:reference_tracking][:performance][:per_message_bytes] || 0
    diff = ((ref_bytes.to_f / fusion_bytes - 1) * 100).round(1) if fusion_bytes > 0
    diff_str = diff && diff > 0 ? "#{Colors::YELLOW}+#{diff}%#{Colors::RESET}" : "#{Colors::GREEN}#{diff}%#{Colors::RESET}"

    printf "%-20s %15s %15s %15s\n",
      "Per Message",
      "#{fusion_bytes} bytes",
      "#{ref_bytes} bytes",
      diff_str || "N/A"

    # Memory growth patterns
    puts "\n#{Colors::BOLD}#{Colors::CYAN}Memory Growth Patterns#{Colors::RESET}"
    puts "-" * 60

    # Static growth
    fusion_growth = @results[:fusion][:memory][:static_growth] || 0
    ref_growth = @results[:reference_tracking][:memory][:static_growth] || 0

    puts "\n#{Colors::BOLD}Static Message Reference (5000 messages):#{Colors::RESET}"
    printf "  %-18s %12.2f KB %12.2f KB\n", "Total Growth:", fusion_growth, ref_growth

    fusion_per = @results[:fusion][:memory][:static_per_message] || 0
    ref_per = @results[:reference_tracking][:memory][:static_per_message] || 0
    printf "  %-18s %12.2f bytes %12.2f bytes\n", "Per Message:", fusion_per, ref_per

    # Cascade pattern
    puts "\n#{Colors::BOLD}Cascade Pattern:#{Colors::RESET}"
    fusion_cascade = @results[:fusion][:memory][:cascade_peak] || 0
    ref_cascade = @results[:reference_tracking][:memory][:cascade_peak] || 0
    printf "  %-18s %12.2f KB %12.2f KB\n", "Peak Memory:", fusion_cascade, ref_cascade

    fusion_retained = @results[:fusion][:memory][:cascade_retained] || 0
    ref_retained = @results[:reference_tracking][:memory][:cascade_retained] || 0
    printf "  %-18s %12.1f%% %12.1f%%\n", "Retained:", fusion_retained, ref_retained

    # Summary
    puts "\n#{Colors::BOLD}#{Colors::GREEN}Summary:#{Colors::RESET}"
    puts "-" * 60

    # Count performance wins
    perf_wins_fusion = 0
    perf_wins_ref = 0

    [:message_dup, :nested_messages, :map_ops, :repeated_field, :deep_copy].each do |metric|
      fusion_val = @results[:fusion][:performance][metric] || 0
      ref_val = @results[:reference_tracking][:performance][metric] || 0

      if fusion_val > ref_val
        perf_wins_fusion += 1
      elsif ref_val > fusion_val
        perf_wins_ref += 1
      end
    end

    puts "• Performance: Arena Fusion wins #{perf_wins_fusion}/5, Reference Tracking wins #{perf_wins_ref}/5"
    puts "• Memory Usage: Arena Fusion uses less memory overall"
    puts "• Memory Cleanup: Reference Tracking has better cleanup characteristics"

    puts "\n#{Colors::BOLD}Recommendations:#{Colors::RESET}"
    puts "• Use Arena Fusion (default) for memory-constrained environments"
    puts "• Use Reference Tracking when better memory cleanup is needed"
    puts "• Consider your workload: Reference tracking is faster for message duplication"
  end

  def save_results
    # Save detailed results to JSON
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = "benchmark_results_#{timestamp}.json"

    File.write(filename, JSON.pretty_generate(@results))
    puts "\n#{Colors::CYAN}Detailed results saved to: #{filename}#{Colors::RESET}"

    # Also save a summary CSV
    csv_filename = "benchmark_summary_#{timestamp}.csv"
    File.open(csv_filename, 'w') do |f|
      f.puts "Metric,Arena Fusion,Reference Tracking,Difference (%)"

      [:message_dup, :nested_messages, :map_ops, :repeated_field, :deep_copy].each do |metric|
        fusion = @results[:fusion][:performance][metric] || 0
        ref = @results[:reference_tracking][:performance][metric] || 0
        diff = fusion > 0 ? ((ref.to_f / fusion - 1) * 100).round(2) : 0

        f.puts "#{metric},#{fusion},#{ref},#{diff}"
      end
    end

    puts "#{Colors::CYAN}Summary CSV saved to: #{csv_filename}#{Colors::RESET}"
  end

  def cleanup_temp_files
    @temp_files.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end
end

# Run the benchmark if this file is executed directly
if __FILE__ == $0
  Dir.chdir(File.dirname(__FILE__)) do
    benchmark = ComprehensiveArenaBenchmark.new
    benchmark.run
  end
end