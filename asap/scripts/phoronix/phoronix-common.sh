if [ -z "$CFLAGS" ]; then
    echo "Please set CFLAGS" >&2
    exit 1
fi
if [ -z "$CXXFLAGS" ]; then
    echo "Please set CXXFLAGS" >&2
    exit 1
fi
if [ -z "$LDFLAGS" ]; then
    echo "Please set LDFLAGS" >&2
    exit 1
fi

PROFILE_DIR="$HOME/.phoronix-test-suite/test-profiles"
INSTALL_DIR="$HOME/.phoronix-test-suite/installed-tests"

TEST_BASENAME=$( basename "$testname" )
CURRENT_TESTNAME="local/${TEST_BASENAME}-${ext}"
CURRENT_PROFILE_DIR="$PROFILE_DIR/$CURRENT_TESTNAME"
CURRENT_INSTALL_DIR="$INSTALL_DIR/$CURRENT_TESTNAME"
STATE_DIR="$INSTALL_DIR/local/asap-state-${TEST_BASENAME}-${ext}"
export ASAP_STATE_PATH="$STATE_DIR"


# Copy the test profile
if ! [ -d "$PROFILE_DIR/$testname" ]; then
    echo "Could not find test $testname" >&2
    exit 1
fi
rm -rf "$CURRENT_PROFILE_DIR"
cp -r "$PROFILE_DIR/$testname" "$CURRENT_PROFILE_DIR"

# Ensure the test profile mentions the name of the executable
EXECUTABLE="${TEST_BASENAME%-*}"
if grep '<Executable>.*</Executable>' "$CURRENT_PROFILE_DIR/test-definition.xml" >/dev/null; then
    EXECUTABLE=$( grep '<Executable>.*</Executable>' "$CURRENT_PROFILE_DIR/test-definition.xml" | sed -e 's/\s//g' -e 's|</\?Executable>||g' )
else
    sed --in-place -e "s|</TestInformation>|  <Executable>$EXECUTABLE</Executable>\n  </TestInformation>|" \
        "$CURRENT_PROFILE_DIR/test-definition.xml"
fi

if ! which asap-clang >/dev/null 2>&1; then
    echo "Please add asap-clang to PATH" >&2
    exit 1
fi
export CC="$( which asap-clang )"
export CXX="$( which asap-clang++ )"


phoronix_install() {
    echo "y" | phoronix-test-suite remove-installed-test "$CURRENT_TESTNAME"
    rm -rf "$CURRENT_INSTALL_DIR"
    mkdir -p "$CURRENT_INSTALL_DIR"
    echo | phoronix-test-suite batch-install "$CURRENT_TESTNAME"
    if ! [ -x "$CURRENT_INSTALL_DIR/$EXECUTABLE" ]; then
        echo "Could not find executable '$CURRENT_INSTALL_DIR/$EXECUTABLE'" >&2
        echo "y" | phoronix-test-suite remove-installed-test "$CURRENT_TESTNAME"
        exit 1
    fi
    if [ -f "$CURRENT_INSTALL_DIR/install-failed.log" ]; then
        echo "found install-failed.log" >&2
        echo "y" | phoronix-test-suite remove-installed-test "$CURRENT_TESTNAME"
        exit 1
    fi
    if [ -f "$CURRENT_INSTALL_DIR/install-exit-status" ] && [ "$( cat "$CURRENT_INSTALL_DIR/install-exit-status" )" != "0" ]; then
        echo "install-exit-status is not zero" >&2
        echo "y" | phoronix-test-suite remove-installed-test "$CURRENT_TESTNAME"
        exit 1
    fi

    echo "$CURRENT_TESTNAME installed successfully"
    echo
}


phoronix_is_installed() {
    phoronix-test-suite info "$CURRENT_TESTNAME" | grep "Test Installed: Yes" > /dev/null
}
