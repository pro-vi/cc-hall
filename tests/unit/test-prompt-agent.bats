#!/usr/bin/env bats
# Unit tests for editor module (Prompt Agent + editors) and cc-hall module (settings)
# Tests prompt builder, config loading, entry generation, preview, and on_select routing.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"
EDITOR_DIR="$HALL_DIR/modules/editor"
CC_HALL_DIR="$HALL_DIR/modules/cc-hall"

setup() {
    hall_test_setup_home
}

teardown() {
    hall_test_teardown_home
}

# ============================================================================
# PROMPT BUILDER
# ============================================================================

@test "prompt.sh can be sourced without errors" {
    run bash -c "source '$EDITOR_DIR/prompt.sh'"
    assert_success
}

@test "hall_build_prompt_agent_system function exists" {
    run bash -c "source '$EDITOR_DIR/prompt.sh' && type hall_build_prompt_agent_system"
    assert_success
    assert_output --partial 'hall_build_prompt_agent_system is a function'
}

@test "prompt builder: interactive mode generates valid prompt" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    assert_output --partial 'MISSION'
    assert_output --partial '$FILE'
    assert_output --partial 'Rules'
    assert_output --partial 'Procedure'
    assert_output --partial 'Example'
    assert_output --partial 'Mode'
}

@test "prompt builder: auto mode generates valid prompt" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system auto
    assert_success
    assert_output --partial 'MISSION'
    assert_output --partial 'Mode: Auto'
    assert_output --partial 'Done'
}

@test "prompt builder: interactive mode includes interactive marker" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    assert_output --partial 'Mode: Interactive'
    refute_output --partial 'Mode: Auto'
}

@test "prompt builder: auto mode includes auto marker" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system auto
    assert_success
    assert_output --partial 'Mode: Auto'
}

@test "prompt builder: defaults to interactive" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system
    assert_success
    assert_output --partial 'Mode: Interactive'
}

@test "prompt builder: unknown mode defaults to interactive" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system bogus
    assert_success
    assert_output --partial 'Mode: Interactive'
}

@test "prompt builder: includes constraint about not modifying codebase" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system auto
    assert_success
    assert_output --partial 'Never modify codebase files'
}

@test "prompt builder: includes rules about path verification" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    assert_output --partial 'Verify before mention'
    assert_output --partial 'expand scope'
    assert_output --partial 'guess at code structure'
}

@test "prompt builder: includes verification checklist" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system auto
    assert_success
    assert_output --partial 'Before concluding, verify'
    assert_output --partial '[ ]'
}

@test "prompt builder: produces substantial output (>30 lines)" {
    source "$EDITOR_DIR/prompt.sh"
    output=$(hall_build_prompt_agent_system interactive)
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    [ "$line_count" -gt 30 ]
}

@test "prompt builder: substitutes file path when provided" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive "/tmp/my-prompt.txt"
    assert_success
    assert_output --partial '/tmp/my-prompt.txt'
    refute_output --partial '$FILE'
}

@test "prompt builder: path with ampersand substituted literally" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive "/tmp/foo&bar.txt"
    assert_success
    assert_output --partial '/tmp/foo&bar.txt'
    refute_output --partial '$FILE'
}

@test "prompt builder: path with pipe substituted literally" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive "/tmp/foo|bar.txt"
    assert_success
    assert_output --partial '/tmp/foo|bar.txt'
    refute_output --partial '$FILE'
}

@test "prompt builder: path with spaces substituted correctly" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive "/tmp/my prompt file.txt"
    assert_success
    assert_output --partial '/tmp/my prompt file.txt'
    refute_output --partial '$FILE'
}

@test "prompt builder: path with backslash substituted literally" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive '/tmp/foo\bar.txt'
    assert_success
    assert_output --partial '/tmp/foo\bar.txt'
    refute_output --partial '$FILE'
}

@test "prompt builder: preserves literal \$FILE when no path given" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    assert_output --partial '$FILE'
}

