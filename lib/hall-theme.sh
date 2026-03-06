#!/usr/bin/env bash
# hall-theme.sh — Theme loader for cc-hall
# Reads active theme from config, sources palette, builds derived variables.
# shellcheck disable=SC2034

[ -n "${_HALL_THEME_LOADED:-}" ] && return 0; _HALL_THEME_LOADED=1

# ── Load active theme ────────────────────────────────────────────────

_hall_theme_dir="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/themes"

# Read theme name from config (default: mirrors)
_hall_active_theme="mirrors"
_hall_theme_config="${HALL_CONFIG_FILE:-${HOME}/.claude/reflections/config.json}"
if [ -f "$_hall_theme_config" ]; then
    _hall_theme_content=$(<"$_hall_theme_config")
    if [[ "$_hall_theme_content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        _hall_active_theme="${BASH_REMATCH[1]}"
    fi
fi

# Source theme file (fall back to mirrors if missing)
if [ -f "$_hall_theme_dir/${_hall_active_theme}.sh" ]; then
    source "$_hall_theme_dir/${_hall_active_theme}.sh"
else
    source "$_hall_theme_dir/mirrors.sh"
fi

# ── Derived: fzf color string ────────────────────────────────────────

HALL_FZF_COLORS="
  bg:${HALL_BG_0}
  fg:${HALL_FG_MUTED}
  fg+:${HALL_FG}
  bg+:${HALL_BG_1}
  hl:${HALL_ACCENT}
  hl+:${HALL_ACCENT_2}
  border:${HALL_BORDER}
  label:${HALL_ACCENT_2}:bold
  prompt:${HALL_ACCENT}
  pointer:${HALL_ACCENT}
  marker:${HALL_MARKER}
  header:${HALL_FG_DIM}
  info:${HALL_FG_MUTED}
  separator:${HALL_BORDER}
  scrollbar:${HALL_BORDER}
  gutter:${HALL_BG_0}
  preview-fg:${HALL_FG}
  preview-bg:${HALL_BG_1}
  list-border:${HALL_BORDER}
  input-border:${HALL_BORDER}
  spinner:${HALL_SUCCESS}
"

# ── Derived: tmux style variables ────────────────────────────────────

HALL_TMUX_WINDOW_BG="$HALL_BG_0"
HALL_TMUX_WINDOW_FG="$HALL_FG"
HALL_TMUX_STATUS_BG="$HALL_BG_1"
HALL_TMUX_STATUS_FG="$HALL_ACCENT"
HALL_TMUX_PANE_BORDER_FG="$HALL_BORDER"
HALL_TMUX_PANE_ACTIVE_BORDER_FG="$HALL_ACCENT"
HALL_TMUX_STATUS_LEFT=" cc-hall "
HALL_TMUX_STATUS_RIGHT=" %H:%M "

# ── Visual config ────────────────────────────────────────────────────

HALL_FZF_POINTER='▌'
HALL_FZF_MARKER='◆'
HALL_FZF_SCROLLBAR='█░'
HALL_FZF_SEPARATOR='─'
HALL_FZF_PROMPT='❯ '

# ── Derived: glow style JSON ──────────────────────────────────────

# Map #RRGGBB to nearest 256-color index (for collision detection)
_hall_hex_to_256() {
    local h="${1#\#}"
    local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
    # Grayscale shortcut
    if [ $r -eq $g ] && [ $g -eq $b ]; then
        if [ $r -lt 8 ]; then echo 16; return; fi
        if [ $r -gt 248 ]; then echo 231; return; fi
        echo $(( (r - 8 + 5) / 10 + 232 ))
        return
    fi
    # 6x6x6 cube
    local ri=$(( (r + 25) / 51 )) gi=$(( (g + 25) / 51 )) bi=$(( (b + 25) / 51 ))
    echo $(( 16 + 36 * ri + 6 * gi + bi ))
}

_hall_generate_glow_style() {
    local out="$1"
    local variant="${2:-default}"
    local document_margin=2
    local code_prefix=' '
    local code_suffix=' '

    if [ "$variant" = "preview" ]; then
        document_margin=0
        code_prefix=''
        code_suffix=''
    fi

    # Glow 2.x requires 256-color number strings for top-level style elements
    # (document, heading, code, link, etc.) but accepts hex inside chroma.
    # Convert all theme vars to 256-color for non-chroma, keep hex for chroma.
    local c_fg c_fg_dim c_fg_muted c_accent c_accent2 c_bg2 c_border c_success c_marker c_h1_fg c_h1_bg
    c_fg=$(_hall_hex_to_256 "$HALL_FG")
    c_fg_dim=$(_hall_hex_to_256 "$HALL_FG_DIM")
    c_bg2=$(_hall_hex_to_256 "$HALL_BG_2")
    c_border=$(_hall_hex_to_256 "$HALL_BORDER")
    c_success=$(_hall_hex_to_256 "$HALL_SUCCESS")
    c_marker=$(_hall_hex_to_256 "$HALL_MARKER")

    # Monochrome themes (Zinc) have ACCENT ≈ FG in 256-color space,
    # so headings/links/keywords would be invisible against body text.
    # Fall back to FG_DIM which always contrasts with FG.
    c_accent=$(_hall_hex_to_256 "$HALL_ACCENT")
    c_accent2=$(_hall_hex_to_256 "$HALL_ACCENT_2")
    [ "$c_accent" = "$c_fg" ] && c_accent="$c_fg_dim"
    [ "$c_accent2" = "$c_fg" ] && c_accent2="$c_fg_dim"
    c_h1_fg="${HALL_GLOW_H1_FG_256:-$c_accent2}"
    c_h1_bg="${HALL_GLOW_H1_BG_256:-$c_bg2}"

    cat > "$out" <<GLOWEOF
{
  "document": {
    "block_prefix": "\n",
    "block_suffix": "\n",
    "color": "${c_fg}",
    "margin": ${document_margin}
  },
  "block_quote": {
    "indent": 1,
    "indent_token": "│ ",
    "color": "${c_fg_dim}"
  },
  "paragraph": {},
  "list": {
    "level_indent": 2
  },
  "heading": {
    "block_suffix": "\n",
    "color": "${c_accent}",
    "bold": true
  },
  "h1": {
    "prefix": " ",
    "suffix": " ",
    "color": "${c_h1_fg}",
    "background_color": "${c_h1_bg}",
    "bold": true
  },
  "h2": {
    "prefix": "▌ ",
    "color": "${c_accent}"
  },
  "h3": {
    "prefix": "┃ ",
    "color": "${c_accent}"
  },
  "h4": {
    "prefix": "│ "
  },
  "h5": {
    "prefix": "│ "
  },
  "h6": {
    "prefix": "│ ",
    "color": "${c_fg_dim}",
    "bold": false
  },
  "text": {},
  "strikethrough": {
    "crossed_out": true
  },
  "emph": {
    "italic": true
  },
  "strong": {
    "color": "${c_accent}",
    "bold": true
  },
  "hr": {
    "color": "${c_border}",
    "format": "\n--------\n"
  },
  "item": {
    "block_prefix": "• "
  },
  "enumeration": {
    "block_prefix": ". "
  },
  "task": {
    "ticked": "[✓] ",
    "unticked": "[ ] "
  },
  "link": {
    "color": "${c_accent}",
    "underline": true
  },
  "link_text": {
    "color": "${c_accent}",
    "bold": true
  },
  "image": {
    "color": "${c_accent2}",
    "underline": true
  },
  "image_text": {
    "color": "${c_fg_dim}",
    "format": "Image: {{.text}} →"
  },
  "code": {
    "prefix": "${code_prefix}",
    "suffix": "${code_suffix}",
    "color": "${c_accent2}",
    "background_color": "${c_bg2}"
  },
  "code_block": {
    "color": "${c_fg}",
    "margin": 2,
    "chroma": {
      "text": { "color": "${HALL_FG}" },
      "error": { "color": "${HALL_FG}", "background_color": "${HALL_MARKER}" },
      "comment": { "color": "${HALL_FG_DIM}" },
      "comment_preproc": { "color": "${HALL_ACCENT_2}" },
      "keyword": { "color": "${HALL_ACCENT}" },
      "keyword_reserved": { "color": "${HALL_ACCENT_2}" },
      "keyword_namespace": { "color": "${HALL_ACCENT}" },
      "keyword_type": { "color": "${HALL_ACCENT_2}" },
      "operator": { "color": "${HALL_FG_DIM}" },
      "punctuation": { "color": "${HALL_FG_DIM}" },
      "name": { "color": "${HALL_FG}" },
      "name_builtin": { "color": "${HALL_ACCENT_2}" },
      "name_tag": { "color": "${HALL_ACCENT}" },
      "name_attribute": { "color": "${HALL_ACCENT_2}" },
      "name_class": { "color": "${HALL_FG}", "underline": true, "bold": true },
      "name_constant": {},
      "name_decorator": { "color": "${HALL_ACCENT_2}" },
      "name_exception": {},
      "name_function": { "color": "${HALL_SUCCESS}" },
      "name_other": {},
      "literal": {},
      "literal_number": { "color": "${HALL_SUCCESS}" },
      "literal_date": {},
      "literal_string": { "color": "${HALL_ACCENT_2}" },
      "literal_string_escape": { "color": "${HALL_SUCCESS}" },
      "generic_deleted": { "color": "${HALL_MARKER}" },
      "generic_emph": { "italic": true },
      "generic_inserted": { "color": "${HALL_SUCCESS}" },
      "generic_strong": { "bold": true },
      "generic_subheading": { "color": "${HALL_FG_DIM}" },
      "background": { "background_color": "${HALL_BG_2}" }
    }
  },
  "table": {},
  "definition_list": {},
  "definition_term": {},
  "definition_description": {
    "block_prefix": "\n🠶 "
  },
  "html_block": {},
  "html_span": {}
}
GLOWEOF
}

# hall_apply_glow_style — generate themed glow style into HALL_STATE_DIR.
# Called by bin/cc-hall after HALL_STATE_DIR is created and on theme switch.
hall_apply_glow_style() {
    [ -n "${HALL_STATE_DIR:-}" ] && [ -d "${HALL_STATE_DIR}" ] || return 0
    HALL_GLOW_STYLE="${HALL_STATE_DIR}/glow-style.json"
    HALL_GLOW_PREVIEW_STYLE="${HALL_STATE_DIR}/glow-preview-style.json"
    _hall_generate_glow_style "$HALL_GLOW_STYLE"
    _hall_generate_glow_style "$HALL_GLOW_PREVIEW_STYLE" preview
}
HALL_FZF_GHOST='Type to filter...'

# ── ANSI helpers for module authors ──────────────────────────────────
# Use these when building menu entries with rich formatting.

hall_ansi_reset=$'\033[0m'

hall_ansi_bold() {
  printf '\033[1m%s\033[0m' "$*"
}

hall_ansi_dim() {
  printf '\033[2m%s\033[0m' "$*"
}

hall_ansi_italic() {
  printf '\033[3m%s\033[0m' "$*"
}

hall_ansi_strike() {
  printf '\033[9m%s\033[0m' "$*"
}

# hall_ansi_color CODE TEXT
#   CODE is an ANSI color number (e.g., 33 for yellow, 31 for red)
hall_ansi_color() {
  local code="$1"; shift
  printf '\033[%sm%s\033[0m' "$code" "$*"
}
