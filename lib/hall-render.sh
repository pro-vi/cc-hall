#!/usr/bin/env bash
# hall-render.sh - Shared rendering utilities for preview panes
# Provides glow-based markdown/JSON rendering with plain-text fallback.
# Source after hall-common.sh (needs HALL_LIB_DIR).

[ -n "${_HALL_RENDER_LOADED:-}" ] && return 0; _HALL_RENDER_LOADED=1

HALL_GLOW_STYLE="${HALL_GLOW_STYLE:-${HALL_LIB_DIR}/glow-style.json}"
HALL_GLOW_PREVIEW_STYLE="${HALL_GLOW_PREVIEW_STYLE:-${HALL_LIB_DIR}/glow-preview-style.json}"

# Cache glow and python3 availability (avoids repeated command -v subprocess spawns)
if [ -z "${_HALL_HAS_GLOW:-}" ]; then
    command -v glow &>/dev/null && _HALL_HAS_GLOW=1 || _HALL_HAS_GLOW=0
fi
if [ -z "${_HALL_HAS_PYTHON3:-}" ]; then
    command -v python3 &>/dev/null && _HALL_HAS_PYTHON3=1 || _HALL_HAS_PYTHON3=0
fi

# Glow strips 256-color when stdout is not a TTY (termenv regression in glow 2.x).
# When python3 is available, allocate a PTY so glow detects a terminal (full 256-color).
# When python3 is missing, fall back to direct glow (4-bit color, but still renders).
_hall_glow() {
    if [ "$_HALL_HAS_PYTHON3" = "1" ]; then
        python3 -c "
import subprocess,os,pty,sys
m,s=pty.openpty()
p=subprocess.Popen(sys.argv[1:],stdin=sys.stdin,stdout=s,stderr=subprocess.DEVNULL)
os.close(s)
o=b''
while True:
 try:
  c=os.read(m,4096)
  if not c:break
  o+=c
 except OSError:break
p.wait();os.close(m)
sys.stdout.buffer.write(o.replace(b'\r\n',b'\n').replace(b'\r',b''))
" glow "$@"
    else
        glow "$@"
    fi
}

_hall_preview_cache_dir() {
    local cache_dir

    [ -n "${HALL_STATE_DIR:-}" ] && [ -d "${HALL_STATE_DIR}" ] || return 1

    cache_dir="${HALL_STATE_DIR}/preview-cache"
    mkdir -p "$cache_dir" 2>/dev/null || return 1
    printf '%s' "$cache_dir"
}

_hall_render_cache_file() {
    local width="$1"
    local max_lines="$2"
    local style="$3"
    local content="$4"
    local theme_token="${HALL_THEME_NAME:-default}"
    local cache_dir checksum

    cache_dir=$(_hall_preview_cache_dir) || return 1

    checksum=$(printf '%s\037%s\037%s\037%s\037%s' \
        "$theme_token" "$style" "$width" "$max_lines" "$content" | cksum)
    checksum="${checksum%% *}"
    theme_token=$(printf '%s' "$theme_token" | tr '[:upper:] ' '[:lower:]-')

    printf '%s/md-%s-%s.ansi' "$cache_dir" "$theme_token" "$checksum"
}

_hall_file_render_cache_file() {
    local path="$1"
    local width="$2"
    local max_lines="$3"
    local style="$4"
    local theme_token="${HALL_THEME_NAME:-default}"
    local cache_dir stamp checksum

    cache_dir=$(_hall_preview_cache_dir) || return 1

    stamp=$(stat -f '%m:%z' "$path" 2>/dev/null || stat -c '%Y:%s' "$path" 2>/dev/null)
    [ -n "$stamp" ] || return 1

    checksum=$(printf '%s\037%s\037%s\037%s\037%s\037%s' \
        "$theme_token" "$style" "$width" "$max_lines" "$path" "$stamp" | cksum)
    checksum="${checksum%% *}"
    theme_token=$(printf '%s' "$theme_token" | tr '[:upper:] ' '[:lower:]-')

    printf '%s/file-%s-%s.ansi' "$cache_dir" "$theme_token" "$checksum"
}

