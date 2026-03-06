#!/usr/bin/env bash
# hall-cmd-reload.sh — cc-hall reload
# Rebuild current module's entries. Drop-in replacement for hall-rebuild-menu.sh.
# Called from fzf reload bindings (e.g. after toggle, delete, archive).

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ -L "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || readlink "$SCRIPT_PATH")"
fi
export HALL_LIB_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
export HALL_DIR="$(cd "$HALL_LIB_DIR/.." && pwd)"

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"

# Read current module from state
idx=$(<"$HALL_STATE_DIR/current")

declare -a mod_lines=()
while IFS= read -r line; do
    mod_lines+=("$line")
done < "$HALL_STATE_DIR/modules"

mod_name="${mod_lines[$idx]%%:*}"

# Build entries for current module
entries=$(hall_build_module_entries "$mod_name")
if [ -n "$entries" ]; then
    echo "$entries" | hall_tag_entries "$mod_name"
fi
