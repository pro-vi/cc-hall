#!/usr/bin/env bats
# Unit tests for cc-config module
# Tests entry generation, layer switching, flag toggles, and preview.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"
CC_CONFIG_DIR="$HALL_DIR/modules/cc-config"

setup() {
    hall_test_setup_home
    HALL_STATE_DIR=$(mktemp -d)
    export HALL_STATE_DIR
    export HALL_DIR
    export HALL_LIB_DIR

    TEST_PROJECT=$(mktemp -d)
    ORIG_DIR="$PWD"
    cd "$TEST_PROJECT"

    # Hermetic fake HOME for tests that write to ~/.claude/settings.json
    FAKE_HOME="$TEST_PROJECT/fakehome"
    mkdir -p "$FAKE_HOME/.claude"
    printf '{}' > "$FAKE_HOME/.claude/settings.json"
    export FAKE_HOME
}

# Seed global settings.json with specific content before a toggle test.
_seed_settings() {
    printf '%s' "$1" > "$FAKE_HOME/.claude/settings.json"
}

# Helper to generate entries for a specific layer
_entries_for_layer() {
    local layer="$1"
    echo "$layer" > "$HALL_STATE_DIR/module-subtab"
    bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        cd '$TEST_PROJECT'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        hall_cc_config_entries
    "
}

teardown() {
    cd "$ORIG_DIR"
    rm -rf "$HALL_STATE_DIR" "$TEST_PROJECT" 2>/dev/null
    hall_test_teardown_home
}

# ============================================================================
# module.sh: sourcing and metadata
# ============================================================================

@test "entries: cc-config module.sh can be sourced" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        echo \$HALL_MODULE_LABEL
        echo \$HALL_MODULE_ORDER
    "
    assert_success
    assert_line --index 0 'Config'
    assert_line --index 1 '25'
}

@test "entries: module declares no FZF_OPTS (search disabled at framework level)" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        echo \${#HALL_MODULE_FZF_OPTS[@]}
    "
    assert_success
    assert_output '0'
}

@test "entries: module declares no bindings (search toggle is framework-level)" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        echo \${#HALL_MODULE_BINDINGS[@]}
    "
    assert_success
    assert_output '0'
}

@test "entries: module declares HALL_MODULE_SUBTABS" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        printf '%s\n' \"\${HALL_MODULE_SUBTABS[@]}\"
    "
    assert_success
    assert_line --index 0 'Global'
    assert_line --index 1 'Shared'
    assert_line --index 2 'Local'
}

# ============================================================================
# module.sh: layer state initialization
# ============================================================================

@test "entries: reads layer from module-subtab state file" {
    echo 0 > "$HALL_STATE_DIR/module-subtab"
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$CC_CONFIG_DIR/module.sh'
        hall_cc_config_entries >/dev/null
        cat '$HALL_STATE_DIR/module-subtab'
    "
    assert_success
    assert_output '0'
}

@test "entries: default layer is 0 (Global)" {
    run _entries_for_layer 0
    assert_success
    # Global layer uses cv-flag commands
    assert_output --partial 'cv-flag alwaysThinkingEnabled'
}

# ============================================================================
# module.sh: Global layer (0) — all settings
# ============================================================================

@test "entries: Global layer shows all settings with cv-flag commands" {
    run _entries_for_layer 0
    assert_success
    # Thinking & Output
    assert_output --partial 'Thinking'
    assert_output --partial 'Adaptive Thinking'
    assert_output --partial 'Effort'
    assert_output --partial '1M Context'
    assert_output --partial 'Simple Mode'
    assert_output --partial 'Fast Mode'
    assert_output --partial 'Model'
    # Capabilities
    assert_output --partial 'Agent Teams'
    assert_output --partial 'Subagent Model'
    assert_output --partial 'Tool Search'
    assert_output --partial 'Background Tasks'
    assert_output --partial 'Task'
    # Context & Privacy
    assert_output --partial 'CLAUDE.md Files'
    assert_output --partial 'Gitignore'
    assert_output --partial 'Auto Memory'
    assert_output --partial 'Prompt Caching'
    assert_output --partial 'Auto Compact'
    assert_output --partial 'Compact'
    # UI
    assert_output --partial 'Spinner'
    assert_output --partial 'Duration'
    assert_output --partial 'Terminal Title'
    assert_output --partial 'Progress Bar'
    assert_output --partial 'Reduced Motion'
    assert_output --partial 'Output'
    # Permissions & Updates
    assert_output --partial 'Skip Perm Prompt'
    assert_output --partial 'Auto Updates'
}

