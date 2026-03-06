#!/usr/bin/env bash
# cc-hall skill install|uninstall — manage MODULE_API as a Claude Code skill

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
HALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODULE_API="$HALL_DIR/MODULE_API.md"
SKILL_DIR="$HOME/.claude/skills/cc-hall-module-api"
SKILL_FILE="$SKILL_DIR/SKILL.md"
REF_DIR="$SKILL_DIR/references"

case "${1:-}" in
    install)
        if [ ! -f "$MODULE_API" ]; then
            echo "Error: MODULE_API.md not found at $MODULE_API" >&2
            exit 1
        fi
        mkdir -p "$REF_DIR"

        # Lean SKILL.md — zero inline backticks, imperative voice
        cat > "$SKILL_FILE" << 'SKILL_EOF'
---
name: cc-hall-module-api
description: This skill should be used when building, editing, or debugging cc-hall modules. Provides the module directory structure, entry function pattern, metadata variables, exit codes, preview conventions, and available library functions. Consult when creating module.sh, on_select.sh, or preview.sh files for cc-hall.
invoke: user
---

# cc-hall Module Development

Build modules for the cc-hall extensible Ctrl-G menu in Claude Code.

## Module structure

A module is a directory with up to three files:

```
~/.claude/hall/modules/{name}/
    module.sh       # Required: entries + metadata
    on_select.sh    # Optional: command handler
    preview.sh      # Optional: preview renderer
```

Place in ~/.claude/hall/modules/{name}/ to shadow builtins, or register with "cc-hall module link".

## Quick reference

### module.sh (sourced into parent process — keep fast)

Set metadata:

```
HALL_MODULE_LABEL="My Module"
HALL_MODULE_ORDER=30
HALL_MODULE_PREVIEW_RENDERER="quick"  # Optional: auto|glow|quick
```

Define entry function matching directory name:

```
hall_mymodule_entries() {
    printf '%s\t%s\n' "Label" "command"
}
```

Use hall_section_header "Title" for visual separators.
Use hall_icon "guide" for nerd font icons (fallback to unicode).
Available icons: guide, theme, module, skill, file, memory, config, toggle.

### on_select.sh (subprocess)

Receives: $1 = command string, $2 = prompt file path.

Source hall-common.sh for named exit codes:

```
source "${HALL_LIB_DIR}/hall-common.sh"
exit $HALL_RC_CLOSE         # 0 — handled, close menu
exit $HALL_RC_RELOAD        # 2 — handled, rebuild and relaunch
exit $HALL_RC_NOT_HANDLED   # 1 — fall through to builtins
```

### preview.sh (subprocess, called per cursor movement)

Receives: $1 = command string, $2 = display label.
Pipe heredocs through hall_render_markdown (from hall-render.sh).
Use "**Bold**" for headers, not "# Heading". No leading newlines.
For static help prose, set HALL_MODULE_PREVIEW_RENDERER="quick" in module.sh and
keep calling hall_render_markdown normally.

### Available libraries (source from $HALL_LIB_DIR)

- hall-common.sh: logging, parsing, temp files, hall_preview_prompt_content, hall_icon()
- hall-agent.sh: hall_spawn_agent, hall_spawn_agent_auto, hall_run_agent
- hall-theme.sh: hall_ansi_bold, hall_ansi_dim, hall_section_header
- hall-render.sh: hall_render_markdown, hall_render_quick_markdown, hall_render_file
- hall-config.sh: hall_config_set_string, hall_config_toggle_bool

### Stable subcommands (use instead of sourcing internal scripts)

- cc-hall reload: rebuild current module entries
- cc-hall preview {}: preview dispatcher
- cc-hall agent --mode auto|interactive ...: agent dispatch
- cc-hall module link|unlink|list: module registration
- cc-hall skill install|uninstall: install this skill

### Environment variables (available in all three files)

HALL_DIR, HALL_LIB_DIR, HALL_FILE, HALL_SAFE_FILE, ORIGINAL_TMUX, HALL_STATE_DIR, HALL_MODULE_PREVIEW_RENDERER.

## Full API reference

Consult references/MODULE_API.md for complete documentation including:
sub-tabs, keybindings, entry tagging, lifecycle diagram, JSON settings conventions,
naming conventions, and detailed examples.
SKILL_EOF

        # Copy full reference (backticks safe in references/)
        cp "$MODULE_API" "$REF_DIR/MODULE_API.md"

        echo "Installed: $SKILL_DIR/"
        echo "Available as /cc-hall-module-api in Claude Code."
        ;;
    uninstall)
        if [ -d "$SKILL_DIR" ]; then
            rm -rf "$SKILL_DIR"
            echo "Removed: $SKILL_DIR/"
        else
            echo "Not installed." >&2
        fi
        ;;
    *)
        echo "Usage: cc-hall skill install|uninstall" >&2
        exit 1
        ;;
esac