@test "prompt builder: no seed/reflection references" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    refute_output --partial 'seed'
    refute_output --partial 'SEED_JSON'
    refute_output --partial 'reflection'
}

@test "prompt builder: no tool names prescribed" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    refute_output --partial '**Read**:'
    refute_output --partial '**Grep**:'
    refute_output --partial '**Glob**:'
    refute_output --partial '**Bash**:'
}

@test "prompt builder: includes example block" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    assert_output --partial '## Example'
    assert_output --partial 'make the search faster'
    assert_output --partial 'searchDocuments'
    assert_output --partial 'Out of Scope'
}

# ============================================================================
# COMPOSABLE BLOCKS (isolated)
# ============================================================================

@test "block: _hall_pa_mission includes success definition" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_mission)
    [[ "$result" == *"MISSION"* ]]
    [[ "$result" == *"prompt enhancement agent"* ]]
    [[ "$result" == *'$FILE'* ]]
}

@test "block: _hall_pa_procedure includes all 3 steps" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_procedure)
    [[ "$result" == *'1. Read `$FILE`'* ]]
    [[ "$result" == *"2. Investigate"* ]]
    [[ "$result" == *"3. Write the enhanced prompt"* ]]
}

@test "block: _hall_pa_procedure includes OUT OF SCOPE section" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_procedure)
    [[ "$result" == *"OUT OF SCOPE"* ]]
}

@test "block: _hall_pa_procedure handles empty file case" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_procedure)
    [[ "$result" == *"Empty or whitespace-only"* ]]
}

@test "block: _hall_pa_rules includes path verification" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_rules)
    [[ "$result" == *"Verify before mention"* ]]
    [[ "$result" == *"Categorize paths"* ]]
    [[ "$result" == *"self-sufficiency"* ]]
}

@test "block: _hall_pa_example includes before/after" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_example)
    [[ "$result" == *"Before"* ]]
    [[ "$result" == *"After"* ]]
    [[ "$result" == *"searchDocuments"* ]]
    [[ "$result" == *"Acceptance Criteria"* ]]
}

@test "block: _hall_pa_mode_interactive has checklist" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_mode_interactive)
    [[ "$result" == *'$FILE'* ]]
    [[ "$result" == *"verified or marked as new"* ]]
    [[ "$result" == *"Original intent preserved"* ]]
}

@test "block: _hall_pa_mode_auto has checklist and Done" {
    source "$EDITOR_DIR/prompt.sh"
    result=$(_hall_pa_mode_auto)
    [[ "$result" == *'$FILE'* ]]
    [[ "$result" == *"verified or marked as new"* ]]
    [[ "$result" == *"Original intent preserved"* ]]
    [[ "$result" == *'"Done"'* ]]
}

# ============================================================================
# CONFIG LOADING
# ============================================================================

setup_config() {
    TEST_CONFIG_DIR=$(mktemp -d)
    TEST_CONFIG_FILE="$TEST_CONFIG_DIR/config.json"
}

teardown_config() {
    rm -rf "$TEST_CONFIG_DIR" 2>/dev/null
}

@test "config: defaults when no config file" {
    setup_config
    _hall_load_config() {
        local config_file="$TEST_CONFIG_DIR/nonexistent/config.json"
        _PA_MODEL="sonnet"
        _PA_SKIP_PERMS="false"
        _PA_TMUX_MODE="false"
        _PA_THEME="mirrors"
        [ -f "$config_file" ] || return 0
    }
    _hall_load_config
    [ "$_PA_MODEL" = "sonnet" ]
    [ "$_PA_SKIP_PERMS" = "false" ]
    [ "$_PA_TMUX_MODE" = "false" ]
    [ "$_PA_THEME" = "mirrors" ]
    teardown_config
}