@test "entries: Global shows cv-flag commands for env flags" {
    run _entries_for_layer 0
    assert_success
    assert_output --partial 'cv-val effortLevel'
    assert_output --partial 'cv-flag CLAUDE_CODE_DISABLE_THINKING'
    assert_output --partial 'cv-flag CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING'
    assert_output --partial 'cv-flag fastMode'
    assert_output --partial 'cv-flag CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
    assert_output --partial 'cv-flag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS'
    assert_output --partial 'cv-flag CLAUDE_CODE_ENABLE_TASKS'
    assert_output --partial 'cv-flag DISABLE_AUTO_COMPACT'
    assert_output --partial 'cv-flag DISABLE_COMPACT'
    assert_output --partial 'cv-flag autoMemoryEnabled'
    assert_output --partial 'cv-flag DISABLE_PROMPT_CACHING'
    assert_output --partial 'cv-flag CLAUDE_CODE_DISABLE_CLAUDE_MDS'
    assert_output --partial 'cv-flag CLAUDE_CODE_DISABLE_TERMINAL_TITLE'
    assert_output --partial 'cv-flag showTurnDuration'
    assert_output --partial 'cv-flag respectGitignore'
    assert_output --partial 'cv-flag CLAUDE_CODE_SUBAGENT_MODEL'
    assert_output --partial 'cv-flag terminalProgressBarEnabled'
    assert_output --partial 'cv-flag prefersReducedMotion'
}

@test "entries: Global shows subheader separators" {
    run _entries_for_layer 0
    assert_success
    assert_output --partial 'Thinking & Output'
    assert_output --partial 'Capabilities'
    assert_output --partial 'Context & Privacy'
    assert_output --partial 'UI'
    assert_output --partial 'Permissions & Updates'
    assert_output --partial 'cv-noop'
}

@test "entries: Global groups output and context settings with related sections" {
    run _entries_for_layer 0
    assert_success

    local stripped
    stripped=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')

    local pos_output pos_caps pos_context pos_claude pos_auto_memory pos_ui
    pos_output=$(printf '%s\n' "$stripped" | grep -bo 'Output Style' | head -1 | cut -d: -f1)
    pos_caps=$(printf '%s\n' "$stripped" | grep -bo 'Capabilities' | head -1 | cut -d: -f1)
    pos_context=$(printf '%s\n' "$stripped" | grep -bo 'Context & Privacy' | head -1 | cut -d: -f1)
    pos_claude=$(printf '%s\n' "$stripped" | grep -bo 'CLAUDE.md Files' | head -1 | cut -d: -f1)
    pos_auto_memory=$(printf '%s\n' "$stripped" | grep -bo 'Auto Memory' | head -1 | cut -d: -f1)
    pos_ui=$(printf '%s\n' "$stripped" | grep -bo 'UI' | head -1 | cut -d: -f1)

    [ "$pos_output" -lt "$pos_caps" ]
    [ "$pos_caps" -lt "$pos_context" ]
    [ "$pos_context" -lt "$pos_claude" ]
    [ "$pos_claude" -lt "$pos_auto_memory" ]
    [ "$pos_auto_memory" -lt "$pos_ui" ]
}

@test "entries: Effort Level shows cycle indicator" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$TEST_PROJECT'
        echo 0 > '$HALL_STATE_DIR/module-subtab'
        cd '$TEST_PROJECT'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        hall_cc_config_entries
    "
    assert_success
    assert_output --partial 'Effort'
    assert_output --partial 'default'
    assert_output --partial 'low'
}

@test "entries: Global auto updates defaults to latest" {
    run _entries_for_layer 0
    assert_success
    assert_output --partial 'Auto Updates'
    assert_output --partial 'latest'
}

# ============================================================================
# module.sh: Shared layer (1) — .claude/settings.json
# ============================================================================

