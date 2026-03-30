#!/usr/bin/env bash
# Command handler for git module
# Args: $1 = raw command (after \x1f split), $2 = prompt file path

set -e

source "${HALL_LIB_DIR}/hall-common.sh"

CMD="$1"

# ── Command routing ──────────────────────────────────────────

case "$CMD" in
    gs-noop)
        exit $HALL_RC_RELOAD ;;

    gs-file\ *)
        # Read-only — reload refreshes git status
        exit $HALL_RC_RELOAD ;;
esac

exit $HALL_RC_NOT_HANDLED
