#!/usr/bin/env bats
# Unit tests for hall-menu.sh
# Tests discovery parsing, module resolution, tab header, and module loading.

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
# hall_parse_discovery_entry
# ============================================================================

@test "hall_parse_discovery_entry: parses all fields" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_parse_discovery_entry '10:editor:/path/to/editor:◇:My Editors:quick'
        echo \"name=\$HALL_ENTRY_NAME\"
        echo \"dir=\$HALL_ENTRY_DIR\"
        echo \"icon=\$HALL_ENTRY_ICON\"
        echo \"label=\$HALL_ENTRY_LABEL\"
        echo \"renderer=\$HALL_ENTRY_PREVIEW_RENDERER\"
    "
    assert_success
    assert_output --partial 'name=editor'
    assert_output --partial 'dir=/path/to/editor'
    assert_output --partial 'icon=◇'
    assert_output --partial 'label=My Editors'
    assert_output --partial 'renderer=quick'
}

@test "hall_parse_discovery_entry: defaults preview renderer for legacy entries" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_parse_discovery_entry '50:inline-mod:/path/inline:○:'
        echo \"name=\$HALL_ENTRY_NAME\"
        echo \"icon=\$HALL_ENTRY_ICON\"
        echo \"label=[\$HALL_ENTRY_LABEL]\"
        echo \"renderer=\$HALL_ENTRY_PREVIEW_RENDERER\"
    "
    assert_success
    assert_output --partial 'name=inline-mod'
    assert_output --partial 'icon=○'
    assert_output --partial 'label=[]'
    assert_output --partial 'renderer=auto'
}

@test "hall_parse_discovery_entry: handles hyphenated names" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_parse_discovery_entry '30:skill-viewer:/fake/dir:◆:Skills'
        echo \"\$HALL_ENTRY_NAME\"
    "
    assert_success
    assert_output 'skill-viewer'
}

# ============================================================================
# hall_find_module_dir
# ============================================================================

@test "hall_find_module_dir: finds built-in module" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        result=\$(hall_find_module_dir 'cc-hall')
        [ -n \"\$result\" ] && [ -d \"\$result\" ]
    "
    assert_success
}

@test "hall_find_module_dir: returns empty for nonexistent module" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        result=\$(hall_find_module_dir 'nonexistent-module-xyz')
        [ -z \"\$result\" ]
    "
    assert_success
}

@test "hall_find_module_file: returns module.sh path for built-in" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        result=\$(hall_find_module_file 'cc-hall')
        [[ \"\$result\" == */modules/cc-hall/module.sh ]]
    "
    assert_success
}

@test "hall_find_module_file: returns empty for nonexistent module" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        result=\$(hall_find_module_file 'nonexistent-module-xyz')
        [ -z \"\$result\" ]
    "
    assert_success
}

# ============================================================================
# hall_build_tab_header
# ============================================================================

@test "hall_build_tab_header: single tab shows active marker, no arrows" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 0 80 'Editors'
    "
    assert_success
    assert_output --partial '▸ Editors'
    refute_output --partial '‹'
    refute_output --partial '›'
}

@test "hall_build_tab_header: carousel shows prev and next neighbors" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 1 80 'Editors' 'Settings' 'Skills'
    "
    assert_success
    assert_output --partial '▸ Settings'
    assert_output --partial 'Editors'
    assert_output --partial 'Skills'
    assert_output --partial '‹'
    assert_output --partial '›'
}

@test "hall_build_tab_header: first tab wraps prev to last" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 0 80 'Editors' 'Hall' 'Config'
    "
    assert_success
    assert_output --partial '▸ Editors'
    assert_output --partial 'Config'
    assert_output --partial 'Hall'
}

@test "hall_build_tab_header: last tab wraps next to first" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 2 80 'A' 'B' 'C'
    "
    assert_success
    assert_output --partial '▸ C'
    assert_output --partial 'B'
    assert_output --partial 'A'
}