@test "entries: Shared layer shows cv-sflag commands" {
    run _entries_for_layer 1
    assert_success
    assert_output --partial 'cv-sflag alwaysThinkingEnabled'
    assert_output --partial 'cv-sval effortLevel'
    assert_output --partial 'cv-sflag spinnerTipsEnabled'
}

@test "entries: Shared layer shows 'inherited' when file absent" {
    run _entries_for_layer 1
    assert_success
    assert_output --partial 'inherited'
}

@test "entries: Shared layer shows values from .claude/settings.json" {
    mkdir -p "$TEST_PROJECT/.claude"
    printf '{"alwaysThinkingEnabled": true}\n' > "$TEST_PROJECT/.claude/settings.json"
    run _entries_for_layer 1
    assert_success
    assert_output --partial 'Thinking'
    assert_output --partial 'on'
}

@test "entries: Shared layer shows cv-sval for named cycles" {
    run _entries_for_layer 1
    assert_success
    assert_output --partial 'cv-sval model'
    assert_output --partial 'cv-sval outputStyle'
}

# ============================================================================
# module.sh: Local layer (2) — .claude/settings.local.json
# ============================================================================

@test "entries: Local layer shows cv-pflag commands" {
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'cv-pflag alwaysThinkingEnabled'
    assert_output --partial 'cv-pval effortLevel'
    assert_output --partial 'cv-pflag spinnerTipsEnabled'
}

@test "entries: Local layer shows 'inherited' when file absent" {
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'inherited'
}

@test "entries: Local shows overridden value when set" {
    mkdir -p "$TEST_PROJECT/.claude"
    printf '{"alwaysThinkingEnabled": true}\n' > "$TEST_PROJECT/.claude/settings.local.json"
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'Thinking'
    assert_output --partial 'on'
}

@test "entries: Local shows off state for false override" {
    mkdir -p "$TEST_PROJECT/.claude"
    printf '{"alwaysThinkingEnabled": false}\n' > "$TEST_PROJECT/.claude/settings.local.json"
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'off'
    assert_output --partial 'inherited'
}

@test "entries: Local shows model and outputStyle" {
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'cv-pval model'
    assert_output --partial 'cv-pval outputStyle'
    assert_output --partial 'Model'
    assert_output --partial 'Output'
}

@test "entries: Local shows inherited for model when absent" {
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'inherited'
    assert_output --partial 'haiku'
}

@test "entries: Local shows model value when set" {
    mkdir -p "$TEST_PROJECT/.claude"
    printf '{"model": "sonnet"}\n' > "$TEST_PROJECT/.claude/settings.local.json"
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'sonnet'
    assert_output --partial 'opus'
}

@test "entries: Local Effort Level shows inherited when absent" {
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'Effort'
    assert_output --partial 'inherited'
}

@test "entries: Local shows all new settings" {
    run _entries_for_layer 2
    assert_success
    assert_output --partial 'cv-pflag CLAUDE_CODE_DISABLE_THINKING'
    assert_output --partial 'cv-pflag CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING'
    assert_output --partial 'cv-pflag fastMode'
    assert_output --partial 'cv-pflag CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
    assert_output --partial 'cv-pflag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS'
    assert_output --partial 'cv-pflag CLAUDE_CODE_ENABLE_TASKS'
    assert_output --partial 'cv-pflag DISABLE_AUTO_COMPACT'
    assert_output --partial 'cv-pflag DISABLE_COMPACT'
    assert_output --partial 'cv-pflag autoMemoryEnabled'
    assert_output --partial 'cv-pflag CLAUDE_CODE_DISABLE_CLAUDE_MDS'
    assert_output --partial 'cv-pflag CLAUDE_CODE_DISABLE_TERMINAL_TITLE'
    assert_output --partial 'cv-pflag showTurnDuration'
    assert_output --partial 'cv-pflag respectGitignore'
}

# ============================================================================
# module.sh: Guide entry
# ============================================================================

@test "entries: Guide is the first non-separator entry" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo 0 > '$HALL_STATE_DIR/module-subtab'
        cd '$TEST_PROJECT'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$CC_CONFIG_DIR/module.sh'
        hall_cc_config_entries | head -1
    "
    assert_success
    assert_output --partial 'Guide'
    assert_output --partial 'cv-info guide'
}

