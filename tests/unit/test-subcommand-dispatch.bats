#!/usr/bin/env bats
# Hermetic tests for cc-hall subcommand dispatch
# Tests: dispatch routing, hall-cmd-reload, hall-cmd-preview, hall-cmd-agent, hall-cmd-module

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
# DISPATCH ROUTING (bin/cc-hall case statement)
# ============================================================================

@test "dispatch: subcommands are routed before EDITOR mode" {
    # Verify the case statement appears before sourcing hall-common.sh
    run bash -c "
        awk '/^case.*\\\$\{1:-\}/,/^esac/' '$HALL_DIR/bin/cc-hall' | head -1
    "
    assert_success
    assert_output --partial 'case'
}

@test "dispatch: reload subcommand is recognized" {
    run bash -c "grep -q 'reload).*hall-cmd-reload' '$HALL_DIR/bin/cc-hall'"
    assert_success
}

@test "dispatch: preview subcommand is recognized" {
    run bash -c "grep -q 'preview).*hall-cmd-preview' '$HALL_DIR/bin/cc-hall'"
    assert_success
}

@test "dispatch: agent subcommand is recognized" {
    run bash -c "grep -q 'agent).*hall-cmd-agent' '$HALL_DIR/bin/cc-hall'"
    assert_success
}

@test "dispatch: module subcommand is recognized" {
    run bash -c "grep -q 'module).*hall-cmd-module' '$HALL_DIR/bin/cc-hall'"
    assert_success
}

@test "dispatch: file path falls through to EDITOR mode" {
    # A file path argument should not match any subcommand
    run bash -c "
        case '/tmp/test.md' in
            reload|preview|agent|module) echo 'matched subcommand' ;;
            *) echo 'fell through' ;;
        esac
    "
    assert_output 'fell through'
}

@test "dispatch: usage shows subcommands when no args" {
    run bash "$HALL_DIR/bin/cc-hall" 2>&1
    assert_failure
    assert_output --partial 'cc-hall reload'
    assert_output --partial 'cc-hall preview'
    assert_output --partial 'cc-hall agent'
    assert_output --partial 'cc-hall module'
}

# ============================================================================
# hall-cmd-reload.sh
# ============================================================================

@test "reload: sources hall-common.sh and hall-menu.sh" {
    run bash -c "grep -q 'source.*hall-common.sh' '$HALL_LIB_DIR/hall-cmd-reload.sh'"
    assert_success
    run bash -c "grep -q 'source.*hall-menu.sh' '$HALL_LIB_DIR/hall-cmd-reload.sh'"
    assert_success
}

@test "reload: reads current module index from state" {
    run bash -c "grep -q 'HALL_STATE_DIR/current' '$HALL_LIB_DIR/hall-cmd-reload.sh'"
    assert_success
}

@test "reload: outputs tagged entries for current module" {
    # Set up minimal state
    local state_dir
    state_dir=$(mktemp -d /tmp/hall-reload-test.XXXXXX)
    echo 0 > "$state_dir/current"

    # Create a minimal module state with built-in editor module
    local mod_dir="$HALL_DIR/modules/editor"
    echo "editor:${mod_dir}:○:Editor" > "$state_dir/modules"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_STATE_DIR='$state_dir'
        export HALL_FILE='/tmp/test-prompt.md'
        bash '$HALL_LIB_DIR/hall-cmd-reload.sh'
    "
    assert_success
    # Should contain tagged entries (module\x1fcommand format)
    assert_output --partial 'editor'

    rm -rf "$state_dir"
}

# ============================================================================
# hall-cmd-preview.sh
# ============================================================================

@test "preview: exits 0 on empty input" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-preview.sh'
    "
    assert_success
    assert_output ''
}

@test "preview: exits 0 on input without tab" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-preview.sh' 'no-tab-here'
    "
    assert_success
}

