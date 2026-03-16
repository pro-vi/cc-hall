#!/usr/bin/env bash
# Preview handler for cc-config module
# Receives: $1=clean command, $2=label (routing tag stripped by cc-hall)
# No `local` at top level — this is a script, not a function.

set -e

HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-render.sh"

HALL_PREVIEW_CMD="$1"
[ -z "$HALL_PREVIEW_CMD" ] && exit 0

# ── Effect indicator helpers ──────────────────────────────────

_cv_effect_saved_default() {
    printf '\n  \033[33m↻ Saved default\033[0m\n'
    printf '  Start a new Claude Code session to guarantee it applies.\n'
}

_cv_effect_next_session() {
    printf '\n  \033[36m↻ New session required\033[0m\n'
}

_cv_current_session_tip() {
    local command="$1"
    printf '  For the current session, use %s.\n' "$command"
}

# ── Stored-in line helper ─────────────────────────────────────

_cv_stored_in() {
    local cmd_prefix="$1"
    case "$cmd_prefix" in
        cv-flag|cv-val)   printf '  Stored in: ~/.claude/settings.json\n' ;;
        cv-sflag|cv-sval) printf '  Stored in: .claude/settings.json\n' ;;
        cv-pflag|cv-pval) printf '  Stored in: .claude/settings.local.json\n' ;;
    esac
}

# ── Guide preview with markdown rendering ─────────────────────

_cv_guide_render() {
    cat <<'GUIDEEOF' | hall_render_markdown
**Config — Settings & Flags**

Settings not directly accessible through Claude Code's `/config` — hidden env vars, experimental flags, and project overrides.

**Layers**

| Layer | File |
|-------|------|
| **Global** | `~/.claude/settings.json` |
| **Shared** | `.claude/settings.json` |
| **Local** | `.claude/settings.local.json` |

**Controls**

| Key | Action |
|-----|--------|
| `Enter` | Cycle to next value |
| `◂` / `▸` | Switch layer |

**States**

**Global** layer: binary `on`/`off` toggles.

**Project** layers add an `inherited` state —
meaning no override is set, the global value applies.
GUIDEEOF
}

# ── Flag preview: shared across cv-flag/cv-sflag/cv-pflag ─────

_cv_preview_flag() {
    local prefix="$1" flag="$2"

    # For project layers, show override header
    if [ "$prefix" = "cv-sflag" ] || [ "$prefix" = "cv-pflag" ]; then
        local layer_name="Shared Project"
        [ "$prefix" = "cv-pflag" ] && layer_name="Local Project"
        printf '**%s Override**\n\n' "$layer_name" | hall_render_markdown
    fi

    case "$flag" in
        alwaysThinkingEnabled)
            cat <<'EOF' | hall_render_markdown
**Always Thinking**

When enabled, Claude always uses extended thinking, even for simple questions.

Key: `alwaysThinkingEnabled` (boolean)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        CLAUDE_CODE_DISABLE_1M_CONTEXT)
            cat <<'EOF' | hall_render_markdown
**1M Token Context**

Controls the extended 1M context window.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `CLAUDE_CODE_DISABLE_1M_CONTEXT=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_SIMPLE)
            cat <<'EOF' | hall_render_markdown
**Simple Mode**

Reduces Claude Code's output verbosity.
Uses simpler, more concise responses.

Key: `CLAUDE_CODE_SIMPLE = "1"`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_DISABLE_THINKING)
            cat <<'EOF' | hall_render_markdown
**Thinking**

Controls whether Claude uses thinking (extended reasoning) in responses.

This flag is currently **undocumented** in the public Claude Code docs,
but it is still present in the shipped CLI.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `CLAUDE_CODE_DISABLE_THINKING=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING)
            cat <<'EOF' | hall_render_markdown
**Adaptive Thinking**

Controls adaptive thinking budget behavior.

This flag is currently **undocumented** in the public Claude Code docs,
but it is still present in the shipped CLI.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        fastMode)
            cat <<'EOF' | hall_render_markdown
**Fast Mode**

Controls whether `/fast` is available in Claude Code.

Key: `fastMode` (boolean)

