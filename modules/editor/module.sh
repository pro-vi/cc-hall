#!/usr/bin/env bash
# editor module — Prompt editors and Prompt Agent
# Built-in module for cc-hall

source "${HALL_LIB_DIR}/hall-theme.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

# Metadata
HALL_MODULE_LABEL="Editor"
HALL_MODULE_ORDER=10
HALL_MODULE_ICON="◇"
HALL_MODULE_LOCKED=1
HALL_MODULE_PREVIEW_RENDERER="quick"

# Entry generator
hall_editor_entries() {
    local safe_file="${HALL_SAFE_FILE:-}"
    local icon=""

    printf '%s\t%s\n' \
        "$(hall_icon guide) $(hall_ansi_bold "Guide")" \
        "ed-info guide"

    printf '%s\t%s\n' "$(hall_ansi_dim "╭─ Prompt Editor ──")" "ed-noop"

    # Vim (always available)
    icon=$(hall_get_editor_icon "vim")
    if [ -n "$icon" ]; then
        printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold Vim)" "vi $safe_file"
    else
        printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold Vim)" "vi $safe_file"
    fi

    # Neovim
    if command -v nvim &>/dev/null; then
        icon=$(hall_get_editor_icon "neovim")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold Neovim)" "nvim $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold Neovim)" "nvim $safe_file"
        fi
    fi

    # VS Code
    if command -v code &>/dev/null; then
        icon=$(hall_get_editor_icon "vscode")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold "VS Code")" "code -w $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold "VS Code")" "code -w $safe_file"
        fi
    fi

    # Cursor
    if command -v cursor &>/dev/null; then
        icon=$(hall_get_editor_icon "cursor")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold Cursor)" "cursor -w $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold Cursor)" "cursor -w $safe_file"
        fi
    fi

    # Windsurf
    if command -v windsurf &>/dev/null; then
        icon=$(hall_get_editor_icon "windsurf")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold Windsurf)" "windsurf -w $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold Windsurf)" "windsurf -w $safe_file"
        fi
    fi

    # Zed
    if command -v zed &>/dev/null; then
        icon=$(hall_get_editor_icon "zed")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold Zed)" "zed --wait $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold Zed)" "zed --wait $safe_file"
        fi
    fi

    # Sublime Text
    if command -v subl &>/dev/null; then
        icon=$(hall_get_editor_icon "sublime")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold "Sublime Text")" "subl -w $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold "Sublime Text")" "subl -w $safe_file"
        fi
    fi

    # Antigravity
    if command -v agy &>/dev/null; then
        icon=$(hall_get_editor_icon "antigravity")
        if [ -n "$icon" ]; then
            printf '%s\t%s\n' "$(hall_ansi_dim "│") $icon Edit with $(hall_ansi_bold Antigravity)" "agy -w $safe_file"
        else
            printf '%s\t%s\n' "$(hall_ansi_dim "│") Edit with $(hall_ansi_bold Antigravity)" "agy -w $safe_file"
        fi
    fi

    printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "ed-noop"

    # ── Prompt Agent ─────────────────────────────────────────
    _hall_load_config

    printf '%s\t%s\n' "$(hall_ansi_dim "╭─ Prompt Agent ──")" "ed-noop"
    printf '%s\t%s\n' \
        "$(hall_ansi_dim "│") $(hall_ansi_bold 'Prompt Agent') $(hall_ansi_dim Interactive)" \
        "prompt-agent-interactive"
    printf '%s\t%s\n' \
        "$(hall_ansi_dim "│") $(hall_ansi_bold 'Prompt Agent') $(hall_ansi_dim Auto)" \
        "prompt-agent-auto"
    printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "ed-noop"

    # ── Agent Settings ────────────────────────────────────────
    printf '%s\t%s\n' "$(hall_ansi_dim "╭─ Agent Settings ──")" "ed-noop"

    # Model
    local current_model next_model
    case "$_PA_MODEL" in
        opus)   current_model="Opus";   next_model="Sonnet" ;;
        sonnet) current_model="Sonnet"; next_model="Haiku"  ;;
        haiku)  current_model="Haiku";  next_model="Opus"   ;;
        *)      current_model="Sonnet"; next_model="Haiku"  ;;
    esac
    printf '%s\t%s\n' \
        "$(hall_ansi_dim "│") Model: $current_model $(hall_ansi_dim "→ $next_model")" \
        "pa-toggle-model"

    # Permissions
    local perm_status perm_next
    if [ "$_PA_SKIP_PERMS" = "true" ]; then
        perm_status="On"; perm_next="Off"
    else
        perm_status="Off"; perm_next="On"
    fi
    printf '%s\t%s\n' \
        "$(hall_ansi_dim "│") Skip perms: $perm_status $(hall_ansi_dim "→ $perm_next")" \
        "pa-toggle-permissions"

    # Tmux mode
    local tmux_status tmux_next
    if [ "$_PA_TMUX_MODE" = "true" ]; then
        tmux_status="On"; tmux_next="Off"
    else
        tmux_status="Off"; tmux_next="On"
    fi
    printf '%s\t%s\n' \
        "$(hall_ansi_dim "│") Tmux: $tmux_status $(hall_ansi_dim "→ $tmux_next")" \
        "pa-toggle-tmux"

    printf '%s\t%s\n' "$(hall_ansi_dim "╰─")" "ed-noop"
}
