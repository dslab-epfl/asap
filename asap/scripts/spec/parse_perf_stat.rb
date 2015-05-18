#!/usr/bin/env ruby

REGEXES = {
  "task-clock"    => /([\d.]+) \s+ task-clock/x,
  "page-faults"   => /([\d.]+) \s+ page-faults/x,
  "cycles"        => /([\d.]+) \s+ cycles/x,
  "instructions"  => /([\d.]+) \s+ instructions/x,
  "branches"      => /([\d.]+) \s+ branches/x,
  "branch-misses" => /([\d.]+) \s+ branch-misses/x
}

results = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

ARGF.each_line do |line|
  ARGF.filename =~ /\d{3}\.([^\/]+) \/ run \/ .*_([^\/]+)\.\d{4} \/ /x or raise "Cannot detect extension from #{ARGF.filename}"
  benchmark = $1
  extension = $2
  REGEXES.each do |key, re|
    if line =~ re
      results[benchmark][extension][key] = $1
    end
  end
end

results.keys.sort.each do |benchmark|
  puts benchmark
  benchmark_results = results[benchmark]

  all_extensions = benchmark_results.keys.sort
  puts "%20s\t%s" % ["", all_extensions.join("\t")]
  REGEXES.keys.each do |key|
    puts "%20s\t%s" % [key, all_extensions.map { |e| benchmark_results[e][key] }.join("\t")]
  end
  puts
end