@test "hall_build_tab_header: two tabs fixed order, highlight on first" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 0 80 'Editors' 'Hall'
    "
    assert_success
    assert_output --partial '▸ Editors'
    assert_output --partial 'Hall'
    assert_output --partial '●○'
    # Editors appears before Hall (fixed order)
    local stripped
    stripped=$(echo "$output" | sed $'s/\033\[[0-9;]*m//g')
    local pos_ed pos_hall
    pos_ed=$(echo "$stripped" | grep -bo 'Editors' | head -1 | cut -d: -f1)
    pos_hall=$(echo "$stripped" | grep -bo 'Hall' | head -1 | cut -d: -f1)
    [ "$pos_ed" -lt "$pos_hall" ]
}

@test "hall_build_tab_header: two tabs fixed order, highlight on second" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 1 80 'Editors' 'Hall'
    "
    assert_success
    assert_output --partial '▸ Hall'
    assert_output --partial 'Editors'
    assert_output --partial '○●'
    # Editors still appears before Hall (fixed order, only highlight moved)
    local stripped
    stripped=$(echo "$output" | sed $'s/\033\[[0-9;]*m//g')
    local pos_ed pos_hall
    pos_ed=$(echo "$stripped" | grep -bo 'Editors' | head -1 | cut -d: -f1)
    pos_hall=$(echo "$stripped" | grep -bo 'Hall' | head -1 | cut -d: -f1)
    [ "$pos_ed" -lt "$pos_hall" ]
}

@test "hall_build_tab_header: minimap shows dots matching module count" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 1 80 'A' 'B' 'C'
    "
    assert_success
    assert_output --partial '○●○'
}

@test "hall_build_tab_header: minimap first position" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 0 80 'A' 'B' 'C' 'D'
    "
    assert_success
    assert_output --partial '●○○○'
}

@test "hall_build_tab_header: adaptive shows more neighbors when wide" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        # Very wide terminal should show 2 neighbors each side
        hall_build_tab_header 2 200 'A' 'B' 'C' 'D' 'E'
    "
    assert_success
    assert_output --partial '▸ C'
    # Should see A and B on the left, D and E on the right
    assert_output --partial 'A'
    assert_output --partial 'B'
    assert_output --partial 'D'
    assert_output --partial 'E'
}

@test "hall_build_tab_header: narrow width shows fewer neighbors" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        # Narrow — should still show at least 1 neighbor
        hall_build_tab_header 2 40 'Editor' 'Hall' 'Config' 'Skills' 'Memory'
    "
    assert_success
    assert_output --partial '▸ Config'
    assert_output --partial '‹'
    assert_output --partial '›'
}

@test "hall_build_tab_header: no minimap for single tab" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_build_tab_header 0 80 'Only'
    "
    assert_success
    refute_output --partial '●'
    refute_output --partial '○'
}

# ============================================================================
# hall_discover_modules
# ============================================================================

@test "hall_discover_modules: built-ins load when user modules dir is absent" {
    run bash -c "
        tmp_home=\$(mktemp -d)
        trap 'rm -rf \"\$tmp_home\"' EXIT
        export HOME=\"\$tmp_home\"
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-menu.sh'
        hall_discover_modules
    "
    assert_success
    assert_output --partial ':editor:'
    assert_output --partial ':cc-hall:'
}

@test "hall_build_module_entries: caches entries per module and subtab" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        export HALL_STATE_DIR='$BATS_TEST_TMPDIR/state-cache'
        export HOME='$BATS_TEST_TMPDIR/home-cache'
        mkdir -p \"\$HALL_STATE_DIR\" \"\$HOME/.claude/hall/modules/cachemod\"
        echo 0 > \"\$HALL_STATE_DIR/module-subtab\"
        cat > \"\$HOME/.claude/hall/modules/cachemod/module.sh\" <<'EOF'
