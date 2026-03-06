#!/usr/bin/env bash
# Command handler for editor module (Prompt Agent entries)
# Args: $1 = raw command (after \x1f split), $2 = prompt file path
# Falls through (exit 1) for editor commands — handled by built-in pattern.

set -e

_HANDLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

source "${HALL_LIB_DIR}/hall-common.sh"
source "${HALL_LIB_DIR}/hall-agent.sh"
source "${HALL_LIB_DIR}/hall-config.sh"
source "$_HANDLER_DIR/prompt.sh"

CMD="$1"
FILE="$2"

_hall_load_config

# ── Config toggle helpers ────────────────────────────────────

_hall_toggle_config() {
    local key="$1"; shift
    local -a values=("$@")

    _hall_load_config
    local current
    case "$key" in
        model) current="$_PA_MODEL" ;;
    esac

    local next="${values[0]}"
    for i in "${!values[@]}"; do
        if [ "${values[$i]}" = "$current" ]; then
            local next_idx=$(( (i + 1) % ${#values[@]} ))
            next="${values[$next_idx]}"
            break
        fi
    done

    hall_config_set_string "$HALL_CONFIG_FILE" "$key" "$next"
}

_hall_toggle_bool() {
    local key="$1"
    hall_config_toggle_bool "$HALL_CONFIG_FILE" "$key" "false" "binary"
}

# Build a tmux command string for claude (defers $(cat) to tmux shell)
_hall_pa_tmux_cmd() {
    local mode="$1"
    local cmd="env FILE=$(printf '%q' "$FILE") claude --model $(printf '%q' "$_PA_MODEL")"
    if [ "$mode" = "interactive" ]; then
        [ "$_PA_SKIP_PERMS" = "true" ] && cmd="$cmd --dangerously-skip-permissions"
    else
        cmd="$cmd --dangerously-skip-permissions"
        cmd="$cmd -p $(printf '%q' "Begin enhancement")"
    fi
    cmd="$cmd --append-system-prompt \"\$(cat $(printf '%q' "$PROMPT_FILE"))\""
    cmd="$cmd ; rm -f $(printf '%q' "$PROMPT_FILE")"
    printf '%s' "$cmd"
}

case "$CMD" in
    ed-noop|ed-info\ *)
        exit $HALL_RC_RELOAD ;;
    prompt-agent-interactive)
        PROMPT_FILE=$(hall_mktemp "prompt-agent")
        hall_build_prompt_agent_system interactive "$FILE" > "$PROMPT_FILE"
        if [ "$_PA_TMUX_MODE" = "true" ]; then
            if hall_in_tmux; then
                hall_spawn_agent \
                    --system-prompt-file "$PROMPT_FILE" \
                    --model "$_PA_MODEL" \
                    $([ "$_PA_SKIP_PERMS" = "true" ] && echo "--skip-permissions") \
                    --window-name "prompt-agent" \
                    --env "FILE=$FILE" \
                    --cleanup "$PROMPT_FILE" \
                    --message "Begin enhancement"
                exit 0
            else
                session_name="prompt-agent-$$"
                cmd=$(_hall_pa_tmux_cmd interactive)
                tmux new-session -d -s "$session_name" bash -c "$cmd"
                _hall_apply_tmux_session_style "$session_name"
                sleep 1
                tmux send-keys -t "$session_name" "Begin enhancement"
                exec tmux attach -t "$session_name"
            fi
        else
            _sys_prompt="$(cat "$PROMPT_FILE")"
            rm -f "$PROMPT_FILE" 2>/dev/null
            exec env FILE="$FILE" claude \
                --model "$_PA_MODEL" \
                $([ "$_PA_SKIP_PERMS" = "true" ] && echo "--dangerously-skip-permissions") \
                --append-system-prompt "$_sys_prompt"
        fi
        ;;
    prompt-agent-auto)
        PROMPT_FILE=$(hall_mktemp "prompt-agent")
        hall_build_prompt_agent_system auto "$FILE" > "$PROMPT_FILE"
        if [ "$_PA_TMUX_MODE" = "true" ]; then
            if hall_in_tmux; then
                hall_spawn_agent_auto \
                    --system-prompt-file "$PROMPT_FILE" \
                    --prompt "Begin enhancement" \
                    --model "$_PA_MODEL" \
                    --skip-permissions \
                    --window-name "prompt-agent" \
                    --env "FILE=$FILE" \
                    --cleanup "$PROMPT_FILE"
            else
                session_name="prompt-agent-$$"
                tmux new-session -d -s "$session_name" bash -c "$(_hall_pa_tmux_cmd auto)"
                _hall_apply_tmux_session_style "$session_name"
                exec tmux attach -t "$session_name"
            fi
        else
            hall_run_agent \
                --system-prompt-file "$PROMPT_FILE" \
                --prompt "Begin enhancement" \
                --model "$_PA_MODEL" \
                --skip-permissions \
                --verbose \
                --env "FILE=$FILE"
            rm -f "$PROMPT_FILE" 2>/dev/null
        fi
        exit 0 ;;
    pa-toggle-model)
        _hall_toggle_config "model" "opus" "sonnet" "haiku" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;
    pa-toggle-permissions)
        _hall_toggle_bool "skip_permissions" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;
    pa-toggle-tmux)
        _hall_toggle_bool "tmux_mode" || exit $HALL_RC_RELOAD
        exit $HALL_RC_RELOAD ;;
esac

exit $HALL_RC_NOT_HANDLED   # fall through to built-in editor pattern
