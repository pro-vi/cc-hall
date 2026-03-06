#!/usr/bin/env bash
# hall-cmd-agent.sh — cc-hall agent
# Host-owned agent dispatch. Modules call this instead of sourcing hall-agent.sh.
#
# Usage:
#   cc-hall agent --mode auto|interactive \
#       --system-prompt-file FILE \
#       [--prompt TEXT] \
#       [--model MODEL] \
#       [--skip-permissions] \
#       [--cleanup FILE ...] \
#       [--window-name NAME] \
#       [--env KEY=VAL ...]

HALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HALL_DIR="$(cd "$HALL_LIB_DIR/.." && pwd)"

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-agent.sh"

# Parse arguments
_mode=""
_system_prompt_file=""
_prompt=""
_model="sonnet"
_skip_permissions=false
_window_name="agent"
_message=""
_verbose=false
_wait_after=false
declare -a _env_args=()
declare -a _cleanup_args=()

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)               _mode="$2"; shift 2 ;;
        --system-prompt-file) _system_prompt_file="$2"; shift 2 ;;
        --prompt)             _prompt="$2"; shift 2 ;;
        --model)              _model="$2"; shift 2 ;;
        --skip-permissions)   _skip_permissions=true; shift ;;
        --window-name)        _window_name="$2"; shift 2 ;;
        --env)                _env_args+=("$2"); shift 2 ;;
        --cleanup)            _cleanup_args+=("$2"); shift 2 ;;
        --message)            _message="$2"; shift 2 ;;
        --verbose)            _verbose=true; shift ;;
        --wait-after)         _wait_after=true; shift ;;
        *) echo "cc-hall agent: unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$_mode" ]; then
    echo "cc-hall agent: --mode required (auto|interactive)" >&2
    exit 1
fi

if [ -z "$_system_prompt_file" ]; then
    echo "cc-hall agent: --system-prompt-file required" >&2
    exit 1
fi

case "$_mode" in
    interactive)
        if hall_in_tmux; then
            # Build args array
            declare -a spawn_args=(--system-prompt-file "$_system_prompt_file" --model "$_model" --window-name "$_window_name")
            [ "$_skip_permissions" = true ] && spawn_args+=(--skip-permissions)
            [ -n "$_message" ] && spawn_args+=(--message "$_message")
            for e in "${_env_args[@]}"; do spawn_args+=(--env "$e"); done
            for c in "${_cleanup_args[@]}"; do spawn_args+=(--cleanup "$c"); done
            hall_spawn_agent "${spawn_args[@]}"
        else
            echo "Error: Interactive mode requires tmux. Use --mode auto or start tmux." >&2
            exit 1
        fi
        ;;
    auto)
        if hall_in_tmux; then
            declare -a auto_args=(--system-prompt-file "$_system_prompt_file" --model "$_model" --window-name "$_window_name")
            [ -n "$_prompt" ] && auto_args+=(--prompt "$_prompt")
            [ "$_skip_permissions" = true ] && auto_args+=(--skip-permissions)
            for e in "${_env_args[@]}"; do auto_args+=(--env "$e"); done
            for c in "${_cleanup_args[@]}"; do auto_args+=(--cleanup "$c"); done
            hall_spawn_agent_auto "${auto_args[@]}"
        else
            # No tmux — run blocking in current terminal
            declare -a run_args=(--model "$_model")
            [ -n "$_system_prompt_file" ] && run_args+=(--system-prompt-file "$_system_prompt_file")
            [ -n "$_prompt" ] && run_args+=(--prompt "$_prompt")
            [ "$_skip_permissions" = true ] && run_args+=(--skip-permissions)
            [ "$_verbose" = true ] && run_args+=(--verbose)
            [ "$_wait_after" = true ] && run_args+=(--wait-after)
            for e in "${_env_args[@]}"; do run_args+=(--env "$e"); done
            hall_run_agent "${run_args[@]}"
            # hall_run_agent is blocking — clean up files that tmux path would handle via --cleanup
            for c in "${_cleanup_args[@]}"; do rm -f "$c"; done
        fi
        ;;
    *)
        echo "cc-hall agent: unknown mode '$_mode' (expected auto|interactive)" >&2
        exit 1
        ;;
esac
