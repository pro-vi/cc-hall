#!/usr/bin/env bats
# Unit tests for hall-common.sh
# Tests menu parsing, route splitting, entry tagging, and preview extraction.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"

setup() {
    hall_test_setup_home
}

teardown() {
    hall_test_teardown_home
}

# ============================================================================
# hall_parse_command
# ============================================================================

@test "hall_parse_command: extracts command after tab delimiter" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_parse_command \$'My Label\tsome-command arg1'
    "
    assert_success
    assert_output --partial 'some-command arg1'
}

@test "hall_parse_command: extracts tagged command with module prefix" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_parse_command \$'Label\tcc-hall\x1fpa-toggle-theme'
    "
    assert_success
    assert_output --partial 'cc-hall'
    assert_output --partial 'pa-toggle-theme'
}

@test "hall_parse_command: returns 1 on empty input" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_parse_command ''
    "
    assert_failure
}

# ============================================================================
# hall_split_route
# ============================================================================

@test "hall_split_route: splits module and command on unit separator" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_split_route \$'cc-hall\x1fpa-toggle-theme'
        echo \"module=\$HALL_ROUTE_MODULE\"
        echo \"cmd=\$HALL_ROUTE_CMD\"
    "
    assert_success
    assert_output --partial 'module=cc-hall'
    assert_output --partial 'cmd=pa-toggle-theme'
}

@test "hall_split_route: no module when no separator" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_split_route 'bare-command arg'
        echo \"module=\$HALL_ROUTE_MODULE\"
        echo \"cmd=\$HALL_ROUTE_CMD\"
    "
    assert_success
    assert_output --partial 'module='
    assert_output --partial 'cmd=bare-command arg'
}

@test "hall_split_route: handles command with spaces" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_split_route \$'editor\x1fvi /tmp/file.md'
        echo \"module=\$HALL_ROUTE_MODULE\"
        echo \"cmd=\$HALL_ROUTE_CMD\"
    "
    assert_success
    assert_output --partial 'module=editor'
    assert_output --partial 'cmd=vi /tmp/file.md'
}

# ============================================================================
# hall_tag_entries
# ============================================================================

@test "hall_tag_entries: inserts module name between label and command" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        echo \$'My Label\tmy-command' | hall_tag_entries 'editor'
    "
    assert_success
    # Output format: label\tmodule\x1fcommand
    assert_output --partial 'My Label'
    assert_output --partial 'editor'
    assert_output --partial 'my-command'
}

@test "hall_tag_entries: handles multiple lines" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        printf '%s\n%s\n' \$'Label A\tcmd-a' \$'Label B\tcmd-b' | hall_tag_entries 'mod'
    "
    assert_success
    assert_output --partial 'cmd-a'
    assert_output --partial 'cmd-b'
}

@test "hall_tag_entries: skips empty lines" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        printf '%s\n\n%s\n' \$'A\tcmd-a' \$'B\tcmd-b' | hall_tag_entries 'mod' | wc -l | tr -d ' '
    "
    assert_success
    assert_output '2'
}

# ============================================================================
# hall_preview_extract_cmd
# ============================================================================

@test "hall_preview_extract_cmd: extracts command from tagged line" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_preview_extract_cmd \$'Label\tcc-hall\x1fpa-toggle-theme'
        echo \"\$HALL_PREVIEW_CMD\"
    "
    assert_success
    assert_output 'pa-toggle-theme'
}

@test "hall_preview_extract_cmd: extracts command without module tag" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_preview_extract_cmd \$'Label\tbare-command'
        echo \"\$HALL_PREVIEW_CMD\"
    "
    assert_success
    assert_output 'bare-command'
}

@test "hall_preview_extract_cmd: returns 1 on empty input" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_preview_extract_cmd ''
    "
    assert_failure
}

@test "hall_editor_cmd: quotes filepath with spaces" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_editor_cmd vim '/path/with spaces/CLAUDE.md'
    "
    assert_success
    assert_output "vi '/path/with spaces/CLAUDE.md'"
}

@test "hall_editor_cmd: code uses -w flag" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_editor_cmd code '/tmp/test.md'
    "
    assert_success
    assert_output "code -w '/tmp/test.md'"
}

@test "hall_editor_cmd: subl uses -w flag" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_editor_cmd subl '/tmp/test.md'
    "
    assert_success
    assert_output "subl -w '/tmp/test.md'"
}

@test "hall_editor_cmd: unknown editor falls back to vi" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_editor_cmd nano '/tmp/test.md'
    "
    assert_success
    assert_output "vi '/tmp/test.md'"
}

@test "hall_preview_extract_cmd: preserves command arguments" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_preview_extract_cmd \$'Label\tskill-viewer\x1fskill-invoke commit /path/to/SKILL.md'
        echo \"\$HALL_PREVIEW_CMD\"
    "
    assert_success
    assert_output 'skill-invoke commit /path/to/SKILL.md'
}

@test "hall_set_footer_message + hall_consume_footer_message: one-shot state" {
    local state_dir
    state_dir=$(mktemp -d)
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR' HALL_STATE_DIR='$state_dir'
        source '$HALL_LIB_DIR/hall-common.sh'
        hall_set_footer_message ' Invalid JSON in ~/.claude/settings.json. '
        first=\$(hall_consume_footer_message)
        second=\$(hall_consume_footer_message)
        printf 'first=%s\nsecond=%s\n' \"\$first\" \"\$second\"
    "
    assert_success
    assert_output --partial 'first= Invalid JSON in ~/.claude/settings.json. '
    assert_output --partial 'second='
    rm -rf "$state_dir"
}
