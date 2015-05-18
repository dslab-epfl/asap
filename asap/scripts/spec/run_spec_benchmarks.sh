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
size="test"
rebuild=""
n_jobs="--jobs 1"
extensions="asap-baseline asap-asan-s0000 asap-asan-c0010 asap-asan-c0040 asap-asan-c1000"
config="$SCRIPT_DIR/asap.cfg"

usage() {
    echo "Usage: run_spec_benchmarks.sh" >&2
    echo "  [--rebuild] if true, existing builds are not used" >&2
    echo "  [--jobs <n>] the number of jobs for running benchmarks." >&2
    echo "               Note that benchmarks are always built in parallel." >&2
    echo "               You can optionally run them in parallel by setting this" >&2
    echo "               to 40, 100%, +1 or similar (see 'man parallel')." >&2
    echo "  [--benchmarks <benchmarks>] a (quoted) list of benchmarks" >&2
    echo "  [--size <size>] the workload size (test, train, ref)" >&2
    echo "  [--extensions <exts>] a quoted list of extensions" >&2
    echo "  [--config <cfg>] path to a spec config file" >&2
    echo "example: run_spec_benchmarks.sh --rebuild --benchmarks bzip2 --size test" >&2
    echo "example: run_spec_benchmarks.sh --benchmarks \"all_c all_cpp\" \\" >&2
    echo "             --size train --extensions \"asap-baseline asap-asan-c0010\"" >&2
    echo "By default, all benchmarks are run at size test," >&2
    echo "for baseline, sanity level 0, and cost levels 0.01, 0.04, 1.0." >&2
    echo "The config file asap.cfg in the script folder is used by default." >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        "--rebuild")
            rebuild="--rebuild"
            shift;;
        "--jobs")
            n_jobs="--jobs $2"
            shift; shift;;
        "--benchmarks")
            benchmarks="$2"
            shift; shift;;
        "--size")
            size="$2"
            shift; shift;;
        "--extensions")
            extensions="$2"
            shift; shift;;
        "--config")
            config="$2"
            shift; shift;;
        *)
            usage;;
    esac
done

if ! [[ "$size" =~ test|train|ref ]]; then
    echo "unknown size: $size" >&2
    usage
fi

benchmarks=" $benchmarks "
benchmarks="${benchmarks/" all_c "/" $ALL_C_BENCHMARKS "}"
benchmarks="${benchmarks/" all_cpp "/" $ALL_CPP_BENCHMARKS "}"


# Build SPEC benchmarks in parallel; only the runs need to be done
# sequentially.
build_spec() {
    parallel --gnu runspec --config="$config" \
        --extension="{1}" --size="$size" \
        $rebuild --action=build {2} ::: $extensions ::: $benchmarks
}

benchmark_spec() {
    parallel --gnu $n_jobs \
        runspec --config="$config" \
        --extension="{1}" --size="$size" \
        --nobuild {2} ::: $extensions ::: $benchmarks
}

# Clear previous benchmark results
(
    cd "$SPEC"
    if [ -d result ]; then
        mv result "result_$( date '+%Y%m%d_%H%M%S' )"
    fi
)

build_spec

# Move build logs away
(
    cd "$SPEC/result"
    mkdir buildlogs
    mv *.log buildlogs
    rm -f CPU2006.lock
)

benchmark_spec