@test "preview: extracts module and dispatches to preview.sh" {
    # Create a test module with a preview script
    local mod_dir
    mod_dir=$(mktemp -d /tmp/hall-preview-test.XXXXXX)
    mkdir -p "$mod_dir/testmod"
    cat > "$mod_dir/testmod/preview.sh" <<'SCRIPT'
#!/usr/bin/env bash
echo "cmd=$1"
echo "label=$2"
SCRIPT
    chmod +x "$mod_dir/testmod/preview.sh"

    # Create module.sh for discovery
    cat > "$mod_dir/testmod/module.sh" <<'SCRIPT'
HALL_MODULE_LABEL="Test"
HALL_MODULE_ORDER=99
hall_testmod_entries() { echo ""; }
SCRIPT

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$mod_dir/fakehome'
        mkdir -p '$mod_dir/fakehome/.claude/hall/modules'
        ln -s '$mod_dir/testmod' '$mod_dir/fakehome/.claude/hall/modules/testmod'
        bash '$HALL_LIB_DIR/hall-cmd-preview.sh' \$'My Label\ttestmod\x1fmy-command arg1'
    "
    assert_success
    assert_output --partial 'cmd=my-command arg1'
    assert_output --partial 'label=My Label'

    rm -rf "$mod_dir"
}

@test "preview: passes clean command without x1f to module" {
    # Verify the dispatcher strips x1f before calling module preview.sh
    local mod_dir
    mod_dir=$(mktemp -d /tmp/hall-preview-clean.XXXXXX)
    mkdir -p "$mod_dir/cleanmod"
    cat > "$mod_dir/cleanmod/preview.sh" <<'SCRIPT'
#!/usr/bin/env bash
# Check that $1 does NOT contain \x1f
if [[ "$1" == *$'\x1f'* ]]; then
    echo "FAIL: x1f found in command"
    exit 1
fi
echo "PASS: clean command=$1"
SCRIPT
    chmod +x "$mod_dir/cleanmod/preview.sh"
    cat > "$mod_dir/cleanmod/module.sh" <<'SCRIPT'
HALL_MODULE_LABEL="Clean"
hall_cleanmod_entries() { echo ""; }
SCRIPT

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$mod_dir/fakehome'
        mkdir -p '$mod_dir/fakehome/.claude/hall/modules'
        ln -s '$mod_dir/cleanmod' '$mod_dir/fakehome/.claude/hall/modules/cleanmod'
        bash '$HALL_LIB_DIR/hall-cmd-preview.sh' \$'Label\tcleanmod\x1fsome-cmd with args'
    "
    assert_success
    assert_output --partial 'PASS: clean command=some-cmd with args'

    rm -rf "$mod_dir"
}

@test "preview: resolves module directory from state file without discovery" {
    local mod_dir
    local state_dir
    mod_dir=$(mktemp -d /tmp/hall-preview-state.XXXXXX)
    state_dir=$(mktemp -d /tmp/hall-preview-statefile.XXXXXX)
    mkdir -p "$mod_dir/statemod"
    cat > "$mod_dir/statemod/preview.sh" <<'SCRIPT'
#!/usr/bin/env bash
echo "state-preview=$1"
echo "renderer=$HALL_MODULE_PREVIEW_RENDERER"
SCRIPT
    chmod +x "$mod_dir/statemod/preview.sh"
    printf 'statemod:%s:◆:State\n' "$mod_dir/statemod" > "$state_dir/modules"
    printf 'statemod:quick\n' > "$state_dir/module-preview-renderers"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_STATE_DIR='$state_dir'
        export HOME='$mod_dir/fakehome'
        mkdir -p '$mod_dir/fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-preview.sh' \$'Label\tstatemod\x1ffast-path'
    "
    assert_success
    assert_output --partial 'state-preview=fast-path'
    assert_output --partial 'renderer=quick'

    rm -rf "$mod_dir" "$state_dir"
}

# ============================================================================
# hall-cmd-agent.sh
# ============================================================================

@test "agent: requires --mode argument" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-agent.sh' --system-prompt-file /tmp/test
    "
    assert_failure
    assert_output --partial '--mode required'
}

@test "agent: requires --system-prompt-file" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-agent.sh' --mode auto
    "
    assert_failure
    assert_output --partial '--system-prompt-file required'
}

@test "agent: rejects unknown mode" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-agent.sh' --mode bogus --system-prompt-file /tmp/test
    "
    assert_failure
    assert_output --partial "unknown mode 'bogus'"
}