@test "config: reads model from JSON" {
    setup_config
    echo '{"model": "opus"}' > "$TEST_CONFIG_FILE"

    _hall_load_config() {
        local config_file="$TEST_CONFIG_FILE"
        _PA_MODEL="sonnet"
        _PA_SKIP_PERMS="false"
        _PA_TMUX_MODE="false"
        _PA_THEME="mirrors"
        [ -f "$config_file" ] || return 0
        local content=$(<"$config_file")
        [[ "$content" =~ \"model\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MODEL="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"skip_permissions\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_SKIP_PERMS="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"tmux_mode\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_TMUX_MODE="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_THEME="${BASH_REMATCH[1]}" || true
    }
    _hall_load_config
    [ "$_PA_MODEL" = "opus" ]
    teardown_config
}

@test "config: reads skip_permissions from JSON" {
    setup_config
    echo '{"skip_permissions": true}' > "$TEST_CONFIG_FILE"

    _hall_load_config() {
        local config_file="$TEST_CONFIG_FILE"
        _PA_MODEL="sonnet"
        _PA_SKIP_PERMS="false"
        _PA_TMUX_MODE="false"
        _PA_THEME="mirrors"
        [ -f "$config_file" ] || return 0
        local content=$(<"$config_file")
        [[ "$content" =~ \"model\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MODEL="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"skip_permissions\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_SKIP_PERMS="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"tmux_mode\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_TMUX_MODE="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_THEME="${BASH_REMATCH[1]}" || true
    }
    _hall_load_config
    [ "$_PA_SKIP_PERMS" = "true" ]
    teardown_config
}

@test "config: reads multiple keys from JSON" {
    setup_config
    echo '{"model": "haiku", "skip_permissions": true, "tmux_mode": true}' > "$TEST_CONFIG_FILE"

    _hall_load_config() {
        local config_file="$TEST_CONFIG_FILE"
        _PA_MODEL="sonnet"
        _PA_SKIP_PERMS="false"
        _PA_TMUX_MODE="false"
        _PA_THEME="mirrors"
        [ -f "$config_file" ] || return 0
        local content=$(<"$config_file")
        [[ "$content" =~ \"model\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MODEL="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"skip_permissions\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_SKIP_PERMS="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"tmux_mode\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_TMUX_MODE="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_THEME="${BASH_REMATCH[1]}" || true
    }
    _hall_load_config
    [ "$_PA_MODEL" = "haiku" ]
    [ "$_PA_SKIP_PERMS" = "true" ]
    [ "$_PA_TMUX_MODE" = "true" ]
    teardown_config
}

# ============================================================================
# EDITOR MODULE ENTRIES
# ============================================================================

@test "entries: editor module.sh can be sourced" {
    run bash -c "
        HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_LIB_DIR/hall-theme.sh'
        source '$EDITOR_DIR/module.sh'
    "
    assert_success
}

@test "entries: editor includes Prompt Editor section header" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    [[ "$output" == *"Prompt Editor"* ]]
}

@test "entries: editor includes Prompt Agent section header" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    [[ "$output" == *"Prompt Agent"* ]]
}

@test "entries: editor includes prompt-agent-interactive command" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep -q "prompt-agent-interactive"
}

@test "entries: editor includes prompt-agent-auto command" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep -q "prompt-agent-auto"
}

@test "entries: editor includes vim (always present)" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    [[ "$output" == *"Vim"* ]]
}

# ============================================================================
# CC-HALL MODULE ENTRIES
# ============================================================================

@test "entries: cc-hall module.sh can be sourced" {
    run bash -c "
        HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_LIB_DIR/hall-theme.sh'
        source '$CC_HALL_DIR/module.sh'
    "
    assert_success
}

@test "entries: editor includes Agent Settings section header" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    [[ "$output" == *"Agent Settings"* ]]
}

@test "entries: editor includes pa-toggle-model command" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep -q "pa-toggle-model"
}

@test "entries: editor includes pa-toggle-permissions command" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep -q "pa-toggle-permissions"
}

