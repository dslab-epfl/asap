ASAP: High System Code Security at Low Overhead
===============================================

ASAP is a system for instrumenting software using sanity checks, subject to
performance constraints.

ASAP is based on the LLVM compiler framework. For more information about LLVM
please consult `llvm/README.txt` and `llvm/LICENSE.txt`. ASAP itself is
distributed under the terms of `LICENSE.txt` in the same folder as this
`README.md` file.


Documentation
-------------

The files in `asap/doc/` and the remainder of this README contain various examples
of using ASAP.


Obtaining and Compiling ASAP
----------------------------

1. Check out ASAP's source code:

        # Create a project folder
        mkdir asap
        cd asap
        export ASAP_DIR=$(pwd)

        # Clone the source code
        git clone https://github.com/dslab-epfl/asap.git
        git clone http://llvm.org/git/clang.git asap/tools/clang
        ( cd asap/tools/clang && git checkout release_37 )
        git clone http://llvm.org/git/compiler-rt.git asap/projects/compiler-rt
        ( cd asap/projects/compiler-rt && git checkout release_37 )

2. On Linux, compiling ASAP also depends on binutils development files, since
   we need to build the LLVM Gold linker plugin:

        sudo aptitude install binutils-dev

3. Compile ASAP:

        cd $ASAP_DIR
        mkdir build
        cd build

        # For configuring, these settings are recommended:
        # - -G Ninja finishes the build sooner (you want your build ASAP, after all :) )
        # - -DLLVM_ENABLE_ASSERTIONS=ON makes bugs a bit easier to understand
        # - -DCMAKE_EXPORT_COMPILE_COMMANDS=ON causes a compile_commands.json
        #   file to be generated. This file is useful if you're editing the ASAP
        #   source code or running code analysis tools.
        cmake -G Ninja -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ../asap

        # Launch the compilation
        cmake --build .

   On Linux, add `-DLLVM_BINUTILS_INCDIR=/usr/include` to the cmake command
   line.


Trying ASAP on a small example
------------------------------

A small example for ASAP is available in
`llvm/lib/Transforms/SanityChecks/doc/sum/`. It contains a small program
vulnerable to a buffer overflow. The program is protected by compiling it with
AddressSanitizer. ASAP then measures the effect of each ASan check, and removes
the most expensive ones.

To run the example:

    export PATH=$ASAP_DIR/build/bin:$PATH
    cd $ASAP_DIR/asap/lib/Transforms/SanityChecks/doc/sum
    make

Please have a look at the Makefile to see the individual steps performed by
ASAP.
