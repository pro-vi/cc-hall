#!/usr/bin/env bash
# Preview handler for editor module
# Receives: $1=clean command, $2=label (routing tag already stripped by cc-hall)

set -e

HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-render.sh"

RAW_CMD="$1"
[ -z "$RAW_CMD" ] && exit 0

# ── Prompt Agent entries ─────────────────────────────────────

case "$RAW_CMD" in
    ed-info\ guide)
        cat <<'EOF' | hall_render_markdown
**Editor**

Open your prompt in an editor for manual refinement,
or send it to the **Prompt Agent** for AI-powered
enhancement.

**Prompt Editor** — launch vim, VS Code, Cursor, or
any detected editor. The prompt file is passed directly;
save and quit to return it to Claude Code.

**Prompt Agent** — an AI agent that investigates the
codebase and turns rough intent into a grounded,
executable prompt. Two modes:

| Mode | Behavior |
|------|----------|
| **Interactive** | Chat with the agent inline |
| **Auto** | Agent enhances and returns silently |

**Agent Settings** — control model (Opus/Sonnet/Haiku),
permission level, and execution mode (inline vs tmux).
EOF
        ;;
    prompt-agent-interactive)
        cat <<'EOF' | hall_render_markdown
**Prompt Agent (Interactive)**

Investigates the codebase and turns your rough intent into a grounded, executable prompt. Good for:

* **Planning** — sketch intent, get verified steps
* **Grounding** — confirm files and APIs exist
* **Structuring** — vague paragraph → Context/Task/Criteria
* **Scoping** — add "Out of scope" to prevent drift
* **Iterating** — refine after seeing first results

Runs inline. Chat with the agent, then exit to return the enhanced prompt to Claude Code.

**Guardrails**

* Serves your intent, doesn't redirect it
* Verifies all paths before mentioning
* Writes only to your prompt file
EOF
        hall_preview_prompt_content "Current prompt"
        exit 0 ;;

    prompt-agent-auto)
        cat <<'EOF' | hall_render_markdown
**Prompt Agent (Auto)**

Same planning agent, running non-interactively.
Runs inline, writes the enhanced prompt, and exits.

* Reads your prompt, investigates, rewrites
* No user interaction during execution
* Returns enhanced prompt to Claude Code when done
* System prompt is the only guardrail
EOF
        hall_preview_prompt_content "Current prompt"
        exit 0 ;;

    # ── Agent settings previews ───────────────────────────────

    pa-toggle-model)
        cat <<'EOF' | hall_render_markdown
**Model Selection**

| Model | Description |
|-------|-------------|
| **Opus** | Most capable. Deep reasoning. |
| **Sonnet** | Fast and capable. Good balance. |
| **Haiku** | Fastest. Quick iterations. |

Cycles: Opus → Sonnet → Haiku → Opus

Shared with cc-reflection settings.
EOF
        exit 0 ;;

    pa-toggle-permissions)
        cat <<'EOF' | hall_render_markdown
**Permissions**

**Off:** Agent asks before Write/Edit operations.
You see the target file and can deny.
This is the real guardrail (interactive).

**On:** Runs with `--dangerously-skip-permissions`.
Faster but system prompt is only constraint.

Only enable if you trust the prompt context.
EOF
        exit 0 ;;

    pa-toggle-tmux)
        cat <<'EOF' | hall_render_markdown
**Tmux Mode**

**Off:** Agent runs inline in your current terminal.
Interactive: exec replaces process (gets TTY).
Auto: blocks until agent finishes.

**On:** Agent spawns in a new tmux window.
Your terminal returns immediately.
Switch to the agent window to interact.

Requires an active tmux session.
EOF
        exit 0 ;;
esac

# ── Editor entries (vim, code, cursor, etc.) ─────────────────

case "$RAW_CMD" in
    vi\ *)
        cat <<'EOF' | hall_render_markdown
**Vim**

Terminal-based editor. Opens in current terminal.
Lightweight, always available.

`:wq` to save and return to Claude Code.
EOF
        ;;
    nvim\ *)
        cat <<'EOF' | hall_render_markdown
**Neovim**

Modern Vim fork. Opens in current terminal.
Lua-based config, LSP built-in.

`:wq` to save and return to Claude Code.
EOF
        ;;
    code\ *)
        cat <<'EOF' | hall_render_markdown
**VS Code**

Opens in VS Code with `--wait` flag.
Full IDE experience: syntax highlighting,
extensions, integrated terminal.

Save and close the tab to return to Claude Code.
EOF
        ;;
    cursor\ *)
        cat <<'EOF' | hall_render_markdown
**Cursor**

AI-native code editor. Opens with `--wait` flag.
Built-in AI assistance for prompt editing.

Save and close the tab to return to Claude Code.
EOF
        ;;
    windsurf\ *)
        cat <<'EOF' | hall_render_markdown
**Windsurf**

AI-powered code editor. Opens with `--wait` flag.

Save and close the tab to return to Claude Code.
EOF
        ;;
    zed\ *)
        cat <<'EOF' | hall_render_markdown
**Zed**

High-performance editor. Opens with `--wait` flag.
Fast startup, GPU-accelerated rendering.

Save and close the tab to return to Claude Code.
EOF
        ;;
    subl\ *)
        cat <<'EOF' | hall_render_markdown
**Sublime Text**

Fast, polished text editor. Opens with `--wait` flag.
Multi-cursor, command palette, extensive plugins.

Save and close the tab to return to Claude Code.
EOF
        ;;
    agy\ *)
        cat <<'EOF' | hall_render_markdown
**Antigravity**

Opens with `--wait` flag.

Save and close the tab to return to Claude Code.
EOF
        ;;
    *) exit 0 ;;
esac
hall_preview_prompt_content "Current prompt"
exit 0