@test "entries: editor includes pa-toggle-tmux command" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep -q "pa-toggle-tmux"
}

@test "entries: editor tmux toggle shows status" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep "pa-toggle-tmux" | grep -q "Tmux:"
}

@test "entries: editor model toggle shows cycle indicator" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries editor
    )
    echo "$output" | grep "pa-toggle-model" | grep -q "Model:"
}

@test "entries: cc-hall includes Settings section header" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries cc-hall
    )
    [[ "$output" == *"Settings"* ]]
}

@test "entries: cc-hall includes Modules section header" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries cc-hall
    )
    [[ "$output" == *"Modules"* ]]
}

@test "entries: cc-hall includes pa-toggle-theme command" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries cc-hall
    )
    echo "$output" | grep -q "pa-toggle-theme"
}

@test "entries: cc-hall theme toggle shows cycle indicator" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries cc-hall
    )
    echo "$output" | grep "pa-toggle-theme" | grep -q "Theme:"
}

@test "entries: cc-hall lists discovered modules" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries cc-hall
    )
    echo "$output" | grep -q "module-toggle:editor"
    echo "$output" | grep -q "module-toggle:cc-hall"
}

# ============================================================================
# ON_SELECT ROUTING (editor module)
# ============================================================================

@test "on_select: editor unhandled command exits 1" {
    run env HOME="$(mktemp -d)" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "vi /tmp/test.txt" "/tmp/test.txt"
    assert_failure  # exit 1 = not handled
}

@test "on_select: prompt-agent-interactive routes correctly (mock claude)" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": false}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\nexit 0\n' > "$mockdir/claude"
    chmod +x "$mockdir/claude"
    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" PATH="$mockdir:$PATH" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-interactive" "$promptfile"
    rm -rf "$mockdir" "$promptfile" "$tmphome"
    assert_success
}

@test "on_select: prompt-agent-auto routes correctly (mock claude)" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": false}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\nexit 0\n' > "$mockdir/claude"
    chmod +x "$mockdir/claude"
    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" PATH="$mockdir:$PATH" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-auto" "$promptfile"
    rm -rf "$mockdir" "$promptfile" "$tmphome"
    assert_success
}

# ============================================================================
# ON_SELECT ROUTING (cc-hall module)
# ============================================================================

@test "on_select: pa-toggle-model exits 2 for reload" {
    run env HOME="$(mktemp -d)" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "pa-toggle-model" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
}

@test "on_select: pa-toggle-permissions exits 2 for reload" {
    run env HOME="$(mktemp -d)" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "pa-toggle-permissions" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
}

@test "on_select: pa-toggle-tmux exits 2 for reload" {
    run env HOME="$(mktemp -d)" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "pa-toggle-tmux" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
}

@test "on_select: pa-toggle-theme exits 2 for reload" {
    run env HOME="$(mktemp -d)" HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$CC_HALL_DIR/on_select.sh" "pa-toggle-theme" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
}

@test "on_select: module-toggle on locked module does not disable it" {
    local tmphome
    tmphome=$(mktemp -d)
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"disabled_modules": []}' > "$tmphome/.claude/reflections/config.json"
    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$CC_HALL_DIR/on_select.sh" "module-toggle:cc-hall" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
    # cc-hall should NOT appear in disabled_modules
    run grep 'cc-hall' "$tmphome/.claude/reflections/config.json"
    refute_output --partial '"cc-hall"'
}

@test "on_select: module-toggle on locked editor module does not disable it" {
    local tmphome
    tmphome=$(mktemp -d)
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"disabled_modules": []}' > "$tmphome/.claude/reflections/config.json"
    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$CC_HALL_DIR/on_select.sh" "module-toggle:editor" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
    run grep 'editor' "$tmphome/.claude/reflections/config.json"
    refute_output --partial '"editor"'
}

