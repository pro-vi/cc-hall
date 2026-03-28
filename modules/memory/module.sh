#!/usr/bin/env bash
# memory module — Read-only viewer for Claude Code memory layers
# Built-in module for cc-hall
#
# Shows all files that Claude loads into context:
# project instructions, user instructions, and auto memory.

source "${HALL_LIB_DIR}/hall-theme.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

# Metadata
HALL_MODULE_LABEL="Memory"
HALL_MODULE_ORDER=35
HALL_MODULE_ICON="◎"

# Keybindings: y = yank (copy) memory file content to clipboard
HALL_MODULE_BINDINGS=(
    "y:transform('$HALL_LIB_DIR/hall-yank.sh' {2} mv-open 1 && printf 'change-footer( ✓ yanked  ? help )')"
)

# Footer hint shown when this module is active
HALL_MODULE_FOOTER=" y yank  ? help "

# Section state helpers
_mv_sections_file() { echo "$HALL_STATE_DIR/memory-sections"; }

_mv_load_sections() {
    local sf
    sf=$(_mv_sections_file)
    if [ ! -f "$sf" ]; then
        printf 'Project:1\nUser:1\nAuto:1\n' > "$sf"
    fi
}

_mv_is_expanded() {
    local section="$1" sf
    sf=$(_mv_sections_file)
    local val
    val=$(grep "^${section}:" "$sf" 2>/dev/null | cut -d: -f2)
    [ "$val" = "1" ]
}

