#!/usr/bin/env bash
# usage module — Read-only usage analytics for local Claude Code transcripts
# Built-in module for cc-hall

source "${HALL_LIB_DIR}/hall-theme.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

HALL_MODULE_LABEL="Usage"
HALL_MODULE_ORDER=15
HALL_MODULE_ICON="◍"
HALL_MODULE_LOCKED=1
HALL_MODULE_PREVIEW_RENDERER="quick"
HALL_MODULE_SUBTABS=("Overview" "Daily" "Projects" "Models")

_uv_cache_dir() {
    printf '%s' "$HALL_STATE_DIR/usage"
}

_uv_clear_entry_cache() {
    rm -f "${HALL_STATE_DIR:-}/entries-cache"/usage--subtab-*.entries 2>/dev/null
}

_uv_ensure_snapshot() {
    local cache_dir
    cache_dir=$(_uv_cache_dir)
    [ -f "$cache_dir/manifest.json" ] && return 0

    # Background pre-warm in progress — do not block tab navigation.
    if [ -f "$cache_dir/.building" ]; then
        return 2
    fi

    return 1
}

hall_usage_entries() {
    local subtab_idx entries_file
    subtab_idx=$(hall_get_subtab_index)

    printf '%s\t%s\n' \
        "$(hall_icon guide) $(hall_ansi_bold "Guide")" \
        "usage-info guide"

    printf '%s\t%s\n' \
        "$(hall_icon toggle) Refresh snapshot" \
        "usage-refresh"

    _uv_ensure_snapshot
    case $? in
        0) ;;
        2)
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "Usage snapshot building…")" \
                "usage-info building"
            return 0
            ;;
        *)
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "Usage snapshot unavailable")" \
                "usage-info unavailable"
            return 0
            ;;
    esac

    case "$subtab_idx" in
        0) entries_file="$(_uv_cache_dir)/overview.entries" ;;
        1) entries_file="$(_uv_cache_dir)/daily.entries" ;;
        2) entries_file="$(_uv_cache_dir)/projects.entries" ;;
        3) entries_file="$(_uv_cache_dir)/models.entries" ;;
        *) entries_file="$(_uv_cache_dir)/overview.entries" ;;
    esac

    [ -f "$entries_file" ] && cat "$entries_file"
}
