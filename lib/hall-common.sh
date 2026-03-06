#!/usr/bin/env bash
# hall-common.sh - Shared utilities for cc-hall and its modules
# Pure bash. No external runtime dependencies.

[ -n "${_HALL_COMMON_LOADED:-}" ] && return 0; _HALL_COMMON_LOADED=1

# Hall directory (where this lib lives)
HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
HALL_DIR="${HALL_DIR:-$(cd "$HALL_LIB_DIR/.." && pwd)}"

# ============================================================================
# CONSTANTS
# ============================================================================

# Field separator for tagged menu entries (ASCII Unit Separator)
HALL_FIELD_SEP=$'\x1f'

# Exit codes for on_select.sh handlers
HALL_RC_CLOSE=0      # handled, close menu
HALL_RC_NOT_HANDLED=1 # not handled, fall through
HALL_RC_RELOAD=2     # handled, reload menu

# Config file path (shared with cc-reflection)
HALL_CONFIG_FILE="${HOME}/.claude/reflections/config.json"

# ============================================================================
# LOGGING
# ============================================================================

HALL_LOG_DIR="${HALL_LOG_DIR:-${HOME}/.claude/hall/logs}"
mkdir -p "$HALL_LOG_DIR" 2>/dev/null || true
HALL_LOG_FILE="$HALL_LOG_DIR/cc-hall.log"

hall_log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"

    if [ ! -d "$HALL_LOG_DIR" ]; then
        mkdir -p "$HALL_LOG_DIR" 2>/dev/null || return 0
    fi
    if [ ! -w "$HALL_LOG_DIR" ]; then
        return 0
    fi

    {
        printf '[%s] [%s] [%s] %s\n' "$timestamp" "$level" "$caller" "$msg"
    } >>"$HALL_LOG_FILE" 2>/dev/null || true
}

hall_log_info() { hall_log INFO "$@"; }
hall_log_warn() { hall_log WARN "$@"; }
hall_log_error() { hall_log ERROR "$@"; }
hall_log_debug() { hall_log DEBUG "$@"; }

# ============================================================================
# MENU PARSING
# ============================================================================

# Parse command from menu selection
# Format: "Label text<TAB>[module\x1f]command args"
# Returns the full tagged command (caller splits on \x1f if needed)
hall_parse_command() {
    local choice="$1"

    if [ -z "$choice" ]; then
        hall_log_warn "Empty menu choice"
        return 1
    fi

    # Reject lines without tab delimiter (separators, malformed entries)
    if [[ "$choice" != *$'\t'* ]]; then
        hall_log_warn "No tab delimiter in: $choice"
        return 1
    fi

    local cmd
    cmd="${choice#*$'\t'}"

    if [ -z "$cmd" ]; then
        hall_log_warn "Failed to extract command from: $choice"
        return 1
    fi

    hall_log_debug "Extracted command: $cmd"
    echo "$cmd"
}

# Split tagged command into module name and raw command
# Input: "module_name\x1fraw command"
# Sets: HALL_ROUTE_MODULE, HALL_ROUTE_CMD
hall_split_route() {
    local tagged="$1"

    if [[ "$tagged" == *"$HALL_FIELD_SEP"* ]]; then
        HALL_ROUTE_MODULE="${tagged%%"$HALL_FIELD_SEP"*}"
        HALL_ROUTE_CMD="${tagged#*"$HALL_FIELD_SEP"}"
    else
        HALL_ROUTE_MODULE=""
        HALL_ROUTE_CMD="$tagged"
    fi
}

# Write a styled empty-state placeholder to an entries file.
# Usage: hall_write_empty_state "$HALL_STATE_DIR/entries"
hall_write_empty_state() {
    printf '\033[2m  No items\033[0m\techo\n' > "$1"
}

# Write a one-shot footer message for the next fzf render.
hall_set_footer_message() {
    local message="$*"
    [ -n "${HALL_STATE_DIR:-}" ] || return 0
    [ -d "$HALL_STATE_DIR" ] || return 0
    printf '%s\n' "$message" > "$HALL_STATE_DIR/footer-message"
}

# Read and clear any one-shot footer message.
hall_consume_footer_message() {
    local path="${HALL_STATE_DIR:-}/footer-message"
    [ -f "$path" ] || return 0
    cat "$path"
    rm -f "$path"
}

# Tag a module's entry lines with the module name
# Reads from stdin, outputs tagged lines to stdout
# Usage: echo "$entries" | hall_tag_entries "module_name"
hall_tag_entries() {
    local module_name="$1"
    awk -v mod="$module_name" -v sep="$HALL_FIELD_SEP" -F'\t' \
        'NF && NF>=2 { printf "%s\t%s%s%s\n", $1, mod, sep, substr($0, index($0,"\t")+1) }'
}

