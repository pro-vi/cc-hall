#!/usr/bin/env bash
# hall-agent.sh — Tmux agent spawning primitive for cc-hall modules
#
# Encapsulates ORIGINAL_TMUX vs TMUX branching so modules only declare
# *what* to tell the agent, not *how* to spawn it.
#
# Sources hall-common.sh for logging, mktemp, validation.
# Pure bash, no external deps beyond tmux and claude CLI.

[ -n "${_HALL_AGENT_LOADED:-}" ] && return 0
_HALL_AGENT_LOADED=1

if [ -z "${HALL_LIB_DIR:-}" ]; then
    HALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-theme.sh"

HALL_AGENT_LOG_DIR="${HOME}/.claude/hall/logs"
mkdir -p "$HALL_AGENT_LOG_DIR" 2>/dev/null || true

# ── Tmux detection (public) ───────────────────────────────────────

# Check if running in tmux
# Usage: if hall_in_tmux; then ...; fi
hall_in_tmux() {
    [ -n "${TMUX:-}" ] || [ -n "${ORIGINAL_TMUX:-}" ]
}

# Validate tmux session exists (socket is alive)
# Usage: if hall_validate_tmux_session "$TMUX"; then ...; fi
hall_validate_tmux_session() {
    local session_socket="$1"

    if [ -z "$session_socket" ]; then
        return 1
    fi

    # Extract socket path from TMUX format: /path,PID,INDEX
    local socket_path="${session_socket%%,*}"

    if [ -S "$socket_path" ]; then
        return 0
    else
        hall_log_warn "Tmux socket not found: $socket_path"
        return 1
    fi
}

# ── Internal helpers ──────────────────────────────────────────────

# TMUX resolution: ORIGINAL_TMUX → TMUX → fail
# Sets HALL_TMUX_TARGET
_hall_resolve_tmux() {
    if [ -n "${ORIGINAL_TMUX:-}" ]; then
        HALL_TMUX_TARGET="$ORIGINAL_TMUX"
    elif [ -n "${TMUX:-}" ]; then
        HALL_TMUX_TARGET="$TMUX"
    else
        hall_log_error "No tmux session (ORIGINAL_TMUX and TMUX both empty)"
        return 1
    fi
}

# Run tmux with resolved target
_hall_tmux_cmd() {
    TMUX="${HALL_TMUX_TARGET}" tmux "$@"
}

