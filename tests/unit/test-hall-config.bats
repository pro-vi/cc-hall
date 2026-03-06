#!/usr/bin/env bats
# Unit tests for hall-config.sh guards around JSON mutation.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"

setup() {
    hall_test_setup_home
    TEST_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null
    hall_test_teardown_home
}

@test "hall_config_set_string: refuses malformed hall config without overwriting it" {
    local config_file="$TEST_DIR/config.json"
    local malformed='{"theme":"mirrors",}'
    printf '%s' "$malformed" > "$config_file"

    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-config.sh'
        hall_config_set_string '$config_file' 'theme' 'clawd'
    "
    assert_failure
    assert_output --partial 'Invalid JSON'

    run cat "$config_file"
    assert_output "$malformed"
}