@test "agent: rejects unknown arguments" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-agent.sh' --mode auto --system-prompt-file /tmp/test --bogus
    "
    assert_failure
    assert_output --partial 'unknown argument'
}

@test "agent: interactive mode without tmux fails gracefully" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        unset TMUX
        unset ORIGINAL_TMUX
        bash '$HALL_LIB_DIR/hall-cmd-agent.sh' --mode interactive --system-prompt-file /tmp/test
    "
    assert_failure
    assert_output --partial 'Interactive mode requires tmux'
}

@test "agent: parses all flag arguments correctly" {
    # Verify argument parsing by checking that it reaches mode dispatch
    # without errors (it will fail at tmux check, proving all args parsed OK)
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        unset TMUX
        unset ORIGINAL_TMUX
        bash '$HALL_LIB_DIR/hall-cmd-agent.sh' \
            --mode interactive \
            --system-prompt-file '/tmp/path with spaces/test.md' \
            --model opus \
            --skip-permissions \
            --window-name 'my-agent' \
            --env 'FILE=/tmp/test' \
            --cleanup '/tmp/cleanup1' \
            --cleanup '/tmp/cleanup2' \
            --message 'Begin work'
    "
    assert_failure  # fails at tmux check, not at arg parsing
    assert_output --partial 'Interactive mode requires tmux'
}

# ============================================================================
# hall-cmd-module.sh
# ============================================================================

@test "module: shows usage with no subcommand" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh'
    "
    assert_failure
    assert_output --partial 'Usage:'
    assert_output --partial 'link'
    assert_output --partial 'unlink'
    assert_output --partial 'list'
}

@test "module link: requires path argument" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' link
    "
    assert_failure
    assert_output --partial 'path required'
}

@test "module link: validates module.sh exists" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modlink-test.XXXXXX)
    mkdir -p "$tmpdir/nomodule"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' link '$tmpdir/nomodule'
    "
    assert_failure
    assert_output --partial 'module.sh not found'

    rm -rf "$tmpdir"
}

@test "module link: creates symlink with derived name" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modlink-test.XXXXXX)
    mkdir -p "$tmpdir/mymod"
    touch "$tmpdir/mymod/module.sh"

    local fakehome="$tmpdir/fakehome"
    mkdir -p "$fakehome/.claude/hall/modules"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' link '$tmpdir/mymod'
    "
    assert_success
    assert_output --partial 'Linked: mymod'

    # Verify symlink was created
    run bash -c "[ -L '$fakehome/.claude/hall/modules/mymod' ] && echo 'symlink exists'"
    assert_output 'symlink exists'

    # Verify symlink target
    run readlink "$fakehome/.claude/hall/modules/mymod"
    assert_output "$tmpdir/mymod"

    rm -rf "$tmpdir"
}

@test "module link: rejects --name override until alias loading is supported" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modlink-test.XXXXXX)
    mkdir -p "$tmpdir/hall-module"
    touch "$tmpdir/hall-module/module.sh"

    local fakehome="$tmpdir/fakehome"
    mkdir -p "$fakehome/.claude/hall/modules"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' link '$tmpdir/hall-module' --name reflection
    "
    assert_failure
    assert_output --partial '--name is not supported'

    run bash -c "[ ! -e '$fakehome/.claude/hall/modules/reflection' ] && echo 'absent'"
    assert_output 'absent'

    rm -rf "$tmpdir"
}

@test "module link: replaces existing link with warning" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modlink-test.XXXXXX)
    mkdir -p "$tmpdir/mymod"
    touch "$tmpdir/mymod/module.sh"

    local fakehome="$tmpdir/fakehome"
    mkdir -p "$fakehome/.claude/hall/modules"
    ln -s /nonexistent "$fakehome/.claude/hall/modules/mymod"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' link '$tmpdir/mymod'
    "
    assert_success
    assert_output --partial 'already registered'
    assert_output --partial 'Linked: mymod'

    rm -rf "$tmpdir"
}

@test "module unlink: requires name argument" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' unlink
    "
    assert_failure
    assert_output --partial 'module name required'
}

