#!/usr/bin/env bash
# Preview handler for cc-hall module (app settings + modules)
# Receives: $1=clean command, $2=label (routing tag stripped by cc-hall)

set -e

HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"
source "$HALL_LIB_DIR/hall-render.sh"

HALL_PREVIEW_CMD="$1"
[ -z "$HALL_PREVIEW_CMD" ] && exit 0

case "$HALL_PREVIEW_CMD" in
    hall-info\ guide)
        cat <<'EOF' | hall_render_markdown
**Hall**

cc-hall is the Ctrl-G menu for Claude Code.
Navigate tabs with **Tab** / **Shift-Tab**.

**Theme** — switch the visual palette across
fzf and tmux. Three built-in themes:

| Theme | Feel |
|-------|------|
| **Mirrors** | Ice blue, midnight (default) |
| **Clawd** | Terracotta, warm dark |
| **Zinc** | Monochrome, shadcn/ui |

**Modules** — enable or disable tabs. Core modules
(Editor, Hall) are always present. Community modules
can be linked with `cc-hall module link <path>`.

EOF
        ;;
    pa-toggle-theme)
        cat <<'EOF' | hall_render_markdown
**Theme**

| Theme | Description |
|-------|-------------|
| **Mirrors** | Ice blue / midnight. Default. |
| **Clawd** | Terracotta / warm dark. |
| **Zinc** | Monochrome zinc scale. shadcn/ui. |

Cycles: Mirrors → Clawd → Zinc → Mirrors

Changes fzf colors and tmux window styling.
EOF
        exit 0 ;;

    module-toggle:*)
        mod_name="${HALL_PREVIEW_CMD#module-toggle:}"

        # Resolve module metadata from discovery
        source "$HALL_LIB_DIR/hall-config.sh"
        _hall_load_config

        mod_label=""
        mod_order=""
        disc=$(hall_discover_modules)
        while IFS= read -r dentry; do
            [ -z "$dentry" ] && continue
            hall_parse_discovery_entry "$dentry"
            if [ "$HALL_ENTRY_NAME" = "$mod_name" ]; then
                mod_label="${HALL_ENTRY_LABEL:-$mod_name}"
                mod_order=$(echo "$dentry" | cut -d: -f1)
                break
            fi
        done <<< "$disc"

        mod_dir=$(hall_find_module_dir "$mod_name")

        # ── Per-module description ──────────────────────
        case "$mod_name" in
            cc-hall)
                cat <<EOF | hall_render_markdown
**${mod_label:-$mod_name}**

App settings and module management.
Toggle themes, manage installed modules.

> Settings panel — cannot be disabled.
EOF
                ;;
            editor)
                cat <<EOF | hall_render_markdown
**${mod_label:-$mod_name}**

Prompt editing and agent launching.
Open your prompt in **vim**, **VS Code**, **Cursor**, or send it to the **Prompt Agent** for AI-powered enhancement.

> Core module — cannot be disabled.
EOF
                ;;
            reflection)
                cat <<EOF | hall_render_markdown
**${mod_label:-$mod_name}**

Reflection seed viewer and settings.
Browse, archive, and expand seeds captured during coding sessions. Configure expansion mode, model, and context turns.

> Provided by the **cc-reflection** project.
EOF
                ;;
            skill-viewer)
                cat <<EOF | hall_render_markdown
**${mod_label:-$mod_name}**

Browse and invoke Claude Code skills.
Selecting a skill appends \`/skill-name\` to your prompt, triggering it when Claude processes the message.
EOF
                ;;
            *)
                # Generic fallback for unknown/user modules
                desc=""
                if [ -n "$mod_dir" ] && [ -f "$mod_dir/module.sh" ]; then
                    desc=$(sed -n '2s/^# *//p' "$mod_dir/module.sh")
                fi
                if [ -n "$desc" ]; then
                    printf '**%s**\n\n%s\n' "${mod_label:-$mod_name}" "$desc" | hall_render_markdown
                else
                    printf '**%s**\n\nNo description available.\n' "${mod_label:-$mod_name}" | hall_render_markdown
                fi
                ;;
        esac

        # ── Attributes ──────────────────────────────────
        printf '\n'
        printf '**Details**\n\n' | hall_render_markdown
        printf '  Name:     %s\n' "$mod_name"
        [ "$mod_label" != "$mod_name" ] && \
            printf '  Label:    %s\n' "$mod_label"
        printf '  Order:    %s\n' "${mod_order:-50}"

        if [ -n "$mod_dir" ]; then
            if [[ "$mod_dir" == "$HALL_DIR/modules/"* ]]; then
                printf '  Location: built-in\n'
            else
                printf '  Location: user\n'
            fi
            # File list
            printf '  Files:    '
            first=true
            for f in "$mod_dir"/*.sh; do
                [ -f "$f" ] || continue
                if $first; then
                    printf '%s\n' "$(basename "$f")"
                    first=false
                else
                    printf '            %s\n' "$(basename "$f")"
                fi
            done
        fi

        # ── Status ──────────────────────────────────────
        printf '\n'
        if [ "$mod_name" = "cc-hall" ] || [ "$mod_name" = "editor" ]; then
            printf '  Status:   ✓ core\n'
        elif hall_is_module_disabled "$mod_name"; then
            printf '  Status:   ✗ disabled\n'
            printf '  ⏎ Select to enable\n'
        else
            printf '  Status:   ✓ enabled\n'
            printf '  ⏎ Select to disable\n'
        fi
        exit 0 ;;
esac

exit 0
