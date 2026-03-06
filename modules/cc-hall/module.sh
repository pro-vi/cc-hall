#!/usr/bin/env bash
# cc-hall module — App settings and module management
# Built-in module for cc-hall

source "${HALL_LIB_DIR}/hall-theme.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

# Metadata
HALL_MODULE_LABEL="Hall"
HALL_MODULE_ORDER=20
HALL_MODULE_ICON="◈"
HALL_MODULE_LOCKED=1
HALL_MODULE_PREVIEW_RENDERER="quick"

# Entry generator
hall_cc_hall_entries() {
    _hall_load_config

    printf '%s\t%s\n' \
        "$(hall_icon guide) $(hall_ansi_bold "Guide")" \
        "hall-info guide"

    # ── Settings ─────────────────────────────────────────────
    printf '%s\t%s\n' "$(hall_ansi_dim "╭─ Settings ──")" "hall-noop"

    # Theme
    local current_theme next_theme
    case "$_PA_THEME" in
        mirrors) current_theme="Mirrors"; next_theme="Clawd"   ;;
        clawd)   current_theme="Clawd";   next_theme="Zinc" ;;
        zinc)    current_theme="Zinc";   next_theme="Mirrors" ;;
        *)       current_theme="Mirrors"; next_theme="Clawd"   ;;
    esac
    printf '%s\t%s\n' \
        "$(hall_ansi_dim "│") $(hall_icon theme) Theme: $current_theme $(hall_ansi_dim "→ $next_theme")" \
        "pa-toggle-theme"

    printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "hall-noop"

    # ── Modules ──────────────────────────────────────────────
    printf '%s\t%s\n' "$(hall_ansi_dim "╭─ Modules ──")" "hall-noop"

    local discovered
    discovered=$(hall_discover_modules)
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        hall_parse_discovery_entry "$entry"
        local mod_name="$HALL_ENTRY_NAME"
        local mod_label="${HALL_ENTRY_LABEL:-$mod_name}"
        local location="built-in"
        [[ "$HALL_ENTRY_DIR" != "$HALL_DIR/modules/"* ]] && location="user"

        # Check core status from module metadata (grep, not source — module.sh has side effects)
        local _mod_icon
        _mod_icon=$(hall_icon module)
        if grep -q '^HALL_MODULE_LOCKED=1' "$HALL_ENTRY_DIR/module.sh" 2>/dev/null; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $_mod_icon $(hall_ansi_bold "$mod_label") ✓ $(hall_ansi_dim "core")" \
                "module-toggle:$mod_name"
        elif hall_is_module_disabled "$mod_name"; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $_mod_icon $mod_label $(hall_ansi_dim "✗ disabled")" \
                "module-toggle:$mod_name"
        else
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $_mod_icon $(hall_ansi_bold "$mod_label") ✓ $(hall_ansi_dim "$location")" \
                "module-toggle:$mod_name"
        fi
    done <<< "$discovered"

    printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "hall-noop"
}
