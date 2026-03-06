#!/usr/bin/env bash
# hall-help-toggle.sh - Toggle help overlay state
# Called from fzf binding: ?:transform(...)
# Flips flag file and outputs fzf actions (preview label + refresh).

FLAG="$HALL_STATE_DIR/help-active"

if [ -f "$FLAG" ]; then
    rm -f "$FLAG"
    printf 'change-preview-label( Details )+change-preview-window(right:50%%:wrap:border-left)+refresh-preview'
else
    touch "$FLAG"
    printf 'change-preview-label( Help )+change-preview-window(right:50%%:wrap:border-left)+refresh-preview'
fi
