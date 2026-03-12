#!/usr/bin/env bash
# Command handler for usage module

source "${HALL_LIB_DIR}/hall-common.sh"

case "${1:-}" in
    usage-info\ *|usage-show\ *)
        exit $HALL_RC_RELOAD
        ;;
    usage-refresh)
        rm -rf "${HALL_STATE_DIR:-}/usage" 2>/dev/null
        exit $HALL_RC_RELOAD
        ;;
esac

exit $HALL_RC_NOT_HANDLED