# Build claude command string for tmux send-keys
# Reads caller's locals via dynamic scoping:
#   _model, _skip_permissions, _verbose, _prompt,
#   _system_prompt_file, _env_vars[], _cleanup_files[]
_hall_build_claude_cmd() {
    local cmd=""

    # Env var prefix (quote values for paths with spaces)
    if [ ${#_env_vars[@]} -gt 0 ]; then
        local _v _k _vv
        for _v in "${_env_vars[@]}"; do
            _k="${_v%%=*}"
            _vv="${_v#*=}"
            cmd="${cmd}${_k}=$(printf '%q' "$_vv") "
        done
    fi

    cmd="${cmd}claude"
    [ -n "${_model:-}" ] && cmd="$cmd --model $_model"
    [ "${_skip_permissions:-}" = true ] && cmd="$cmd --dangerously-skip-permissions"
    [ "${_verbose:-}" = true ] && cmd="$cmd --verbose"

    # -p prompt (auto/run modes)
    [ -n "${_prompt:-}" ] && cmd="$cmd -p $(printf '%q' "$_prompt")"

    # System prompt file — $(cat) deferred to expand in tmux shell, not ours
    [ -n "${_system_prompt_file:-}" ] && \
        cmd="$cmd --append-system-prompt \"\$(cat $(printf '%q' "$_system_prompt_file"))\""

    # Post-exit cleanup (rm runs after claude exits)
    if [ ${#_cleanup_files[@]} -gt 0 ]; then
        cmd="$cmd && rm -f"
        local _f
        for _f in "${_cleanup_files[@]}"; do
            cmd="$cmd $(printf '%q' "$_f")"
        done
    fi

    printf '%s' "$cmd"
}

# Lightweight lifecycle tracking
_hall_register_agent() {
    local type="$1" window="$2" module="${3:-unknown}"
    printf '[%s] type=%s window=%s module=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$type" "$window" "$module" \
        >> "$HALL_AGENT_LOG_DIR/hall-agents.log" 2>/dev/null || true
}

# ── Tmux styling ─────────────────────────────────────────────────

# Apply theme to a tmux window in an existing session
# Usage: _hall_apply_tmux_style "$window_name"
_hall_apply_tmux_style() {
    local window_name="$1"
    [ -z "$window_name" ] && return 0
    _hall_tmux_cmd set-window-option -t "$window_name" window-style "bg=$HALL_TMUX_WINDOW_BG,fg=$HALL_TMUX_WINDOW_FG" 2>/dev/null || true
    _hall_tmux_cmd set-window-option -t "$window_name" window-active-style "bg=$HALL_TMUX_WINDOW_BG,fg=$HALL_TMUX_WINDOW_FG" 2>/dev/null || true
    _hall_tmux_cmd set-window-option -t "$window_name" pane-border-style "fg=$HALL_TMUX_PANE_BORDER_FG" 2>/dev/null || true
    _hall_tmux_cmd set-window-option -t "$window_name" pane-active-border-style "fg=$HALL_TMUX_PANE_ACTIVE_BORDER_FG" 2>/dev/null || true
}

# Apply theme to a standalone tmux session we own
# Usage: _hall_apply_tmux_session_style "$session_name"
_hall_apply_tmux_session_style() {
    local session_name="$1"
    [ -z "$session_name" ] && return 0
    tmux set-option -t "$session_name" status-style "bg=$HALL_TMUX_STATUS_BG,fg=$HALL_TMUX_STATUS_FG" 2>/dev/null || true
    tmux set-option -t "$session_name" status-left "$HALL_TMUX_STATUS_LEFT" 2>/dev/null || true
    tmux set-option -t "$session_name" status-right "$HALL_TMUX_STATUS_RIGHT" 2>/dev/null || true
    tmux set-window-option -t "$session_name" window-style "bg=$HALL_TMUX_WINDOW_BG,fg=$HALL_TMUX_WINDOW_FG" 2>/dev/null || true
    tmux set-window-option -t "$session_name" window-active-style "bg=$HALL_TMUX_WINDOW_BG,fg=$HALL_TMUX_WINDOW_FG" 2>/dev/null || true
    tmux set-window-option -t "$session_name" pane-border-style "fg=$HALL_TMUX_PANE_BORDER_FG" 2>/dev/null || true
    tmux set-window-option -t "$session_name" pane-active-border-style "fg=$HALL_TMUX_PANE_ACTIVE_BORDER_FG" 2>/dev/null || true
}

# ── Public API ────────────────────────────────────────────────────

# hall_spawn_agent — Interactive agent in new tmux window
#
# --system-prompt-file FILE  (required)
# --model MODEL              opus|sonnet|haiku (default: sonnet)
# --skip-permissions         adds --dangerously-skip-permissions
# --window-name NAME         tmux window name (default: agent)
# --env "KEY=VAL"            env var for agent (repeatable)
# --message TEXT             typed into claude input after 1s delay
# --cleanup FILE             rm after claude exits (repeatable)
#
# Returns 0 on success, 1 on failure. No stdout.
hall_spawn_agent() {
    local _system_prompt_file="" _model="sonnet" _skip_permissions=false
    local _verbose=false _prompt="" _window_name="agent" _message=""
    local -a _env_vars=() _cleanup_files=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --system-prompt-file) _system_prompt_file="$2"; shift 2 ;;
            --model)              _model="$2"; shift 2 ;;
            --skip-permissions)   _skip_permissions=true; shift ;;
            --window-name)        _window_name="$2"; shift 2 ;;
            --env)                _env_vars+=("$2"); shift 2 ;;
            --message)            _message="$2"; shift 2 ;;
            --cleanup)            _cleanup_files+=("$2"); shift 2 ;;
            *) hall_log_error "hall_spawn_agent: unknown arg: $1"; return 1 ;;
        esac
    done

    [ -z "$_system_prompt_file" ] && {
        hall_log_error "hall_spawn_agent: --system-prompt-file required"; return 1; }

    _hall_resolve_tmux || { echo "Error: agent requires tmux" >&2; return 1; }

    local cmd
    cmd=$(_hall_build_claude_cmd)
    hall_log_info "spawn_agent: window=$_window_name model=$_model"
    hall_log_debug "Command: $cmd"

    _hall_tmux_cmd new-window -n "$_window_name"
    _hall_apply_tmux_style "$_window_name"
    _hall_tmux_cmd send-keys "$cmd" Enter

    if [ -n "$_message" ]; then
        sleep 1
        _hall_tmux_cmd send-keys "$_message"
    fi

    _hall_register_agent "spawn" "$_window_name" "${HALL_ROUTE_MODULE:-unknown}"
}

