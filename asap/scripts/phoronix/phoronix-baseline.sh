#!/bin/sh

set -e

if [ $# -ne 2 ]; then
    echo "usage: phoronix-baseline <testname> <ext>" >&2
    exit 1
fi
testname="$1"
ext="$2"

SCRIPT_DIR="$( dirname $0 )"
. "$SCRIPT_DIR/phoronix-common.sh"

if phoronix_is_installed; then
    echo "Test $CURRENT_TESTNAME is already installed; please remove manually" >&2
    exit 1
fi


echo "Phase 1: initial build"
"$CC" -asap-init
phoronix_install
