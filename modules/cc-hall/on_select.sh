#!/usr/bin/env bash
# Command handler for cc-hall module (app settings + module management)
# Args: $1 = raw command (after \x1f split), $2 = prompt file path

set -e

source "${HALL_LIB_DIR}/hall-common.sh"
source "${HALL_LIB_DIR}/hall-config.sh"
source "${HALL_LIB_DIR}/hall-menu.sh"

CMD="$1"
FILE="$2"

# ── Command routing ──────────────────────────────────────────

case "$CMD" in
    hall-noop|hall-info\ *)
        exit $HALL_RC_RELOAD ;;
    pa-toggle-theme)
        _hall_load_config
        local_next=""
        case "$_PA_THEME" in
            mirrors) local_next="clawd" ;;
            clawd)   local_next="zinc" ;;
            *)       local_next="mirrors" ;;
        esac
        hall_config_set_string "$HALL_CONFIG_FILE" "theme" "$local_next" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;
    module-toggle:*)
        mod_name="${CMD#module-toggle:}"
        # Check for core modules via metadata (grep, not source — module.sh has side effects)
        mod_dir=$(hall_find_module_dir "$mod_name" 2>/dev/null || true)
        if [ -n "$mod_dir" ] && [ -f "$mod_dir/module.sh" ]; then
            if grep -q '^HALL_MODULE_LOCKED=1' "$mod_dir/module.sh" 2>/dev/null; then
                exit $HALL_RC_RELOAD
            fi
        fi
        hall_config_toggle_module "$HALL_CONFIG_FILE" "$mod_name" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;
esac

exit $HALL_RC_NOT_HANDLED
