#!/usr/bin/env bats
# Unit tests for lib/hall-yank.sh
# Covers prefix guard, skip-count extraction, space-in-path, and non-file no-ops.
# Exit code contract: 0 = copied, non-zero = skipped (drives transform footer).

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
YANK="$HALL_DIR/lib/hall-yank.sh"

setup() {
    TMPDIR_YANK=$(mktemp -d "${TMPDIR:-/tmp}/hall-yank-test.XXXXXX")
    # Seed clipboard with sentinel so we can detect no-ops
    printf 'SENTINEL' | pbcopy
}

teardown() {
    rm -rf "$TMPDIR_YANK" 2>/dev/null
}

# ============================================================================
# Prefix guard — non-matching commands must exit non-zero and not touch clipboard
# ============================================================================

@test "prefix guard: skill-info row is rejected with non-zero exit" {
    run "$YANK" $'skill-viewer\x1fskill-info guide' skill-invoke 2
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}

@test "prefix guard: mv-noop row is rejected with non-zero exit" {
    run "$YANK" $'memory\x1fmv-noop' mv-open 1
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}

@test "prefix guard: mv-section row is rejected with non-zero exit" {
    run "$YANK" $'memory\x1fmv-section:Project' mv-open 1
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}

@test "prefix guard: mv-toggle-editor row is rejected with non-zero exit" {
    run "$YANK" $'memory\x1fmv-toggle-editor' mv-open 1
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}

@test "prefix guard: empty input is rejected with non-zero exit" {
    run "$YANK" '' mv-open 1
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}

# ============================================================================
# Happy path — matching commands copy file content and exit 0
# ============================================================================

@test "mv-open: copies file content to clipboard" {
    local f="$TMPDIR_YANK/CLAUDE.md"
    printf 'project instructions' > "$f"

    run "$YANK" $'memory\x1fmv-open '"$f" mv-open 1
    assert_success
    assert_equal "$(pbpaste)" "project instructions"
}

@test "skill-invoke: copies file content to clipboard" {
    local f="$TMPDIR_YANK/SKILL.md"
    printf 'skill body' > "$f"

    run "$YANK" $'skill-viewer\x1fskill-invoke myskill '"$f" skill-invoke 2
    assert_success
    assert_equal "$(pbpaste)" "skill body"
}

# ============================================================================
# Space-in-path — filepath with spaces must not be truncated
# ============================================================================

@test "mv-open: path with spaces is preserved" {
    local dir="$TMPDIR_YANK/My Project/.claude"
    mkdir -p "$dir"
    local f="$dir/CLAUDE.md"
    printf 'spaced content' > "$f"

    run "$YANK" $'memory\x1fmv-open '"$f" mv-open 1
    assert_success
    assert_equal "$(pbpaste)" "spaced content"
}

@test "skill-invoke: path with spaces is preserved" {
    local dir="$TMPDIR_YANK/My Home/.claude/skills/demo"
    mkdir -p "$dir"
    local f="$dir/SKILL.md"
    printf 'spaced skill' > "$f"

    run "$YANK" $'skill-viewer\x1fskill-invoke demo '"$f" skill-invoke 2
    assert_success
    assert_equal "$(pbpaste)" "spaced skill"
}

# ============================================================================
# Missing file — must exit non-zero and not change clipboard
# ============================================================================

@test "mv-open: missing file exits non-zero" {
    run "$YANK" $'memory\x1fmv-open /no/such/file.md' mv-open 1
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}

@test "skill-invoke: missing file exits non-zero" {
    run "$YANK" $'skill-viewer\x1fskill-invoke gone /no/such/SKILL.md' skill-invoke 2
    assert_failure
    assert_equal "$(pbpaste)" "SENTINEL"
}
