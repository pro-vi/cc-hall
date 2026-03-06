#!/usr/bin/env bats
# Unit tests for hall-agent.sh
# Tests internal helpers and public API with mocked tmux/claude.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"

setup() {
    hall_test_setup_home
    # Create mock directory for each test
    MOCK_DIR=$(mktemp -d)
    export MOCK_DIR

    # Ensure HALL_AGENT_LOG_DIR exists
    export HALL_AGENT_LOG_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$MOCK_DIR" 2>/dev/null
    rm -rf "$HALL_AGENT_LOG_DIR" 2>/dev/null
    hall_test_teardown_home
}

# ============================================================================
# _hall_resolve_tmux
# ============================================================================

@test "_hall_resolve_tmux: prefers ORIGINAL_TMUX when both set" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux-original/default,123,0'
        TMUX='/tmp/tmux-inner/default,456,0'
        _hall_resolve_tmux
        echo \"\$HALL_TMUX_TARGET\"
    "
    assert_success
    assert_output '/tmp/tmux-original/default,123,0'
}

@test "_hall_resolve_tmux: falls back to TMUX when ORIGINAL_TMUX empty" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX=''
        TMUX='/tmp/tmux-session/default,789,0'
        _hall_resolve_tmux
        echo \"\$HALL_TMUX_TARGET\"
    "
    assert_success
    assert_output '/tmp/tmux-session/default,789,0'
}

@test "_hall_resolve_tmux: returns 1 when neither set" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        unset ORIGINAL_TMUX
        unset TMUX
        _hall_resolve_tmux
    "
    assert_failure
}

# ============================================================================
# hall_in_tmux
# ============================================================================

@test "hall_in_tmux: returns false when neither TMUX nor ORIGINAL_TMUX set" {
    run bash -c "
        unset TMUX
        unset ORIGINAL_TMUX
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_in_tmux
    "
    assert_failure
}

@test "hall_in_tmux: returns true when TMUX is set" {
    run bash -c "
        unset ORIGINAL_TMUX
        export TMUX='/tmp/tmux-1000/default,12345,0'
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_in_tmux
    "
    assert_success
}

@test "hall_in_tmux: returns true when ORIGINAL_TMUX is set" {
    run bash -c "
        unset TMUX
        export ORIGINAL_TMUX='/tmp/tmux-1000/default,67890,1'
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_in_tmux
    "
    assert_success
}

@test "hall_in_tmux: returns true when both TMUX and ORIGINAL_TMUX are set" {
    run bash -c "
        export TMUX='/tmp/tmux-1000/default,11111,0'
        export ORIGINAL_TMUX='/tmp/tmux-1000/default,22222,1'
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_in_tmux
    "
    assert_success
}

# ============================================================================
# hall_validate_tmux_session
# ============================================================================

@test "hall_validate_tmux_session: fails on empty socket path" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_validate_tmux_session ''
    "
    assert_failure
}

@test "hall_validate_tmux_session: extracts socket path correctly" {
    # Create fake socket
    SOCKET_DIR="/tmp/tmux-test-$$"
    SOCKET_PATH="$SOCKET_DIR/default"
    mkdir -p "$SOCKET_DIR"

    if ! command -v nc &>/dev/null; then
        skip "nc not available for socket creation"
    fi

    # Use nc to create a listening socket briefly
    nc -U -l "$SOCKET_PATH" >/dev/null 2>&1 &
    NC_PID=$!
    sleep 0.1

    # Skip if socket couldn't be created (e.g., sandbox restrictions)
    if [ ! -S "$SOCKET_PATH" ]; then
        kill $NC_PID 2>/dev/null || true
        rm -rf "$SOCKET_DIR"
        skip "Unable to create unix socket at $SOCKET_PATH"
    fi

    TMUX_VAR="$SOCKET_PATH,12345,0"
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_validate_tmux_session '$TMUX_VAR'
    "

    kill $NC_PID 2>/dev/null || true
    rm -rf "$SOCKET_DIR"

    assert_success
}

