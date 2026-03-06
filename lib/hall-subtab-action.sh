#!/usr/bin/env bash
# hall-subtab-action.sh - Generic sub-tab switching via fzf transform
# Called from fzf binding: left:transform($HALL_DIR/lib/hall-subtab-action.sh prev)
#
# Reads HALL_MODULE_SUBTABS from the active module. If empty, outputs nothing (no-op).
# Otherwise switches sub-tab index with wrapping, rebuilds entries, and outputs
# fzf action: reload()+change-header()

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"

DIRECTION="${1:-next}"
SUBTAB_FILE="$HALL_STATE_DIR/module-subtab"

# Read current module from state
mod_name=""
if [ -f "$HALL_STATE_DIR/modules" ]; then
    current_mod=$(<"$HALL_STATE_DIR/current")
    declare -a mod_lines=()
    while IFS= read -r line; do
        mod_lines+=("$line")
    done < "$HALL_STATE_DIR/modules"
    mod_name="${mod_lines[$current_mod]%%:*}"
fi

# Source module to get HALL_MODULE_SUBTABS (needed for count before switching)
HALL_MODULE_SUBTABS=()
if [ -n "$mod_name" ]; then
    mod_file=$(hall_find_module_file "$mod_name")
    [ -n "$mod_file" ] && source "$mod_file" 2>/dev/null
fi

SUBTAB_COUNT=${#HALL_MODULE_SUBTABS[@]}

# No subtabs → no-op (output empty string so fzf does nothing)
if [ "$SUBTAB_COUNT" -eq 0 ]; then
    exit 0
fi

# Read current subtab index
current=0
[ -f "$SUBTAB_FILE" ] && current=$(<"$SUBTAB_FILE")

# Compute new index with wrapping
if [ "$DIRECTION" = "next" ]; then
    new_idx=$(( (current + 1) % SUBTAB_COUNT ))
else
    new_idx=$(( (current - 1 + SUBTAB_COUNT) % SUBTAB_COUNT ))
fi

# Write new subtab index
echo "$new_idx" > "$SUBTAB_FILE"

# Clear and rebuild entries
rm -f "$HALL_STATE_DIR/module-header"
entries=$(hall_build_module_entries "$mod_name")
if [ -n "$entries" ]; then
    echo "$entries" | hall_tag_entries "$mod_name" > "$HALL_STATE_DIR/entries"
else
    hall_write_empty_state "$HALL_STATE_DIR/entries"
fi

# Render sub-tab header
subtab_header=$(hall_render_subtab_header "$new_idx" "${HALL_MODULE_SUBTABS[@]}")
printf '%s' "$subtab_header" > "$HALL_STATE_DIR/module-header"

# Build module tab header
declare -a _tab_labels=()
for i in "${!mod_lines[@]}"; do
    _r="${mod_lines[$i]#*:}"; _r="${_r#*:}"; _r="${_r#*:}"; _tab_labels+=("$_r")
done
_mod_idx=$(<"$HALL_STATE_DIR/current")
header=$(hall_build_tab_header "$_mod_idx" "${COLUMNS:-80}" "${_tab_labels[@]}")

# Append sub-tab header
if [ -f "$HALL_STATE_DIR/module-header" ]; then
    _sub_header=$(<"$HALL_STATE_DIR/module-header")
    header=$(printf '%s\n%s' "$header" "$_sub_header")
fi

# Output fzf action string
printf 'reload(cat %s)+change-header(%s)' \
    "$HALL_STATE_DIR/entries" "$header"
