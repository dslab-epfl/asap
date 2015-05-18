#!/usr/bin/env python

import os.path
import re
import sys

def get_configuration(filename):
    EXTENSION_RE = re.compile(r'^ Ext \s+ = \s+ (\S+) $', re.VERBOSE)
    RUN_NUMBER_RE = re.compile(r'.* \. (\d{3}) \. [^/]*', re.VERBOSE)

    run_number = RUN_NUMBER_RE.match(filename).group(1)
    results_folder = os.path.dirname(filename)
    logfile_name = os.path.join(results_folder, 'CPU2006.%s.log' % run_number)

    with open(logfile_name) as f:
        for line in f:
            m = EXTENSION_RE.match(line)
            if m:
                configuration = m.group(1)
                return re.sub('^asap-', '', configuration)

    raise "Could not find extension in %s" % logfile_name


def parse_spec_results_file(filename):
    # 401.bzip2,,,,,,--,3.687219,--,1,S
    RESULTS_RE = re.compile(
            r'''^ \s* ([\w .]+) \s* ,
            .* , .* , .* , .* , .* , .* ,
            \s* ([\d .]+) \s* ,
            .* ,
            \s* \d* \s* ,
            \s* S \s* $''', re.VERBOSE)

    configuration = get_configuration(filename)

    results = []
    with open(filename) as f:
        for line in f:
            m = RESULTS_RE.match(line)
            if m:
                benchmark = m.group(1)
                runtime = float(m.group(2))
                results.append( (configuration, benchmark, runtime) )

    return results


def main():
    results = []
    for filename in sys.argv[1:]:
        results.extend(parse_spec_results_file(filename))

    # Print out molten results... it's probably easier to aggregate them in R.
    print "variable,benchmark,value"
    for result in results:
        print ",".join([ str(v) for v in result ])

    # Cast the results in a rectangular shape.
    #configurations = sorted(list(set( result[0] for result in results )))
    #benchmarks = sorted(list(set( result[1] for result in results )))
    #runtimes = [ [ 'NA' for c in configurations ] for b in benchmarks ]

    #configuration_ids = { configurations[i]: i for i in range(len(configurations)) }
    #benchmark_ids = { benchmarks[i]: i for i in range(len(benchmarks)) }

    #for result in results:
    #    runtimes[benchmark_ids[result[1]]][configuration_ids[result[0]]] = str(result[2])

    #print "benchmark," + ",".join(configurations)
    #for benchmark in benchmarks:
    #    print benchmark + "," + ",".join(runtimes[benchmark_ids[benchmark]])


if __name__ == '__main__':
    main()