@test "hall_validate_tmux_session: fails on non-existent socket" {
    FAKE_SOCKET="/tmp/nonexistent-socket-$$"
    rm -f "$FAKE_SOCKET"

    TMUX_VAR="$FAKE_SOCKET,12345,0"
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_validate_tmux_session '$TMUX_VAR'
    "
    assert_failure
}

# ============================================================================
# _hall_build_claude_cmd
# ============================================================================

@test "_hall_build_claude_cmd: basic produces claude --model sonnet" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=()
            local -a _cleanup_files=()
            local _model='sonnet' _skip_permissions=false _verbose=false
            local _prompt='' _system_prompt_file=''
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output 'claude --model sonnet'
}

@test "_hall_build_claude_cmd: with env vars" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=('KEY=val')
            local -a _cleanup_files=()
            local _model='sonnet' _skip_permissions=false _verbose=false
            local _prompt='' _system_prompt_file=''
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial 'KEY=val'
    assert_output --partial 'claude --model sonnet'
}

@test "_hall_build_claude_cmd: with system prompt file" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=()
            local -a _cleanup_files=()
            local _model='sonnet' _skip_permissions=false _verbose=false
            local _prompt='' _system_prompt_file='/tmp/prompt.txt'
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial '--append-system-prompt'
    assert_output --partial '/tmp/prompt.txt'
}

@test "_hall_build_claude_cmd: with -p prompt" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=()
            local -a _cleanup_files=()
            local _model='sonnet' _skip_permissions=false _verbose=false
            local _prompt='Do the thing' _system_prompt_file=''
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial "-p"
    assert_output --partial "Do"
    assert_output --partial "thing"
}

@test "_hall_build_claude_cmd: with cleanup files" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=()
            local -a _cleanup_files=('/tmp/file1' '/tmp/file2')
            local _model='sonnet' _skip_permissions=false _verbose=false
            local _prompt='' _system_prompt_file=''
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial '&& rm -f'
    assert_output --partial '/tmp/file1'
    assert_output --partial '/tmp/file2'
}

@test "_hall_build_claude_cmd: with skip-permissions" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=()
            local -a _cleanup_files=()
            local _model='opus' _skip_permissions=true _verbose=false
            local _prompt='' _system_prompt_file=''
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial '--dangerously-skip-permissions'
}

@test "_hall_build_claude_cmd: with verbose" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=()
            local -a _cleanup_files=()
            local _model='sonnet' _skip_permissions=false _verbose=true
            local _prompt='' _system_prompt_file=''
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial '--verbose'
}

@test "_hall_build_claude_cmd: combinations" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _test() {
            local -a _env_vars=('FILE=/tmp/f.txt')
            local -a _cleanup_files=('/tmp/clean.txt')
            local _model='opus' _skip_permissions=true _verbose=true
            local _prompt='Begin work' _system_prompt_file='/tmp/sys.txt'
            _hall_build_claude_cmd
        }
        _test
    "
    assert_success
    assert_output --partial 'FILE='
    assert_output --partial 'claude'
    assert_output --partial '--model opus'
    assert_output --partial '--dangerously-skip-permissions'
    assert_output --partial '--verbose'
    assert_output --partial '-p'
    assert_output --partial 'Begin'
    assert_output --partial '--append-system-prompt'
    assert_output --partial '/tmp/sys.txt'
    assert_output --partial '&& rm -f'
    assert_output --partial '/tmp/clean.txt'
}

# ============================================================================
# hall_spawn_agent
# ============================================================================

@test "hall_spawn_agent: returns 1 without --system-prompt-file" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        hall_spawn_agent --model opus
    "
    assert_failure
}