COUNT_FILE=\"${BATS_TEST_TMPDIR}/cachemod-count\"
hall_cachemod_entries() {
    count=0
    [ -f \"\$COUNT_FILE\" ] && count=\$(cat \"\$COUNT_FILE\")
    count=\$((count + 1))
    printf '%s\n' \"\$count\" > \"\$COUNT_FILE\"
    printf 'Label %s\tcmd-%s\n' \"\$count\" \"\$count\"
}
EOF
        source '$HALL_LIB_DIR/hall-menu.sh'
        first=\$(hall_build_module_entries cachemod)
        second=\$(hall_build_module_entries cachemod)
        echo 1 > \"\$HALL_STATE_DIR/module-subtab\"
        third=\$(hall_build_module_entries cachemod)
        printf 'first=%s\nsecond=%s\nthird=%s\ncount=%s\n' \
            \"\$first\" \"\$second\" \"\$third\" \"\$(cat '${BATS_TEST_TMPDIR}/cachemod-count')\"
    "
    assert_success
    assert_output --partial $'first=Label 1\tcmd-1'
    assert_output --partial $'second=Label 1\tcmd-1'
    assert_output --partial $'third=Label 2\tcmd-2'
    assert_output --partial 'count=2'
}

# ============================================================================
# hall_is_module_disabled
# ============================================================================

@test "hall_is_module_disabled: returns true for disabled module" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        _PA_DISABLED_MODULES='\"skills\", \"editor\"'
        hall_is_module_disabled 'skills'
    "
    assert_success
}

@test "hall_is_module_disabled: returns false for enabled module" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        _PA_DISABLED_MODULES='\"skills\"'
        hall_is_module_disabled 'editor'
    "
    assert_failure
}

@test "hall_is_module_disabled: returns false when no modules disabled" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        _PA_DISABLED_MODULES=''
        hall_is_module_disabled 'skills'
    "
    assert_failure
}

@test "hall_is_module_disabled: no partial match on similar names" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        _PA_DISABLED_MODULES='\"skill\"'
        hall_is_module_disabled 'skills'
    "
    assert_failure
}

# ============================================================================
# _hall_load_config: disabled_modules parsing
# ============================================================================

@test "_hall_load_config: parses disabled_modules from config" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        CONFIG_DIR=\$(mktemp -d)
        HOME=\"\$CONFIG_DIR\"
        HALL_CONFIG_FILE=\"\$HOME/.claude/reflections/config.json\"
        mkdir -p \"\$CONFIG_DIR/.claude/reflections\"
        echo '{\"disabled_modules\": [\"skills\", \"editor\"]}' > \"\$CONFIG_DIR/.claude/reflections/config.json\"
        _hall_load_config
        echo \"\$_PA_DISABLED_MODULES\"
        rm -rf \"\$CONFIG_DIR\"
    "
    assert_success
    assert_output --partial '"skills"'
    assert_output --partial '"editor"'
}

@test "_hall_load_config: empty disabled_modules when key absent" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        CONFIG_DIR=\$(mktemp -d)
        HOME=\"\$CONFIG_DIR\"
        HALL_CONFIG_FILE=\"\$HOME/.claude/reflections/config.json\"
        mkdir -p \"\$CONFIG_DIR/.claude/reflections\"
        echo '{\"theme\": \"mirrors\"}' > \"\$CONFIG_DIR/.claude/reflections/config.json\"
        _hall_load_config
        [ -z \"\$_PA_DISABLED_MODULES\" ]
    "
    assert_success
}

@test "_hall_load_config: empty disabled_modules when array is empty" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        CONFIG_DIR=\$(mktemp -d)
        HOME=\"\$CONFIG_DIR\"
        HALL_CONFIG_FILE=\"\$HOME/.claude/reflections/config.json\"
        mkdir -p \"\$CONFIG_DIR/.claude/reflections\"
        echo '{\"disabled_modules\": []}' > \"\$CONFIG_DIR/.claude/reflections/config.json\"
        _hall_load_config
        [ -z \"\$_PA_DISABLED_MODULES\" ]
    "
    assert_success
}

# ============================================================================
# hall_load_active_modules
# ============================================================================

@test "hall_load_active_modules: filters out disabled modules" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        # Mock hall_discover_modules to return known modules
        hall_discover_modules() {
            echo '10:editor:/fake/editor:◇:Editors'
            echo '20:cc-hall:/fake/cc-hall:◈:cc-hall'
            echo '30:skills:/fake/skills:◆:Skills'
        }

        # Simulate skills disabled
        _PA_DISABLED_MODULES='\"skills\"'

        hall_load_active_modules
        echo \"count=\${#HALL_MOD_NAMES[@]}\"
        echo \"names=\${HALL_MOD_NAMES[*]}\"
    "
    assert_success
    assert_output --partial 'count=2'
    assert_output --partial 'editor'
    assert_output --partial 'cc-hall'
    refute_output --partial 'skills'
}

