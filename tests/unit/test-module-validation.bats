#!/usr/bin/env bats
# Module validation tests — structural invariants for all cc-hall modules.
# Tests entry format, on_select coverage, toggle label conventions,
# and entry count regression guards.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"

setup() {
    hall_test_setup_home
    HALL_STATE_DIR=$(mktemp -d)
    export HALL_STATE_DIR
    export HALL_DIR
    export HALL_LIB_DIR
    export HALL_SAFE_FILE="/tmp/test-prompt.md"
    export HALL_FILE="/tmp/test-prompt.md"

    TEST_PROJECT=$(mktemp -d)
    ORIG_DIR="$PWD"
    cd "$TEST_PROJECT"

    # Minimal CLAUDE.md so memory module has something to list
    echo "test" > "$TEST_PROJECT/CLAUDE.md"
}

teardown() {
    cd "$ORIG_DIR"
    rm -rf "$HALL_STATE_DIR" "$TEST_PROJECT" 2>/dev/null
    hall_test_teardown_home
}

# ============================================================================
# TEST 1: Entry format validation
# Every non-empty line from hall_{name}_entries() must be Label<TAB>command.
# ============================================================================

@test "validate: editor entries are well-formed (label<TAB>command)" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_SAFE_FILE='$HALL_SAFE_FILE'
        export HALL_FILE='$HALL_FILE'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/editor/module.sh'
        entries=\$(hall_editor_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-hall entries are well-formed (label<TAB>command)" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-hall/module.sh'
        entries=\$(hall_cc_hall_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-config entries are well-formed (label<TAB>command)" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-config/module.sh'
        entries=\$(hall_cc_config_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: memory entries are well-formed (label<TAB>command)" {
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/memory/module.sh'
        entries=\$(hall_memory_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: skill-viewer entries are well-formed (label<TAB>command)" {
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/skill-viewer/module.sh'
        entries=\$(hall_skill_viewer_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: usage entries are well-formed (label<TAB>command)" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/usage/module.sh'
        entries=\$(hall_usage_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-config subtab 1 (Shared) entries well-formed" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '1' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-config/module.sh'
        entries=\$(hall_cc_config_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-config subtab 2 (Local) entries well-formed" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '2' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-config/module.sh'
        entries=\$(hall_cc_config_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            case \"\$line\" in
                *\$'\\t'*) ;;
                *) echo \"FAIL: line without tab: \$line\"; fail=1 ;;
            esac
            cmd=\"\${line#*\$'\\t'}\"
            [ -z \"\$cmd\" ] && { echo \"FAIL: empty command\"; fail=1; }
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

# ============================================================================
# TEST 2: on_select exit code coverage
# Commands emitted by entries should be handled by on_select.sh.
# Skip: "echo" (section headers), editor launch commands (intentional fallthrough).
# ============================================================================

@test "validate: memory on_select handles all entry commands" {
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/memory/module.sh'
        entries=\$(hall_memory_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            # Skip section headers
            [ \"\$cmd\" = 'echo' ] && continue
            # Skip mv-open commands — they exec an editor (blocks test)
            case \"\$cmd\" in mv-open\ *) continue ;; esac
            set +e
            bash '$HALL_DIR/modules/memory/on_select.sh' \"\$cmd\" '/dev/null' 2>/dev/null
            rc=\$?
            set -e
            if [ \"\$rc\" -eq 1 ]; then
                echo \"NOT_HANDLED: \$cmd\"
                fail=1
            fi
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-hall on_select handles all entry commands" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-hall/module.sh'
        entries=\$(hall_cc_hall_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            [ \"\$cmd\" = 'echo' ] && continue
            set +e
            bash '$HALL_DIR/modules/cc-hall/on_select.sh' \"\$cmd\" '/dev/null' 2>/dev/null
            rc=\$?
            set -e
            if [ \"\$rc\" -eq 1 ]; then
                echo \"NOT_HANDLED: \$cmd\"
                fail=1
            fi
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-config on_select handles all entry commands" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-config/module.sh'
        entries=\$(hall_cc_config_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            [ \"\$cmd\" = 'echo' ] && continue
            set +e
            bash '$HALL_DIR/modules/cc-config/on_select.sh' \"\$cmd\" '/dev/null' 2>/dev/null
            rc=\$?
            set -e
            if [ \"\$rc\" -eq 1 ]; then
                echo \"NOT_HANDLED: \$cmd\"
                fail=1
            fi
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: skill-viewer on_select handles all entry commands" {
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/skill-viewer/module.sh'
        entries=\$(hall_skill_viewer_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            [ \"\$cmd\" = 'echo' ] && continue
            set +e
            bash '$HALL_DIR/modules/skill-viewer/on_select.sh' \"\$cmd\" '/dev/null' 2>/dev/null
            rc=\$?
            set -e
            if [ \"\$rc\" -eq 1 ]; then
                echo \"NOT_HANDLED: \$cmd\"
                fail=1
            fi
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: editor on_select handles non-editor entry commands" {
    # Editor module: editor launch commands (vi, code, etc.) intentionally
    # fall through to the built-in editor pattern. Only test module-specific
    # commands (prompt agent, toggles, info, noop).
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_SAFE_FILE='$HALL_SAFE_FILE'
        export HALL_FILE='$HALL_FILE'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/editor/module.sh'
        entries=\$(hall_editor_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            [ \"\$cmd\" = 'echo' ] && continue
            # Skip editor launch commands — intentional fallthrough
            case \"\$cmd\" in
                vi\ *|nvim\ *|code\ *|cursor\ *|windsurf\ *|zed\ *|subl\ *|agy\ *) continue ;;
                # Skip prompt-agent commands — they exec/spawn external processes
                prompt-agent-*) continue ;;
            esac
            set +e
            bash '$HALL_DIR/modules/editor/on_select.sh' \"\$cmd\" '/dev/null' 2>/dev/null
            rc=\$?
            set -e
            if [ \"\$rc\" -eq 1 ]; then
                echo \"NOT_HANDLED: \$cmd\"
                fail=1
            fi
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: usage on_select handles all entry commands" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/usage/module.sh'
        entries=\$(hall_usage_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            [ \"\$cmd\" = 'echo' ] && continue
            set +e
            bash '$HALL_DIR/modules/usage/on_select.sh' \"\$cmd\" '/dev/null' 2>/dev/null
            rc=\$?
            set -e
            if [ \"\$rc\" -eq 1 ]; then
                echo \"NOT_HANDLED: \$cmd\"
                fail=1
            fi
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

# ============================================================================
# TEST 3: Toggle label consistency
# Toggle entries should show current state and next state with → indicator.
# ============================================================================

@test "validate: editor toggle entries show state transition" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_SAFE_FILE='$HALL_SAFE_FILE'
        export HALL_FILE='$HALL_FILE'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/editor/module.sh'
        entries=\$(hall_editor_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            label=\"\${line%%\$'\\t'*}\"
            case \"\$cmd\" in
                pa-toggle-*)
                    clean=\$(printf '%s' \"\$label\" | sed \$'s/\033\[[0-9;]*m//g')
                    case \"\$clean\" in
                        *→*) ;;
                        *) echo \"FAIL: toggle missing arrow: \$clean (\$cmd)\"; fail=1 ;;
                    esac
                    ;;
            esac
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-hall toggle entries show state transition" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-hall/module.sh'
        entries=\$(hall_cc_hall_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            label=\"\${line%%\$'\\t'*}\"
            case \"\$cmd\" in
                pa-toggle-*)
                    clean=\$(printf '%s' \"\$label\" | sed \$'s/\033\[[0-9;]*m//g')
                    case \"\$clean\" in
                        *→*) ;;
                        *) echo \"FAIL: toggle missing arrow: \$clean (\$cmd)\"; fail=1 ;;
                    esac
                    ;;
            esac
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: cc-config toggle entries show state transition" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-config/module.sh'
        entries=\$(hall_cc_config_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            label=\"\${line%%\$'\\t'*}\"
            case \"\$cmd\" in
                cv-flag\ *|cv-val\ *|cv-sflag\ *|cv-sval\ *|cv-pflag\ *|cv-pval\ *)
                    clean=\$(printf '%s' \"\$label\" | sed \$'s/\033\[[0-9;]*m//g')
                    case \"\$clean\" in
                        *→*) ;;
                        *) echo \"FAIL: toggle missing arrow: \$clean (\$cmd)\"; fail=1 ;;
                    esac
                    ;;
            esac
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

@test "validate: memory toggle entries show state transition" {
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/memory/module.sh'
        entries=\$(hall_memory_entries)
        fail=0
        while IFS= read -r line; do
            [ -z \"\$line\" ] && continue
            cmd=\"\${line#*\$'\\t'}\"
            label=\"\${line%%\$'\\t'*}\"
            case \"\$cmd\" in
                mv-toggle-*)
                    clean=\$(printf '%s' \"\$label\" | sed \$'s/\033\[[0-9;]*m//g')
                    case \"\$clean\" in
                        *→*) ;;
                        *) echo \"FAIL: toggle missing arrow: \$clean (\$cmd)\"; fail=1 ;;
                    esac
                    ;;
            esac
        done <<< \"\$entries\"
        exit \$fail
    "
    assert_success
}

# ============================================================================
# TEST 4: Entry count regression guards
# Modules should emit a stable minimum number of entries.
# Prevents silent entry loss from sourcing errors or broken conditionals.
# ============================================================================

@test "validate: editor emits at least 8 entries" {
    # Guide + vim + prompt agent x2 + 3 toggles + noop dividers = 11+
    # Minimum 8 accounts for minimal editor availability (just vim)
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_SAFE_FILE='$HALL_SAFE_FILE'
        export HALL_FILE='$HALL_FILE'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/editor/module.sh'
        entries=\$(hall_editor_entries)
        count=\$(printf '%s\n' \"\$entries\" | wc -l | tr -d ' ')
        echo \"\$count\"
    "
    assert_success
    [ "$output" -ge 8 ]
}

@test "validate: cc-hall emits at least 4 entries" {
    # Guide + theme toggle + noop dividers + module list (6 built-ins)
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-hall/module.sh'
        entries=\$(hall_cc_hall_entries)
        count=\$(printf '%s\n' \"\$entries\" | wc -l | tr -d ' ')
        echo \"\$count\"
    "
    assert_success
    [ "$output" -ge 4 ]
}

@test "validate: cc-config emits at least 15 entries" {
    # Guide + 4 section headers + ~20 toggles + noop closers
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/cc-config/module.sh'
        entries=\$(hall_cc_config_entries)
        count=\$(printf '%s\n' \"\$entries\" | wc -l | tr -d ' ')
        echo \"\$count\"
    "
    assert_success
    [ "$output" -ge 15 ]
}

@test "validate: memory emits at least 5 entries" {
    # Guide + editor toggle + 3 sections (collapsed or expanded)
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/memory/module.sh'
        entries=\$(hall_memory_entries)
        count=\$(printf '%s\n' \"\$entries\" | wc -l | tr -d ' ')
        echo \"\$count\"
    "
    assert_success
    [ "$output" -ge 5 ]
}

@test "validate: skill-viewer emits at least 1 entry" {
    # Always emits guide entry at minimum
    run bash -c "
        cd '$TEST_PROJECT'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/skill-viewer/module.sh'
        entries=\$(hall_skill_viewer_entries)
        count=\$(printf '%s\n' \"\$entries\" | wc -l | tr -d ' ')
        echo \"\$count\"
    "
    assert_success
    [ "$output" -ge 1 ]
}

@test "validate: usage emits at least 4 entries" {
    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo '0' > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$HALL_DIR/modules/usage/module.sh'
        entries=\$(hall_usage_entries)
        count=\$(printf '%s\n' \"\$entries\" | wc -l | tr -d ' ')
        echo \"\$count\"
    "
    assert_success
    [ "$output" -ge 4 ]
}
