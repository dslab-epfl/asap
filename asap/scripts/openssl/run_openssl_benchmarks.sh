#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )"
source "$SCRIPT_DIR/../python/build_utils.sh"

OPENSSL_PID=
start_server() {
    local openssl_dir="$( pwd )"

    echo "Starting web server..."
    cd "$SCRIPT_DIR"
    "$openssl_dir/apps/openssl" s_server -cert conf/cert_localhost.cert -key conf/cert_localhost.key -WWW > /dev/null 2>&1 &
    OPENSSL_PID=$!
    sleep 2
    cd "$openssl_dir"

    # Verify that the server has been started correctly
    if ! kill -0 $OPENSSL_PID; then
        echo "Web server is not running at PID $OPENSSL_PID?" >&2
        return 1
    fi
}

stop_server() {
    echo "Stopping web server..."
    kill $OPENSSL_PID
    sleep 2
}

wait_for_ports() {
    echo "Waiting for TCP ports to become available..."
    local n_ports_occupied=$( netstat -tn | grep TIME_WAIT | wc -l  || true )
    while [ $n_ports_occupied -gt 30000 ]; do
        sleep 1
        n_ports_occupied=$( netstat -tn | grep TIME_WAIT | wc -l  || true )
    done
}

benchmark_openssl_webserver() {
    start_server

    # Warmup
    wait_for_ports
    echo "Performing 100 warmup requests..."
    ab -n 100 -c 1 https://localhost:4433/html/test.txt > /dev/null 2>&1
    sleep 2

    # The real measurements
    wait_for_ports
    echo "Performing 10'000 benchmarking requests..."
    ab -n 10000 -c 1 https://localhost:4433/html/test.txt
    sleep 2

    stop_server
    echo "Done."
}

benchmark_openssl_s_time() {
    start_server

    # Warmup
    wait_for_ports
    echo "Performing warmup requests..."
    ./apps/openssl s_time -new -time 1 > /dev/null 2>&1  || true
    sleep 2

    # The real measurements
    wait_for_ports
    echo "Performing benchmarking requests for 5 seconds..."
    ./apps/openssl s_time -new -time 5  || true
    sleep 2

    stop_server

    echo "Done."
}

benchmark_openssl_speed() {
    ./apps/openssl speed -mr sha1 md5 aes-256-cbc rsa2048 dsa1024 ecdsap224 ecdhb283
}

benchmark_openssl() {
    mkdir -p asap_state/benchmark_results

    benchmark_openssl_speed | tee asap_state/benchmark_results/openssl_speed.txt
    benchmark_openssl_s_time | tee asap_state/benchmark_results/openssl_s_time.txt
    benchmark_openssl_webserver | tee asap_state/benchmark_results/openssl_webserver.txt
}

benchmark_asap "openssl" "baseline-initial" "benchmark_openssl"
benchmark_asap "openssl" "asan-c1000" "benchmark_openssl"
benchmark_asap "openssl" "asan-c0040" "benchmark_openssl"
benchmark_asap "openssl" "asan-c0010" "benchmark_openssl"
benchmark_asap "openssl" "asan-s0000" "benchmark_openssl"