@test "on_select: module-toggle on unlocked module toggles it" {
    local tmphome
    tmphome=$(mktemp -d)
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"disabled_modules": []}' > "$tmphome/.claude/reflections/config.json"
    # memory module is not locked
    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$CC_HALL_DIR/on_select.sh" "module-toggle:memory" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
    # memory should now appear in disabled_modules
    run cat "$tmphome/.claude/reflections/config.json"
    assert_output --partial '"memory"'
}

@test "on_select: pa-toggle-permissions writes JSON boolean not string" {
    local tmphome
    tmphome=$(mktemp -d)
    mkdir -p "$tmphome/.claude/reflections"
    echo '{}' > "$tmphome/.claude/reflections/config.json"
    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "pa-toggle-permissions" "/tmp/test.txt" 2>/dev/null
    [ "$status" -eq 2 ]
    # Should be unquoted true (boolean), not "true" (string)
    run cat "$tmphome/.claude/reflections/config.json"
    assert_output --partial ': true'
    refute_output --partial ': "true"'
}

@test "entries: cc-hall shows locked modules with locked indicator" {
    output=$(
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" HALL_SAFE_FILE=/tmp/test
        source "$HALL_LIB_DIR/hall-menu.sh"
        source "$HALL_LIB_DIR/hall-theme.sh"
        hall_build_module_entries cc-hall
    )
    # cc-hall and editor are locked — current UI labels them as core modules
    echo "$output" | grep "module-toggle:cc-hall" | grep -q "core"
    echo "$output" | grep "module-toggle:editor" | grep -q "core"
}

# ============================================================================
# ON_SELECT TMUX PATHS (editor module)
# ============================================================================

@test "on_select: interactive tmux mode creates detached session when not in tmux" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": true}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\nexit 0\n' > "$mockdir/claude"
    printf '#!/bin/sh\necho "$@" >> "%s/tmux_calls"\nexit 0\n' "$mockdir" > "$mockdir/tmux"
    chmod +x "$mockdir/claude" "$mockdir/tmux"

    run env HOME="$tmphome" PATH="$mockdir:$PATH" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-interactive" "$promptfile"
    assert_success

    local calls
    calls=$(<"$mockdir/tmux_calls")
    [[ "$calls" == *"new-session -d"* ]]
    [[ "$calls" == *"prompt-agent"* ]]
    [[ "$calls" == *"send-keys"* ]]
    [[ "$calls" == *"Begin enhancement"* ]]
    [[ "$calls" == *"attach"* ]]
    local first_call
    first_call=$(echo "$calls" | head -1)
    [[ "$first_call" != *" -p "* ]]
    rm -rf "$mockdir" "$promptfile" "$tmphome"
}

@test "on_select: auto tmux mode creates session when not in tmux" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": true}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\nexit 0\n' > "$mockdir/claude"
    printf '#!/bin/sh\necho "$@" >> "%s/tmux_calls"\nexit 0\n' "$mockdir" > "$mockdir/tmux"
    chmod +x "$mockdir/claude" "$mockdir/tmux"

    run env HOME="$tmphome" PATH="$mockdir:$PATH" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-auto" "$promptfile"
    assert_success

    local calls
    calls=$(<"$mockdir/tmux_calls")
    [[ "$calls" == *"new-session"* ]]
    [[ "$calls" == *"-p"* ]]
    [[ "$calls" == *"status-style"* ]]
    [[ "$calls" == *"attach"* ]]
    rm -rf "$mockdir" "$promptfile" "$tmphome"
}

