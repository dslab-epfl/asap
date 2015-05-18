#!/bin/bash

set -e

SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
source "$SCRIPT_DIR/../python/build_utils.sh"

export CC="$( which asap-clang )"
export CXX="$( which asap-clang++ )"

CFLAGS_BASE=( -fno-omit-frame-pointer -fno-sanitize-recover=all
              -fsanitize-blacklist="$SCRIPT_DIR/asan_blacklist.txt"
              -DOPENSSL_NO_HW_PADLOCK -DOPENSSL_NO_BUF_FREELISTS )
CFLAGS_ASAN=( -fsanitize=address "${CFLAGS_BASE[@]}" )

fetch_openssl() {
    [ -d openssl ] && return 0
    git clone git://git.openssl.org/openssl.git
    (
        cd openssl
        git checkout -b asap 3143a332e8f2f5ca1a6f0262a1a1a66103f2adf7
        git apply "$SCRIPT_DIR/openssl_asap.patch"
        git add .
        git commit -m "Patching OpenSSL for AddressSanitizer"
    )
}

configure_and_build_openssl() {
    rsync -a ../openssl/ .
    ./Configure "$@" linux-x86_64
    make clean && make depend && make all
}

build_openssl() {
    make clean && make all
}

build_and_test_openssl() {
    make clean && make all && make test
}

fetch_openssl

build_asap_initial "openssl" "baseline" "configure_and_build_openssl" "${CFLAGS_BASE[@]}"
build_asap_initial "openssl" "asan" "configure_and_build_openssl" "${CFLAGS_ASAN[@]}"

build_asap_coverage "openssl" "asan" "build_and_test_openssl"

build_asap_optimized "openssl" "asan" "s0000" "-asap-sanity-level=0.000" "build_openssl"
build_asap_optimized "openssl" "asan" "c0010" "-asap-cost-level=0.010" "build_openssl"
build_asap_optimized "openssl" "asan" "c0040" "-asap-cost-level=0.040" "build_openssl"
build_asap_optimized "openssl" "asan" "c1000" "-asap-cost-level=1.000" "build_openssl"
