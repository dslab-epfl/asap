#!/usr/bin/env python

import os.path
import re
import sys

def extract_connections(filename):
    # 13085 connections in 6 real seconds, 0 bytes read per connection
    RESULTS_RE = re.compile(r'^ \s* (\d+) \s* connections \s* in \s* \d+ \s* real \s* seconds', re.VERBOSE)
    with open(filename) as f:
        for line in f:
            m = RESULTS_RE.match(line)
            if m:
                return int(m.group(1))
    raise "Did not find results line!"


def main():
    configs = ['baseline-initial', 'asan-s0000', 'asan-c0010', 'asan-c0040', 'asan-c1000']
    connections = {}
    for config in configs:
        connections[config] = extract_connections(os.path.join(
            "openssl-%s-build" % config, 'asap_state', 'benchmark_results', 'openssl_s_time.txt'))

    overhead = [ (float(connections['baseline-initial']) / connections[config] - 1.0) * 100
            for config in configs[1:] ]

    print "OpenSSL,ASan,SSL handshakes," + ",".join([ str(o) for o in overhead ])

if __name__ == '__main__':
    main()


