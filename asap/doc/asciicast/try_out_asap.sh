# Welcome! This screencast shows how to obtain, install, and use ASAP

# Create a project folder
mkdir asap
cd asap

# Clone the source code
git clone https://github.com/dslab-epfl/asap.git
git clone http://llvm.org/git/clang.git asap/tools/clang
( cd asap/tools/clang && git checkout release_37 )
git clone http://llvm.org/git/compiler-rt.git asap/projects/compiler-rt
( cd asap/projects/compiler-rt && git checkout release_37 )

# Let's build ASAP
mkdir build
cd build

# For configuring, these settings are recommended:
# - -G Ninja finishes the build sooner (you want your build ASAP, after all :) )
# - -DLLVM_ENABLE_ASSERTIONS=ON makes bugs a bit easier to understand
# - -DCMAKE_EXPORT_COMPILE_COMMANDS=ON causes a compile_commands.json
#   file to be generated. This file is useful if you're editing the ASAP
#   source code or running code analysis tools.
cmake -G Ninja -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ../asap

cmake --build .

# ASAP was built. Now let's try things out!
# Here, we add ASAP to the path so that we can more easily compile the benchmarks.
cd ..
PATH=$(pwd)/build/bin:$PATH

# There is a ready-to-use script to test ASAP with bzip2. It does the following:
# - Download bzip2 from the official website
# - Compile it without instrumentation (the baseline version)
# - Compile it with AddressSanitizer instrumentation.
# - Profile it. Bzip2 comes with a few tiny test files. Running these tests is good enough for ASAP.
# - Compile optimized versions with cost levels from 1% to 100%
mkdir bzip2
cd bzip2
../asap/asap/scripts/bzip2/build_bzip2.sh

# Let's inspect the result
ls -l

# We test the speed by measuring the time it takes to compress the ASAP source code
tar cf test-archive.tar ../asap/*
time ./bzip2-baseline-build/bzip2 --keep --force test-archive.tar
time ./bzip2-asan-c1000-build/bzip2 --keep --force test-archive.tar

# The baseline version took 37 seconds, whereas the AddressSanitizer-instrumented version takes 70 seconds.
# An overhead of 89%

# Let's see how ASAP reduces this overhead
time ./bzip2-asan-c0010-build/bzip2 --keep --force test-archive.tar

# ASAP has reduced the overhead to 8% (while keeping 77% of the instrumentation)
# That's it. Have a lot of fun!
