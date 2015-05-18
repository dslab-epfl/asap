#!/bin/sh

set -e

if [ $# -ne 3 ]; then
    echo "usage: phoronix-asap <testname> <ext> <asap-flags>" >&2
    exit 1
fi
testname="$1"
ext="$2"
asap_flags="$3"

SCRIPT_DIR="$( dirname $0 )"
. "$SCRIPT_DIR/phoronix-common.sh"

if phoronix_is_installed; then
    echo "Test $CURRENT_TESTNAME is already installed; please remove manually" >&2
    exit 1
fi


echo "Phase 1: initial build"
"$CC" -asap-init
phoronix_install


echo "Phase 2: coverage build"
"$CC" -asap-coverage
phoronix_install


echo "Run profiling workload"

# Override the run script to run only once, even if there are multiple test runs.
# TODO: we could also use "timeout" to shorten this even further. However,
# processes don't write .gcda files when terminated... we'd need a workaround
# for this.
mv "$CURRENT_INSTALL_DIR/$EXECUTABLE" "$CURRENT_INSTALL_DIR/${EXECUTABLE}.orig"
cat > "$CURRENT_INSTALL_DIR/$EXECUTABLE" <<EOF
#!/bin/sh
profiling_file="profiling.\$( echo "\$@" | tr -C -d 'a-zA-Z0-9_-' ).log"
if [ -f "\$profiling_file" ]; then exit 0; fi
"$CURRENT_INSTALL_DIR/${EXECUTABLE}.orig" "\$@"
status=\$?
cp "\$LOG_FILE" "\$profiling_file"
exit \$status
EOF
chmod u+x "$CURRENT_INSTALL_DIR/$EXECUTABLE"

echo | phoronix-test-suite batch-run "$CURRENT_TESTNAME"


echo "Phase 3: optimized build"
"$CC" -asap-optimize $asap_flags
phoronix_install