@test "on_select: interactive tmux mode uses spawn_agent with message when in tmux" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": true}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\nexit 0\n' > "$mockdir/claude"
    printf '#!/bin/sh\necho "$@" >> "%s/tmux_calls"\nexit 0\n' "$mockdir" > "$mockdir/tmux"
    chmod +x "$mockdir/claude" "$mockdir/tmux"

    run env HOME="$tmphome" PATH="$mockdir:$PATH" \
        ORIGINAL_TMUX="/tmp/tmux-fake/default,123,0" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-interactive" "$promptfile"
    assert_success

    local calls
    calls=$(<"$mockdir/tmux_calls")
    [[ "$calls" == *"new-window"* ]]
    [[ "$calls" == *"send-keys"* ]]
    [[ "$calls" == *"Begin enhancement"* ]]
    local cmd_line
    cmd_line=$(echo "$calls" | head -2 | tail -1)
    [[ "$cmd_line" != *" -p "* ]] || {
        local first_sendkeys
        first_sendkeys=$(echo "$calls" | grep "send-keys" | head -1)
        [[ "$first_sendkeys" != *" -p "* ]]
    }
    rm -rf "$mockdir" "$promptfile" "$tmphome"
}

@test "on_select: interactive passes correct args to claude (inline mode, no -p)" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": false}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\necho "$@" > "%s/claude_args"\nexit 0\n' "$mockdir" > "$mockdir/claude"
    chmod +x "$mockdir/claude"

    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" PATH="$mockdir:$PATH" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-interactive" "$promptfile"
    assert_success

    local args
    args=$(<"$mockdir/claude_args")
    [[ "$args" == *"--model"* ]]
    [[ "$args" == *"--append-system-prompt"* ]]
    [[ "$args" != *"-p"* ]]
    rm -rf "$mockdir" "$promptfile" "$tmphome"
}

@test "on_select: auto passes correct args to claude (inline mode)" {
    local mockdir promptfile tmphome
    mockdir=$(mktemp -d)
    promptfile=$(mktemp)
    tmphome=$(mktemp -d)
    echo "test prompt" > "$promptfile"
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"tmux_mode": false}' > "$tmphome/.claude/reflections/config.json"
    printf '#!/bin/sh\necho "$@" > "%s/claude_args"\nexit 0\n' "$mockdir" > "$mockdir/claude"
    chmod +x "$mockdir/claude"

    run env HOME="$tmphome" HALL_CONFIG_FILE="$tmphome/.claude/reflections/config.json" PATH="$mockdir:$PATH" \
        HALL_LIB_DIR="$HALL_LIB_DIR" HALL_DIR="$HALL_DIR" \
        bash "$EDITOR_DIR/on_select.sh" "prompt-agent-auto" "$promptfile"
    assert_success

    local args
    args=$(<"$mockdir/claude_args")
    [[ "$args" == *"--verbose"* ]]
    [[ "$args" == *"--dangerously-skip-permissions"* ]]
    [[ "$args" == *"-p"* ]]
    rm -rf "$mockdir" "$promptfile" "$tmphome"
}

# ============================================================================
# PREVIEW (editor module)
# ============================================================================

@test "preview: prompt-agent-interactive shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_FILE="/dev/null" \
        bash "$EDITOR_DIR/preview.sh" "prompt-agent-interactive"
    assert_success
    assert_output --partial 'Interactive'
    assert_output --partial 'Investigates the codebase'
}

@test "preview: prompt-agent-auto shows description" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_FILE="/dev/null" \
        bash "$EDITOR_DIR/preview.sh" "prompt-agent-auto"
    assert_success
    assert_output --partial 'Auto'
}

@test "preview: editor entry shows description and prompt content" {
    local tmpfile
    tmpfile=$(mktemp)
    echo "test prompt content here" > "$tmpfile"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_FILE="$tmpfile" \
        bash "$EDITOR_DIR/preview.sh" "vi $tmpfile"
    rm -f "$tmpfile"
    assert_success
    assert_output --partial 'Vim'
    assert_output --partial 'test prompt content here'
}

@test "preview: shows prompt content for prompt-agent entries" {
    local tmpfile
    tmpfile=$(mktemp)
    echo "my rough prompt" > "$tmpfile"
    run env HALL_LIB_DIR="$HALL_LIB_DIR" HALL_FILE="$tmpfile" \
        bash "$EDITOR_DIR/preview.sh" "prompt-agent-interactive"
    rm -f "$tmpfile"
    assert_success
    assert_output --partial 'Prompt'
    assert_output --partial 'my rough prompt'
}

