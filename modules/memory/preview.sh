#!/usr/bin/env bash
# Preview handler for memory module
# Receives: $1=clean command, $2=label (routing tag stripped by cc-hall)

set -e

HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-render.sh"

HALL_PREVIEW_CMD="$1"
[ -z "$HALL_PREVIEW_CMD" ] && exit 0

case "$HALL_PREVIEW_CMD" in

    # ── Guide ────────────────────────────────────────────────

    mv-info\ guide)
        cat <<'EOF' | hall_render_markdown
**Memory — What Claude Loads**

Claude reads instructions from several layers,
loaded in order of priority:

| Layer | Files |
|-------|-------|
| **Project** | `CLAUDE.md`, `CLAUDE.local.md` |
| **User** | `~/.claude/CLAUDE.md` |
| **Auto** | `~/.claude/projects/<slug>/memory/` |

**MEMORY.md** is always loaded (200 lines).
Topic files are loaded on demand.

Select a file to open in your editor.
EOF
        exit 0 ;;

    mv-info\ no-auto)
        cat <<'EOF' | hall_render_markdown
**No Auto Memory**

Claude hasn't created any auto memory files for this project yet.

Auto memory is written when Claude learns patterns or preferences during conversations.

The files will appear at:
`~/.claude/projects/<slug>/memory/`
EOF
        exit 0 ;;

    # ── Section headers ──────────────────────────────────────

    mv-section:*)
        _mv_name="${HALL_PREVIEW_CMD#mv-section:}"
        case "$_mv_name" in
            Project)
                cat <<'EOF' | hall_render_markdown
**Project Memory**

Instructions scoped to this project:

| File | Description |
|------|-------------|
| `CLAUDE.md` | Checked-in project instructions. Shared with all contributors. |
| `CLAUDE.local.md` | Private project instructions. Not checked into git. |
| `.claude/CLAUDE.local.md` | Alternative location for private project instructions. |

Press Enter to expand/collapse.
EOF
                ;;
            User)
                cat <<'EOF' | hall_render_markdown
**User Memory**

Global instructions that apply to all projects.

`~/.claude/CLAUDE.md` — Your private global instructions.
Loaded into every Claude session.

Press Enter to expand/collapse.
EOF
                ;;
            Auto)
                cat <<'EOF' | hall_render_markdown
**Auto Memory**

Files Claude creates to remember patterns and preferences for this project.

| File | Description |
|------|-------------|
| `MEMORY.md` | Main auto memory (200 lines). Always loaded. |
| `<topic>.md` | Topic-specific. Loaded on demand. |

Location: `~/.claude/projects/<slug>/memory/`

Press Enter to expand/collapse.
EOF
                ;;
        esac
        exit 0 ;;

    # ── Editor toggle ──────────────────────────────────────────

    mv-toggle-editor)
        source "$HALL_LIB_DIR/hall-config.sh"
        _hall_load_config
        _mv_eds=$(hall_available_editors)
        printf '**Preferred Editor**\n\n' | hall_render_markdown
        printf '  Select which editor opens memory files.\n'
        printf '  Press Enter to cycle.\n\n'
        for _mv_ed in $_mv_eds; do
            if [ "$_mv_ed" = "$_PA_MEMORY_EDITOR" ]; then
                printf '  \033[1m● %s\033[0m\n' "$_mv_ed"
            else
                printf '  \033[2m○ %s\033[0m\n' "$_mv_ed"
            fi
        done
        exit 0 ;;

    # ── File entries ─────────────────────────────────────────

    mv-open\ *)
        _mv_path="${HALL_PREVIEW_CMD#mv-open }"

        if [ ! -f "$_mv_path" ]; then
            printf '  %s\n\n' "$_mv_path"
            printf '  \033[2mFile does not exist.\033[0m\n'
            printf '  \033[2mPress Enter to create it in your editor.\033[0m\n'
            exit 0
        fi

        # File header: path, line count, last modified
        _mv_lines=$(wc -l < "$_mv_path" 2>/dev/null | tr -d ' ')
        _mv_modified=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$_mv_path" 2>/dev/null || \
                       stat -c '%y' "$_mv_path" 2>/dev/null | cut -d. -f1 || \
                       echo "unknown")

        printf '**%s**\n' "$_mv_path" | hall_render_markdown
        printf '  \033[2m%s lines · modified %s\033[0m\n\n' "$_mv_lines" "$_mv_modified"

        # Render file content
        hall_render_file "$_mv_path" 50
        exit 0 ;;

esac

exit 0