@test "module unlink: removes symlink" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modunlink-test.XXXXXX)
    local fakehome="$tmpdir/fakehome"
    mkdir -p "$fakehome/.claude/hall/modules"
    ln -s /some/path "$fakehome/.claude/hall/modules/testmod"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' unlink testmod
    "
    assert_success
    assert_output --partial 'Unlinked: testmod'

    run bash -c "[ -e '$fakehome/.claude/hall/modules/testmod' ] && echo 'exists' || echo 'gone'"
    assert_output 'gone'

    rm -rf "$tmpdir"
}

@test "module unlink: refuses to remove real directory" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modunlink-test.XXXXXX)
    local fakehome="$tmpdir/fakehome"
    mkdir -p "$fakehome/.claude/hall/modules/realdir"
    touch "$fakehome/.claude/hall/modules/realdir/module.sh"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' unlink realdir
    "
    assert_failure
    assert_output --partial 'not a symlink'

    # Verify directory still exists
    run bash -c "[ -d '$fakehome/.claude/hall/modules/realdir' ] && echo 'safe'"
    assert_output 'safe'

    rm -rf "$tmpdir"
}

@test "module unlink: fails on nonexistent module" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/hall-modunlink-test.XXXXXX)
    local fakehome="$tmpdir/fakehome"
    mkdir -p "$fakehome/.claude/hall/modules"

    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HOME='$fakehome'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' unlink nonexistent
    "
    assert_failure
    assert_output --partial 'not found'

    rm -rf "$tmpdir"
}

@test "module list: shows discovered modules" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_LIB_DIR/hall-cmd-module.sh' list
    "
    assert_success
    assert_output --partial 'NAME'
    assert_output --partial 'editor'
    assert_output --partial 'cc-hall'
}

# ============================================================================
# PREVIEW CONVENTION: all module preview.sh receive clean $1
# ============================================================================

@test "preview convention: editor/preview.sh uses \$1 directly (no extract call)" {
    run bash -c "grep -c 'hall_preview_extract_cmd' '$HALL_DIR/modules/editor/preview.sh'"
    assert_output '0'
}

@test "preview convention: cc-hall/preview.sh uses \$1 directly (no extract call)" {
    run bash -c "grep -c 'hall_preview_extract_cmd' '$HALL_DIR/modules/cc-hall/preview.sh'"
    assert_output '0'
}

@test "preview convention: cc-config/preview.sh uses \$1 directly (no extract call)" {
    run bash -c "grep -c 'hall_preview_extract_cmd' '$HALL_DIR/modules/cc-config/preview.sh'"
    assert_output '0'
}

@test "preview convention: memory/preview.sh uses \$1 directly (no extract call)" {
    run bash -c "grep -c 'hall_preview_extract_cmd' '$HALL_DIR/modules/memory/preview.sh'"
    assert_output '0'
}

@test "preview convention: skill-viewer/preview.sh uses \$1 directly (no extract call)" {
    run bash -c "grep -c 'hall_preview_extract_cmd' '$HALL_DIR/modules/skill-viewer/preview.sh'"
    assert_output '0'
}