Hall also cleans up legacy `CLAUDE_CODE_DISABLE_FAST_MODE=1`
if it already exists in this layer.
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            _cv_current_session_tip '`/fast`'
            ;;
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)
            cat <<'EOF' | hall_render_markdown
**Agent Teams (Experimental)**

Enables the TeamCreate and SendMessage tools for multi-agent workflows.

Key: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_SUBAGENT_MODEL)
            cat <<'EOF' | hall_render_markdown
**Subagent Model**

Override the model used by subagents (Agent tool).

Cycles: haiku → sonnet → opus

Useful for running cheaper subagents while
keeping the main session on a stronger model.

Key: `CLAUDE_CODE_SUBAGENT_MODEL`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to cycle.\n'
            _cv_effect_next_session
            ;;
        ENABLE_TOOL_SEARCH)
            cat <<'EOF' | hall_render_markdown
**Tool Search (Experimental)**

Enables deferred tool loading via the ToolSearch tool. Reduces initial context by loading MCP tools on demand.

Key: `ENABLE_TOOL_SEARCH`

Supported values:
- `auto` (default)
- `true`
- `false`
- `auto:<number>`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_DISABLE_BACKGROUND_TASKS)
            cat <<'EOF' | hall_render_markdown
**Background Tasks**

Controls whether Claude can run long-running commands in the background.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`

Hall also cleans up the temporary
`CLAUDE_CODE_ENABLE_BACKGROUND_TASKS` compatibility key on write.
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_ENABLE_TASKS)
            cat <<'EOF' | hall_render_markdown
**Task Tracking**

Controls the TaskCreate/TaskList/TaskUpdate tools for structured task management.

Default: on (`true`)

Set to `false` to disable task tracking and fall back to the older TODO flow.

Key: `CLAUDE_CODE_ENABLE_TASKS`

Hall also cleans up the temporary `DISABLE_TASKS`
compatibility key on write.
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        DISABLE_AUTO_COMPACT)
            cat <<'EOF' | hall_render_markdown
**Auto Compact**

Controls automatic context compaction near context limits.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `DISABLE_AUTO_COMPACT=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        DISABLE_COMPACT)
            cat <<'EOF' | hall_render_markdown
**Compact**

Controls the `/compact` command and context compaction capability entirely.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `DISABLE_COMPACT=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        CLAUDE_CODE_DISABLE_CLAUDE_MDS)
            cat <<'EOF' | hall_render_markdown
**CLAUDE.md Files**

Controls loading of CLAUDE.md instruction files (global, project, and local).

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        respectGitignore)
            cat <<'EOF' | hall_render_markdown
**Respect Gitignore**

When enabled, file operations respect `.gitignore` patterns. Disable to allow Claude to access ignored files.

Key: `respectGitignore` (boolean, default true)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        autoMemoryEnabled)
            cat <<'EOF' | hall_render_markdown
**Auto Memory**

Controls automatic background memory loading.

Key: `autoMemoryEnabled` (boolean)

Hall also cleans up legacy
`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` if it already exists.
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        DISABLE_PROMPT_CACHING)
            cat <<'EOF' | hall_render_markdown
**Prompt Caching**

Caches repeated prompt prefixes to reduce API costs and latency on long conversations.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `DISABLE_PROMPT_CACHING=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        spinnerTipsEnabled)
            cat <<'EOF' | hall_render_markdown
**Spinner Tips**

Shows helpful tips in the spinner while Claude is thinking.

Key: `spinnerTipsEnabled` (boolean)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        showTurnDuration)
            cat <<'EOF' | hall_render_markdown
**Turn Duration**

Shows how long each turn took after Claude finishes responding.

Key: `showTurnDuration` (boolean, default true)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        CLAUDE_CODE_DISABLE_TERMINAL_TITLE)
            cat <<'EOF' | hall_render_markdown
**Terminal Title**

Controls whether Claude Code updates the terminal title with session info.