# hall_run_agent — Blocking agent in current terminal
#
# --prompt TEXT              (required) the -p prompt
# --model MODEL              opus|sonnet|haiku (default: sonnet)
# --skip-permissions         adds --dangerously-skip-permissions
# --verbose                  adds --verbose
# --env "KEY=VAL"            env var for agent (repeatable)
# --wait-after               "Press Enter to return..." after completion
#
# Returns claude's exit code.
hall_run_agent() {
    local _prompt="" _model="sonnet" _skip_permissions=false
    local _verbose=false _wait_after=false _system_prompt_file=""
    local -a _env_vars=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --prompt)             _prompt="$2"; shift 2 ;;
            --system-prompt-file) _system_prompt_file="$2"; shift 2 ;;
            --model)              _model="$2"; shift 2 ;;
            --skip-permissions)   _skip_permissions=true; shift ;;
            --verbose)            _verbose=true; shift ;;
            --env)                _env_vars+=("$2"); shift 2 ;;
            --wait-after)         _wait_after=true; shift ;;
            *) hall_log_error "hall_run_agent: unknown arg: $1"; return 1 ;;
        esac
    done

    [ -z "$_prompt" ] && {
        hall_log_error "hall_run_agent: --prompt required"; return 1; }

    hall_log_info "run_agent: model=$_model verbose=$_verbose"

    local -a claude_args=()
    [ -n "$_model" ] && claude_args+=(--model "$_model")
    [ "$_skip_permissions" = true ] && claude_args+=(--dangerously-skip-permissions)
    [ "$_verbose" = true ] && claude_args+=(--verbose)
    [ -n "$_system_prompt_file" ] && [ -f "$_system_prompt_file" ] && \
        claude_args+=(--append-system-prompt "$(cat "$_system_prompt_file")")
    claude_args+=(-p "$_prompt")

    _hall_register_agent "run" "inline" "${HALL_ROUTE_MODULE:-unknown}"

    local rc
    if [ ${#_env_vars[@]} -gt 0 ]; then
        env "${_env_vars[@]}" claude "${claude_args[@]}"
    else
        claude "${claude_args[@]}"
    fi
    rc=$?

    [ "$_wait_after" = true ] && { echo "Press Enter to return..."; read; }

    return $rc
}

# hall_spawn_agent_auto — Non-interactive agent in new tmux window
#
# --system-prompt-file FILE  (required)
# --prompt TEXT              (required) -p prompt
# --model MODEL              opus|sonnet|haiku (default: sonnet)
# --skip-permissions         adds --dangerously-skip-permissions
# --window-name NAME         tmux window name (default: agent)
# --env "KEY=VAL"            env var for agent (repeatable)
# --cleanup FILE             rm after claude exits (repeatable)
#
# Returns 0 on success, 1 on failure.
hall_spawn_agent_auto() {
    local _system_prompt_file="" _model="sonnet" _skip_permissions=false
    local _verbose=false _prompt="" _window_name="agent"
    local -a _env_vars=() _cleanup_files=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --system-prompt-file) _system_prompt_file="$2"; shift 2 ;;
            --prompt)             _prompt="$2"; shift 2 ;;
            --model)              _model="$2"; shift 2 ;;
            --skip-permissions)   _skip_permissions=true; shift ;;
            --window-name)        _window_name="$2"; shift 2 ;;
            --env)                _env_vars+=("$2"); shift 2 ;;
            --cleanup)            _cleanup_files+=("$2"); shift 2 ;;
            *) hall_log_error "hall_spawn_agent_auto: unknown arg: $1"; return 1 ;;
        esac
    done

    [ -z "$_system_prompt_file" ] && {
        hall_log_error "hall_spawn_agent_auto: --system-prompt-file required"; return 1; }
    [ -z "$_prompt" ] && {
        hall_log_error "hall_spawn_agent_auto: --prompt required"; return 1; }

    _hall_resolve_tmux || { echo "Error: auto agent requires tmux" >&2; return 1; }

    local cmd
    cmd=$(_hall_build_claude_cmd)
    hall_log_info "spawn_agent_auto: window=$_window_name model=$_model"
    hall_log_debug "Command: $cmd"

    _hall_tmux_cmd new-window -n "$_window_name"
    _hall_apply_tmux_style "$_window_name"
    _hall_tmux_cmd send-keys "$cmd" Enter

    _hall_register_agent "auto" "$_window_name" "${HALL_ROUTE_MODULE:-unknown}"
}
