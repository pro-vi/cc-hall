#!/usr/bin/env bats
# Unit tests for skill-viewer module
# Tests on_select.sh skill invocation, edge cases, and entry generation.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"
SKILL_VIEWER_DIR="$HALL_DIR/modules/skill-viewer"

setup() {
    hall_test_setup_home
    TMPFILE=$(mktemp)
    export TMPFILE
}

teardown() {
    rm -f "$TMPFILE" 2>/dev/null
    hall_test_teardown_home
}

# ============================================================================
# entries: metadata parsing and cache-friendly rendering
# ============================================================================

@test "_hall_skill_read_meta: extracts name and description in one pass" {
    local skill_dir="$HOME/.claude/skills/demo"
    local skill_file="$skill_dir/SKILL.md"
    mkdir -p "$skill_dir"
    cat > "$skill_file" <<'EOF'
---
name: "Demo Skill"
description: "Description: with colon"
---
Body
EOF

    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$SKILL_VIEWER_DIR/module.sh'
        _hall_skill_read_meta '$skill_file'
        printf 'name=%s\ndesc=%s\n' \"\$HALL_SKILL_NAME\" \"\$HALL_SKILL_DESC\"
    "
    assert_success
    assert_output --partial 'name=Demo Skill'
    assert_output --partial 'desc=Description: with colon'
}

@test "entries: probes Nerd Fonts once per render" {
    local skill_dir="$HOME/.claude/skills/demo"
    local tool_dir
    local count_file
    tool_dir=$(mktemp -d)
    count_file=$(mktemp)
    mkdir -p "$skill_dir"

    cat > "$skill_dir/SKILL.md" <<'EOF'
---
name: Demo Skill
description: Demo description
---
Body
EOF

    cat > "$tool_dir/fc-list" <<EOF
#!/usr/bin/env bash
count_file='$count_file'
count=0
[ -f "\$count_file" ] && count=\$(cat "\$count_file")
count=\$((count + 1))
printf '%s\n' "\$count" > "\$count_file"
printf '%s\n' 'Hack Nerd Font'
EOF
    chmod +x "$tool_dir/fc-list"

    run bash -c "
        export PATH='$tool_dir':\$PATH
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$SKILL_VIEWER_DIR/module.sh'
        hall_skill_viewer_entries >/dev/null
        cat '$count_file'
    "
    assert_success
    assert_output '1'

    rm -rf "$tool_dir"
    rm -f "$count_file"
}

# ============================================================================
# on_select: skill-invoke happy path
# ============================================================================

@test "on_select: skill-invoke appends /name to file" {
    echo -n "rough prompt" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke commit /path/to/SKILL.md" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    [[ "$result" == "rough prompt/commit" ]]
}

@test "on_select: skill-invoke exits 0 (close hall)" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke commit /path/to/SKILL.md" "$TMPFILE"
    [ "$status" -eq 0 ]
}

@test "on_select: skill-invoke with hyphenated name" {
    echo -n "" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke code-review /path/to/SKILL.md" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    [[ "$result" == "/code-review" ]]
}

@test "on_select: skill-invoke preserves existing file content" {
    printf 'add auth to login page' > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke refactor /fake/SKILL.md" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    [[ "$result" == "add auth to login page/refactor" ]]
}

@test "on_select: skill-invoke with no filepath arg still extracts name" {
    echo -n "" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke debugging" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    [[ "$result" == "/debugging" ]]
}

# ============================================================================
# on_select: edge cases
# ============================================================================

@test "on_select: empty skill name exits 1 and leaves file untouched" {
    echo -n "content" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke " "$TMPFILE"
    [ "$status" -eq 1 ]
    result=$(<"$TMPFILE")
    [[ "$result" == "content" ]]
}

@test "on_select: unrecognized command exits 1" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "unknown-command" "$TMPFILE"
    [ "$status" -eq 1 ]
}

@test "on_select: bare skill-invoke (no space) exits 1" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke" "$TMPFILE"
    [ "$status" -eq 1 ]
}

@test "on_select: file untouched on unrecognized command" {
    echo -n "original" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "bogus" "$TMPFILE"
    result=$(<"$TMPFILE")
    [[ "$result" == "original" ]]
}

@test "on_select: skill name with underscores" {
    echo -n "" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke my_skill /fake/SKILL.md" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    [[ "$result" == "/my_skill" ]]
}

@test "on_select: only appends skill name, not filepath" {
    echo -n "" > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke commit /home/user/.claude/skills/commit/SKILL.md" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    # Should be /commit, not the full path
    [[ "$result" == "/commit" ]]
}

# ============================================================================
# on_select: file with newlines (multiline prompt)
# ============================================================================

@test "on_select: appends to multiline prompt file" {
    printf 'line one\nline two\n' > "$TMPFILE"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$SKILL_VIEWER_DIR/on_select.sh" "skill-invoke start-linear /fake/SKILL.md" "$TMPFILE"
    assert_success
    result=$(<"$TMPFILE")
    [[ "$result" == *"/start-linear" ]]
    # Original content preserved
    [[ "$result" == "line one"* ]]
}
