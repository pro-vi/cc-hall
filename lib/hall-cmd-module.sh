#!/usr/bin/env bash
# hall-cmd-module.sh — cc-hall module link|unlink|list
# Module management: register, unregister, and list modules.

HALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HALL_DIR="$(cd "$HALL_LIB_DIR/.." && pwd)"

source "$HALL_LIB_DIR/hall-common.sh"
source "$HALL_LIB_DIR/hall-menu.sh"

MODULES_DIR="${HOME}/.claude/hall/modules"

_usage() {
    echo "Usage:" >&2
    echo "  cc-hall module link <path>                 Register a module" >&2
    echo "  cc-hall module unlink <name>               Unregister a module" >&2
    echo "  cc-hall module list                        List registered modules" >&2
    exit 1
}

subcmd="${1:-}"
shift 2>/dev/null || true

case "$subcmd" in
    link)
        mod_path=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --name)
                    echo "Error: --name is not supported; module entrypoints must match the source directory name" >&2
                    exit 1
                    ;;
                -*) echo "cc-hall module link: unknown option: $1" >&2; exit 1 ;;
                *) mod_path="$1"; shift ;;
            esac
        done

        if [ -z "$mod_path" ]; then
            echo "Error: path required" >&2
            _usage
        fi

        # Resolve to absolute path
        mod_path="$(cd "$mod_path" 2>/dev/null && pwd)" || {
            echo "Error: directory not found: $mod_path" >&2
            exit 1
        }

        # Validate module.sh exists
        if [ ! -f "$mod_path/module.sh" ]; then
            echo "Error: $mod_path/module.sh not found" >&2
            exit 1
        fi

        # Derive runtime name from directory basename so module function names match.
        mod_name="$(basename "$mod_path")"

        # Create modules dir and symlink
        mkdir -p "$MODULES_DIR"
        if [ -L "$MODULES_DIR/$mod_name" ] || [ -e "$MODULES_DIR/$mod_name" ]; then
            echo "Warning: $mod_name already registered, replacing" >&2
            rm -f "$MODULES_DIR/$mod_name"
        fi
        ln -s "$mod_path" "$MODULES_DIR/$mod_name"
        echo "Linked: $mod_name → $mod_path"
        ;;

    unlink)
        mod_name="${1:-}"
        if [ -z "$mod_name" ]; then
            echo "Error: module name required" >&2
            _usage
        fi

        target="$MODULES_DIR/$mod_name"
        if [ ! -L "$target" ] && [ ! -e "$target" ]; then
            echo "Error: module '$mod_name' not found in $MODULES_DIR" >&2
            exit 1
        fi

        # Safety: only remove symlinks
        if [ -L "$target" ]; then
            rm "$target"
            echo "Unlinked: $mod_name"
        else
            echo "Error: $target is not a symlink. Refusing to remove." >&2
            exit 1
        fi
        ;;

    list)
        discovered=$(hall_discover_modules)
        if [ -z "$discovered" ]; then
            echo "No modules found."
            exit 0
        fi

        printf '%-16s %-20s %s\n' "NAME" "LABEL" "PATH"
        printf '%-16s %-20s %s\n' "────" "─────" "────"
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            hall_parse_discovery_entry "$entry"
            printf '%-16s %-20s %s\n' "$HALL_ENTRY_NAME" "$HALL_ENTRY_LABEL" "$HALL_ENTRY_DIR"
        done <<< "$discovered"
        ;;

    *)
        _usage
        ;;
esac
