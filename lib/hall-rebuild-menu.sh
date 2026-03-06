#!/usr/bin/env bash
# hall-rebuild-menu.sh - Rebuild current module's entries
# Called from fzf reload bindings (e.g. after toggle, delete, archive)
# Reads current module from state and outputs its tagged entries.

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ -L "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || readlink "$SCRIPT_PATH")"
fi
export HALL_LIB_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
export HALL_DIR="$(cd "$HALL_LIB_DIR/.." && pwd)"

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"
source "$HALL_LIB_DIR/hall-theme.sh"

# Read current module from state
idx=$(<"$HALL_STATE_DIR/current")

declare -a mod_lines=()
while IFS= read -r line; do
    mod_lines+=("$line")
done < "$HALL_STATE_DIR/modules"

mod_name=$(echo "${mod_lines[$idx]}" | cut -d: -f1)

# Build entries for current module
entries=$(hall_build_module_entries "$mod_name")
if [ -n "$entries" ]; then
    echo "$entries" | hall_tag_entries "$mod_name"
fi
