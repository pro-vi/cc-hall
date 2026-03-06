#!/usr/bin/env bats
# Unit tests for install.sh

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"

setup() {
    hall_test_setup_home
}

teardown() {
    hall_test_teardown_home
}

@test "install.sh: streamed execution aborts with clone instructions" {
    run bash -lc "
        cd '$HALL_DIR'
        cat install.sh | bash
    "
    assert_failure
    assert_output --partial 'Streamed install is not supported.'
    assert_output --partial 'git clone https://github.com/pro-vi/cc-hall.git'
    assert_output --partial 'cd cc-hall && ./install.sh'
}
