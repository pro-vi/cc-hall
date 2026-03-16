#!/usr/bin/env bash
# Command handler for cc-config module
# Args: $1 = raw command (after \x1f split), $2 = prompt file path

set -e

source "${HALL_LIB_DIR}/hall-common.sh"
source "${HALL_LIB_DIR}/hall-config.sh"

CMD="$1"
FILE="$2"

# ── Flag routing: resolve file + mode from command prefix ─────

_cv_route_flag() {
    local prefix="$1" flag="$2"
    local file mode

    case "$prefix" in
        cv-flag)  file="${HOME}/.claude/settings.json"; mode="binary" ;;
        cv-sflag) file=".claude/settings.json"; mode="three_state" ;;
        cv-pflag) file=".claude/settings.local.json"; mode="three_state" ;;
    esac

    case "$flag" in
        # Root-level booleans (default false)
        alwaysThinkingEnabled|skipDangerousModePermissionPrompt|prefersReducedMotion)
            hall_config_toggle_bool "$file" "$flag" "false" "$mode" ;;

        # Root-level booleans (default true)
        spinnerTipsEnabled|respectGitignore|showTurnDuration|terminalProgressBarEnabled)
            hall_config_toggle_bool "$file" "$flag" "true" "$mode" ;;

        # Root-level booleans (default true, canonical settings keys with
        # legacy env compatibility)
        autoMemoryEnabled)
            hall_config_toggle_auto_memory "$file" "$mode" ;;
        fastMode)
            hall_config_toggle_fast_mode "$file" "$mode" ;;

        # Auto updates channel
        autoUpdatesChannel)
            hall_config_toggle_updates_channel "$file" "$mode" ;;

        # Env vars: "1" / absent
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS|CLAUDE_CODE_SIMPLE)
            hall_config_toggle_env_1 "$file" "$flag" "$mode" ;;

        # Subagent Model: env var named cycle
        CLAUDE_CODE_SUBAGENT_MODEL)
            hall_config_toggle_env_named_cycle "$file" "$flag" "$mode" "haiku" "sonnet" "opus" ;;

        # Tool Search: auto/true/false
        ENABLE_TOOL_SEARCH)
            hall_config_toggle_tool_search "$file" "$mode" ;;

        # Background Tasks: canonical disable flag with compatibility cleanup
        CLAUDE_CODE_DISABLE_BACKGROUND_TASKS)
            hall_config_toggle_background_tasks "$file" "$mode" ;;

        # Task Tracking: canonical enable flag with compatibility cleanup
        CLAUDE_CODE_ENABLE_TASKS)
            hall_config_toggle_task_tracking "$file" "$mode" ;;

        # Inverted DISABLE flags
        CLAUDE_CODE_DISABLE_1M_CONTEXT|DISABLE_PROMPT_CACHING|\
CLAUDE_CODE_DISABLE_THINKING|CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING|\
DISABLE_AUTO_COMPACT|DISABLE_COMPACT|CLAUDE_CODE_DISABLE_CLAUDE_MDS|\
CLAUDE_CODE_DISABLE_TERMINAL_TITLE)
            hall_config_toggle_env_disable "$file" "$flag" "$mode" ;;

    esac
}

# ── Val routing: resolve file + mode from command prefix ──────

_cv_route_val() {
    local prefix="$1" key="$2"
    local file mode

    case "$prefix" in
        cv-val)  file="${HOME}/.claude/settings.json"; mode="binary" ;;
        cv-sval) file=".claude/settings.json"; mode="three_state" ;;
        cv-pval) file=".claude/settings.local.json"; mode="three_state" ;;
    esac

    case "$key" in
        model)       hall_config_toggle_named_cycle "$file" "$key" "$mode" "haiku" "sonnet" "opus" ;;
        effortLevel) hall_config_toggle_effort_level "$file" "$mode" ;;
        outputStyle) hall_config_toggle_named_cycle "$file" "$key" "$mode" "concise" "explanatory" "learning" ;;
    esac
}

# ── Command routing ──────────────────────────────────────────

case "$CMD" in
    cv-flag\ *|cv-sflag\ *|cv-pflag\ *)
        _cv_prefix="${CMD%% *}"
        _cv_flag="${CMD#* }"
        _cv_route_flag "$_cv_prefix" "$_cv_flag" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;

    cv-val\ *|cv-sval\ *|cv-pval\ *)
        _cv_prefix="${CMD%% *}"
        _cv_key="${CMD#* }"
        _cv_route_val "$_cv_prefix" "$_cv_key" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;

    cv-noop)
        exit $HALL_RC_RELOAD ;;

    cv-info\ *)
        exit $HALL_RC_RELOAD ;;
esac

exit $HALL_RC_NOT_HANDLED