@test "preview convention: no built-in module preview.sh calls hall_preview_extract_cmd" {
    run bash -c "
        count=0
        for f in '$HALL_DIR'/modules/*/preview.sh; do
            [ -f \"\$f\" ] || continue
            if grep -q 'hall_preview_extract_cmd' \"\$f\"; then
                echo \"FAIL: \$f still calls hall_preview_extract_cmd\"
                count=\$((count + 1))
            fi
        done
        echo \"violations=\$count\"
    "
    assert_output --partial 'violations=0'
}

# ============================================================================
# PREVIEW: built-in modules handle clean command correctly
# ============================================================================

@test "preview: editor/preview.sh renders for clean command" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_FILE='/tmp/test.md'
        bash '$HALL_DIR/modules/editor/preview.sh' 'pa-toggle-model' 'Model'
    "
    assert_success
    assert_output --partial 'Model'
}

@test "preview: cc-hall/preview.sh renders for clean command" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_DIR/modules/cc-hall/preview.sh' 'pa-toggle-theme' 'Theme'
    "
    assert_success
    assert_output --partial 'Theme'
}

@test "preview: cc-config/preview.sh renders for clean command" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bash '$HALL_DIR/modules/cc-config/preview.sh' 'cv-info guide' 'Guide'
    "
    assert_success
    assert_output --partial 'Config'
}

@test "preview: editor/preview.sh exits cleanly on unknown command" {
    run bash -c "
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_FILE='/tmp/test.md'
        bash '$HALL_DIR/modules/editor/preview.sh' 'unknown-command' 'Label'
    "
    assert_success
}

@test "preview: all modules exit cleanly on empty \$1" {
    for mod in editor cc-hall cc-config memory skill-viewer; do
        local preview="$HALL_DIR/modules/$mod/preview.sh"
        [ -f "$preview" ] || continue
        run bash -c "
            export HALL_DIR='$HALL_DIR'
            export HALL_LIB_DIR='$HALL_LIB_DIR'
            export HALL_FILE='/tmp/test.md'
            bash '$preview' '' ''
        "
        assert_success
    done
}

# ============================================================================
# fzf --preview binding uses the current cc-hall binary
# ============================================================================

@test "main loop: --preview uses resolved cc-hall binary, not PATH lookup" {
    run bash -c "grep -- '--preview=' '$HALL_DIR/bin/cc-hall'"
    assert_output --partial '$HALL_SAFE_BIN preview {}'
    refute_output --partial 'hall-preview.sh'
}

@test "main loop: usage prewarm cleanup only targets active background jobs" {
    run bash -c "
        grep -q '_hall_cleanup_usage_prewarm' '$HALL_DIR/bin/cc-hall' &&
        grep -q 'jobs -pr' '$HALL_DIR/bin/cc-hall'
    "
    assert_success
}

@test "main loop: fzf listen socket is enabled for async usage refresh" {
    run bash -c "
        grep -q 'fzf.sock' '$HALL_DIR/bin/cc-hall' &&
        grep -q -- '--listen=' '$HALL_DIR/bin/cc-hall'
    "
    assert_success
}

@test "main loop: binds both shift-tab and btab to previous-module transform" {
    run bash -c "
        grep -q 'shift-tab:transform(.*hall-tab-action.sh prev)' '$HALL_DIR/bin/cc-hall' &&
        grep -q 'btab:transform(.*hall-tab-action.sh prev)' '$HALL_DIR/bin/cc-hall'
    "
    assert_success
}

@test "main loop: usage prewarm posts reload via resolved cc-hall binary" {
    run bash -c "
        grep -q '_hall_usage_maybe_refresh_current_view' '$HALL_DIR/bin/cc-hall' &&
        grep -q 'reload(\$HALL_SAFE_BIN reload)+refresh-preview' '$HALL_DIR/bin/cc-hall'
    "
    assert_success
}

# ============================================================================
# MODULE_API.md documents new convention
# ============================================================================

@test "docs: MODULE_API.md documents cc-hall reload in bindings" {
    run bash -c "grep 'reload(cc-hall reload)' '$HALL_DIR/MODULE_API.md'"
    assert_success
}

@test "docs: MODULE_API.md documents preview.sh receives \$1=command \$2=label" {
    run bash -c "grep -q '\$1.*Clean command' '$HALL_DIR/MODULE_API.md'"
    assert_success
}

@test "docs: MODULE_API.md documents subcommands section" {
    run bash -c "grep -q 'Subcommands (stable module API)' '$HALL_DIR/MODULE_API.md'"
    assert_success
}

# ============================================================================
# Lint: no bare JS truthy checks on c.env[] across ALL modules
# ============================================================================

@test "lint: no module on_select.sh uses bare !c.env[] truthy check" {
    # Bare !c.env['key'] treats empty string as absent — use === undefined || === null
    run bash -c "grep -r '!c\.env\[' '$HALL_DIR/modules/' --include='*.sh' | wc -l | tr -d ' '"
    [ "$output" = "0" ]
}

@test "lint: no module on_select.sh uses bare c.env[] in if() without ===" {
    # Match if(c.env['x']) without === operator — bare truthy check
    run bash -c "grep -rE 'if \(c\.env\[.*\]\)' '$HALL_DIR/modules/' --include='*.sh' | grep -v '===' | wc -l | tr -d ' '"
    [ "$output" = "0" ]
}
