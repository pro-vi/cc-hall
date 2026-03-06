#!/usr/bin/env bash
# Command handler for memory module
# Args: $1 = raw command (after \x1f split), $2 = prompt file path

set -e

source "${HALL_LIB_DIR}/hall-common.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

CMD="$1"
FILE="$2"

# ── Command routing ──────────────────────────────────────────

case "$CMD" in
    mv-noop)
        exit $HALL_RC_RELOAD ;;

    mv-open\ *)
        # Open file in preferred editor (not EDITOR — that's cc-hall)
        _mv_path="${CMD#mv-open }"
        _hall_load_config
        mkdir -p "$(dirname "$_mv_path")"
        exec bash -c "$(hall_editor_cmd "$_PA_MEMORY_EDITOR" "$_mv_path")"
        exit $HALL_RC_CLOSE ;;

    mv-toggle-editor)
        # Cycle through available editors
        _hall_load_config
        _mv_eds=$(hall_available_editors)
        _mv_eds_arr=($_mv_eds)
        _mv_cur="$_PA_MEMORY_EDITOR"
        _mv_next="${_mv_eds_arr[0]}"
        for _mv_i in "${!_mv_eds_arr[@]}"; do
            if [ "${_mv_eds_arr[$_mv_i]}" = "$_mv_cur" ]; then
                _mv_next_i=$(( (_mv_i + 1) % ${#_mv_eds_arr[@]} ))
                _mv_next="${_mv_eds_arr[$_mv_next_i]}"
                break
            fi
        done
        hall_config_set_string "$HALL_CONFIG_FILE" "memory_editor" "$_mv_next" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;

    mv-info\ *)
        # Info-only entries (guide, no-auto) — just reload
        exit $HALL_RC_RELOAD ;;

    mv-section:*)
        # Toggle section collapse/expand
        _mv_section="${CMD#mv-section:}"
        _mv_state_file="$HALL_STATE_DIR/memory-sections"
        if [ -f "$_mv_state_file" ]; then
            # Toggle: flip 0↔1 for matching section
            _mv_new=""
            while IFS=: read -r _mv_name _mv_val; do
                if [ "$_mv_name" = "$_mv_section" ]; then
                    [ "$_mv_val" = "1" ] && _mv_val=0 || _mv_val=1
                fi
                _mv_new="${_mv_new}${_mv_name}:${_mv_val}
"
            done < "$_mv_state_file"
            printf '%s' "$_mv_new" > "$_mv_state_file"
        fi
        exit $HALL_RC_RELOAD ;;
esac

exit $HALL_RC_NOT_HANDLED