_mv_count_items() {
    local section="$1" count=0
    case "$section" in
        Project)
            [ -f "./CLAUDE.md" ] && count=$((count + 1))
            [ -f "./CLAUDE.local.md" ] && count=$((count + 1))
            [ -f "./.claude/CLAUDE.local.md" ] && count=$((count + 1))
            ;;
        User)
            [ -f "${HOME}/.claude/CLAUDE.md" ] && count=$((count + 1))
            ;;
        Auto)
            local slug
            slug=$(_mv_project_slug)
            local adir="${HOME}/.claude/projects/${slug}/memory"
            if [ -d "$adir" ]; then
                local f
                for f in "$adir"/*.md; do
                    [ -f "$f" ] && count=$((count + 1))
                done
            fi
            ;;
    esac
    echo "$count"
}

# Entry generator
hall_memory_entries() {

    _mv_file_stat() {
        if [ ! -f "$1" ]; then
            hall_ansi_dim "(missing)"
        else
            local n
            n=$(wc -l < "$1" 2>/dev/null | tr -d ' ')
            [ "$n" = "0" ] && hall_ansi_dim "(empty)" || hall_ansi_dim "($n lines)"
        fi
    }

    _mv_project_slug() {
        local p="$PWD"
        p="${p//\//-}"
        echo "${p//_/-}"
    }

    # ── Guide ────────────────────────────────────────────────

    printf '%s\t%s\n' \
        "$(hall_icon guide) $(hall_ansi_bold "Guide")" \
        "mv-info guide"

    # ── Editor preference ─────────────────────────────────────

    _hall_load_config
    local _mv_eds
    _mv_eds=$(hall_available_editors)
    local _mv_eds_arr=($_mv_eds)
    local _mv_cur_ed="$_PA_MEMORY_EDITOR"
    # Find next editor in cycle
    local _mv_next_ed="${_mv_eds_arr[0]}"
    local _mv_i
    for _mv_i in "${!_mv_eds_arr[@]}"; do
        if [ "${_mv_eds_arr[$_mv_i]}" = "$_mv_cur_ed" ]; then
            local _mv_next_i=$(( (_mv_i + 1) % ${#_mv_eds_arr[@]} ))
            _mv_next_ed="${_mv_eds_arr[$_mv_next_i]}"
            break
        fi
    done
    printf '%s\t%s\n' \
        "$(hall_ansi_bold "Editor"): $_mv_cur_ed $(hall_ansi_dim "→ $_mv_next_ed")" \
        "mv-toggle-editor"

    _mv_load_sections

    # ── Project Memory ───────────────────────────────────────

    if _mv_is_expanded "Project"; then
        printf '%s\t%s\n' "$(hall_ansi_dim "╭─") ▾ $(hall_ansi_bold "Project Memory") $(hall_ansi_dim "──")" "mv-section:Project"

        local _mv_fi
        _mv_fi=$(hall_icon file)
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $_mv_fi $(hall_ansi_bold "CLAUDE.md")  $(_mv_file_stat "./CLAUDE.md")" \
            "mv-open ./CLAUDE.md"

        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $_mv_fi $(hall_ansi_bold "CLAUDE.local.md")  $(_mv_file_stat "./CLAUDE.local.md")" \
            "mv-open ./CLAUDE.local.md"

        if [ -f "./.claude/CLAUDE.local.md" ]; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $_mv_fi $(hall_ansi_bold ".claude/CLAUDE.local.md")  $(_mv_file_stat "./.claude/CLAUDE.local.md")" \
                "mv-open ./.claude/CLAUDE.local.md"
        fi

        printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "mv-noop"
    else
        local _mv_pc
        _mv_pc=$(_mv_count_items "Project")
        printf '%s\t%s\n' "▸ Project Memory $(hall_ansi_dim "($_mv_pc items)")" "mv-section:Project"
    fi

    # ── User Memory ──────────────────────────────────────────

    if _mv_is_expanded "User"; then
        printf '%s\t%s\n' "$(hall_ansi_dim "╭─") ▾ $(hall_ansi_bold "User Memory") $(hall_ansi_dim "──")" "mv-section:User"

        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_icon file) $(hall_ansi_bold "CLAUDE.md")  $(_mv_file_stat "${HOME}/.claude/CLAUDE.md")" \
            "mv-open ${HOME}/.claude/CLAUDE.md"

        printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "mv-noop"
    else
        local _mv_uc
        _mv_uc=$(_mv_count_items "User")
        printf '%s\t%s\n' "▸ User Memory $(hall_ansi_dim "($_mv_uc items)")" "mv-section:User"
    fi

    # ── Auto Memory ──────────────────────────────────────────

    local _mv_slug
    _mv_slug=$(_mv_project_slug)
    local _mv_auto_dir="${HOME}/.claude/projects/${_mv_slug}/memory"

    if _mv_is_expanded "Auto"; then
        printf '%s\t%s\n' "$(hall_ansi_dim "╭─") ▾ $(hall_ansi_bold "Auto Memory") $(hall_ansi_dim "──")" "mv-section:Auto"

        if [ -d "$_mv_auto_dir" ]; then
            local _mv_main="${_mv_auto_dir}/MEMORY.md"
            local _mv_afi
            _mv_afi=$(hall_icon file)
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $_mv_afi $(hall_ansi_bold "MEMORY.md")  $(_mv_file_stat "$_mv_main")" \
                "mv-open $_mv_main"

            local _mv_topic
            for _mv_topic in "$_mv_auto_dir"/*.md; do
                [ -f "$_mv_topic" ] || continue
                local _mv_basename
                _mv_basename=$(basename "$_mv_topic")
                [ "$_mv_basename" = "MEMORY.md" ] && continue
                printf '%s\t%s\n' \
                    "$(hall_ansi_dim "│") $_mv_afi $(hall_ansi_bold "$_mv_basename")  $(_mv_file_stat "$_mv_topic")" \
                    "mv-open $_mv_topic"
            done
        else
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_dim "(none yet)")" \
                "mv-noop"
        fi

        printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "mv-noop"
    else
        local _mv_ac
        _mv_ac=$(_mv_count_items "Auto")
        printf '%s\t%s\n' "▸ Auto Memory $(hall_ansi_dim "($_mv_ac items)")" "mv-section:Auto"
    fi
}