# ============================================================================
# on_select: cv-flag (global) exits 2
# ============================================================================

@test "on_select: cv-flag exits 2 for boolean flag" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag alwaysThinkingEnabled" "/dev/null"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-val exits 2 for effort level cycle" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-val effortLevel" "/dev/null"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-flag exits 2 for new inverted flags" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag autoMemoryEnabled" "/dev/null"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-flag exits 2 for task tracking" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag CLAUDE_CODE_ENABLE_TASKS" "/dev/null"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-flag default-false bool absent toggles to true" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag alwaysThinkingEnabled" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"alwaysThinkingEnabled": true'
}

@test "on_select: cv-flag default-true bool absent toggles to false" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag spinnerTipsEnabled" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"spinnerTipsEnabled": false'
}

@test "on_select: cv-flag toggles existing true to false" {
    _seed_settings '{"alwaysThinkingEnabled": true}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag alwaysThinkingEnabled" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"alwaysThinkingEnabled": false'
}

@test "on_select: cv-flag autoMemoryEnabled defaults on and toggles to false" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag autoMemoryEnabled" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"autoMemoryEnabled": false'
}

@test "on_select: cv-flag tool search cycles auto to on" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag ENABLE_TOOL_SEARCH" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"ENABLE_TOOL_SEARCH": "true"'
}

@test "on_select: cv-flag background tasks cleans compatibility key" {
    _seed_settings '{"env":{"CLAUDE_CODE_ENABLE_BACKGROUND_TASKS":"1"}}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    refute_output --partial 'CLAUDE_CODE_ENABLE_BACKGROUND_TASKS'
    assert_output --partial '"CLAUDE_CODE_DISABLE_BACKGROUND_TASKS": "1"'
}

@test "on_select: cv-flag task tracking cleans compatibility key" {
    _seed_settings '{"env":{"DISABLE_TASKS":"1"}}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag CLAUDE_CODE_ENABLE_TASKS" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    refute_output --partial 'DISABLE_TASKS'
    refute_output --partial 'CLAUDE_CODE_ENABLE_TASKS'
}

@test "on_select: cv-flag fastMode cleans legacy disable alias" {
    _seed_settings '{"env":{"CLAUDE_CODE_DISABLE_FAST_MODE":"1"}}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag fastMode" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    refute_output --partial 'CLAUDE_CODE_DISABLE_FAST_MODE'
    refute_output --partial '"fastMode"'
}

@test "on_select: cv-flag autoMemoryEnabled cleans legacy disable alias" {
    _seed_settings '{"env":{"CLAUDE_CODE_DISABLE_AUTO_MEMORY":"1"}}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag autoMemoryEnabled" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    refute_output --partial 'CLAUDE_CODE_DISABLE_AUTO_MEMORY'
    refute_output --partial '"autoMemoryEnabled"'
}

@test "on_select: cv-flag refuses malformed global settings without overwriting them" {
    local malformed='{"env":{"FOO":"1",},"permissions":{"allow":["Bash"]}}'
    _seed_settings "$malformed"
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag alwaysThinkingEnabled" "/dev/null"
    [ "$status" -eq 2 ]
    assert_output --partial 'Invalid JSON'
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output "$malformed"
    run cat "$HALL_STATE_DIR/footer-message"
    assert_output ' Invalid JSON in ~/.claude/settings.json. Fix it before changing settings. '
}

# ============================================================================
# on_select: cv-flag for new settings
# ============================================================================

@test "on_select: cv-flag exits 2 for new DISABLE flags" {
    for flag in CLAUDE_CODE_DISABLE_THINKING CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING \
                fastMode CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS \
                CLAUDE_CODE_DISABLE_BACKGROUND_TASKS DISABLE_AUTO_COMPACT DISABLE_COMPACT \
                CLAUDE_CODE_DISABLE_CLAUDE_MDS CLAUDE_CODE_DISABLE_TERMINAL_TITLE \
                CLAUDE_CODE_ENABLE_TASKS; do
        run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
            bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag $flag" "/dev/null"
        [ "$status" -eq 2 ]
    done
}

