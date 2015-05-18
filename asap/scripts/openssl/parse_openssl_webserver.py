#!/usr/bin/env python

import os.path
import re
import sys

def extract_requests(filename):
    # Requests per second:    350.49 [#/sec] (mean)
    RESULTS_RE = re.compile(r'^ \s* Requests \s per \s second: \s* ([\d .]+) ', re.VERBOSE)
    with open(filename) as f:
        for line in f:
            m = RESULTS_RE.match(line)
            if m:
                return float(m.group(1))
    raise "Did not find results line!"


def main():
    configs = ['baseline-initial', 'asan-s0000', 'asan-c0010', 'asan-c0040', 'asan-c1000']
    requests = {}
    for config in configs:
        requests[config] = extract_requests(os.path.join(
            "openssl-%s-build" % config, 'asap_state', 'benchmark_results', 'openssl_webserver.txt'))

    overhead = [ (requests['baseline-initial'] / requests[config] - 1.0) * 100
            for config in configs[1:] ]

    print "OpenSSL,ASan,Web server," + ",".join([ str(o) for o in overhead ])

if __name__ == '__main__':
    main()


