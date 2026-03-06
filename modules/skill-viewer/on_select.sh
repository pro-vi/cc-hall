#!/usr/bin/env bash
# Command handler for skill-viewer module
# Args: $1 = raw command (after \x1f split), $2 = prompt file path

set -e

source "${HALL_LIB_DIR}/hall-common.sh"

CMD="$1"
FILE="$2"

case "$CMD" in
    skill-noop)
        # Group header/footer — no action
        exit $HALL_RC_RELOAD ;;
    skill-info\ *)
        # Guide/info entries — preview only, no action
        exit $HALL_RC_RELOAD ;;
    skill-invoke\ *)
        # Extract skill name (first arg after command)
        rest="${CMD#skill-invoke }"
        skill_name="${rest%% *}"
        # Guard: skip if name is empty
        [ -z "$skill_name" ] && exit $HALL_RC_NOT_HANDLED
        # Append /skill-name to prompt file and close hall
        printf '/%s' "$skill_name" >> "$FILE"
        exit $HALL_RC_CLOSE ;;
esac

exit $HALL_RC_NOT_HANDLED
