#!/usr/bin/env bash
# hall-switch-module.sh - Tab/Shift-Tab module switching
# Called from fzf binding: reload($HALL_DIR/lib/hall-switch-module.sh next)
# Outputs new module's tagged entries to stdout for fzf reload.
# Also writes border-label and header to state files for transform bindings.

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"
source "$HALL_LIB_DIR/hall-theme.sh"

DIRECTION="${1:-next}"

# Read module list from state
declare -a mod_lines=()
while IFS= read -r line; do
    mod_lines+=("$line")
done < "$HALL_STATE_DIR/modules"
MOD_COUNT=${#mod_lines[@]}

# Read current index
current=$(<"$HALL_STATE_DIR/current")

# Compute new index
if [ "$DIRECTION" = "next" ]; then
    new_idx=$(( (current + 1) % MOD_COUNT ))
else
    new_idx=$(( (current - 1 + MOD_COUNT) % MOD_COUNT ))
fi

# Write new index
echo "$new_idx" > "$HALL_STATE_DIR/current"

# Parse module info (format: name:dir:label)
mod_name=$(echo "${mod_lines[$new_idx]}" | cut -d: -f1)
mod_label=$(echo "${mod_lines[$new_idx]}" | cut -d: -f3-)

# Write label for transform-border-label
printf ' %s ' "$mod_label" > "$HALL_STATE_DIR/label"

# Write tab header for transform-header
# Current tab is bold, others are dim: "  ▸ Editors │ Reflection Seeds  "
header=""
for i in "${!mod_lines[@]}"; do
    lbl=$(echo "${mod_lines[$i]}" | cut -d: -f3-)
    if [ "$i" -eq "$new_idx" ]; then
        tab=$(printf '\033[1m▸ %s\033[0m' "$lbl")
    else
        tab=$(printf '\033[2m  %s\033[0m' "$lbl")
    fi
    header="${header:+$header  │  }$tab"
done
printf '  %s  ' "$header" > "$HALL_STATE_DIR/header"

# Output new module entries for fzf reload
entries=$(hall_build_module_entries "$mod_name")
if [ -n "$entries" ]; then
    echo "$entries" | hall_tag_entries "$mod_name"
fi
