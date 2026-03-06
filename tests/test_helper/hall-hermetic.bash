#!/usr/bin/env bash
# Shared hermetic HOME setup for Bats tests that source hall-common.sh.

hall_test_setup_home() {
    HALL_TEST_ORIG_HOME="${HOME:-}"
    HALL_TEST_ORIG_TMUX="${TMUX:-}"
    HALL_TEST_ORIG_ORIGINAL_TMUX="${ORIGINAL_TMUX:-}"
    HALL_TEST_ORIG_TMUX_PANE="${TMUX_PANE:-}"
    HALL_TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/cc-hall-home.XXXXXX")
    export HALL_TEST_HOME
    export HOME="$HALL_TEST_HOME"
    unset TMUX ORIGINAL_TMUX TMUX_PANE
}

hall_test_teardown_home() {
    if [ -n "${HALL_TEST_ORIG_HOME:-}" ]; then
        export HOME="$HALL_TEST_ORIG_HOME"
    fi
    if [ -n "${HALL_TEST_ORIG_TMUX:-}" ]; then
        export TMUX="$HALL_TEST_ORIG_TMUX"
    else
        unset TMUX
    fi
    if [ -n "${HALL_TEST_ORIG_ORIGINAL_TMUX:-}" ]; then
        export ORIGINAL_TMUX="$HALL_TEST_ORIG_ORIGINAL_TMUX"
    else
        unset ORIGINAL_TMUX
    fi
    if [ -n "${HALL_TEST_ORIG_TMUX_PANE:-}" ]; then
        export TMUX_PANE="$HALL_TEST_ORIG_TMUX_PANE"
    else
        unset TMUX_PANE
    fi
    rm -rf "${HALL_TEST_HOME:-}" 2>/dev/null
    unset HALL_TEST_HOME HALL_TEST_ORIG_HOME HALL_TEST_ORIG_TMUX \
        HALL_TEST_ORIG_ORIGINAL_TMUX HALL_TEST_ORIG_TMUX_PANE
}
