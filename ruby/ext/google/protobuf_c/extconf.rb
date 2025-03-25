#!/usr/bin/ruby

require 'mkmf'

ext_name = "google/protobuf_c"

dir_config(ext_name)

# Dir.chdir(File.expand_path("../../../..", __FILE__)) do
#   unless File.exist? 'ext/google/protobuf_c/third_party/utf8_range'
#     FileUtils.mkdir_p 'ext/google/protobuf_c/third_party/utf8_range'
#     # We need utf8_range in-tree.
#     utf8_root = '../third_party/utf8_range'
#     %w[
#       utf8_range.h utf8_range.c utf8_range_sse.inc utf8_range_neon.inc LICENSE
#     ].each do |file|
#       FileUtils.cp File.join(utf8_root, file),
#                    "ext/google/protobuf_c/third_party/utf8_range"
#     end
#   end
# end

if ENV["CC"]
  RbConfig::CONFIG["CC"] = RbConfig::MAKEFILE_CONFIG["CC"] = ENV["CC"]
end

if ENV["CXX"]
  RbConfig::CONFIG["CXX"] = RbConfig::MAKEFILE_CONFIG["CXX"] = ENV["CXX"]
end

if ENV["LD"]
  RbConfig::CONFIG["LD"] = RbConfig::MAKEFILE_CONFIG["LD"] = ENV["LD"]
end

if RUBY_PLATFORM =~ /darwin/ || RUBY_PLATFORM =~ /linux/ || RUBY_PLATFORM =~ /freebsd/
  $CFLAGS += " -std=gnu99 -O3 -DNDEBUG -fvisibility=hidden -Wall -Wsign-compare -Wno-declaration-after-statement"
else
  $CFLAGS += " -std=gnu99 -O3 -DNDEBUG"
end

if RUBY_PLATFORM =~ /linux/
  # Instruct the linker to point memcpy calls at our __wrap_memcpy wrapper.
  $LDFLAGS += " -Wl,-wrap,memcpy"
end

$VPATH << "$(srcdir)/third_party/utf8_range"
$INCFLAGS += " -I$(srcdir)/third_party/utf8_range"

$srcs = ["protobuf.c", "convert.c", "defs.c", "message.c",
         "repeated_field.c", "map.c", "ruby-upb.c", "wrap_memcpy.c",
         "utf8_range.c", "shared_convert.c",
         "shared_message.c"]

create_makefile(ext_name)
