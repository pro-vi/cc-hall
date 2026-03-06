#!/usr/bin/env bash
# hall-preview.sh - Preview dispatcher for cc-hall
# Called by fzf's --preview binding. Routes to the owning module's preview.sh.

HALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HALL_DIR="$(cd "$HALL_LIB_DIR/.." && pwd)"

source "$HALL_LIB_DIR/hall-common.sh"

LINE="$*"

if [ -z "$LINE" ]; then
    exit 0
fi

# Extract tagged command
tagged=$(printf '%s' "$LINE" | cut -d$'\t' -f2-)
if [ -z "$tagged" ]; then
    exit 0
fi

# Split route
hall_split_route "$tagged"
module="$HALL_ROUTE_MODULE"

if [ -z "$module" ]; then
    exit 0
fi

# Find module's preview.sh
source "$HALL_LIB_DIR/hall-menu.sh"
module_dir=$(hall_find_module_dir "$module")
preview_script=""
[ -n "$module_dir" ] && [ -f "$module_dir/preview.sh" ] && preview_script="$module_dir/preview.sh"

if [ -n "$preview_script" ]; then
    _pad=$(( ${FZF_PREVIEW_LINES:-40} / 12 ))
    [ "$_pad" -lt 1 ] && _pad=1
    for (( _i=0; _i<_pad; _i++ )); do printf '\n'; done
    exec bash "$preview_script" "$LINE"
fi