# ============================================================================
# PARAMETER VALIDATION
# ============================================================================

hall_require_param() {
    local all_valid=true

    while [ $# -gt 0 ]; do
        local name="$1"
        local value="$2"
        shift 2

        if [ -z "$value" ]; then
            hall_log_error "Required parameter missing: $name"
            echo "Error: Required parameter missing: $name" >&2
            all_valid=false
        fi
    done

    if [ "$all_valid" = false ]; then
        return 1
    fi
    return 0
}

# ============================================================================
# TEMP FILE MANAGEMENT
# ============================================================================

HALL_TMP_DIR="${HOME}/.claude/hall/tmp"

hall_mktemp() {
    local prefix="${1:-cc-hall}"
    mkdir -p "$HALL_TMP_DIR" 2>/dev/null

    local tmpfile
    tmpfile=$(mktemp "$HALL_TMP_DIR/${prefix}.XXXXXX") || {
        hall_log_error "Failed to create temp file with prefix: $prefix"
        return 1
    }

    hall_log_debug "Created temp file: $tmpfile"
    echo "$tmpfile"
}

hall_cleanup_on_exit() {
    local quoted_files=""
    for f in "$@"; do
        quoted_files="$quoted_files $(printf '%q' "$f")"
    done

    # shellcheck disable=SC2064
    trap "rm -f $quoted_files 2>/dev/null" EXIT INT TERM
    hall_log_debug "Registered cleanup for:$quoted_files"
}

# ============================================================================
# STRING UTILITIES
# ============================================================================

hall_sanitize_string() {
    local input="$1"
    echo "$input" | tr -cd '[:alnum:]._-' | tr '[:upper:]' '[:lower:]'
}

# ============================================================================
# NERD FONT DETECTION
# ============================================================================

hall_has_nerd_fonts() {
    if [ -n "$HALL_HAS_NERD_FONTS" ]; then
        [ "$HALL_HAS_NERD_FONTS" = "1" ] && return 0 || return 1
    fi

    if command -v fc-list &>/dev/null; then
        if fc-list 2>/dev/null | grep -qi "nerd"; then
            HALL_HAS_NERD_FONTS="1"
            return 0
        fi
    fi

    HALL_HAS_NERD_FONTS="0"
    return 1
}

# Get editor icon (Nerd Font)
# UTF-8 hex encoding for bash 3.x compatibility (macOS)
hall_get_editor_icon() {
    local editor="$1"

    if ! hall_has_nerd_fonts; then
        echo ""
        return
    fi

    case "$editor" in
    vim | vi)
        printf '\xee\x98\xab'
        ;;
    neovim | nvim)
        printf '\xee\xa0\xba'
        ;;
    sublime | subl)
        printf '\xee\x9e\xaa'
        ;;
    vscode | code | cursor | windsurf | zed | antigravity | agy)
        printf '\xee\xa3\x9a'
        ;;
    *)
        echo ""
        ;;
    esac
}

# Get semantic icon (Nerd Font → unicode fallback, no emoji)
# UTF-8 hex encoding for bash 3.x compatibility (macOS)
# Usage: icon=$(hall_icon guide)
hall_icon() {
    local name="$1"
    if hall_has_nerd_fonts; then
        case "$name" in
            guide)   printf '\xf3\xb0\x88\x99' ;;  # 󰈙 nf-md-file_document  U+F0219
            theme)   printf '\xf3\xb0\x8f\x98' ;;  # 󰏘 nf-md-palette        U+F03D8
            module)  printf '\xf3\xb0\x90\xb1' ;;  # 󰐱 nf-md-package_variant U+F0431
            skill)   printf '\xf3\xb1\x90\x8b' ;;  # 󱐋 nf-md-lightning_bolt  U+F140B
            file)    printf '\xf3\xb0\x88\x94' ;;  # 󰈔 nf-md-file            U+F0214
            memory)  printf '\xf3\xb0\x86\xbc' ;;  # 󰆼 nf-md-database        U+F01BC
            config)  printf '\xf3\xb0\x92\x93' ;;  # 󰒓 nf-md-cog             U+F0493
            toggle)  printf '\xf3\xb0\x94\xa1' ;;  # 󰔡 nf-md-toggle_switch   U+F0521
            *)       printf '' ;;
        esac
    else
        case "$name" in
            guide)  printf '◇' ;;
            theme)  printf '◈' ;;
            module) printf '◆' ;;
            skill)  printf '◇' ;;
            file)   printf '·' ;;
            memory) printf '○' ;;
            config) printf '◉' ;;
            toggle) printf '·' ;;
            *)      printf '' ;;
        esac
    fi
}

