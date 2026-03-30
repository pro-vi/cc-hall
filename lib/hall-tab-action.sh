#!/usr/bin/env bash
# hall-tab-action.sh - Synchronous tab switching via fzf transform
# Called from fzf binding: tab:transform($HALL_DIR/lib/hall-tab-action.sh next)
#
# Runs synchronously (transform blocks until complete), then outputs an fzf
# action string that atomically reloads entries + updates label + updates header.
# This avoids the race condition of reload()+transform-header() where the header
# file gets read before the reload command finishes writing it.

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"

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

# Write new index to state
echo "$new_idx" > "$HALL_STATE_DIR/current"

# Parse module info (format: name:dir:icon:label)
_line="${mod_lines[$new_idx]}"
mod_name="${_line%%:*}"
_r="${_line#*:}"; _r="${_r#*:}"; _r="${_r#*:}"; mod_label="$_r"

# Reset sub-tab index to 0 for the new module
echo 0 > "$HALL_STATE_DIR/module-subtab"

# Clear module-specific sub-header and help overlay state
rm -f "$HALL_STATE_DIR/module-header"
rm -f "$HALL_STATE_DIR/help-active"

# Init module arrays, then source module.sh in current shell so globals like
# HALL_MODULE_SUBTABS survive (hall_build_module_entries runs in $() subshell)
HALL_MODULE_FZF_OPTS=()
HALL_MODULE_SUBTABS=()
HALL_MODULE_FOOTER=""
HALL_MODULE_PREVIEW_WINDOW=""
_search_action=""

_mod_file=$(hall_find_module_file "$mod_name")
[ -n "$_mod_file" ] && source "$_mod_file" 2>/dev/null

# Build entries and write to file (reload reads from here)
entries=$(hall_build_module_entries "$mod_name")
if [ -n "$entries" ]; then
    echo "$entries" | hall_tag_entries "$mod_name" > "$HALL_STATE_DIR/entries"
else
    hall_write_empty_state "$HALL_STATE_DIR/entries"
fi

# Render sub-tab header if target module has subtabs
if [ ${#HALL_MODULE_SUBTABS[@]} -gt 0 ]; then
    hall_render_subtab_header 0 "${HALL_MODULE_SUBTABS[@]}" > "$HALL_STATE_DIR/module-header"
fi

# Build carousel tab header from labels
declare -a _tab_labels=()
for i in "${!mod_lines[@]}"; do
    _r="${mod_lines[$i]#*:}"; _r="${_r#*:}"; _r="${_r#*:}"; _tab_labels+=("$_r")
done
header=$(hall_build_tab_header "$new_idx" "${COLUMNS:-80}" "${_tab_labels[@]}")

# Append module-specific sub-header (subtabs or module-written during entry generation)
if [ -f "$HALL_STATE_DIR/module-header" ]; then
    _sub_header=$(<"$HALL_STATE_DIR/module-header")
    header=$(printf '%s\n%s' "$header" "$_sub_header")
fi
# Reset search on tab switch: disable filtering and clear query
_search_action=""

# Compute unbind/rebind for binding scoping
# Old module = previous tab's module
old_mod_name="${mod_lines[$current]%%:*}"
# Framework keys that must never be unbound by module scoping
_framework_keys=""

_bind_actions=""
if [ "$old_mod_name" != "$mod_name" ]; then
    _unbind_keys=""
    if [ -f "$HALL_STATE_DIR/mod-keys/$old_mod_name" ]; then
        while IFS= read -r k; do
            [ -z "$k" ] && continue
            case ",$_framework_keys," in *",$k,"*) continue ;; esac
            _unbind_keys="${_unbind_keys:+$_unbind_keys,}$k"
        done < "$HALL_STATE_DIR/mod-keys/$old_mod_name"
    fi
    _rebind_keys=""
    if [ -f "$HALL_STATE_DIR/mod-keys/$mod_name" ]; then
        while IFS= read -r k; do
            [ -z "$k" ] && continue
            case ",$_framework_keys," in *",$k,"*) continue ;; esac
            _rebind_keys="${_rebind_keys:+$_rebind_keys,}$k"
        done < "$HALL_STATE_DIR/mod-keys/$mod_name"
    fi
    [ -n "$_unbind_keys" ] && _bind_actions="+unbind($_unbind_keys)"
    [ -n "$_rebind_keys" ] && _bind_actions="${_bind_actions}+rebind($_rebind_keys)"
fi

# Rebuild help file for new module
hall_build_help_file "$HALL_STATE_DIR/help" "$MOD_COUNT" "$mod_name"

# Module-specific footer (fall back to default)
_footer="${HALL_MODULE_FOOTER:- ? help }"

# Preview window: module can request hidden (default: restore standard layout)
_preview_action="+change-preview-window(right:50%:border-left)"
[ "$HALL_MODULE_PREVIEW_WINDOW" = "hidden" ] && _preview_action="+change-preview-window(hidden)"

# Output fzf action string — all values are pre-computed, no file reads needed
# for label/header. Entries are in the file (written above, before this output).
printf 'reload(cat %s)+change-border-label( %s )+change-header(%s)+change-footer(%s)%s%s%s' \
    "$HALL_STATE_DIR/entries" "$mod_label" "$header" "$_footer" "$_preview_action" "$_search_action" "$_bind_actions"