@test "on_select: cv-flag exits 2 for new root bools" {
    for flag in showTurnDuration respectGitignore; do
        run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
            bash "$CC_CONFIG_DIR/on_select.sh" "cv-flag $flag" "/dev/null"
        [ "$status" -eq 2 ]
    done
}

# ============================================================================
# on_select: cv-sflag (shared project) exits 2
# ============================================================================

@test "on_select: cv-sflag exits 2 for boolean flag" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-sflag alwaysThinkingEnabled' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-sflag creates .claude/settings.json" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-sflag alwaysThinkingEnabled' '/tmp/test'"
    [ "$status" -eq 2 ]
    [ -f "$TEST_PROJECT/.claude/settings.json" ]
    run cat "$TEST_PROJECT/.claude/settings.json"
    assert_output --partial '"alwaysThinkingEnabled": true'
}

@test "on_select: cv-sval exits 2 for effort level" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-sval effortLevel' '/tmp/test'"
    [ "$status" -eq 2 ]
}

# ============================================================================
# on_select: cv-pflag (project local) exits 2
# ============================================================================

@test "on_select: cv-pflag exits 2 for boolean flag" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-pflag alwaysThinkingEnabled' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-pval exits 2 for effort level" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-pval effortLevel' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-pflag exits 2 for task tracking" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-pflag CLAUDE_CODE_ENABLE_TASKS' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-pflag exits 2 for spinnerTipsEnabled" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-pflag spinnerTipsEnabled' '/tmp/test'"
    [ "$status" -eq 2 ]
}

# ============================================================================
# on_select: cv-val / cv-sval / cv-pval (named-value cycle) exits 2
# ============================================================================

@test "on_select: cv-val exits 2 for model" {
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-val model" "/dev/null"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-sval exits 2 for model" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-sval model' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-pval exits 2 for model" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-pval model' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-pval exits 2 for outputStyle" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash -c "cd '$TEST_PROJECT' && bash '$CC_CONFIG_DIR/on_select.sh' 'cv-pval outputStyle' '/tmp/test'"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-val model wraps from opus to haiku in global mode" {
    _seed_settings '{"model": "opus"}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-val model" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"model": "haiku"'
    refute_output --partial '"model": "opus"'
}

@test "on_select: cv-val outputStyle wraps from learning to concise in global mode" {
    _seed_settings '{"outputStyle": "learning"}'
    run env HOME="$FAKE_HOME" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-val outputStyle" "/dev/null"
    [ "$status" -eq 2 ]
    run cat "$FAKE_HOME/.claude/settings.json"
    assert_output --partial '"outputStyle": "concise"'
    refute_output --partial '"outputStyle": "learning"'
}

@test "on_select: cv-noop exits 2" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-noop" "/tmp/test"
    [ "$status" -eq 2 ]
}

@test "on_select: cv-info guide exits 2" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "cv-info guide" "/tmp/test"
    [ "$status" -eq 2 ]
}

@test "on_select: unhandled command exits 1" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_STATE_DIR="$HALL_STATE_DIR" \
        bash "$CC_CONFIG_DIR/on_select.sh" "unknown-command" "/tmp/test"
    [ "$status" -eq 1 ]
}

# ============================================================================
# preview: guide
# ============================================================================

@test "preview: cv-info guide shows layers" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-info guide"
    assert_success
    assert_output --partial 'Settings'
    assert_output --partial 'Flags'
    assert_output --partial 'Global'
    assert_output --partial 'Shared'
    assert_output --partial 'Local'
}

# ============================================================================
# preview: flag entries (global)
# ============================================================================

@test "preview: cv-flag alwaysThinkingEnabled shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag alwaysThinkingEnabled"
    assert_success
    assert_output --partial 'Thinking'
    assert_output --partial 'settings.json'
}

@test "preview: cv-val effort level shows cycle info" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-val effortLevel"
    assert_success
    assert_output --partial 'Effort'
    assert_output --partial 'low'
    assert_output --partial 'medium'
    assert_output --partial 'high'
}