# hall_render_file <path> [max_lines]
#   Renders file content for preview panes.
#   Routes .md through glow, wraps .json in ```json fence for glow,
#   falls back to indented plain text when glow is unavailable.
hall_render_file() {
    local path="$1"
    local max_lines="${2:-40}"
    local width="${FZF_PREVIEW_COLUMNS:-72}"
    local lines cache_file ext
    lines=$(wc -l < "$path" 2>/dev/null)
    lines="${lines// /}"
    ext="${path##*.}"

    case "$ext" in
        md)
            cache_file=$(_hall_file_render_cache_file "$path" "$width" "$max_lines" "$HALL_GLOW_STYLE" 2>/dev/null) || cache_file=""
            if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
                cat "$cache_file"
            elif [ "$_HALL_HAS_GLOW" = "1" ] && [ -f "$HALL_GLOW_STYLE" ]; then
                if [ -n "$cache_file" ]; then
                    head -"$max_lines" "$path" | _hall_glow -s "$HALL_GLOW_STYLE" -w "$width" - > "$cache_file"
                    cat "$cache_file"
                else
                    head -"$max_lines" "$path" | _hall_glow -s "$HALL_GLOW_STYLE" -w "$width" -
                fi
            else
                if [ -n "$cache_file" ]; then
                    head -"$max_lines" "$path" | sed 's/^/  /' > "$cache_file"
                    cat "$cache_file"
                else
                    head -"$max_lines" "$path" | sed 's/^/  /'
                fi
            fi
            ;;
        json)
            cache_file=$(_hall_file_render_cache_file "$path" "$width" "$max_lines" "$HALL_GLOW_STYLE" 2>/dev/null) || cache_file=""
            if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
                cat "$cache_file"
            elif [ "$_HALL_HAS_GLOW" = "1" ] && [ -f "$HALL_GLOW_STYLE" ]; then
                if [ -n "$cache_file" ]; then
                    { printf '```json\n'; head -"$max_lines" "$path"; printf '```\n'; } \
                        | _hall_glow -s "$HALL_GLOW_STYLE" -w "$width" - > "$cache_file"
                    cat "$cache_file"
                else
                    { printf '```json\n'; head -"$max_lines" "$path"; printf '```\n'; } \
                        | _hall_glow -s "$HALL_GLOW_STYLE" -w "$width" -
                fi
            else
                if [ -n "$cache_file" ]; then
                    head -"$max_lines" "$path" | sed 's/^/  /' > "$cache_file"
                    cat "$cache_file"
                else
                    head -"$max_lines" "$path" | sed 's/^/  /'
                fi
            fi
            ;;
        *)
            head -"$max_lines" "$path" | sed 's/^/  /'
            ;;
    esac

    if [ "${lines:-0}" -gt "$max_lines" ]; then
        printf '\n  \033[2m... (%s more lines)\033[0m\n' "$((lines - max_lines))"
    fi
}

# hall_render_markdown [max_lines]
#   Renders markdown from stdin for preview panes.
#   Falls back to indented plain text when glow is unavailable.
hall_render_markdown() {
    local max_lines="${1:-}"
    local width="${FZF_PREVIEW_COLUMNS:-72}"
    local style="$HALL_GLOW_PREVIEW_STYLE"
    local content cache_file

    [ -f "$style" ] || style="$HALL_GLOW_STYLE"

    if [ -n "$max_lines" ]; then
        content=$(head -"$max_lines")
    else
        content=$(cat)
    fi

    [ -n "$content" ] || return 0

    cache_file=$(_hall_render_cache_file "$width" "$max_lines" "$style" "$content" 2>/dev/null) || cache_file=""
    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        cat "$cache_file"
        return 0
    fi

    if [ "$_HALL_HAS_GLOW" = "1" ] && [ -f "$style" ]; then
        if [ -n "$cache_file" ]; then
            printf '%s' "$content" | _hall_glow -s "$style" -w "$width" - > "$cache_file"
            cat "$cache_file"
        else
            printf '%s' "$content" | _hall_glow -s "$style" -w "$width" -
        fi
    else
        if [ -n "$cache_file" ]; then
            printf '%s' "$content" | sed 's/^/  /' > "$cache_file"
            cat "$cache_file"
        else
            printf '%s' "$content" | sed 's/^/  /'
        fi
    fi
}

# hall_render_quick_markdown [max_lines]
#   Fast renderer for static help prose in preview panes.
#   Supports basic headings, bullets, inline code/bold stripping, and table rows
#   without invoking glow.
hall_render_quick_markdown() {
    local max_lines="${1:-}"
    local width="${FZF_PREVIEW_COLUMNS:-72}"
    local content line rendered trimmed rest cell row

    if [ -n "$max_lines" ]; then
        content=$(head -"$max_lines")
    else
        content=$(cat)
    fi

    [ -n "$content" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            '')
                printf '\n'
                continue
                ;;
            \|*)
                trimmed="${line//|/}"
                trimmed="${trimmed//-/}"
                trimmed="${trimmed//:/}"
                trimmed="${trimmed// /}"
                [ -z "$trimmed" ] && continue

                row=""
                rest="${line#|}"
                rest="${rest%|}"
                while :; do
                    if [[ "$rest" == *"|"* ]]; then
                        cell="${rest%%|*}"
                        rest="${rest#*|}"
                    else
                        cell="$rest"
                        rest=""
                    fi
                    cell="${cell#"${cell%%[![:space:]]*}"}"
                    cell="${cell%"${cell##*[![:space:]]}"}"
                    [ -n "$cell" ] && row="${row:+$row  }$cell"
                    [ -n "$rest" ] || break
                done
                printf '%s\n' "$row" | fold -s -w "$width"
                continue
                ;;
        esac

        if [[ "$line" =~ ^\*\*(.+)\*\*$ ]]; then
            printf '\033[1m%s\033[0m\n' "${BASH_REMATCH[1]}"
            continue
        fi

        rendered="$line"
        if [[ "$rendered" == \*\ * ]]; then
            rendered="• ${rendered#\* }"
        fi
        rendered="${rendered//\*\*/}"
        rendered="${rendered//\`/}"

        printf '%s\n' "$rendered" | fold -s -w "$width"
    done <<< "$content"
}

hall_use_quick_markdown_preview() {
    HALL_MODULE_PREVIEW_RENDERER="quick"
    hall_apply_preview_renderer
}

hall_apply_preview_renderer() {
    case "${HALL_MODULE_PREVIEW_RENDERER:-auto}" in
        quick)
            hall_render_markdown() {
                hall_render_quick_markdown "$@"
            }
            ;;
    esac
}

hall_apply_preview_renderer
