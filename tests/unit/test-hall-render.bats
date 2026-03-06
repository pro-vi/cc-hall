#!/usr/bin/env bats
# Unit tests for hall-render.sh and themed glow style generation.

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

@test "hall_render_markdown: prefers compact preview glow style" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-render.sh'
        _HALL_HAS_GLOW=1
        HALL_GLOW_STYLE='$BATS_TEST_TMPDIR/glow-style.json'
        HALL_GLOW_PREVIEW_STYLE='$BATS_TEST_TMPDIR/glow-preview-style.json'
        : > \"\$HALL_GLOW_STYLE\"
        : > \"\$HALL_GLOW_PREVIEW_STYLE\"
        FZF_PREVIEW_COLUMNS=72
        _hall_glow() { printf '%s\n' \"\$*\"; cat >/dev/null; }
        printf 'preview text\n' | hall_render_markdown
    "
    assert_success
    assert_output "-s $BATS_TEST_TMPDIR/glow-preview-style.json -w 72 -"
}

@test "hall_render_markdown: respects quick preview renderer metadata" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_MODULE_PREVIEW_RENDERER='quick'
        source '$HALL_LIB_DIR/hall-render.sh'
        _HALL_HAS_GLOW=1
        _hall_glow() {
            echo 'unexpected glow'
            exit 1
        }
        FZF_PREVIEW_COLUMNS=80
        printf '**Heading**\n\nUse \`code\`.\n' | hall_render_markdown
    "
    assert_success
    assert_output --partial 'Heading'
    assert_output --partial 'Use code.'
    refute_output --partial 'unexpected glow'
}

@test "hall_render_markdown: caches rendered markdown by theme and width" {
    local count_file="$BATS_TEST_TMPDIR/glow-count"
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_STATE_DIR='$BATS_TEST_TMPDIR/state'
        export HALL_THEME_NAME='Mirrors'
        mkdir -p \"\$HALL_STATE_DIR\"
        source '$HALL_LIB_DIR/hall-render.sh'
        _HALL_HAS_GLOW=1
        HALL_GLOW_STYLE='$BATS_TEST_TMPDIR/glow-style.json'
        HALL_GLOW_PREVIEW_STYLE='$BATS_TEST_TMPDIR/glow-preview-style.json'
        : > \"\$HALL_GLOW_STYLE\"
        : > \"\$HALL_GLOW_PREVIEW_STYLE\"
        FZF_PREVIEW_COLUMNS=72
        _hall_glow() {
            count=0
            [ -f '$count_file' ] && count=\$(cat '$count_file')
            count=\$((count + 1))
            printf '%s\n' \"\$count\" > '$count_file'
            cat
        }
        printf 'preview text\n' | hall_render_markdown >/dev/null
        printf 'preview text\n' | hall_render_markdown >/dev/null
        cat '$count_file'
    "
    assert_success
    assert_output '1'
}

@test "hall_render_quick_markdown: strips simple markdown and table separators" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-render.sh'
        FZF_PREVIEW_COLUMNS=80
        cat <<'EOF' | hall_render_quick_markdown
**Heading**

| Key | Value |
|-----|-------|
| A | B |