@test "preview: editor empty input exits cleanly" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$EDITOR_DIR/preview.sh" ''
    assert_success
}

# ============================================================================
# PREVIEW (cc-hall module)
# ============================================================================

@test "preview: pa-toggle-model shows model info" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$EDITOR_DIR/preview.sh" "pa-toggle-model"
    assert_success
    assert_output --partial 'Model'
    assert_output --partial 'Opus'
    assert_output --partial 'Sonnet'
    assert_output --partial 'Haiku'
}

@test "preview: pa-toggle-permissions shows permissions info" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$EDITOR_DIR/preview.sh" "pa-toggle-permissions"
    assert_success
    assert_output --partial 'Permissions'
}

@test "preview: pa-toggle-tmux shows tmux info" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$EDITOR_DIR/preview.sh" "pa-toggle-tmux"
    assert_success
    assert_output --partial 'Tmux'
    assert_output --partial 'tmux window'
}

@test "preview: pa-toggle-theme shows theme info" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash "$CC_HALL_DIR/preview.sh" "pa-toggle-theme"
    assert_success
    assert_output --partial 'Theme'
    assert_output --partial 'Mirrors'
    assert_output --partial 'Clawd'
    assert_output --partial 'Zinc'
}

# ============================================================================
# HALL-COMMON PREVIEW HELPER
# ============================================================================

@test "hall_preview_prompt_content: shows file content" {
    local tmpfile
    tmpfile=$(mktemp)
    echo "line one" > "$tmpfile"
    echo "line two" >> "$tmpfile"
    source "$HALL_LIB_DIR/hall-common.sh"
    HALL_FILE="$tmpfile"
    run hall_preview_prompt_content "Test label"
    rm -f "$tmpfile"
    assert_success
    assert_output --partial 'Test label'
    assert_output --partial 'line one'
    assert_output --partial 'line two'
    [[ "$output" == *'Test label'*$'\n\n\n  line one'* ]]
}

@test "hall_preview_prompt_content: no output when HALL_FILE empty" {
    source "$HALL_LIB_DIR/hall-common.sh"
    unset HALL_FILE
    run hall_preview_prompt_content
    assert_success
    assert_output ''
}

@test "hall_preview_prompt_content: no output when file missing" {
    source "$HALL_LIB_DIR/hall-common.sh"
    HALL_FILE="/tmp/nonexistent-file-12345"
    run hall_preview_prompt_content
    assert_success
    assert_output ''
}

@test "hall_preview_prompt_content: truncation indicator for long files" {
    local tmpfile
    tmpfile=$(mktemp)
    for i in $(seq 1 30); do echo "line $i" >> "$tmpfile"; done
    source "$HALL_LIB_DIR/hall-common.sh"
    HALL_FILE="$tmpfile"
    run hall_preview_prompt_content
    rm -f "$tmpfile"
    assert_success
    assert_output --partial 'more lines'
}

# ============================================================================
# CONFIG: THEME
# ============================================================================

