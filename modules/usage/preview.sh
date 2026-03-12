#!/usr/bin/env bash
# Preview handler for usage module
# Receives: $1=clean command, $2=label (routing tag stripped by cc-hall)

set -e

HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-render.sh"

HALL_PREVIEW_CMD="$1"
[ -z "$HALL_PREVIEW_CMD" ] && exit 0

case "$HALL_PREVIEW_CMD" in
    usage-info\ guide)
        cat <<'EOF' | hall_render_markdown
**Usage**

Local usage analytics from Claude Code transcripts under `~/.claude/projects/`.

**What is exact**

- token totals from assistant usage records
- daily / project / model breakdowns
- subagent usage folded into the same totals

**What is estimated**

- API cost, derived from transcript `costUSD` (when available) or rate-based calculation
- fast mode multiplier (6x for Opus 4.5/4.6) and long context surcharges applied automatically

**What Hall does not fake**

- weekly subscription quota remaining
- current live burn for an active session
- rate limit events are detected from `isApiErrorMessage` entries

Use `Refresh snapshot` after a long session if you want the current Hall popup to rescan transcripts.
EOF
        ;;
    usage-info\ unavailable)
        cat <<'EOF' | hall_render_markdown
**Usage snapshot unavailable**

Hall could not build the local usage snapshot.

Checks:
- Bun is installed and available on `PATH`
- `~/.claude/projects/` exists
- the current Hall state directory is writable
EOF
        ;;
    usage-info\ building)
        cat <<'EOF' | hall_render_markdown
**Usage snapshot building**

Hall is scanning local Claude transcripts in the background.

The first build can take a few seconds on large histories.
Tab away and back, or use `Refresh snapshot`, once the build finishes.
EOF
        ;;
    usage-refresh)
        cat <<'EOF' | hall_render_markdown
**Refresh snapshot**

Clears Hall's session-local usage cache and rebuilds it on the next render.

This does not modify Claude Code settings or transcripts.
EOF
        ;;
    usage-show\ *)
        preview_file="${HALL_STATE_DIR:-}/usage/previews/${HALL_PREVIEW_CMD#usage-show }.md"
        if [ -f "$preview_file" ]; then
            hall_render_markdown < "$preview_file"
        else
            cat <<'EOF' | hall_render_markdown
**Usage detail unavailable**

The requested usage preview is missing from the current session cache.
Use `Refresh snapshot` to rebuild it.
EOF
        fi
        ;;
esac

exit 0