@test "hall_spawn_agent: calls tmux new-window and send-keys" {
    # Create mock tmux that logs calls
    cat > "$MOCK_DIR/tmux" << 'MOCK'
#!/bin/sh
echo "tmux $@" >> "$MOCK_DIR/tmux_calls"
MOCK
    chmod +x "$MOCK_DIR/tmux"

    local sys_file=$(mktemp)
    echo "system prompt" > "$sys_file"

    run env PATH="$MOCK_DIR:$PATH" MOCK_DIR="$MOCK_DIR" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        hall_spawn_agent --system-prompt-file '$sys_file' --model sonnet
    "
    assert_success

    # Verify tmux was called with new-window
    run grep 'new-window' "$MOCK_DIR/tmux_calls"
    assert_success

    # Verify tmux was called with send-keys
    run grep 'send-keys' "$MOCK_DIR/tmux_calls"
    assert_success

    rm -f "$sys_file"
}

@test "hall_spawn_agent: sends --message with second send-keys call" {
    cat > "$MOCK_DIR/tmux" << 'MOCK'
#!/bin/sh
echo "tmux $@" >> "$MOCK_DIR/tmux_calls"
MOCK
    chmod +x "$MOCK_DIR/tmux"

    local sys_file=$(mktemp)
    echo "system prompt" > "$sys_file"

    run env PATH="$MOCK_DIR:$PATH" MOCK_DIR="$MOCK_DIR" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        hall_spawn_agent --system-prompt-file '$sys_file' --message 'hello agent'
    "
    assert_success

    # Should have two send-keys calls: one for command, one for message
    local count
    count=$(grep -c 'send-keys' "$MOCK_DIR/tmux_calls")
    [ "$count" -eq 2 ]

    rm -f "$sys_file"
}

# ============================================================================
# hall_spawn_agent_auto
# ============================================================================

@test "hall_spawn_agent_auto: returns 1 without --system-prompt-file" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        hall_spawn_agent_auto --prompt 'do something'
    "
    assert_failure
}

@test "hall_spawn_agent_auto: returns 1 without --prompt" {
    local sys_file=$(mktemp)
    echo "system prompt" > "$sys_file"

    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        hall_spawn_agent_auto --system-prompt-file '$sys_file'
    "
    assert_failure

    rm -f "$sys_file"
}

# ============================================================================
# hall_run_agent
# ============================================================================

@test "hall_run_agent: returns 1 without --prompt" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_run_agent --model sonnet
    "
    assert_failure
}

@test "hall_run_agent: passes env vars via env command" {
    cat > "$MOCK_DIR/claude" << 'MOCK'
#!/bin/sh
# Check that FILE env var is set
if [ -n "$FILE" ]; then
    echo "FILE=$FILE"
    exit 0
fi
exit 1
MOCK
    chmod +x "$MOCK_DIR/claude"

    run env PATH="$MOCK_DIR:$PATH" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_run_agent --prompt 'test' --env 'FILE=/tmp/test.txt'
    "
    assert_success
    assert_output --partial 'FILE=/tmp/test.txt'
}

@test "hall_run_agent: returns claude's exit code" {
    cat > "$MOCK_DIR/claude" << 'MOCK'
#!/bin/sh
exit 42
MOCK
    chmod +x "$MOCK_DIR/claude"

    run env PATH="$MOCK_DIR:$PATH" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_run_agent --prompt 'test'
    "
    [ "$status" -eq 42 ]
}

@test "hall_run_agent: includes --verbose when specified" {
    cat > "$MOCK_DIR/claude" << 'MOCK'
#!/bin/sh
echo "$@"
exit 0
MOCK
    chmod +x "$MOCK_DIR/claude"

    run env PATH="$MOCK_DIR:$PATH" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_run_agent --prompt 'test' --verbose
    "
    assert_success
    assert_output --partial '--verbose'
}

# ============================================================================
# _hall_apply_tmux_style
# ============================================================================

