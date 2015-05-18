#!/bin/bash

set -e

SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
source "$SCRIPT_DIR/../python/build_utils.sh"

ALL_C_BENCHMARKS="
   400.perlbench
   401.bzip2
   403.gcc
   429.mcf
   445.gobmk
   456.hmmer
   458.sjeng
   462.libquantum
   464.h264ref
   433.milc
   470.lbm
   482.sphinx3
"
ALL_CPP_BENCHMARKS="
   471.omnetpp
   473.astar
   483.xalancbmk
   444.namd
   447.dealII
   450.soplex
   453.povray
"

if ! which runspec > /dev/null; then
    echo "Please run \"source shrc\" in the spec folder prior to calling this script." >&2
    exit 1
fi

# Option parsing
# Default values:
benchmarks="all_c all_cpp"
extensions="asap-baseline asap-asan-s0000 asap-asan-c0010 asap-asan-c0040 asap-asan-c1000"
repeat=1

usage() {
    echo "Usage: perf_stat_spec_benchmarks.sh" >&2
    echo "  [--benchmarks <benchmarks>] a (quoted) list of benchmarks" >&2
    echo "  [--extensions <exts>] a quoted list of extensions" >&2
    echo "  [--repeat n] number of repetitions to run" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        "--benchmarks")
            benchmarks="$2"
            shift; shift;;
        "--repeat")
            repeat="$2"
            shift; shift;;
        "--extensions")
            extensions="$2"
            shift; shift;;
        *)
            usage;;
    esac
done

benchmarks=" $benchmarks "
benchmarks="${benchmarks/" all_c "/" $ALL_C_BENCHMARKS "}"
benchmarks="${benchmarks/" all_cpp "/" $ALL_CPP_BENCHMARKS "}"

setup_env() {
    local extension="$1"

    case "$extension" in
        *-nointercept)
            echo "export ASAN_OPTIONS=$ASAN_OPTIONS:replace_str=0:replace_intrin=0" ;;
        *-noquarantine)
            echo "export ASAN_OPTIONS=$ASAN_OPTIONS:quarantine_size=0" ;;
        *-noheap)
            echo "export ASAN_OPTIONS=$ASAN_OPTIONS:poison_heap=0" ;;
        *)
            echo "export ASAN_OPTIONS=$ASAN_OPTIONS" ;;
    esac > setup.env
}

benchmark_spec() {
    local benchmark="$1"
    local extension="$2"

    (
        if cd "$SPEC/benchspec/CPU2006/"*"${benchmark}"*"/run/run_"*"_${extension}.0000" 2>/dev/null ; then
            setup_env "$extension"
            source setup.env

            echo "benchmark: $benchmark" | tee perf_stat.txt
            echo "extension: $extension" | tee -a perf_stat.txt
            cat setup.env | tee -a perf_stat.txt
            perf stat -r "$repeat" specinvoke 2>&1 | tee -a perf_stat.txt
        else
            echo "Skipping $benchmark $extension (run folder does not exist)" >&2
        fi
    )
}

# Run the benchmarks
for benchmark in $benchmarks; do
    for extension in $extensions; do
        benchmark_spec "$benchmark" "$extension"
    done
done

# Print the result in tabular form
result_files=()
for benchmark in $benchmarks; do
    for extension in $extensions; do
        result_file="$( ls "$SPEC/benchspec/CPU2006/"*"${benchmark}"*"/run/run_"*"_${extension}.0000/perf_stat.txt" 2>/dev/null || true )"
        if [ -f "$result_file" ]; then
            result_files=( "${result_files[@]}" "$result_file" )
        fi
    done
done
"$SCRIPT_DIR/parse_perf_stat.rb" "${result_files[@]}"
