#!/usr/bin/env bats
# Unit tests for usage module
# Tests snapshot building, subtab entries, preview rendering, and refresh.

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../test_helper/hall-hermetic'

HALL_DIR="${BATS_TEST_DIRNAME}/../../"
HALL_LIB_DIR="$HALL_DIR/lib"
USAGE_DIR="$HALL_DIR/modules/usage"

setup() {
    hall_test_setup_home
    HALL_STATE_DIR=$(mktemp -d)
    export HALL_STATE_DIR
    export HALL_DIR
    export HALL_LIB_DIR
    export HALL_USAGE_NOW="2026-03-07T12:00:00Z"
    export HALL_USAGE_OAUTH_RESPONSE=""

    TEST_ROOT=$(mktemp -d)
    CURRENT_PROJECT="$TEST_ROOT/alpha"
    OTHER_PROJECT="$TEST_ROOT/beta"
    mkdir -p "$CURRENT_PROJECT" "$OTHER_PROJECT"
    ORIG_DIR="$PWD"
    cd "$CURRENT_PROJECT"

    mkdir -p "$HOME/.claude/projects/alpha-slug/sess-alpha/subagents"
    cat > "$HOME/.claude/projects/alpha-slug/sess-alpha.jsonl" <<EOF
{"type":"assistant","cwd":"$CURRENT_PROJECT","sessionId":"sess-alpha","requestId":"req-1","timestamp":"2026-03-07T09:00:00Z","message":{"id":"msg-1","role":"assistant","model":"claude-opus-4-6","usage":{"input_tokens":1000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":3000,"output_tokens":200,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":5000}}}}
{"type":"assistant","cwd":"$CURRENT_PROJECT","sessionId":"sess-alpha","requestId":"req-2","timestamp":"2026-03-06T12:00:00Z","message":{"id":"msg-2","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":800,"cache_creation_input_tokens":0,"cache_read_input_tokens":1200,"output_tokens":100,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
not-json
EOF
    cat > "$HOME/.claude/projects/alpha-slug/sess-alpha/subagents/agent-1.jsonl" <<EOF
{"type":"assistant","isSidechain":true,"cwd":"$CURRENT_PROJECT","sessionId":"sess-alpha","requestId":"req-3","timestamp":"2026-03-07T10:00:00Z","message":{"id":"msg-3","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":400,"cache_creation_input_tokens":1000,"cache_read_input_tokens":0,"output_tokens":50,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":1000,"ephemeral_1h_input_tokens":0}}}}
EOF

    mkdir -p "$HOME/.claude/projects/beta-slug"
    cat > "$HOME/.claude/projects/beta-slug/sess-beta.jsonl" <<EOF
{"type":"assistant","cwd":"$OTHER_PROJECT","sessionId":"sess-beta","requestId":"req-4","timestamp":"2026-02-20T10:00:00Z","message":{"id":"msg-4","role":"assistant","model":"claude-haiku-4-5-20251001","usage":{"input_tokens":700,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":70,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
EOF
}

teardown() {
    cd "$ORIG_DIR"
    rm -rf "$HALL_STATE_DIR" "$TEST_ROOT" 2>/dev/null
    hall_test_teardown_home
}

@test "usage: module.sh can be sourced" {
    run bash -c "
        export HALL_DIR='$HALL_DIR' HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$USAGE_DIR/module.sh'
        echo \$HALL_MODULE_LABEL
        echo \$HALL_MODULE_ORDER
        echo \$HALL_MODULE_LOCKED
    "
    assert_success
    assert_line --index 0 'Usage'
    assert_line --index 1 '15'
    assert_line --index 2 '1'
}

@test "usage: overview entries include current project and rate limit" {
    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo 0 > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$USAGE_DIR/module.sh'
        hall_usage_entries
    "
    assert_success
    assert_output --partial 'usage-info guide'
    assert_output --partial 'usage-refresh'
    assert_output --partial 'This project (30d)'
    assert_output --partial 'Rate limit'
}

@test "usage: daily and models subtabs are populated from transcript data" {
    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$USAGE_DIR/module.sh'
        echo 1 > '$HALL_STATE_DIR/module-subtab'
        echo '--daily--'
        hall_usage_entries
        echo 3 > '$HALL_STATE_DIR/module-subtab'
        echo '--models--'
        hall_usage_entries
    "
    assert_success
    assert_output --partial '--daily--'
    assert_output --partial '2026-03-07'
    assert_output --partial '--models--'
    assert_output --partial 'claude-haiku-4-5-20251001'
}

@test "usage: preview guide describes exact versus estimated values" {
    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$USAGE_DIR/preview.sh" 'usage-info guide'
    assert_success
    assert_output --partial 'Usage'
    assert_output --partial 'exact'
    assert_output --partial 'estimated'
}

@test "usage: generated preview includes subagent usage and exact token breakdown" {
    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo 0 > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$USAGE_DIR/module.sh'
        hall_usage_entries >/dev/null
        bash '$USAGE_DIR/preview.sh' 'usage-show ov-today'
    "
    assert_success
    # Strip ANSI — quick renderer injects escape codes at column boundaries
    # inside table cells, splitting multi-word substrings
    output=$(printf '%s' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    assert_output --partial 'Today'
    assert_output --partial 'Subagent messages included: 1'
    assert_output --partial 'Cache write'
    assert_output --partial 'Total tokens'
}

@test "usage: rate limit preview shows cost table and detection info" {
    # Build snapshot first so the dynamic preview file exists
    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo 0 > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$USAGE_DIR/module.sh'
        hall_usage_entries >/dev/null
        bash '$USAGE_DIR/preview.sh' 'usage-show ov-rate-limit'
    "
    assert_success
    output=$(printf '%s' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    assert_output --partial 'Rate Limit'
    assert_output --partial 'No rate limit events'
    assert_output --partial 'Period'
    assert_output --partial 'Est. Cost'
}

@test "usage: building snapshot shows non-blocking loading state" {
    mkdir -p "$HALL_STATE_DIR/usage"
    : > "$HALL_STATE_DIR/usage/.building"

    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        echo 0 > '$HALL_STATE_DIR/module-subtab'
        source '$HALL_LIB_DIR/hall-common.sh'
        source '$HALL_LIB_DIR/hall-menu.sh'
        source '$USAGE_DIR/module.sh'
        hall_usage_entries
    "
    assert_success
    assert_output --partial 'usage-info guide'
    assert_output --partial 'usage-refresh'
    assert_output --partial 'Usage snapshot building'
    refute_output --partial 'Usage snapshot unavailable'

    run env HALL_LIB_DIR="$HALL_LIB_DIR" bash "$USAGE_DIR/preview.sh" 'usage-info building'
    assert_success
    assert_output --partial 'Usage snapshot building'
    assert_output --partial 'background'
}

@test "usage: live OAuth utilization appears in overview entries" {
    local oauth_response
    oauth_response='{"five_hour":{"utilization":42.0,"resets_at":"2026-03-07T14:15:00Z"},"seven_day":{"utilization":8.0,"resets_at":"2026-03-14T08:00:00Z"},"extra_usage":{"is_enabled":true,"monthly_limit":2000,"used_credits":500,"utilization":25.0}}'

    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_USAGE_OAUTH_RESPONSE='$oauth_response'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        cat '$HALL_STATE_DIR/usage/overview.entries'
    "
    assert_success
    assert_output --partial '5h: 42%'
    assert_output --partial '7d: 8%'
    refute_output --partial 'no events'
}

@test "usage: live OAuth utilization appears in rate limit preview" {
    local oauth_response
    oauth_response='{"five_hour":{"utilization":42.0,"resets_at":"2026-03-07T14:15:00Z"},"seven_day":{"utilization":8.0,"resets_at":"2026-03-14T08:00:00Z"},"extra_usage":{"is_enabled":true,"monthly_limit":2000,"used_credits":500,"utilization":25.0}}'

    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_USAGE_OAUTH_RESPONSE='$oauth_response'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        cat '$HALL_STATE_DIR/usage/previews/ov-rate-limit.md'
    "
    assert_success
    assert_output --partial '| Window | Used | Resets |'
    assert_output --partial '| 5 hour | 42% | in 2h 15m |'
    assert_output --partial '| 7 day | 8% | Mar 14, 2026 |'
    assert_output --partial 'Extra usage: 25% ($500.00 / $2,000.00 monthly limit)'
    assert_output --partial 'Source: Anthropic OAuth API (live)'
}

@test "usage: invalid OAuth response falls back to transcript-based rate limit display" {
    run bash -c "
        cd '$CURRENT_PROJECT'
        export HOME='$HOME'
        export HALL_USAGE_NOW='$HALL_USAGE_NOW'
        export HALL_USAGE_OAUTH_RESPONSE='not-json'
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo '---overview---'
        cat '$HALL_STATE_DIR/usage/overview.entries'
        echo '---preview---'
        cat '$HALL_STATE_DIR/usage/previews/ov-rate-limit.md'
    "
    assert_success
    assert_output --partial 'Rate limit'
    assert_output --partial 'no events'
    assert_output --partial 'No rate limit events detected in local transcripts.'
    refute_output --partial 'Anthropic OAuth API (live)'
}

@test "usage: OAuth token extraction supports JSON credential blobs" {
    run bun -e "
        const source = await Bun.file('$HALL_LIB_DIR/hall-usage.js').text();
        const start = source.indexOf('function extractOAuthAccessToken');
        const end = source.indexOf('async function getOAuthToken');
        if (start === -1 || end === -1 || end <= start) throw new Error('helper not found');
        const extractOAuthAccessToken = new Function(source.slice(start, end) + '; return extractOAuthAccessToken;')();
        console.log(extractOAuthAccessToken('{\"claudeAiOauth\":{\"accessToken\":\"sk-ant-oat01-test\"}}'));
    "
    assert_success
    assert_output 'sk-ant-oat01-test'
}

@test "usage: refresh clears snapshot cache and reloads" {
    mkdir -p "$HALL_STATE_DIR/usage"
    echo '{}' > "$HALL_STATE_DIR/usage/manifest.json"

    run bash -c "
        export HALL_STATE_DIR='$HALL_STATE_DIR'
        export HALL_DIR='$HALL_DIR'
        export HALL_LIB_DIR='$HALL_LIB_DIR'
        source '$USAGE_DIR/on_select.sh' 'usage-refresh' '/dev/null'
    "
    [ "$status" -eq 2 ]
    [ ! -e "$HALL_STATE_DIR/usage/manifest.json" ]
}

@test "usage: deduplication removes records with same messageId:requestId" {
    DEDUP_DIR=$(mktemp -d)
    DEDUP_STATE=$(mktemp -d)
    mkdir -p "$DEDUP_DIR/proj"
    # Write 3 identical records (same messageId + requestId) — should count as 1
    cat > "$DEDUP_DIR/proj/sess-dedup.jsonl" <<EOF
{"type":"assistant","cwd":"/tmp","sessionId":"sess-d","requestId":"req-dup","timestamp":"2026-03-07T08:00:00Z","message":{"id":"msg-dup","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
{"type":"assistant","cwd":"/tmp","sessionId":"sess-d","requestId":"req-dup","timestamp":"2026-03-07T08:00:01Z","message":{"id":"msg-dup","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
{"type":"assistant","cwd":"/tmp","sessionId":"sess-d","requestId":"req-dup","timestamp":"2026-03-07T08:00:02Z","message":{"id":"msg-dup","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
EOF

    run bash -c "
        cd /tmp
        export HALL_USAGE_PROJECTS_DIR='$DEDUP_DIR'
        export HALL_USAGE_NOW='2026-03-07T12:00:00Z'
        export HALL_STATE_DIR='$DEDUP_STATE'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        cat '$DEDUP_STATE/usage/previews/ov-today.md'
    "
    assert_success
    # Should show 1 message (deduped), not 3
    assert_output --partial 'Messages | 1'
    rm -rf "$DEDUP_DIR" "$DEDUP_STATE" 2>/dev/null
}

@test "usage: fast mode applies 6x multiplier to Opus 4.5/4.6 cost" {
    FAST_DIR=$(mktemp -d)
    FAST_STATE=$(mktemp -d)
    mkdir -p "$FAST_DIR/proj"
    # Standard record: 1000 input + 200 output = $0.005 in + $0.005 out = $0.01
    # Fast record: same tokens at 6x = $0.06
    cat > "$FAST_DIR/proj/sess-fast.jsonl" <<EOF
{"type":"assistant","cwd":"/tmp","sessionId":"sess-f","requestId":"req-std","timestamp":"2026-03-07T08:00:00Z","message":{"id":"msg-std","role":"assistant","model":"claude-opus-4-6","usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":200,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
{"type":"assistant","cwd":"/tmp","sessionId":"sess-f","requestId":"req-fast","timestamp":"2026-03-07T09:00:00Z","message":{"id":"msg-fast","role":"assistant","model":"claude-opus-4-6","usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":200,"speed":"fast","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
EOF

    run bash -c "
        cd /tmp
        export HALL_USAGE_PROJECTS_DIR='$FAST_DIR'
        export HALL_USAGE_NOW='2026-03-07T12:00:00Z'
        export HALL_STATE_DIR='$FAST_STATE'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        cat '$FAST_STATE/usage/previews/ov-today.md'
    "
    assert_success
    # 2 messages total
    assert_output --partial 'Messages | 2'
    # Standard: (1000/1M)*5 + (200/1M)*25 = 0.005 + 0.005 = 0.01
    # Fast:     same * 6 = 0.06
    # Total = 0.07 → $0.07
    assert_output --partial '$0.07'
    rm -rf "$FAST_DIR" "$FAST_STATE" 2>/dev/null
}

@test "usage: rate limit events are detected from isApiErrorMessage entries" {
    RL_DIR=$(mktemp -d)
    RL_STATE=$(mktemp -d)
    mkdir -p "$RL_DIR/proj"
    cat > "$RL_DIR/proj/sess-rl.jsonl" <<EOF
{"type":"assistant","cwd":"/tmp","sessionId":"sess-r","requestId":"req-r1","timestamp":"2026-03-07T08:00:00Z","message":{"id":"msg-r1","role":"assistant","model":"claude-opus-4-6","usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":200,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
{"isApiErrorMessage":true,"timestamp":"2026-03-07T09:30:00Z","message":{"content":[{"type":"text","text":"You're out of extra usage \u00b7 resets 9pm (America/Los_Angeles)"}]}}
EOF

    run bash -c "
        cd /tmp
        export HALL_USAGE_PROJECTS_DIR='$RL_DIR'
        export HALL_USAGE_NOW='2026-03-07T12:00:00Z'
        export HALL_STATE_DIR='$RL_STATE'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo '---overview---'
        cat '$RL_STATE/usage/overview.entries'
        echo '---preview---'
        cat '$RL_STATE/usage/previews/ov-rate-limit.md'
    "
    assert_success
    # Overview should show rate limit with reset text
    assert_output --partial '9pm (America/Los_Angeles)'
    # Preview should show the event details and cost table
    assert_output --partial 'Rate Limit'
    assert_output --partial 'Resets 9pm (America/Los_Angeles)'
    assert_output --partial 'Events observed: 1'
    assert_output --partial 'Period'
    assert_output --partial 'Est. Cost'
    rm -rf "$RL_DIR" "$RL_STATE" 2>/dev/null
}

@test "usage: zero-token assistant rows do not inflate messages or model rollups" {
    ZERO_DIR=$(mktemp -d)
    ZERO_STATE=$(mktemp -d)
    mkdir -p "$ZERO_DIR/proj"
    cat > "$ZERO_DIR/proj/sess-zero.jsonl" <<EOF
{"type":"assistant","cwd":"/tmp","sessionId":"sess-real","requestId":"req-real","timestamp":"2026-03-07T08:00:00Z","message":{"id":"msg-real","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
{"type":"assistant","cwd":"/tmp","sessionId":"sess-zero","requestId":"req-zero","timestamp":"2026-03-07T08:30:00Z","message":{"id":"msg-zero","role":"assistant","model":"<synthetic>","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
EOF

    run bash -c "
        cd /tmp
        export HALL_USAGE_PROJECTS_DIR='$ZERO_DIR'
        export HALL_USAGE_NOW='2026-03-07T12:00:00Z'
        export HALL_STATE_DIR='$ZERO_STATE'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo '---today---'
        cat '$ZERO_STATE/usage/previews/ov-today.md'
        echo '---models---'
        cat '$ZERO_STATE/usage/models.entries'
    "
    assert_success
    assert_output --partial 'Messages | 1'
    assert_output --partial 'Sessions | 1'
    refute_output --partial '<synthetic>'
    rm -rf "$ZERO_DIR" "$ZERO_STATE" 2>/dev/null
}

@test "usage: daily buckets follow local time instead of UTC" {
    LOCAL_DIR=$(mktemp -d)
    LOCAL_STATE=$(mktemp -d)
    mkdir -p "$LOCAL_DIR/proj"
    cat > "$LOCAL_DIR/proj/sess-local.jsonl" <<EOF
{"type":"assistant","cwd":"/tmp","sessionId":"sess-local","requestId":"req-local","timestamp":"2026-03-07T07:30:00Z","message":{"id":"msg-local","role":"assistant","model":"claude-sonnet-4-6","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100,"speed":"standard","cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0}}}}
EOF

    run bash -c "
        cd /tmp
        export TZ='America/Los_Angeles'
        export HALL_USAGE_PROJECTS_DIR='$LOCAL_DIR'
        export HALL_USAGE_NOW='2026-03-07T08:15:00Z'
        export HALL_STATE_DIR='$LOCAL_STATE'
        bun '$HALL_LIB_DIR/hall-usage.js' build
        echo '---today---'
        cat '$LOCAL_STATE/usage/previews/ov-today.md'
        echo '---daily---'
        cat '$LOCAL_STATE/usage/daily.entries'
    "
    assert_success
    assert_output --partial 'No usage-bearing assistant messages were found for this slice.'
    assert_output --partial '2026-03-06'
    refute_output --partial '2026-03-07'
    rm -rf "$LOCAL_DIR" "$LOCAL_STATE" 2>/dev/null
}