This is an inverted flag:
- **ON** = env var absent (default)
- **OFF** = `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_next_session
            ;;
        terminalProgressBarEnabled)
            cat <<'EOF' | hall_render_markdown
**Progress Bar**

Shows a progress bar in the terminal while Claude is working.

Key: `terminalProgressBarEnabled` (boolean, default true)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        prefersReducedMotion)
            cat <<'EOF' | hall_render_markdown
**Reduced Motion**

Reduces or disables UI animations in Claude Code. An accessibility setting for motion-sensitive users.

Key: `prefersReducedMotion` (boolean, default false)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        skipDangerousModePermissionPrompt)
            cat <<'EOF' | hall_render_markdown
**Skip Permission Prompt**

When in `--dangerously-skip-permissions` mode, this skips the confirmation prompt.

Use with caution in automated pipelines.

Key: `skipDangerousModePermissionPrompt` (boolean)
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to toggle.\n'
            _cv_effect_saved_default
            ;;
        autoUpdatesChannel)
            cat <<'EOF' | hall_render_markdown
**Auto Updates Channel**

Controls which update channel Claude Code uses.

| Channel | Description |
|---------|-------------|
| **stable** | Production releases |
| **latest** | Newest available channel |

Key: `autoUpdatesChannel`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to cycle: latest → stable\n'
            _cv_effect_next_session
            ;;
    esac
    exit 0
}

# ── Val preview: shared across cv-val/cv-sval/cv-pval ─────────

_cv_preview_val() {
    local prefix="$1" key="$2"

    if [ "$prefix" = "cv-sval" ] || [ "$prefix" = "cv-pval" ]; then
        local layer_name="Shared Project"
        [ "$prefix" = "cv-pval" ] && layer_name="Local Project"
        printf '**%s Override**\n\n' "$layer_name" | hall_render_markdown
    fi

    case "$key" in
        effortLevel)
            cat <<'EOF' | hall_render_markdown
**Effort Level**

Controls reasoning effort for responses.

Cycles: low → medium → high

| Level | Description |
|-------|-------------|
| **low** | Fast, concise answers |
| **medium** | Balanced reasoning |
| **high** | Deep reasoning (default) |

Key: `effortLevel`

Also cleans up legacy `CLAUDE_CODE_EFFORT_LEVEL`
env var if present.
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to cycle.\n'
            _cv_effect_saved_default
            ;;
        model)
            cat <<'EOF' | hall_render_markdown
**Model**

Set a default model for this layer.

Cycles: haiku → sonnet → opus

| Model | Description |
|-------|-------------|
| **haiku** | Fast, concise |
| **sonnet** | Balanced capability |
| **opus** | Maximum reasoning |

Key: `model`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to cycle.\n'
            _cv_effect_saved_default
            _cv_current_session_tip '`/model`'
            ;;
        outputStyle)
            cat <<'EOF' | hall_render_markdown
**Output Style**

Change how Claude responds.

Cycles: concise → explanatory → learning

| Style | Description |
|-------|-------------|
| **concise** | Shorter, focused responses |
| **explanatory** | Adds educational insights |
| **learning** | Collaborative learn-by-doing |

Custom styles in `.claude/output-styles/`
are also available via `/output-style`.

Key: `outputStyle`
EOF
            _cv_stored_in "$prefix"
            printf '\n  Press Enter to cycle.\n'
            _cv_effect_saved_default
            _cv_current_session_tip '`/output-style`'
            ;;
    esac
    exit 0
}

# ── Command dispatch ──────────────────────────────────────────

case "$HALL_PREVIEW_CMD" in

    # ── Guide ────────────────────────────────────────────────

    cv-info\ guide)
        _cv_guide_render
        exit 0 ;;

    # ── Flag entries ─────────────────────────────────────────

    cv-flag\ *)   _cv_preview_flag "cv-flag" "${HALL_PREVIEW_CMD#cv-flag }" ;;
    cv-sflag\ *)  _cv_preview_flag "cv-sflag" "${HALL_PREVIEW_CMD#cv-sflag }" ;;
    cv-pflag\ *)  _cv_preview_flag "cv-pflag" "${HALL_PREVIEW_CMD#cv-pflag }" ;;

    # ── Val entries ──────────────────────────────────────────

    cv-val\ *)    _cv_preview_val "cv-val" "${HALL_PREVIEW_CMD#cv-val }" ;;
    cv-sval\ *)   _cv_preview_val "cv-sval" "${HALL_PREVIEW_CMD#cv-sval }" ;;
    cv-pval\ *)   _cv_preview_val "cv-pval" "${HALL_PREVIEW_CMD#cv-pval }" ;;

esac

exit 0
