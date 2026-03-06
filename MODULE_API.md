# cc-hall Module API

A module is a directory with up to three files. One is required, two are optional.

```
~/.claude/hall/modules/{name}/
    module.sh       # Required — entries + metadata
    on_select.sh    # Optional — command handler
    preview.sh      # Optional — preview renderer
```

Builtin modules live in `$HALL_DIR/modules/{name}/`. User modules in `~/.claude/hall/modules/{name}/` shadow builtins with the same name.

---

## module.sh (sourced)

Sourced into the parent process when building entries. Must be fast — no heavy subprocesses during sourcing.

### Metadata

```bash
HALL_MODULE_LABEL="My Module"   # Tab label. Omit for inline (no tab).
HALL_MODULE_ORDER=30            # Sort order (lower = earlier). Default: 50.
HALL_MODULE_PREVIEW_RENDERER="quick"  # Optional: auto|glow|quick. Default: auto.
```

`HALL_MODULE_PREVIEW_RENDERER` controls how `hall_render_markdown` behaves in
`preview.sh`:
- `auto` / `glow`: use the normal glow-backed renderer with cache/fallbacks
- `quick`: use the fast plain-text-ish markdown renderer for static help prose

This is the preferred way to make a preview snappy for short static docs. Your
`preview.sh` can keep calling `hall_render_markdown` normally.

### Entry function (required)

Name must match directory: `hall_{name}_entries`.

```bash
hall_mymodule_entries() {
    printf '%s\t%s\n' "Label" "command"
    printf '%s\t%s\n' "Another" "other-command arg1 arg2"
}
```

Output: one entry per line, `Label<TAB>command`. Labels support ANSI codes. Commands are opaque strings routed to `on_select.sh`.

### Icons

```bash
hall_icon "guide"    # Returns nerd font icon, unicode fallback if unavailable
# Available: guide, theme, module, skill, file, memory, config, toggle
```

### Section headers

```bash
hall_section_header "Title"
# Outputs: ══ Title ═══════════<TAB>echo
# "echo" command is skipped by fzf enter binding.
```

### Summary function (optional, nested modules only)

```bash
hall_mymodule_summary() {
    echo "Brief description"
}
```

### Sub-tabs (optional)

```bash
HALL_MODULE_SUBTABS=("Global" "Shared" "Local")
```

Declares sub-tab labels. The framework handles everything:
- **State**: `$HALL_STATE_DIR/module-subtab` contains the active index (0, 1, 2, ...)
- **Header**: Rendered automatically in the fzf header (bold active, dim inactive)
- **Navigation**: Left/right arrow keys cycle through sub-tabs
- **Reset**: Sub-tab resets to 0 when switching modules via Tab/Shift-Tab

Your entry function reads `$HALL_STATE_DIR/module-subtab` to determine which sub-tab is active and generate appropriate entries. No bindings or header rendering needed.

### Keybindings (optional)

```bash
HALL_MODULE_BINDINGS=(
    "ctrl-d:execute(/path/to/script {})+reload(cc-hall reload)"
)
```

Collected once at startup. `{}` = fzf selection placeholder. Use `cc-hall reload` instead of direct paths to internal scripts.

**Scoped bindings:** Module keybindings are only active when the module's tab is selected. On tab switch, the previous module's keys are unbound and the new module's keys are rebound. This prevents binding leaks (e.g. `ctrl-d` from one module firing on another module's tab).

---

## on_select.sh (subprocess)

Invoked as: `bash on_select.sh "$command" "$prompt_file"`

