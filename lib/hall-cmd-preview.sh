#!/usr/bin/env bash
# hall-cmd-preview.sh — cc-hall preview
# Preview dispatcher for fzf. Strips routing tag, passes clean args to module preview.sh.

HALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HALL_DIR="$(cd "$HALL_LIB_DIR/.." && pwd)"
HALL_FIELD_SEP=$'\x1f'

LINE="$*"

if [ -z "$LINE" ]; then
    exit 0
fi

# Extract label + tagged command with pure bash (hot path for cursor movement)
case "$LINE" in
    *$'\t'*)
        label="${LINE%%$'\t'*}"
        tagged="${LINE#*$'\t'}"
        ;;
    *)
        exit 0
        ;;
esac

if [ -z "$tagged" ]; then
    exit 0
fi

case "$tagged" in
    *"$HALL_FIELD_SEP"*)
        module="${tagged%%"$HALL_FIELD_SEP"*}"
        clean_cmd="${tagged#*"$HALL_FIELD_SEP"}"
        ;;
    *)
        module=""
        clean_cmd="$tagged"
        ;;
esac

if [ -z "$module" ]; then
    exit 0
fi

# Resolve module directory from state first to avoid sourcing discovery helpers.
module_dir=""
preview_renderer="auto"
if [ -n "${HALL_STATE_DIR:-}" ] && [ -f "$HALL_STATE_DIR/modules" ]; then
    while IFS= read -r mod_line; do
        case "$mod_line" in
            "$module":*)
                _mod_rest="${mod_line#*:}"
                module_dir="${_mod_rest%%:*}"
                break
                ;;
        esac
    done < "$HALL_STATE_DIR/modules"
fi

if [ -n "${HALL_STATE_DIR:-}" ] && [ -f "$HALL_STATE_DIR/module-preview-renderers" ]; then
    while IFS= read -r renderer_line; do
        case "$renderer_line" in
            "$module":*)
                preview_renderer="${renderer_line#*:}"
                break
                ;;
        esac
    done < "$HALL_STATE_DIR/module-preview-renderers"
fi

if [ -z "$module_dir" ] && [ -d "${HOME}/.claude/hall/modules/$module" ]; then
    module_dir="${HOME}/.claude/hall/modules/$module"
elif [ -z "$module_dir" ] && [ -d "$HALL_DIR/modules/$module" ]; then
    module_dir="$HALL_DIR/modules/$module"
fi

preview_script=""
[ -n "$module_dir" ] && [ -f "$module_dir/preview.sh" ] && preview_script="$module_dir/preview.sh"

if [ -n "$preview_script" ]; then
    _pad=$(( ${FZF_PREVIEW_LINES:-40} / 12 ))
    [ "$_pad" -lt 1 ] && _pad=1
    for (( _i=0; _i<_pad; _i++ )); do printf '\n'; done

    export HALL_MODULE_PREVIEW_RENDERER="${preview_renderer:-auto}"
    exec bash "$preview_script" "$clean_cmd" "$label"
fi
