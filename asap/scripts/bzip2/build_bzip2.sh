#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"; pwd )"
source "$SCRIPT_DIR/../python/build_utils.sh"

ASAN_CFLAGS="-fsanitize=address"
ASAN_LDFLAGS="-fsanitize=address"

UBSAN_CFLAGS="-fsanitize=undefined -fno-sanitize=shift -fno-sanitize-recover=all"
UBSAN_LDFLAGS="-fsanitize=undefined"


# Fix Mac machines that don't have sha256sum
if ! which sha256sum >/dev/null 2>&1; then
    sha256sum() {
        shasum -a 256 "$@"
    }
fi

fetch_bzip2() {
    [ -d bzip2 ] && return 0
    [ -f bzip2-1.0.6.tar.gz ] || wget 'http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz'
    sha256sum --check "$SCRIPT_DIR/bzip2-1.0.6.sha256"
    tar -xzf bzip2-1.0.6.tar.gz
    mv bzip2-1.0.6 bzip2
    (
        cd bzip2
        patch -p1 < "$SCRIPT_DIR/bzip2_asap.patch"
    )
}

build_bzip2() {
    local extra_cflags="$1"
    local ldflags="$2"
    make clean
    make -j "$N_PROCESSORS" \
         CC="$(which asap-clang)" \
         CFLAGS="-Wall -Winline -O3 -g -D_FILE_OFFSET_BITS=64 $extra_cflags" \
         LDFLAGS="$ldflags" \
         all
}

configure_and_build_bzip2() {
    rsync -a ../bzip2/ .
    build_bzip2 "$@"
}

fetch_bzip2

build_asap_initial "bzip2" "baseline" "configure_and_build_bzip2" "" ""
build_asap_initial "bzip2" "asan"     "configure_and_build_bzip2" "$ASAN_CFLAGS" "$ASAN_LDFLAGS"
build_asap_initial "bzip2" "ubsan"    "configure_and_build_bzip2" "$UBSAN_CFLAGS" "$UBSAN_LDFLAGS"

build_asap_coverage "bzip2" "asan"  "build_bzip2" "$ASAN_CFLAGS" "$ASAN_LDFLAGS"
build_asap_coverage "bzip2" "ubsan" "build_bzip2" "$UBSAN_CFLAGS" "$UBSAN_LDFLAGS"

build_asap_optimized "bzip2" "asan" "s0000" "-asap-sanity-level=0.000" "build_bzip2" "$ASAN_CFLAGS" "$ASAN_LDFLAGS"
build_asap_optimized "bzip2" "asan" "c0010" "-asap-cost-level=0.010"   "build_bzip2" "$ASAN_CFLAGS" "$ASAN_LDFLAGS"
build_asap_optimized "bzip2" "asan" "c0040" "-asap-cost-level=0.040"   "build_bzip2" "$ASAN_CFLAGS" "$ASAN_LDFLAGS"
build_asap_optimized "bzip2" "asan" "c1000" "-asap-cost-level=1.000"   "build_bzip2" "$ASAN_CFLAGS" "$ASAN_LDFLAGS"

build_asap_optimized "bzip2" "ubsan" "s0000" "-asap-sanity-level=0.000" "build_bzip2" "$UBSAN_CFLAGS" "$UBSAN_LDFLAGS"
build_asap_optimized "bzip2" "ubsan" "c0010" "-asap-cost-level=0.010"   "build_bzip2" "$UBSAN_CFLAGS" "$UBSAN_LDFLAGS"
build_asap_optimized "bzip2" "ubsan" "c0040" "-asap-cost-level=0.040"   "build_bzip2" "$UBSAN_CFLAGS" "$UBSAN_LDFLAGS"
build_asap_optimized "bzip2" "ubsan" "c1000" "-asap-cost-level=1.000"   "build_bzip2" "$UBSAN_CFLAGS" "$UBSAN_LDFLAGS"