@test "_hall_apply_tmux_style: calls set-window-option with theme colors" {
    cat > "$MOCK_DIR/tmux" << 'MOCK'
#!/bin/sh
echo "tmux $@" >> "$MOCK_DIR/tmux_calls"
MOCK
    chmod +x "$MOCK_DIR/tmux"

    run env PATH="$MOCK_DIR:$PATH" MOCK_DIR="$MOCK_DIR" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        _hall_resolve_tmux
        _hall_apply_tmux_style 'test-window'
    "
    assert_success

    run grep 'window-style' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'window-active-style' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'pane-border-style' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'pane-active-border-style' "$MOCK_DIR/tmux_calls"
    assert_success
}

@test "_hall_apply_tmux_style: uses theme accent for active pane border" {
    cat > "$MOCK_DIR/tmux" << 'MOCK'
#!/bin/sh
echo "tmux $@" >> "$MOCK_DIR/tmux_calls"
MOCK
    chmod +x "$MOCK_DIR/tmux"

    run env PATH="$MOCK_DIR:$PATH" MOCK_DIR="$MOCK_DIR" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        ORIGINAL_TMUX='/tmp/tmux/default,1,0'
        _hall_resolve_tmux
        _hall_apply_tmux_style 'test-window'
    "
    assert_success

    # Accent color should appear in pane-active-border-style
    run grep 'pane-active-border-style' "$MOCK_DIR/tmux_calls"
    assert_output --partial "$HALL_ACCENT"
}

@test "_hall_apply_tmux_style: no-ops on empty window name" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _hall_apply_tmux_style ''
    "
    assert_success
}

# ============================================================================
# _hall_apply_tmux_session_style
# ============================================================================

@test "_hall_apply_tmux_session_style: sets status and window options" {
    cat > "$MOCK_DIR/tmux" << 'MOCK'
#!/bin/sh
echo "tmux $@" >> "$MOCK_DIR/tmux_calls"
MOCK
    chmod +x "$MOCK_DIR/tmux"

    run env PATH="$MOCK_DIR:$PATH" MOCK_DIR="$MOCK_DIR" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _hall_apply_tmux_session_style 'test-session'
    "
    assert_success

    run grep 'status-style' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'status-left' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'status-right' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'window-style' "$MOCK_DIR/tmux_calls"
    assert_success
    run grep 'pane-border-style' "$MOCK_DIR/tmux_calls"
    assert_success
}

@test "_hall_apply_tmux_session_style: includes cc-hall in status-left" {
    cat > "$MOCK_DIR/tmux" << 'MOCK'
#!/bin/sh
echo "tmux $@" >> "$MOCK_DIR/tmux_calls"
MOCK
    chmod +x "$MOCK_DIR/tmux"

    run env PATH="$MOCK_DIR:$PATH" MOCK_DIR="$MOCK_DIR" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _hall_apply_tmux_session_style 'test-session'
    "
    assert_success

    run grep 'status-left' "$MOCK_DIR/tmux_calls"
    assert_output --partial 'cc-hall'
}

@test "_hall_apply_tmux_session_style: no-ops on empty session name" {
    run bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        _hall_apply_tmux_session_style ''
    "
    assert_success
}

# ============================================================================
# hall_run_agent
# ============================================================================

@test "hall_run_agent: includes --append-system-prompt when system-prompt-file provided" {
    local sys_file=$(mktemp)
    echo "my system prompt" > "$sys_file"

    cat > "$MOCK_DIR/claude" << 'MOCK'
#!/bin/sh
echo "$@"
exit 0
MOCK
    chmod +x "$MOCK_DIR/claude"

    run env PATH="$MOCK_DIR:$PATH" \
        HALL_AGENT_LOG_DIR="$HALL_AGENT_LOG_DIR" \
        bash -c "
        source '$HALL_LIB_DIR/hall-agent.sh'
        hall_run_agent --prompt 'test' --system-prompt-file '$sys_file'
    "
    assert_success
    assert_output --partial '--append-system-prompt'
    assert_output --partial 'my system prompt'

    rm -f "$sys_file"
}
