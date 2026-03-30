#!/usr/bin/env bash
# hall-help-toggle.sh - Toggle help overlay state
# Called from fzf binding: ?:transform(...)
# Flips flag file and outputs fzf actions (preview label + refresh).

FLAG="$HALL_STATE_DIR/help-active"
_DEFAULT_PW="right:50%:border-left"

# Read current module's preferred preview window from state
if [ -f "$HALL_STATE_DIR/modules" ] && [ -f "$HALL_STATE_DIR/current" ]; then
    _idx=$(<"$HALL_STATE_DIR/current")
    _mod_line=$(sed -n "$((_idx + 1))p" "$HALL_STATE_DIR/modules")
    _mod_name="${_mod_line%%:*}"
    _pw_file="$HALL_STATE_DIR/module-preview-window"
    if [ -f "$_pw_file" ]; then
        while IFS= read -r _line; do
            case "$_line" in "$_mod_name:"*) _DEFAULT_PW="${_line#*:}"; break ;; esac
        done < "$_pw_file"
    fi
fi

if [ -f "$FLAG" ]; then
    rm -f "$FLAG"
    printf 'change-preview-label( Details )+change-preview-window(%s)+refresh-preview' "$_DEFAULT_PW"
else
    touch "$FLAG"
    printf 'change-preview-label( Help )+change-preview-window(right:50%%:wrap:border-left)+refresh-preview'
fi