* Item
Use \`code\` and **bold** text.
EOF
    "
    assert_success
    assert_output --partial 'Heading'
    assert_output --partial 'Key  Value'
    assert_output --partial 'A  B'
    assert_output --partial '• Item'
    assert_output --partial 'Use code and bold text.'
    refute_output --partial '|-----|'
}

@test "hall_render_file: caches markdown file renders by file metadata" {
    local md_file="$BATS_TEST_TMPDIR/test.md"
    local count_file="$BATS_TEST_TMPDIR/file-glow-count"
    printf '# Title\n\nBody\n' > "$md_file"

    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_STATE_DIR='$BATS_TEST_TMPDIR/state-file-cache'
        export HALL_THEME_NAME='Mirrors'
        mkdir -p \"\$HALL_STATE_DIR\"
        source '$HALL_LIB_DIR/hall-render.sh'
        _HALL_HAS_GLOW=1
        HALL_GLOW_STYLE='$BATS_TEST_TMPDIR/glow-style.json'
        : > \"\$HALL_GLOW_STYLE\"
        FZF_PREVIEW_COLUMNS=72
        _hall_glow() {
            count=0
            [ -f '$count_file' ] && count=\$(cat '$count_file')
            count=\$((count + 1))
            printf '%s\n' \"\$count\" > '$count_file'
            cat
        }
        hall_render_file '$md_file' 20 >/dev/null
        hall_render_file '$md_file' 20 >/dev/null
        cat '$count_file'
    "
    assert_success
    assert_output '1'
}

@test "hall_apply_glow_style: generates compact preview style alongside file style" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_STATE_DIR='$BATS_TEST_TMPDIR/state'
        mkdir -p \"\$HALL_STATE_DIR\"
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-theme.sh'
        hall_apply_glow_style
        [ -f \"\$HALL_GLOW_STYLE\" ]
        [ -f \"\$HALL_GLOW_PREVIEW_STYLE\" ]
        grep -F '\"margin\": 2' \"\$HALL_GLOW_STYLE\"
        grep -F '\"margin\": 0' \"\$HALL_GLOW_PREVIEW_STYLE\"
        grep -F '\"prefix\": \"\"' \"\$HALL_GLOW_PREVIEW_STYLE\"
        grep -F '\"suffix\": \"\"' \"\$HALL_GLOW_PREVIEW_STYLE\"
    "
    assert_success
}

@test "hall_apply_glow_style: h1 uses curated theme pair for each built-in theme" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        for theme in mirrors clawd zinc; do
            export HOME='$BATS_TEST_TMPDIR/home-'\"\$theme\"
            export HALL_STATE_DIR='$BATS_TEST_TMPDIR/state-'\"\$theme\"
            mkdir -p \"\$HOME/.claude/reflections\" \"\$HALL_STATE_DIR\"
            printf '{\"theme\":\"%s\"}\n' \"\$theme\" > \"\$HOME/.claude/reflections/config.json\"
            unset _HALL_THEME_LOADED
            unset HALL_CONFIG_FILE
            unset HALL_THEME_NAME HALL_GLOW_H1_FG_256 HALL_GLOW_H1_BG_256 \
                HALL_FZF_COLORS HALL_TMUX_WINDOW_BG HALL_TMUX_WINDOW_FG \
                HALL_TMUX_STATUS_BG HALL_TMUX_STATUS_FG HALL_TMUX_PANE_BORDER_FG \
                HALL_TMUX_PANE_ACTIVE_BORDER_FG HALL_TMUX_STATUS_LEFT HALL_TMUX_STATUS_RIGHT \
                HALL_FZF_POINTER HALL_FZF_MARKER HALL_FZF_SCROLLBAR HALL_FZF_SEPARATOR HALL_FZF_PROMPT
            source '$HALL_LIB_DIR/hall-common.sh'
            source '$HALL_LIB_DIR/hall-theme.sh'
            hall_apply_glow_style
            h1_block=\$(awk '/\"h1\": \\{/{flag=1} flag{print} flag && /\\}/{exit}' \"\$HALL_GLOW_STYLE\")
            printf '%s\n' \"\$theme\"
            printf '%s\n' \"\$h1_block\"
            case \"\$theme\" in
                mirrors)
                    printf '%s\n' \"\$h1_block\" | grep -F '\"color\": \"153\"'
                    printf '%s\n' \"\$h1_block\" | grep -F '\"background_color\": \"59\"'
                    ;;
                clawd)
                    printf '%s\n' \"\$h1_block\" | grep -F '\"color\": \"222\"'
                    printf '%s\n' \"\$h1_block\" | grep -F '\"background_color\": \"94\"'
                    ;;
                zinc)
                    printf '%s\n' \"\$h1_block\" | grep -F '\"color\": \"252\"'
                    printf '%s\n' \"\$h1_block\" | grep -F '\"background_color\": \"237\"'
                    ;;
            esac
        done
    "
    assert_success
}
