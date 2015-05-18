#!/usr/bin/env ruby

require 'set'

# From http://rosettacode.org/wiki/Power_set#Ruby
class Set
  def powerset 
    inject(Set[Set[]]) do |ps, item| 
      ps.union ps.map {|e| e.union (Set.new [item])}
    end
  end
end

template = <<END_OF_TEMPLATE
default=default=%{ext}:
OPTIMIZE = %%{asan_optimize} %{optimize}
EXTRA_LIBS = set_asan_default_options.o
fdo_pre0 = %%{compile_asan_default_options}"%{asan_default_options}"
END_OF_TEMPLATE

all_options = Set.new %w(r w g i s h q)

all_options.powerset.each do |options|
  ext = "asap-asan" + all_options.map { |o| if options.include?(o) then "-#{o}" else "-n#{o}" end }.join

  optimize = []
  if not options.include?('r') then optimize <<= "-mllvm -asan-instrument-reads=0" end
  if not options.include?('w') then optimize <<= "-mllvm -asan-instrument-writes=0" end
  if not options.include?('g') then optimize <<= "-mllvm -asan-globals=0" end
  if not options.include?('s') then optimize <<= "-mllvm -asan-stack=0" end
  optimize = optimize.join(" ")

  asan_default_options = []
  if not options.include?('i') then asan_default_options <<= 'replace_str=0:replace_intrin=0' end
  if not options.include?('h') then asan_default_options <<= 'poison_heap=0' end
  if not options.include?('q') then asan_default_options <<= 'quarantine_size=0' end
  asan_default_options = asan_default_options.join(":")

  puts template % {
    :ext => ext,
    :optimize => optimize,
    :asan_default_options => asan_default_options
  }
  puts
end