@test "preview: cv-flag background tasks shows canonical description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS"
    assert_success
    assert_output --partial 'CLAUDE_CODE_DISABLE_BACKGROUND_TASKS'
}

@test "preview: cv-flag task tracking shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag CLAUDE_CODE_ENABLE_TASKS"
    assert_success
    assert_output --partial 'Task'
    assert_output --partial 'Tracking'
}

@test "preview: cv-flag background tasks shows canonical key" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS"
    assert_success
    assert_output --partial 'Background Tasks'
    assert_output --partial 'CLAUDE_CODE_DISABLE_BACKGROUND_TASKS'
}

@test "preview: cv-flag auto memory shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag autoMemoryEnabled"
    assert_success
    assert_output --partial 'Auto Memory'
    assert_output --partial 'autoMemoryEnabled'
}

@test "preview: cv-flag auto updates shows latest/stable cycle" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag autoUpdatesChannel"
    assert_success
    assert_output --partial 'latest'
    assert_output --partial 'stable'
}

# ============================================================================
# preview: new settings
# ============================================================================

@test "preview: cv-flag shows description for current advanced flags" {
    for flag in CLAUDE_CODE_DISABLE_THINKING CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING \
                fastMode CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS DISABLE_AUTO_COMPACT \
                DISABLE_COMPACT CLAUDE_CODE_DISABLE_CLAUDE_MDS \
                CLAUDE_CODE_DISABLE_TERMINAL_TITLE; do
        run env HALL_LIB_DIR="$HALL_LIB_DIR" \
            bash "$CC_CONFIG_DIR/preview.sh" "cv-flag $flag"
        assert_success
    done
}

@test "preview: cv-flag shows description for new root bools" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag showTurnDuration"
    assert_success
    assert_output --partial 'Duration'

    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag respectGitignore"
    assert_success
    assert_output --partial 'Gitignore'
}

# ============================================================================
# preview: effect indicators
# ============================================================================

@test "preview: settings-file toggles show saved default indicator" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag alwaysThinkingEnabled"
    assert_success
    assert_output --partial 'Saved default'
    assert_output --partial 'Start a new Claude Code session'
}

@test "preview: env-backed flags show new session required indicator" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag CLAUDE_CODE_DISABLE_1M_CONTEXT"
    assert_success
    assert_output --partial 'New session required'
}

@test "preview: current-session command tips are shown when available" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-flag fastMode"
    assert_success
    assert_output --partial '/fast'

    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-val model"
    assert_success
    assert_output --partial '/model'

    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-val outputStyle"
    assert_success
    assert_output --partial '/output-style'
}

# ============================================================================
# preview: shared/local project flag entries
# ============================================================================

@test "preview: cv-sflag shows Shared Project Override" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-sflag alwaysThinkingEnabled"
    assert_success
    assert_output --partial 'Shared Project'
    assert_output --partial '.claude/settings.json'
}

@test "preview: cv-pflag shows Local Project Override" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-pflag alwaysThinkingEnabled"
    assert_success
    assert_output --partial 'Local Project'
    assert_output --partial 'settings.local.json'
}

@test "preview: cv-pval effort level shows cycle info" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-pval effortLevel"
    assert_success
    assert_output --partial 'Effort'
}

@test "preview: cv-pflag spinnerTipsEnabled shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-pflag spinnerTipsEnabled"
    assert_success
    assert_output --partial 'Spinner'
    assert_output --partial 'settings.local.json'
}

# ============================================================================
# preview: named-value entries (all layers)
# ============================================================================

@test "preview: cv-val model shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-val model"
    assert_success
    assert_output --partial 'Model'
    assert_output --partial 'haiku'
    assert_output --partial 'sonnet'
    assert_output --partial 'opus'
}

@test "preview: cv-sval outputStyle shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-sval outputStyle"
    assert_success
    assert_output --partial 'Output'
    assert_output --partial 'concise'
    assert_output --partial 'explanatory'
    assert_output --partial 'learning'
}

@test "preview: cv-pval model shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_CONFIG_DIR/preview.sh" "cv-pval model"
    assert_success
    assert_output --partial 'Model'
    assert_output --partial 'settings.local.json'
}
