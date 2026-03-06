#!/usr/bin/env bats
# Unit tests for memory module
# Tests entry generation, section toggling, on_select routing, and preview.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"
MEMORY_DIR="$HALL_DIR/modules/memory"

setup() {
    hall_test_setup_home
    HALL_STATE_DIR=$(mktemp -d)
    export HALL_STATE_DIR
    export HALL_DIR
    export HALL_LIB_DIR

    TEST_PROJECT=$(mktemp -d)
    ORIG_DIR="$PWD"
    cd "$TEST_PROJECT"
}

teardown() {
    cd "$ORIG_DIR"
    rm -rf "$HALL_STATE_DIR" "$TEST_PROJECT" 2>/dev/null
    hall_test_teardown_home
}

# ============================================================================
# module.sh: sourcing and metadata
# ============================================================================

@test "memory: module.sh can be sourced" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$MEMORY_DIR/module.sh'
        echo \$HALL_MODULE_LABEL
        echo \$HALL_MODULE_ORDER
    "
    assert_success
    assert_line --index 0 'Memory'
    assert_line --index 1 '35'
}

# ============================================================================
# module.sh: section state initialization
# ============================================================================

@test "memory: creates default section state file" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries >/dev/null
        cat '$HALL_STATE_DIR/memory-sections'
    "
    assert_success
    assert_line --index 0 'Project:1'
    assert_line --index 1 'User:1'
    assert_line --index 2 'Auto:1'
}

# ============================================================================
# module.sh: entry generation
# ============================================================================

@test "memory: guide entry always present" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    assert_output --partial 'mv-info guide'
}

@test "memory: project section shows CLAUDE.md with line count" {
    echo -e "line1\nline2\nline3" > "$TEST_PROJECT/CLAUDE.md"
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    assert_output --partial 'CLAUDE.md'
    assert_output --partial '3 lines'
    assert_output --partial 'mv-open ./CLAUDE.md'
}

@test "memory: project section shows missing for absent files" {
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    assert_output --partial 'missing'
}

@test "memory: project section shows empty for empty files" {
    touch "$TEST_PROJECT/CLAUDE.md"
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    assert_output --partial 'empty'
}

@test "memory: shows .claude/CLAUDE.local.md when it exists" {
    mkdir -p "$TEST_PROJECT/.claude"
    echo "alt local" > "$TEST_PROJECT/.claude/CLAUDE.local.md"
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    assert_output --partial '.claude/CLAUDE.local.md'
    assert_output --partial 'mv-open ./.claude/CLAUDE.local.md'
}

@test "memory: collapsed sections show item count" {
    echo "test" > "$TEST_PROJECT/CLAUDE.md"
    echo "test" > "$TEST_PROJECT/CLAUDE.local.md"
    # Force User and Auto to collapsed (default), check count
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        # Set User collapsed with count
        printf 'Project:1\nUser:0\nAuto:0\n' > '$HALL_STATE_DIR/memory-sections'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    # User section should show item count when collapsed
    assert_output --partial '▸ User Memory'
}

@test "memory: auto memory resolves project slug with underscores normalized to hyphens" {
    local project_dir slug auto_dir
    project_dir="$TEST_PROJECT/_projs/cc_hall"
    mkdir -p "$project_dir"
    slug=$(printf '%s' "$project_dir" | sed 's#/#-#g; s#_#-#g')
    auto_dir="$HOME/.claude/projects/$slug/memory"
    mkdir -p "$auto_dir"
    printf '# Auto memory\n' > "$auto_dir/MEMORY.md"

    run bash -c "
        cd '$project_dir'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$HOME'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$MEMORY_DIR/module.sh'
        hall_memory_entries
    "
    assert_success
    assert_output --partial 'Auto Memory'
    assert_output --partial 'MEMORY.md'
    refute_output --partial '(none yet)'
}

# ============================================================================
# on_select.sh: section toggle
# ============================================================================

@test "memory: on_select toggles section state" {
    printf 'Project:1\nUser:0\nAuto:0\n' > "$HALL_STATE_DIR/memory-sections"
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$MEMORY_DIR/on_select.sh' 'mv-section:Project' '/dev/null'
    "
    [ "$status" -eq 2 ]
    run cat "$HALL_STATE_DIR/memory-sections"
    assert_output --partial 'Project:0'
}

@test "memory: on_select toggle expands collapsed section" {
    printf 'Project:1\nUser:0\nAuto:0\n' > "$HALL_STATE_DIR/memory-sections"
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$MEMORY_DIR/on_select.sh' 'mv-section:User' '/dev/null'
    "
    [ "$status" -eq 2 ]
    run cat "$HALL_STATE_DIR/memory-sections"
    assert_output --partial 'User:1'
}

# ============================================================================
# on_select.sh: command routing
# ============================================================================

@test "memory: on_select mv-info returns exit 2" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$MEMORY_DIR/on_select.sh' 'mv-info guide' '/dev/null'
    "
    [ "$status" -eq 2 ]
}

@test "memory: on_select unknown command returns exit 1" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$MEMORY_DIR/on_select.sh' 'unknown-cmd' '/dev/null'
    "
    [ "$status" -eq 1 ]
}

# ============================================================================
# preview.sh: content generation
# ============================================================================

@test "memory: preview guide shows memory overview" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$MEMORY_DIR/preview.sh" "mv-info guide"
    assert_success
    assert_output --partial 'Memory'
    assert_output --partial 'What'
    assert_output --partial 'Loads'
}

@test "memory: preview section header shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$MEMORY_DIR/preview.sh" "mv-section:Project"
    assert_success
    assert_output --partial 'Project'
}

@test "memory: preview file entry shows content" {
    echo -e "# Test\nHello world" > "$TEST_PROJECT/CLAUDE.md"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$MEMORY_DIR/preview.sh" "mv-open $TEST_PROJECT/CLAUDE.md"
    assert_success
    assert_output --partial '2 lines'
    assert_output --partial 'Test'
    assert_output --partial 'Hello world'
}

@test "memory: preview missing file shows creation hint" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$MEMORY_DIR/preview.sh" "mv-open /tmp/nonexistent-test-file.md"
    assert_success
    assert_output --partial 'does not exist'
    assert_output --partial 'create'
}

@test "memory: preview no-auto shows explanation" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$MEMORY_DIR/preview.sh" "mv-info no-auto"
    assert_success
    assert_output --partial 'No'
    assert_output --partial 'Memory'
}