# ============================================================================
# AVAILABLE EDITORS
# ============================================================================

# List available editors as space-separated names.
# Always includes vim. Checks for GUI editors on PATH.
# Output: "vim code cursor zed" (etc.)
hall_available_editors() {
    if [ -n "${_HALL_CACHED_EDITORS:-}" ]; then
        printf '%s' "$_HALL_CACHED_EDITORS"; return
    fi
    local -a eds=("vim")
    command -v nvim &>/dev/null && eds+=("nvim")
    command -v code &>/dev/null && eds+=("code")
    command -v cursor &>/dev/null && eds+=("cursor")
    command -v windsurf &>/dev/null && eds+=("windsurf")
    command -v zed &>/dev/null && eds+=("zed")
    command -v subl &>/dev/null && eds+=("subl")
    command -v agy &>/dev/null && eds+=("agy")
    _HALL_CACHED_EDITORS="${eds[*]}"
    printf '%s' "$_HALL_CACHED_EDITORS"
}

# Get the editor launch command for a given editor name and file path.
# Handles the -w/--wait flags needed by GUI editors.
# Args: $1 = editor name, $2 = file path
# Output: command string ready for exec
hall_editor_cmd() {
    local ed="$1" filepath="$2"
    case "$ed" in
        vim|vi)       printf "vi '%s'" "$filepath" ;;
        neovim|nvim)  printf "nvim '%s'" "$filepath" ;;
        code)         printf "code -w '%s'" "$filepath" ;;
        cursor)       printf "cursor -w '%s'" "$filepath" ;;
        windsurf)     printf "windsurf -w '%s'" "$filepath" ;;
        zed)          printf "zed --wait '%s'" "$filepath" ;;
        subl|sublime) printf "subl -w '%s'" "$filepath" ;;
        agy)          printf "agy -w '%s'" "$filepath" ;;
        *)            printf "vi '%s'" "$filepath" ;;
    esac
}

# ============================================================================
# PREVIEW COMMAND EXTRACTION
# ============================================================================

# Extract the raw command from a fzf menu line for preview handlers.
# Input: full fzf line "label\tmodule\x1fcommand"
# Sets: HALL_PREVIEW_CMD (the raw command after module prefix)
# Returns 1 if line is empty or unparseable.
hall_preview_extract_cmd() {
    local line="$1"
    [ -z "$line" ] && return 1
    HALL_PREVIEW_CMD="${line#*$'\t'}"
    if [[ "$HALL_PREVIEW_CMD" == *"$HALL_FIELD_SEP"* ]]; then
        HALL_PREVIEW_CMD="${HALL_PREVIEW_CMD#*"$HALL_FIELD_SEP"}"
    fi
    [ -z "$HALL_PREVIEW_CMD" ] && return 1
    return 0
}

# ============================================================================
# PREVIEW HELPERS
# ============================================================================

# Show current prompt file content in preview pane.
# Opt-in helper for modules that want to display the prompt.
# Vertically center stdin content in the fzf preview pane.
# Usage: { your content } | hall_preview_vcenter
hall_preview_vcenter() {
    local content
    content=$(cat)
    local lines
    lines=$(printf '%s\n' "$content" | wc -l)
    lines="${lines// /}"
    local available="${FZF_PREVIEW_LINES:-40}"
    local pad=$(( (available - lines) / 2 ))
    if [ "$pad" -gt 1 ]; then
        local i
        for (( i=0; i<pad; i++ )); do printf '\n'; done
    fi
    printf '%s\n' "$content"
}

hall_preview_prompt_content() {
    local label="${1:-Current prompt}"
    if [ -n "${HALL_FILE:-}" ] && [ -f "$HALL_FILE" ]; then
        # Skip if file is empty or whitespace-only
        local content
        content=$(<"$HALL_FILE")
        [[ -z "${content// /}" ]] && return 0
        source "$HALL_LIB_DIR/hall-render.sh" 2>/dev/null || true
        printf '\n**%s**\n' "$label" | hall_render_markdown
        printf '\n'
        # Display first 20 lines from already-read content (no head/wc subprocesses)
        local total=0 shown=0
        while IFS= read -r _line; do
            total=$((total + 1))
            if [ "$shown" -lt 20 ]; then
                printf '  %s\n' "$_line"
                shown=$((shown + 1))
            fi
        done <<< "$content"
        if [ "$total" -gt 20 ]; then
            printf '\n  \033[2m... (%s more lines)\033[0m\n' "$((total - 20))"
        fi
    fi
}
