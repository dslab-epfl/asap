#!/usr/bin/env ruby

SPEED_RESULT_RE = / \+F :        # Literal +F
                    \d+ :        # Test id
                    ([^:]+) :    # Test name
                    ([0-9.]+) :  # Test result for 16B
                    ([0-9.]+) :  # Test result for 64B
                    ([0-9.]+) :  # Test result for 256B
                    ([0-9.]+) :  # Test result for 1024B
                    ([0-9.]+)    # Test result for 8192B
                  /x

SPEED_RESULT2_RE = / \+F(\d+) :   # Literal +F with some digits
                     \d+ :        # Test id
                     (\d+) :      # Key size
                     ([0-9.]+) :  # Encryption or signing throughput
                     ([0-9.]+)    # Decryption or verifying throughput
                   /x

SPEED_RESULTS2_EXPERIMENTS = {
  2 => ["rsa enc", "rsa dec"],
  3 => ["dsa sign", "dsa verify"],
  4 => ["ecdsa sign", "ecdsa verify"],
  5 => ["ecdh", nil]
}

def parse_speed_file(filename, defaults={})
  results = []
  open(filename) do |f|
    f.each_line do |line|
      if line =~ SPEED_RESULT_RE
        test_name = $1
        result_16b = $2.to_f
        result_8kb = $6.to_f
        results <<= defaults.merge :experiment => "#{test_name} (16B)", :value => result_16b
        results <<= defaults.merge :experiment => "#{test_name} (8192B)", :value => result_8kb
      end
      if line =~ SPEED_RESULT2_RE
        test_number = $1.to_i
        test_name = SPEED_RESULTS2_EXPERIMENTS[test_number]
        key_size = $2.to_i
        result = [1.0 / $3.to_f, 1.0 / $4.to_f]
        [0, 1].each do |i|
          if test_name[i]
            results <<= defaults.merge :experiment => "#{test_name[i]} (#{key_size})", :value => result[i]
          end
        end
      end
    end
  end

  results
end

# Functional "map" for hashes
# Expects a block that takes a key and a value, and returns the new value
def hash_map(h)
  Hash[
    h.map { |k, v| [k, yield(k, v)] }
  ]
end

results = []
["baseline-initial", "asan-s0000", "asan-c0010", "asan-c0040", "asan-c1000"].each do |config|
  results += parse_speed_file(
    File.join("openssl-#{config}-build", "asap_state", "benchmark_results", "openssl_speed.txt"),
    :application => "OpenSSL", :config => config
  )
end

aggregated_results = Hash.new { |hash, key| hash[key] = Hash.new { |hash2, key2| hash2[key2] = Hash.new } }
results.each do |result|
  aggregated_results[result[:application]][result[:experiment]][result[:config]] = result[:value]
end

overhead_results = hash_map(aggregated_results) do |application, app_res|
  hash_map(app_res) do |experiment, e_res|
    {
      "overhead.full" => (e_res["baseline-initial"] / e_res["asan-c1000"] - 1.0) * 100.0,
      "overhead.c4" => (e_res["baseline-initial"] / e_res["asan-c0040"] - 1.0) * 100.0,
      "overhead.c1" => (e_res["baseline-initial"] / e_res["asan-c0010"] - 1.0) * 100.0,
      "overhead.zero" => (e_res["baseline-initial"] / e_res["asan-s0000"] - 1.0) * 100.0
    }
  end
end

puts ["application", "tool", "benchmark.name",
      "sanity.zero", "cost.01", "cost.04", "cost.one"].join(",")
overhead_results.each do |application, application_results|
  application_results.each do |experiment, e_res|
    puts [application, "ASan", experiment,
          e_res["overhead.zero"], e_res["overhead.c1"], e_res["overhead.c4"], e_res["overhead.full"]
         ].join(",")
  end
end
