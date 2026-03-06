#!/usr/bin/env bash
# cc-config module — Claude Code settings toggles
# Built-in module for cc-hall
#
# 3-layer settings: Global, Shared (project), Local (project)
# Layer tabs replace collapsible sections. Left/right arrows switch layers.

source "${HALL_LIB_DIR}/hall-theme.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

# Metadata
HALL_MODULE_LABEL="Config"
HALL_MODULE_ORDER=25
HALL_MODULE_ICON="◉"
HALL_MODULE_PREVIEW_RENDERER="quick"

# Sub-tabs: Global, Shared, Local config layers
HALL_MODULE_SUBTABS=("Global" "Shared" "Local")

# Module-specific fzf options: none
HALL_MODULE_FZF_OPTS=()

# Module keybindings: none
HALL_MODULE_BINDINGS=()

# Entry generator
hall_cc_config_entries() {
    local _cv_layer
    _cv_layer=$(hall_get_subtab_index)

    # ── Layer → file mapping ──────────────────────────────────

    local _cv_sf _cv_cmd_flag _cv_cmd_val
    case "$_cv_layer" in
        0) _cv_sf="${HOME}/.claude/settings.json"
           _cv_cmd_flag="cv-flag"; _cv_cmd_val="cv-val" ;;
        1) _cv_sf=".claude/settings.json"
           _cv_cmd_flag="cv-sflag"; _cv_cmd_val="cv-sval" ;;
        2) _cv_sf=".claude/settings.local.json"
           _cv_cmd_flag="cv-pflag"; _cv_cmd_val="cv-pval" ;;
    esac

    # ── Helpers ──────────────────────────────────────────────

    _cv_on_off() {
        if [ "$1" = "true" ] || [ "$1" = "1" ] || [ "$1" = "on" ]; then
            printf '%s %s' "on" "$(hall_ansi_dim "→ off")"
        else
            printf '%s %s' "off" "$(hall_ansi_dim "→ on")"
        fi
    }

    _cv_three_state() {
        case "$1" in
            not_set) printf '%s %s' "$(hall_ansi_dim "inherited")" "$(hall_ansi_dim "→ on")" ;;
            on)      printf '%s %s' "on" "$(hall_ansi_dim "→ off")" ;;
            off)     printf '%s %s' "off" "$(hall_ansi_dim "→ inherited")" ;;
        esac
    }

    _cv_named_cycle() {
        local cur="$1"; shift
        local vals=("$@")
        if [ -z "$cur" ]; then
            printf '%s %s' "$(hall_ansi_dim "inherited")" "$(hall_ansi_dim "→ ${vals[0]}")"
            return
        fi
        local i next
        for i in "${!vals[@]}"; do
            if [ "${vals[$i]}" = "$cur" ]; then
                next=$(( (i + 1) % (${#vals[@]} + 1) ))
                if [ "$next" -ge "${#vals[@]}" ]; then
                    printf '%s %s' "$cur" "$(hall_ansi_dim "→ inherited")"
                else
                    printf '%s %s' "$cur" "$(hall_ansi_dim "→ ${vals[$next]}")"
                fi
                return
            fi
        done
        printf '%s %s' "$cur" "$(hall_ansi_dim "→ inherited")"
    }

    _cv_rbool() {
        local data="$1" key="$2" default="$3"
        if [[ "$data" =~ \"$key\"[[:space:]]*:[[:space:]]*(true|false) ]]; then
            echo "${BASH_REMATCH[1]}"
        else
            echo "$default"
        fi
    }

    _cv_rstr() {
        local data="$1" key="$2" default="$3"
        if [[ "$data" =~ \"$key\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
            echo "${BASH_REMATCH[1]}"
        else
            echo "$default"
        fi
    }

    _cv_env() {
        local data="$1" key="$2" default="$3"
        if [[ "$data" =~ \"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
            echo "${BASH_REMATCH[1]}"
        else
            echo "$default"
        fi
    }

    _cv_rbool_first() {
        local data="$1" default="$2"
        shift 2
        local key value sentinel="__hall_unset__"
        for key in "$@"; do
            value=$(_cv_rbool "$data" "$key" "$sentinel")
            [ "$value" != "$sentinel" ] && { echo "$value"; return; }
        done
        echo "$default"
    }

    _cv_rstr_first() {
        local data="$1" default="$2"
        shift 2
        local key value sentinel="__hall_unset__"
        for key in "$@"; do
            value=$(_cv_rstr "$data" "$key" "$sentinel")
            [ "$value" != "$sentinel" ] && { echo "$value"; return; }
        done
        echo "$default"
    }

    _cv_env_first() {
        local data="$1" default="$2"
        shift 2
        local key value sentinel="__hall_unset__"
        for key in "$@"; do
            value=$(_cv_env "$data" "$key" "$sentinel")
            [ "$value" != "$sentinel" ] && { echo "$value"; return; }
        done
        echo "$default"
    }

    _cv_tool_search_kind() {
        local raw="$1"
        if [ -z "$raw" ]; then
            echo "unset"
        elif [[ "$raw" == auto* ]]; then
            echo "auto"
        elif [ "$raw" = "true" ] || [ "$raw" = "1" ]; then
            echo "on"
        else
            echo "off"
        fi
    }

    _cv_tool_search_label() {
        local raw="$1"
        case "$(_cv_tool_search_kind "$raw")" in
            unset) printf '%s' "$(hall_ansi_dim "inherited")" ;;
            auto)  printf '%s' "${raw:-auto}" ;;
            on)    printf 'on' ;;
            off)   printf 'off' ;;
        esac
    }

    _cv_background_tasks_state() {
        local data="$1" cur compat
        cur=$(_cv_env "$data" "CLAUDE_CODE_DISABLE_BACKGROUND_TASKS" "__hall_unset__")
        compat=$(_cv_env "$data" "CLAUDE_CODE_ENABLE_BACKGROUND_TASKS" "__hall_unset__")
        if [ "$cur" != "__hall_unset__" ]; then
            [ "$cur" = "1" ] && echo "off" || echo "on"
        elif [ "$compat" != "__hall_unset__" ]; then
            [ "$compat" = "0" ] && echo "off" || echo "on"
        else
            echo "not_set"
        fi
    }

    _cv_task_tracking_state() {
        local data="$1" cur compat
        cur=$(_cv_env "$data" "CLAUDE_CODE_ENABLE_TASKS" "__hall_unset__")
        compat=$(_cv_env "$data" "DISABLE_TASKS" "__hall_unset__")
        if [ "$cur" != "__hall_unset__" ]; then
            [ "$cur" = "false" ] && echo "off" || echo "on"
        elif [ "$compat" != "__hall_unset__" ]; then
            [ "$compat" = "1" ] && echo "off" || echo "on"
        else
            echo "not_set"
        fi
    }

    # Group box drawing: ╭─ header, │ entries, ╰─ close
    _cv_group_open=false

    _cv_subheader() {
        # Close previous group if open
        if $_cv_group_open; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "╰─")" \
                "cv-noop"
        fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "╭─ $1 ──")" \
            "cv-noop"
        _cv_group_open=true
    }

    # Close the final group (called at end of entries)
    _cv_close_group() {
        if $_cv_group_open; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "╰─")" \
                "cv-noop"
            _cv_group_open=false
        fi
    }

    # ── Guide ────────────────────────────────────────────────

    printf '%s\t%s\n' \
        "$(hall_icon guide) $(hall_ansi_bold "Guide")" \
        "cv-info guide"

    # ── Read settings file ───────────────────────────────────

    local _cv_s=""
    [ -f "$_cv_sf" ] && _cv_s=$(<"$_cv_sf")

    local _cv_v _cv_st _cv_next

    # ── Display logic depends on layer type ──────────────────
    # Global (layer 0): binary toggles, direct values
    # Shared/Local (layers 1,2): 3-state (inherited → on → off → inherited)

    local _cv_is_project=false
    [ "$_cv_layer" -gt 0 ] && _cv_is_project=true

    # ── Thinking & Output ────────────────────────────────────

    _cv_subheader "Thinking & Output"

    # Always Thinking
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "alwaysThinkingEnabled" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Always Thinking"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag alwaysThinkingEnabled"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "alwaysThinkingEnabled" "false")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Always Thinking"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag alwaysThinkingEnabled"
    fi

    # Effort Level (named cycle) — all layers
    if $_cv_is_project; then
        _cv_v=$(_cv_rstr "$_cv_s" "effortLevel" "")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Effort Level"): $(_cv_named_cycle "$_cv_v" "low" "medium" "high")" \
            "$_cv_cmd_val effortLevel"
    else
        _cv_v=$(_cv_rstr "$_cv_s" "effortLevel" "")
        case "${_cv_v:-}" in
            low)    _cv_next="medium" ;;
            medium) _cv_next="high" ;;
            high)   _cv_next="low" ;;
            *)      _cv_v=""; _cv_next="low" ;;
        esac
        if [ -z "$_cv_v" ]; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Effort Level"): $(hall_ansi_dim "default") $(hall_ansi_dim "→ low")" \
                "cv-val effortLevel"
        else
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Effort Level"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
                "cv-val effortLevel"
        fi
    fi

    # 1M Context
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_1M_CONTEXT" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "1M Context"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_1M_CONTEXT"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_1M_CONTEXT" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "1M Context"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_1M_CONTEXT"
    fi

    # Simple Mode
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_SIMPLE" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Simple Mode"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_SIMPLE"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_SIMPLE" "")
        [ "$_cv_v" = "1" ] && _cv_v="on" || _cv_v="off"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Simple Mode"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_SIMPLE"
    fi

    # Thinking
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_THINKING" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Thinking"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_THINKING"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_THINKING" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Thinking"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_THINKING"
    fi

    # Adaptive Thinking
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Adaptive Thinking"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Adaptive Thinking"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING"
    fi

    # Fast Mode
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "fastMode" "")
        if [ -z "$_cv_v" ]; then
            _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_FAST_MODE" "")
            if [ -z "$_cv_v" ]; then _cv_st="not_set"
            elif [ "$_cv_v" = "1" ]; then _cv_st="off"
            else _cv_st="on"; fi
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Fast Mode"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag fastMode"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "fastMode" "")
        if [ -z "$_cv_v" ]; then
            _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_FAST_MODE" "")
            [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        else
            [ "$_cv_v" = "false" ] && _cv_v="off" || _cv_v="on"
        fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Fast Mode"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag fastMode"
    fi

    # Model (named cycle) — all layers
    if $_cv_is_project; then
        _cv_v=$(_cv_rstr "$_cv_s" "model" "")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Model"): $(_cv_named_cycle "$_cv_v" "haiku" "sonnet" "opus")" \
            "$_cv_cmd_val model"
    else
        _cv_v=$(_cv_rstr "$_cv_s" "model" "")
        case "${_cv_v:-}" in
            haiku)  _cv_next="sonnet" ;;
            sonnet) _cv_next="opus" ;;
            opus)   _cv_next="haiku" ;;
            *)      _cv_v=""; _cv_next="haiku" ;;
        esac
        if [ -z "$_cv_v" ]; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Model"): $(hall_ansi_dim "default") $(hall_ansi_dim "→ haiku")" \
                "cv-val model"
        else
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Model"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
                "cv-val model"
        fi
    fi

    # Output Style (named cycle) — all layers
    if $_cv_is_project; then
        _cv_v=$(_cv_rstr "$_cv_s" "outputStyle" "")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Output Style"): $(_cv_named_cycle "$_cv_v" "concise" "explanatory" "learning")" \
            "$_cv_cmd_val outputStyle"
    else
        _cv_v=$(_cv_rstr "$_cv_s" "outputStyle" "")
        case "${_cv_v:-}" in
            concise)      _cv_next="explanatory" ;;
            explanatory)  _cv_next="learning" ;;
            learning)     _cv_next="concise" ;;
            *)            _cv_v=""; _cv_next="concise" ;;
        esac
        if [ -z "$_cv_v" ]; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Output Style"): $(hall_ansi_dim "default") $(hall_ansi_dim "→ concise")" \
                "cv-val outputStyle"
        else
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Output Style"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
                "cv-val outputStyle"
        fi
    fi

    # ── Capabilities ─────────────────────────────────────────

    _cv_subheader "Capabilities"

    # Agent Teams
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Agent Teams"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "")
        [ "$_cv_v" = "1" ] && _cv_v="on" || _cv_v="off"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Agent Teams"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
    fi

    # Subagent Model (named cycle) — env var
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_SUBAGENT_MODEL" "")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Subagent Model"): $(_cv_named_cycle "$_cv_v" "haiku" "sonnet" "opus")" \
            "$_cv_cmd_flag CLAUDE_CODE_SUBAGENT_MODEL"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_SUBAGENT_MODEL" "")
        case "${_cv_v:-}" in
            haiku)  _cv_next="sonnet" ;;
            sonnet) _cv_next="opus" ;;
            opus)   _cv_next="haiku" ;;
            *)      _cv_v=""; _cv_next="haiku" ;;
        esac
        if [ -z "$_cv_v" ]; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Subagent Model"): $(hall_ansi_dim "default") $(hall_ansi_dim "→ haiku")" \
                "cv-flag CLAUDE_CODE_SUBAGENT_MODEL"
        else
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Subagent Model"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
                "cv-flag CLAUDE_CODE_SUBAGENT_MODEL"
        fi
    fi

    # Tool Search
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "ENABLE_TOOL_SEARCH" "")
        case "$(_cv_tool_search_kind "$_cv_v")" in
            unset) _cv_next="auto" ;;
            auto)  _cv_next="on" ;;
            on)    _cv_next="off" ;;
            off)   _cv_next="inherited" ;;
        esac
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Tool Search"): $(_cv_tool_search_label "$_cv_v") $(hall_ansi_dim "→ $_cv_next")" \
            "$_cv_cmd_flag ENABLE_TOOL_SEARCH"
    else
        _cv_v=$(_cv_env "$_cv_s" "ENABLE_TOOL_SEARCH" "")
        case "$(_cv_tool_search_kind "$_cv_v")" in
            auto) _cv_v="${_cv_v:-auto}"; _cv_next="on" ;;
            on)   _cv_v="on"; _cv_next="off" ;;
            off)  _cv_v="off"; _cv_next="auto" ;;
            *)    _cv_v="auto"; _cv_next="on" ;;
        esac
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Tool Search"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
            "$_cv_cmd_flag ENABLE_TOOL_SEARCH"
    fi

    # Background Tasks
    if $_cv_is_project; then
        _cv_st=$(_cv_background_tasks_state "$_cv_s")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Background Tasks"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS"
    else
        _cv_st=$(_cv_background_tasks_state "$_cv_s")
        [ "$_cv_st" = "off" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Background Tasks"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_BACKGROUND_TASKS"
    fi

    # Task Tracking
    if $_cv_is_project; then
        _cv_st=$(_cv_task_tracking_state "$_cv_s")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Task Tracking"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_ENABLE_TASKS"
    else
        _cv_st=$(_cv_task_tracking_state "$_cv_s")
        [ "$_cv_st" = "off" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Task Tracking"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_ENABLE_TASKS"
    fi

    # ── Context & Privacy ────────────────────────────────────

    _cv_subheader "Context & Privacy"

    # CLAUDE.md files
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_CLAUDE_MDS" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "CLAUDE.md Files"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_CLAUDE_MDS"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_CLAUDE_MDS" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "CLAUDE.md Files"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_CLAUDE_MDS"
    fi

    # Respect Gitignore
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "respectGitignore" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Respect Gitignore"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag respectGitignore"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "respectGitignore" "true")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Respect Gitignore"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag respectGitignore"
    fi

    # Auto Memory
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "autoMemoryEnabled" "")
        if [ -z "$_cv_v" ]; then
            _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_AUTO_MEMORY" "")
            if [ -z "$_cv_v" ]; then _cv_st="not_set"
            elif [ "$_cv_v" = "1" ]; then _cv_st="off"
            else _cv_st="on"; fi
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Memory"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag autoMemoryEnabled"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "autoMemoryEnabled" "")
        if [ -z "$_cv_v" ]; then
            _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_AUTO_MEMORY" "")
            [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        else
            [ "$_cv_v" = "false" ] && _cv_v="off" || _cv_v="on"
        fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Memory"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag autoMemoryEnabled"
    fi

    # Prompt Caching
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "DISABLE_PROMPT_CACHING" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Prompt Caching"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag DISABLE_PROMPT_CACHING"
    else
        _cv_v=$(_cv_env "$_cv_s" "DISABLE_PROMPT_CACHING" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Prompt Caching"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag DISABLE_PROMPT_CACHING"
    fi

    # Auto Compact
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "DISABLE_AUTO_COMPACT" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Compact"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag DISABLE_AUTO_COMPACT"
    else
        _cv_v=$(_cv_env "$_cv_s" "DISABLE_AUTO_COMPACT" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Compact"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag DISABLE_AUTO_COMPACT"
    fi

    # Compact
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "DISABLE_COMPACT" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Compact"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag DISABLE_COMPACT"
    else
        _cv_v=$(_cv_env "$_cv_s" "DISABLE_COMPACT" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Compact"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag DISABLE_COMPACT"
    fi

    # Telemetry
    if $_cv_is_project; then
        _cv_v=$(_cv_env_first "$_cv_s" "" "DISABLE_TELEMETRY" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Telemetry"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag DISABLE_TELEMETRY"
    else
        _cv_v=$(_cv_env_first "$_cv_s" "" "DISABLE_TELEMETRY" "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Telemetry"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag DISABLE_TELEMETRY"
    fi

    # ── UI ───────────────────────────────────────────────────

    _cv_subheader "UI"

    # Spinner Tips
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "spinnerTipsEnabled" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Spinner Tips"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag spinnerTipsEnabled"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "spinnerTipsEnabled" "true")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Spinner Tips"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag spinnerTipsEnabled"
    fi

    # Show Turn Duration — NEW
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "showTurnDuration" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Turn Duration"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag showTurnDuration"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "showTurnDuration" "true")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Turn Duration"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag showTurnDuration"
    fi

    # Terminal Title (DISABLE_TERMINAL_TITLE) — NEW
    if $_cv_is_project; then
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_TERMINAL_TITLE" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "1" ]; then _cv_st="off"
        else _cv_st="on"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Terminal Title"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_TERMINAL_TITLE"
    else
        _cv_v=$(_cv_env "$_cv_s" "CLAUDE_CODE_DISABLE_TERMINAL_TITLE" "")
        [ "$_cv_v" = "1" ] && _cv_v="off" || _cv_v="on"
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Terminal Title"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag CLAUDE_CODE_DISABLE_TERMINAL_TITLE"
    fi

    # Progress Bar
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "terminalProgressBarEnabled" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Progress Bar"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag terminalProgressBarEnabled"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "terminalProgressBarEnabled" "true")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Progress Bar"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag terminalProgressBarEnabled"
    fi

    # Reduced Motion
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "prefersReducedMotion" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Reduced Motion"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag prefersReducedMotion"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "prefersReducedMotion" "false")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Reduced Motion"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag prefersReducedMotion"
    fi

    # ── Permissions & Updates ────────────────────────────────

    _cv_subheader "Permissions & Updates"

    # Skip Perm Prompt
    if $_cv_is_project; then
        _cv_v=$(_cv_rbool "$_cv_s" "skipDangerousModePermissionPrompt" "")
        if [ -z "$_cv_v" ]; then _cv_st="not_set"
        elif [ "$_cv_v" = "true" ]; then _cv_st="on"
        else _cv_st="off"; fi
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Skip Perm Prompt"): $(_cv_three_state "$_cv_st")" \
            "$_cv_cmd_flag skipDangerousModePermissionPrompt"
    else
        _cv_v=$(_cv_rbool "$_cv_s" "skipDangerousModePermissionPrompt" "false")
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Skip Perm Prompt"): $(_cv_on_off "$_cv_v")" \
            "$_cv_cmd_flag skipDangerousModePermissionPrompt"
    fi

    # Auto Updates Channel
    if $_cv_is_project; then
        _cv_v=$(_cv_rstr "$_cv_s" "autoUpdatesChannel" "")
        [ "$_cv_v" = "beta" ] && _cv_v="latest"
        if [ -z "$_cv_v" ]; then
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Updates"): $(hall_ansi_dim "inherited") $(hall_ansi_dim "→ latest")" \
                "$_cv_cmd_flag autoUpdatesChannel"
        else
            [ "$_cv_v" = "stable" ] && _cv_next="inherited" || _cv_next="stable"
            printf '%s\t%s\n' \
                "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Updates"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
                "$_cv_cmd_flag autoUpdatesChannel"
        fi
    else
        _cv_v=$(_cv_rstr_first "$_cv_s" "" "autoUpdatesChannel")
        case "${_cv_v:-latest}" in
            stable) _cv_v="stable"; _cv_next="latest" ;;
            beta)   _cv_v="latest"; _cv_next="stable" ;;
            *)      _cv_v="latest"; _cv_next="stable" ;;
        esac
        printf '%s\t%s\n' \
            "$(hall_ansi_dim "│") $(hall_ansi_bold "Auto Updates"): $_cv_v $(hall_ansi_dim "→ $_cv_next")" \
            "$_cv_cmd_flag autoUpdatesChannel"
    fi

    _cv_close_group
}