@test "config: reads theme from JSON" {
    setup_config
    echo '{"theme": "zinc"}' > "$TEST_CONFIG_FILE"

    _hall_load_config() {
        local config_file="$TEST_CONFIG_FILE"
        _PA_MODEL="sonnet"
        _PA_SKIP_PERMS="false"
        _PA_TMUX_MODE="false"
        _PA_THEME="mirrors"
        [ -f "$config_file" ] || return 0
        local content=$(<"$config_file")
        [[ "$content" =~ \"model\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MODEL="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"skip_permissions\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_SKIP_PERMS="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"tmux_mode\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_TMUX_MODE="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_THEME="${BASH_REMATCH[1]}" || true
    }
    _hall_load_config
    [ "$_PA_THEME" = "zinc" ]
    teardown_config
}

@test "config: theme defaults to mirrors when not set" {
    setup_config
    echo '{"model": "opus"}' > "$TEST_CONFIG_FILE"

    _hall_load_config() {
        local config_file="$TEST_CONFIG_FILE"
        _PA_MODEL="sonnet"
        _PA_SKIP_PERMS="false"
        _PA_TMUX_MODE="false"
        _PA_THEME="mirrors"
        [ -f "$config_file" ] || return 0
        local content=$(<"$config_file")
        [[ "$content" =~ \"model\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MODEL="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"skip_permissions\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_SKIP_PERMS="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"tmux_mode\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_TMUX_MODE="${BASH_REMATCH[1]}" || true
        [[ "$content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_THEME="${BASH_REMATCH[1]}" || true
    }
    _hall_load_config
    [ "$_PA_THEME" = "mirrors" ]
    teardown_config
}

# ============================================================================
# THEME LOADER
# ============================================================================

@test "hall-theme.sh: loads mirrors by default" {
    run bash -c "
        HALL_LIB_DIR='$HALL_LIB_DIR'
        HOME='\$(mktemp -d)'
        source '$HALL_LIB_DIR/hall-theme.sh'
        echo \"\$HALL_THEME_NAME\"
    "
    assert_success
    assert_output 'Mirrors'
}

@test "hall-theme.sh: derives fzf colors from theme" {
    run bash -c "
        HALL_LIB_DIR='$HALL_LIB_DIR'
        HOME='\$(mktemp -d)'
        source '$HALL_LIB_DIR/hall-theme.sh'
        echo \"\$HALL_FZF_COLORS\"
    "
    assert_success
    assert_output --partial 'bg:#0D1117'
    assert_output --partial 'fg:#586069'
    assert_output --partial 'spinner:#7ee787'
}

@test "hall-theme.sh: derives tmux vars from theme" {
    run bash -c "
        HALL_LIB_DIR='$HALL_LIB_DIR'
        HOME='\$(mktemp -d)'
        source '$HALL_LIB_DIR/hall-theme.sh'
        echo \"BG=\$HALL_TMUX_WINDOW_BG FG=\$HALL_TMUX_WINDOW_FG\"
    "
    assert_success
    assert_output --partial 'BG=#0D1117'
    assert_output --partial 'FG=#F0F6FC'
}

@test "hall-theme.sh: loads theme from config" {
    local tmphome
    tmphome=$(mktemp -d)
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"theme": "zinc"}' > "$tmphome/.claude/reflections/config.json"

    run env HOME="$tmphome" HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash -c "source '$HALL_LIB_DIR/hall-theme.sh'; echo \"\$HALL_THEME_NAME\""
    assert_success
    assert_output 'Zinc'
    rm -rf "$tmphome"
}

@test "hall-theme.sh: falls back to mirrors for unknown theme" {
    local tmphome
    tmphome=$(mktemp -d)
    mkdir -p "$tmphome/.claude/reflections"
    echo '{"theme": "nonexistent"}' > "$tmphome/.claude/reflections/config.json"

    run env HOME="$tmphome" HALL_LIB_DIR="$HALL_LIB_DIR" \
        bash -c "source '$HALL_LIB_DIR/hall-theme.sh'; echo \"\$HALL_THEME_NAME\""
    assert_success
    assert_output 'Mirrors'
    rm -rf "$tmphome"
}

# ============================================================================
# GOLDEN SNAPSHOT
# ============================================================================

@test "prompt builder: interactive matches golden snapshot" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system interactive
    assert_success
    diff <(printf '%s\n' "$output") "$BATS_TEST_DIRNAME/../golden/prompt-agent-interactive.golden"
}

@test "prompt builder: auto matches golden snapshot" {
    source "$EDITOR_DIR/prompt.sh"
    run hall_build_prompt_agent_system auto
    assert_success
    diff <(printf '%s\n' "$output") "$BATS_TEST_DIRNAME/../golden/prompt-agent-auto.golden"
}
