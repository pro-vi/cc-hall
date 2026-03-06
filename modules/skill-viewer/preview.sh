#!/usr/bin/env bash
# Preview handler for skill-viewer module
# Receives: $1=clean command, $2=label (routing tag stripped by cc-hall)

set -e

HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-render.sh"

HALL_PREVIEW_CMD="$1"
[ -z "$HALL_PREVIEW_CMD" ] && exit 0

case "$HALL_PREVIEW_CMD" in
    skill-noop)
        exit 0 ;;
    skill-info\ guide)
        cat <<'EOF' | hall_render_markdown
**Skills**

Browse and invoke Claude Code skills.

**Project** skills live in `.claude/skills/`
and are scoped to the current repository.

**Global** skills live in `~/.claude/skills/`
and are available across all projects.

*Select a skill to invoke it as a slash command.*
EOF
        exit 0 ;;
    skill-invoke\ *)
        # skill-invoke <name> <filepath> — extract file path
        rest="${HALL_PREVIEW_CMD#skill-invoke }"
        skill_file="${rest#* }"
        [ -f "$skill_file" ] || { echo "  File not found: $skill_file"; exit 0; }

        # Strip YAML frontmatter, pipe to shared renderer
        awk '/^---$/ { block++; next } block >= 2 { print }' "$skill_file" \
            | hall_render_markdown
        ;;
esac

exit 0