| Arg | Content |
|-----|---------|
| `$1` | Raw command string (from entry's second field) |
| `$2` | Prompt file path (from EDITOR hook) |

### Exit codes

| Code | Meaning | Effect |
|------|---------|--------|
| 0 | Handled | Close cc-hall |
| 1 | Not handled | Fall through to built-in handlers |
| 2 | Reload | Rebuild menu, relaunch fzf |

### Pattern

```bash
#!/usr/bin/env bash
set -e

CMD="$1"
FILE="$2"

source "${HALL_LIB_DIR}/hall-common.sh"
# Available: $HALL_RC_CLOSE (0), $HALL_RC_NOT_HANDLED (1), $HALL_RC_RELOAD (2)

case "$CMD" in
    my-action)
        # do work
        exit $HALL_RC_CLOSE ;;
    my-toggle)
        # toggle state
        exit $HALL_RC_RELOAD ;;
esac

exit $HALL_RC_NOT_HANDLED  # Fall through
```

If no `on_select.sh` exists, all commands fall through to cc-hall's built-in editor pattern (`vi`, `code -w`, `cursor -w`, etc.).

### JSON settings convention

If your module manipulates JSON settings files (e.g. via `bun -e` or `jq`), use **strict null checks** when testing env var presence:

```javascript
// GOOD — strict null check
if (c.env['KEY'] === undefined || c.env['KEY'] === null) { ... }
if (c.env['KEY'] === '1') { ... }

// BAD — bare truthy check (treats "" and "0" as absent)
if (!c.env['KEY']) { ... }
if (c.env['KEY']) { ... }
```

This matters because `"0"` is a valid sentinel value for inverted DISABLE flags (explicit "on").

---

## preview.sh (subprocess)

Invoked as: `bash preview.sh "$command" "$label"`

cc-hall strips the routing tag before calling your preview script. Arguments:

| Arg | Content |
|-----|---------|
| `$1` | Clean command string (no `\x1f` prefix) |
| `$2` | Display label from the menu entry |

```bash
CMD="$1"
LABEL="$2"
# $CMD is the raw command string from your entry — no parsing needed
```

Output goes to stdout, displayed in fzf's preview pane. ANSI codes supported. Called on every cursor movement — keep it fast.

If no `preview.sh` exists, the preview pane stays empty for that module's entries.

### Style conventions

Preview panes are narrow (50% terminal width). Follow these conventions for consistent rendering:

- **Markdown through `hall_render_markdown`**: Pipe heredocs through `hall_render_markdown` (from `lib/hall-render.sh`). By default it uses glow with theme-aware caching and plain-text fallback. If your module declares `HALL_MODULE_PREVIEW_RENDERER="quick"`, the same call automatically uses the fast quick renderer instead.
- **`**Bold Title**` for headers**: Not `# Heading` — glow adds noisy decorations to ATX headings.
- **No leading `\n`**: The preview dispatcher adds dynamic leading padding — modules should not add their own.
- **No ANSI for headers**: Use markdown bold through glow. ANSI (`\033[1m`) is OK for status indicators and dynamic data.
- **No emoji**: Use `hall_icon()` for semantic icons (nerd font with unicode fallback).

Reference: `modules/editor/preview.sh` and `modules/memory/preview.sh` for the canonical style.

### Helper

```bash
source "$HALL_LIB_DIR/hall-common.sh"
hall_preview_prompt_content "Current prompt"
# Shows first 20 lines of $HALL_FILE with "... (N more lines)" indicator
```

---

## Environment

All three files receive these exported variables:

| Variable | Content |
|----------|---------|
| `HALL_DIR` | cc-hall root directory |
| `HALL_LIB_DIR` | `$HALL_DIR/lib` |
| `HALL_FILE` | Prompt file path (unquoted) |
| `HALL_SAFE_FILE` | Shell-quoted `$HALL_FILE` |
| `ORIGINAL_TMUX` | Outer tmux session (before cc-hall) |
| `HALL_STATE_DIR` | Temp dir for tab navigation state |
| `HALL_GLOW_STYLE` | Path to generated glow style JSON (theme-aware) |
| `HALL_MODULE_PREVIEW_RENDERER` | Resolved preview renderer for the current module (`auto`, `glow`, or `quick`) |

---

## Entry tagging

Modules output raw entries (`Label<TAB>command`). cc-hall inserts the module name before the command using `\x1f` (ASCII 31) as separator:

```
# Module outputs:
Label<TAB>my-command

# After tagging:
Label<TAB>mymodule\x1fmy-command

# Parsed by cc-hall:
HALL_ROUTE_MODULE="mymodule"
HALL_ROUTE_CMD="my-command"
```

This is transparent to the module — tagging and untagging is handled by cc-hall.

---

## Lifecycle

```
cc-hall startup
  ├─ Discover modules (source each module.sh in subshell for metadata)
  ├─ Sort by HALL_MODULE_ORDER
  ├─ Collect all HALL_MODULE_BINDINGS
  └─ Enter main loop
       │
       ├─ Build entries: source module.sh, call hall_{name}_entries()
       ├─ Tag entries, launch fzf
       │    ├─ Cursor moves → preview.sh (subprocess, per movement)
       │    ├─ Tab/Shift-Tab → switch module, rebuild entries
       │    └─ Enter → selection
       │
       └─ Route selection:
            ├─ on_select.sh "$cmd" "$file"  (if exists)
            │    ├─ exit 0 → close cc-hall
            │    ├─ exit 2 → rebuild, stay open
            │    └─ exit 1 → fall through
            └─ Built-in editor pattern (vi, code -w, etc.)
```

---

## Subcommands (stable module API)

`cc-hall` is in `$PATH` and provides subcommands that modules should use instead of sourcing internal scripts:

| Subcommand | Replaces | Purpose |
|------------|----------|---------|
| `cc-hall reload` | `$HALL_DIR/lib/hall-rebuild-menu.sh` | Rebuild current module entries (for fzf reload bindings) |
| `cc-hall preview {}` | `$HALL_DIR/lib/hall-preview.sh {}` | Preview dispatcher (strips routing tag, calls module preview.sh) |
| `cc-hall agent --mode auto\|interactive ...` | Sourcing `hall-agent.sh` + branching on tmux | Agent dispatch with automatic tmux detection |
| `cc-hall module link\|unlink\|list` | Manual `ln -s` into `~/.claude/hall/modules/` | Module registration and discovery |
| `cc-hall skill install\|uninstall` | Manual SKILL.md creation | Install/remove MODULE_API as Claude Code skill |

### cc-hall agent

```bash
cc-hall agent --mode auto|interactive \
    --system-prompt-file FILE \
    [--prompt TEXT] \
    [--model MODEL] \
    [--skip-permissions] \
    [--cleanup FILE ...] \
    [--window-name NAME] \
    [--env KEY=VAL ...] \
    [--message TEXT] \
    [--verbose] \
    [--wait-after]
```

**`--mode interactive`:** Opens claude in a new tmux window. Requires tmux.
**`--mode auto`:** Tmux available → spawns in new window. No tmux → runs blocking in current terminal.

### cc-hall module

```bash
cc-hall module link <path>                  # Register module (symlink)
cc-hall module unlink <name>                # Unregister module
cc-hall module list                         # Show all discovered modules
```

---

## Available libraries

Source from `$HALL_LIB_DIR` in on_select.sh or preview.sh:

| Library | Provides |
|---------|----------|
| `hall-common.sh` | Logging, parsing, temp files, `hall_preview_prompt_content`, `hall_icon()` |
| `hall-agent.sh` | `hall_spawn_agent`, `hall_spawn_agent_auto`, `hall_run_agent` |
| `hall-theme.sh` | `hall_ansi_bold`, `hall_ansi_dim`, `hall_section_header`, `hall_apply_glow_style` |
| `hall-render.sh` | `hall_render_markdown`, `hall_render_quick_markdown`, `hall_render_file` (cached renderers with theme-aware glow fallback) |
| `hall-config.sh` | `hall_config_set_string`, `hall_config_toggle_bool`, config mutation helpers |

Note: `hall-theme.sh` and `hall-menu.sh` are already sourced in the parent process, so their functions (`hall_section_header`, `hall_ansi_bold`, etc.) are available in `module.sh` without explicit sourcing. For new modules, prefer using `cc-hall agent` over sourcing `hall-agent.sh` directly.

---

## Naming conventions

| Namespace | Convention | Why |
|-----------|-----------|-----|
| Bash functions | `snake_case` | Bash syntax requires it |
| Menu commands | `kebab-case` | Strings, not identifiers |
| JSON config keys | `snake_case` | Project convention |
| Lib filenames | `kebab-case` | Unix convention |