@test "hall_load_active_modules: returns all when nothing disabled" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        hall_discover_modules() {
            echo '10:editor:/fake/editor:◇:Editors'
            echo '20:cc-hall:/fake/cc-hall:◈:cc-hall'
        }

        _PA_DISABLED_MODULES=''

        hall_load_active_modules
        echo \"count=\${#HALL_MOD_NAMES[@]}\"
        echo \"names=\${HALL_MOD_NAMES[*]}\"
    "
    assert_success
    assert_output --partial 'count=2'
    assert_output --partial 'editor'
    assert_output --partial 'cc-hall'
}

@test "hall_load_active_modules: multiple disabled modules filtered" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        hall_discover_modules() {
            echo '10:editor:/fake/editor:◇:Editors'
            echo '20:cc-hall:/fake/cc-hall:◈:cc-hall'
            echo '30:skills:/fake/skills:◆:Skills'
            echo '40:reflect:/fake/reflect:○:Reflect'
        }

        _PA_DISABLED_MODULES='\"skills\", \"editor\"'

        hall_load_active_modules
        echo \"count=\${#HALL_MOD_NAMES[@]}\"
        echo \"names=\${HALL_MOD_NAMES[*]}\"
    "
    assert_success
    assert_output --partial 'count=2'
    assert_output --partial 'cc-hall'
    assert_output --partial 'reflect'
    refute_output --partial 'skills'
    refute_output --partial 'editor'
}

@test "hall_load_active_modules: preserves labels from discovery" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        hall_discover_modules() {
            echo '10:editor:/fake/editor:◇:My Editors'
            echo '20:cc-hall:/fake/cc-hall:◈:Settings'
        }

        _PA_DISABLED_MODULES=''

        hall_load_active_modules
        echo \"label0=\${HALL_MOD_LABELS[0]}\"
        echo \"label1=\${HALL_MOD_LABELS[1]}\"
    "
    assert_success
    assert_output --partial 'label0=My Editors'
    assert_output --partial 'label1=Settings'
}

@test "hall_load_active_modules: preserves icons from discovery" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        hall_discover_modules() {
            echo '10:editor:/fake/editor:◇:Editors'
            echo '20:cc-hall:/fake/cc-hall:◈:Hall'
        }

        _PA_DISABLED_MODULES=''

        hall_load_active_modules
        echo \"icon0=\${HALL_MOD_ICONS[0]}\"
        echo \"icon1=\${HALL_MOD_ICONS[1]}\"
    "
    assert_success
    assert_output --partial 'icon0=◇'
    assert_output --partial 'icon1=◈'
}

@test "hall_load_active_modules: uses module name as fallback label" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        hall_discover_modules() {
            echo '10:editor:/fake/editor:○:'
        }

        _PA_DISABLED_MODULES=''

        hall_load_active_modules
        echo \"label=\${HALL_MOD_LABELS[0]}\"
    "
    assert_success
    assert_output --partial 'label=editor'
}

@test "hall_load_active_modules: preserves preview renderers from discovery" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-config.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'

        hall_discover_modules() {
            echo '10:editor:/fake/editor:◇:Editors:quick'
            echo '20:cc-hall:/fake/cc-hall:◈:Hall:auto'
            echo '30:memory:/fake/memory:◍:Memory:glow'
        }

        _PA_DISABLED_MODULES=''

        hall_load_active_modules
        echo \"renderer0=\${HALL_MOD_PREVIEW_RENDERERS[0]}\"
        echo \"renderer1=\${HALL_MOD_PREVIEW_RENDERERS[1]}\"
        echo \"renderer2=\${HALL_MOD_PREVIEW_RENDERERS[2]}\"
    "
    assert_success
    assert_output --partial 'renderer0=quick'
    assert_output --partial 'renderer1=auto'
    assert_output --partial 'renderer2=glow'
}
