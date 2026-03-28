#!/usr/bin/env bash
# hall-menu.sh - Menu construction utilities for cc-hall
# Module discovery, entry building, keybinding collection

[ -n "${_HALL_MENU_LOADED:-}" ] && return 0; _HALL_MENU_LOADED=1

# Source common utilities
HALL_MENU_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HALL_MENU_LIB_DIR/hall-common.sh"

# ============================================================================
# SECTION HEADERS
# ============================================================================

hall_section_header() {
    local title="$1"
    local width=40
    local dash_count=$((width - ${#title} - 4))
    local dashes=""
    local i
    for (( i=0; i<dash_count; i++ )); do dashes="${dashes}═"; done
    printf '\033[2m══ %s %s\033[0m\t%s\n' "$title" "$dashes" "echo"
}

# ============================================================================
# MODULE DISCOVERY (shared by all menu builders)
# ============================================================================

# Parse a discovery entry line (format: "order:name:dir:icon:label:preview_renderer")
# Sets: HALL_ENTRY_NAME, HALL_ENTRY_DIR, HALL_ENTRY_ICON, HALL_ENTRY_LABEL,
#       HALL_ENTRY_PREVIEW_RENDERER
hall_parse_discovery_entry() {
    local entry="$1"
    local _r="${entry#*:}"       # strip order
    HALL_ENTRY_NAME="${_r%%:*}"
    _r="${_r#*:}"                # strip name
    HALL_ENTRY_DIR="${_r%%:*}"
    _r="${_r#*:}"                # strip dir
    HALL_ENTRY_ICON="${_r%%:*}"
    _r="${_r#*:}"                # strip icon

    if [[ "$_r" == *:* ]]; then
        HALL_ENTRY_LABEL="${_r%:*}"
        HALL_ENTRY_PREVIEW_RENDERER="${_r##*:}"
    else
        HALL_ENTRY_LABEL="$_r"
        HALL_ENTRY_PREVIEW_RENDERER="auto"
    fi
}

# Find a module's directory by name (user dir takes priority over built-in)
hall_find_module_dir() {
    local mod_name="$1"
    local modules_dir="${HOME}/.claude/hall/modules"
    local builtin_dir="$HALL_DIR/modules"

    if [ -d "$modules_dir/$mod_name" ]; then
        echo "$modules_dir/$mod_name"
    elif [ -d "$builtin_dir/$mod_name" ]; then
        echo "$builtin_dir/$mod_name"
    fi
}

# Discover all modules, sorted by order
# Output: lines of "order:name:dir:icon:label:preview_renderer"
hall_discover_modules() {
    local modules_dir="${HOME}/.claude/hall/modules"
    local builtin_dir="$HALL_DIR/modules"

    # Build file list defensively — skip globs that match nothing
    local -a _mod_files=()
    local _f
    for _f in "$modules_dir"/*/module.sh; do
        [ -f "$_f" ] && _mod_files+=("$_f")
    done
    for _f in "$builtin_dir"/*/module.sh; do
        [ -f "$_f" ] && _mod_files+=("$_f")
    done

    # No modules found at all
    [ ${#_mod_files[@]} -eq 0 ] && return

    # Single awk pass over all module.sh files extracts metadata.
    # User modules globbed first → first-seen wins → user overrides builtin.
    # Constraint: modules must use static HALL_MODULE_*= assignments.
    awk '
    FNR == 1 {
        # Emit previous file results (if any)
        if (name != "") print order ":" name ":" dir ":" icon ":" label ":" preview_renderer
        # Reset for new file
        order = 50; icon = "○"; label = ""; preview_renderer = "auto"
        # Extract dir and name from FILENAME
        dir = FILENAME; sub(/\/module\.sh$/, "", dir)
        name = dir; sub(/.*\//, "", name)
        # Deduplicate: user modules come first, skip if already seen
        if (name in seen) { skip = 1; nextfile }
        seen[name] = 1; skip = 0
    }
    skip { next }
    /HALL_MODULE_ORDER=/ { val = $0; sub(/.*HALL_MODULE_ORDER=/, "", val); gsub(/["'"'"'[:space:]]/, "", val); if (val+0 > 0 || val == "0") order = val }
    /HALL_MODULE_ICON=/  { val = $0; sub(/.*HALL_MODULE_ICON=/, "", val);  gsub(/["'"'"']/, "", val); icon = val }
    /HALL_MODULE_LABEL=/ { val = $0; sub(/.*HALL_MODULE_LABEL=/, "", val); gsub(/["'"'"']/, "", val); label = val }
    /HALL_MODULE_PREVIEW_RENDERER=/ {
        val = $0; sub(/.*HALL_MODULE_PREVIEW_RENDERER=/, "", val); gsub(/["'"'"'[:space:]]/, "", val)
        if (val == "quick" || val == "glow" || val == "auto") preview_renderer = val
    }
    END { if (name != "") print order ":" name ":" dir ":" icon ":" label ":" preview_renderer }
    ' "${_mod_files[@]}" \
    | sort -t: -k1 -n
}

# Find module file path by name
hall_find_module_file() {
    local mod_dir
    mod_dir=$(hall_find_module_dir "$1")
    [ -n "$mod_dir" ] && [ -f "$mod_dir/module.sh" ] && echo "$mod_dir/module.sh"
}

# Get a module's label
hall_get_module_label() {
    local mod_name="$1"
    local mod_file
    mod_file=$(hall_find_module_file "$mod_name")
    [ -z "$mod_file" ] && return

    HALL_MODULE_LABEL=""
    source "$mod_file" 2>/dev/null
    echo "$HALL_MODULE_LABEL"
}

# ============================================================================
# TOP-LEVEL MENU (module picker + inline entries)
# ============================================================================

# Build the top-level menu:
# - Inline modules (no label): entries shown directly
# - Nested modules (has label): single navigation entry
hall_build_top_menu() {
    local menu=""
    local discovered
    discovered=$(hall_discover_modules)

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue

        hall_parse_discovery_entry "$entry"
        local mod_name="$HALL_ENTRY_NAME"
        local mod_dir="$HALL_ENTRY_DIR"
        local label="$HALL_ENTRY_LABEL"
        local mod_file="$mod_dir/module.sh"

        if [ -z "$label" ]; then
            # INLINE module — entries go directly into top-level
            local entries
            entries=$(
                source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
                source "$mod_file" 2>/dev/null
                local fn="hall_${mod_name//-/_}_entries"
                if declare -f "$fn" &>/dev/null; then
                    "$fn"
                fi
            )

            if [ -n "$entries" ]; then
                local tagged
                tagged=$(echo "$entries" | hall_tag_entries "$mod_name")
                menu="${menu:+${menu}
}${tagged}"
            fi
        else
            # NESTED module — show navigation entry with summary
            local summary=""
            summary=$(
                source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
                source "$mod_file" 2>/dev/null
                local fn="hall_${mod_name}_summary"
                if declare -f "$fn" &>/dev/null; then
                    "$fn"
                fi
            )

            local nav_label
            if [ -n "$summary" ]; then
                nav_label=$(printf '%s  \033[2m%s\033[0m' "$label" "$summary")
            else
                nav_label="$label"
            fi

            menu="${menu:+${menu}
}$(printf '%s\t_hall%s'"$HALL_FIELD_SEP"'hall-navigate %s\n' "$nav_label" "$mod_name" "$mod_name")"
        fi

    done <<< "$discovered"

    echo "$menu"
}

# ============================================================================
# MODULE SUBMENU (single module's entries)
# ============================================================================

hall_entries_cache_dir() {
    [ -n "${HALL_STATE_DIR:-}" ] && [ -d "${HALL_STATE_DIR}" ] || return 1
    printf '%s' "$HALL_STATE_DIR/entries-cache"
}

hall_entry_cache_key() {
    local mod_name="$1"
    local subtab_idx=0

    if [ -n "${HALL_STATE_DIR:-}" ] && [ -f "$HALL_STATE_DIR/module-subtab" ]; then
        subtab_idx=$(<"$HALL_STATE_DIR/module-subtab")
    fi

    printf '%s--subtab-%s.entries' "${mod_name//[^[:alnum:]_.-]/_}" "$subtab_idx"
}

hall_clear_entry_cache() {
    local cache_dir
    cache_dir=$(hall_entries_cache_dir) || return 0
    rm -rf "$cache_dir" 2>/dev/null
    mkdir -p "$cache_dir"
}

# Build entries for a specific module (used in submenu)
hall_build_module_entries() {
    local mod_name="$1"
    local mod_file
    local cache_dir="" cache_file="" entries fn
    mod_file=$(hall_find_module_file "$mod_name")
    [ -z "$mod_file" ] && return

    cache_dir=$(hall_entries_cache_dir 2>/dev/null) || cache_dir=""
    if [ -n "$cache_dir" ]; then
        mkdir -p "$cache_dir" 2>/dev/null || cache_dir=""
    fi
    if [ -n "$cache_dir" ]; then
        cache_file="$cache_dir/$(hall_entry_cache_key "$mod_name")"
        if [ -f "$cache_file" ]; then
            cat "$cache_file"
            return 0
        fi
    fi

    source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
    source "$mod_file" 2>/dev/null
    fn="hall_${mod_name//-/_}_entries"
    if declare -f "$fn" &>/dev/null; then
        entries=$("$fn")
        if [ -n "$cache_file" ]; then
            printf '%s' "$entries" > "$cache_file"
        fi
        printf '%s' "$entries"
    fi
}

# ============================================================================
# MODULE KEYBINDINGS
# ============================================================================

# Collect keybindings for a specific module (used in submenu)
hall_collect_module_bindings() {
    local target_name="$1"
    local mod_file
    mod_file=$(hall_find_module_file "$target_name")
    [ -z "$mod_file" ] && return

    HALL_MODULE_BINDINGS=()
    source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
    source "$mod_file" 2>/dev/null

    for b in "${HALL_MODULE_BINDINGS[@]}"; do
        echo "$b"
    done
}

# Collect module-specific fzf options
hall_collect_module_fzf_opts() {
    local target_name="$1"
    local mod_file
    mod_file=$(hall_find_module_file "$target_name")
    [ -z "$mod_file" ] && return

    HALL_MODULE_FZF_OPTS=()
    source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
    source "$mod_file" 2>/dev/null
    for opt in "${HALL_MODULE_FZF_OPTS[@]}"; do
        echo "$opt"
    done
}

# Derive a human-readable label from an fzf binding action string.
# e.g. "execute(/path/to/cc-reflect-delete-seed {})+reload(...)" → "Delete seed"
#      "toggle-filter" → "Toggle filter"
#      "execute-silent(/path/to/cc-reflect-toggle-filter)+reload(...)" → "Toggle filter"
hall_humanize_binding_action() {
    local action="$1"
    case "$action" in
        toggle-search|toggle-filter)
            echo "Toggle filter" ;;
        *)
            # Try to extract script basename from execute(...) or execute-silent(...)
            local script_name=""
            local _exec_arg=""
            # Strip execute( or execute-silent( prefix, then extract up to )
            case "$action" in
                execute\(*|execute-silent\(*)
                    _exec_arg="${action#*\(}"
                    _exec_arg="${_exec_arg%%\)*}"
                    _exec_arg="${_exec_arg%% *}"  # strip args like {}
                    script_name=$(basename "$_exec_arg")
                    ;;
            esac
            if [ -n "$script_name" ]; then
                # Strip common prefixes: cc-reflect-, cc-hall-, cc-
                local label="$script_name"
                label="${label#cc-reflect-}"
                label="${label#cc-hall-}"
                label="${label#cc-}"
                # Convert kebab-case to "Title case" (pure bash, no subprocesses)
                label="${label//-/ }"
                local _titled="" _word
                for _word in $label; do
                    local _first="${_word:0:1}" _rest="${_word:1}"
                    case "$_first" in
                        a) _first=A;; b) _first=B;; c) _first=C;; d) _first=D;;
                        e) _first=E;; f) _first=F;; g) _first=G;; h) _first=H;;
                        i) _first=I;; j) _first=J;; k) _first=K;; l) _first=L;;
                        m) _first=M;; n) _first=N;; o) _first=O;; p) _first=P;;
                        q) _first=Q;; r) _first=R;; s) _first=S;; t) _first=T;;
                        u) _first=U;; v) _first=V;; w) _first=W;; x) _first=X;;
                        y) _first=Y;; z) _first=Z;;
                    esac
                    _titled="${_titled:+$_titled }${_first}${_rest}"
                done
                label="$_titled"
                echo "$label"
            else
                echo "$action"
            fi
            ;;
    esac
}

# Build help file showing keybinding cheat sheet
# Args: output_file mod_count current_mod_name
hall_build_help_file() {
    local output="$1" mod_count="$2" current_mod="$3"
    local mod_label
    mod_label=$(hall_get_module_label "$current_mod")
    [ -z "$mod_label" ] && mod_label="$current_mod"

    {
        cat <<'EOF'

  Keybindings

  Enter       Select item
  Esc         Quit
  Shift-↑/↓   Scroll preview
  Shift-←/→   Page preview
  Ctrl-/      Toggle preview
  ?           Toggle this help
EOF
        if [ "$mod_count" -gt 1 ]; then
            cat <<'EOF'
  Tab         Next module
  Shift-Tab   Previous module
EOF
        fi
        printf '  ◂ / ▸       Switch sub-tab\n'

        local keys_file="$HALL_STATE_DIR/mod-keys/$current_mod"
        if [ -f "$keys_file" ] && [ -s "$keys_file" ]; then
            printf '\n  %s\n\n' "$mod_label"
            local bindings
            bindings=$(hall_collect_module_bindings "$current_mod")
            while IFS= read -r b; do
                [ -z "$b" ] && continue
                local key="${b%%:*}"
                local action="${b#*:}"
                # Derive human-readable label from action string
                action=$(hall_humanize_binding_action "$action")
                printf '  %-12s%s\n' "$key" "$action"
            done <<< "$bindings"
        fi
    } > "$output"
}

# Collect fzf --bind strings from ALL modules (legacy, used by hall_build_menu)
hall_collect_bindings() {
    local modules_dir="${HOME}/.claude/hall/modules"
    local builtin_dir="$HALL_DIR/modules"
    local -a seen_names=()

    for dir in "$builtin_dir"/*/module.sh "$modules_dir"/*/module.sh; do
        [ -f "$dir" ] || continue
        local mod_dir mod_name
        mod_dir="$(dirname "$dir")"
        mod_name="$(basename "$mod_dir")"

        local already=false
        for s in "${seen_names[@]}"; do
            [ "$s" = "$mod_name" ] && already=true && break
        done
        $already && continue
        seen_names+=("$mod_name")

        local bindings
        bindings=$(
            HALL_MODULE_BINDINGS=()
            source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
            source "$dir" 2>/dev/null
            for b in "${HALL_MODULE_BINDINGS[@]}"; do
                echo "$b"
            done
        )

        if [ -n "$bindings" ]; then
            echo "$bindings"
        fi
    done
}

# ============================================================================
# ACTIVE MODULE LOADING (discovery + disabled filtering)
# ============================================================================

# Load active (non-disabled) modules into global arrays.
# Reads config to filter disabled_modules. Requires hall-config.sh sourced.
# Sets: HALL_MOD_NAMES, HALL_MOD_DIRS, HALL_MOD_ICONS, HALL_MOD_LABELS,
#       HALL_MOD_PREVIEW_RENDERERS (global arrays)
hall_load_active_modules() {
    HALL_MOD_NAMES=()
    HALL_MOD_DIRS=()
    HALL_MOD_ICONS=()
    HALL_MOD_LABELS=()
    HALL_MOD_PREVIEW_RENDERERS=()

    local discovered
    discovered=$(hall_discover_modules)

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        hall_parse_discovery_entry "$entry"
        hall_is_module_disabled "$HALL_ENTRY_NAME" && continue
        HALL_MOD_NAMES+=("$HALL_ENTRY_NAME")
        HALL_MOD_DIRS+=("$HALL_ENTRY_DIR")
        HALL_MOD_ICONS+=("${HALL_ENTRY_ICON:-○}")
        HALL_MOD_LABELS+=("${HALL_ENTRY_LABEL:-$HALL_ENTRY_NAME}")
        HALL_MOD_PREVIEW_RENDERERS+=("${HALL_ENTRY_PREVIEW_RENDERER:-auto}")
    done <<< "$discovered"
}

# ============================================================================
# TAB HEADER RENDERING
# ============================================================================

# Measure visible width of a string (strip ANSI escape codes)
_hall_tab_width() {
    local str="$1"
    local stripped
    stripped=$(printf '%s' "$str" | sed $'s/\033\[[0-9;]*m//g')
    printf '%s' "${#stripped}"
}

# Build dot minimap: ○○●○○
# Args: current_idx count
_hall_tab_minimap() {
    local idx="$1" count="$2"
    local dots=""
    local i
    for (( i=0; i<count; i++ )); do
        if [ "$i" -eq "$idx" ]; then
            dots="${dots}●"
        else
            dots="${dots}○"
        fi
    done
    printf '\033[2m%s\033[0m' "$dots"
}

# Build the tab header as a centered adaptive carousel with minimap.
# Shows: ‹ prev   ▸ Active   next ›   ○○●○○
# Adaptive: shows more neighbors when width allows.
# Navigation wraps, so arrows always show when count > 1.
# Args: current_idx width label1 label2 ...
# Output: formatted tab header string (ANSI)
hall_build_tab_header() {
    local current_idx="$1"; shift
    local avail_width="$1"; shift
    local -a labels=("$@")
    local count=${#labels[@]}

    # Single module — no arrows, no minimap
    if [ "$count" -le 1 ]; then
        printf '\033[1m▸ %s\033[0m' "${labels[0]}"
        return
    fi

    # Two modules — fixed positions, highlight moves
    if [ "$count" -eq 2 ]; then
        local minimap
        minimap=$(_hall_tab_minimap "$current_idx" "$count")
        local carousel=""
        local i
        for (( i=0; i<2; i++ )); do
            if [ "$i" -eq "$current_idx" ]; then
                carousel="${carousel}\\033[1m▸ ${labels[$i]}\\033[0m"
            else
                carousel="${carousel}\\033[2m${labels[$i]}\\033[0m"
            fi
            [ "$i" -eq 0 ] && carousel="${carousel}   "
        done
        printf '%b   %s' "$carousel" "$minimap"
        return
    fi

    # Try increasing neighbor counts: 1, 2, ... up to (count-1)/2
    # Pick the largest that fits within avail_width (with minimap + centering)
    local minimap
    minimap=$(_hall_tab_minimap "$current_idx" "$count")
    local minimap_w=$count  # each dot is 1 char

    local best_n=1
    local max_n=$(( (count - 1) / 2 ))
    [ "$max_n" -lt 1 ] && max_n=1

    local n
    for (( n=1; n<=max_n; n++ )); do
        # Build candidate: measure width
        local cand=""
        cand="‹ "
        local i
        for (( i=n; i>=1; i-- )); do
            local idx=$(( (current_idx - i + count) % count ))
            cand="${cand}${labels[$idx]}  "
        done
        cand="${cand}▸ ${labels[$current_idx]}  "
        for (( i=1; i<=n; i++ )); do
            local idx=$(( (current_idx + i) % count ))
            cand="${cand}${labels[$idx]}  "
        done
        cand="${cand}›   "
        # Add minimap width
        local total_w=$(( ${#cand} + minimap_w ))
        if [ "$total_w" -le "$avail_width" ]; then
            best_n=$n
        else
            break
        fi
    done

    # Build the actual header with best_n neighbors
    local carousel=""

    # Left arrow + left neighbors (farthest to nearest)
    carousel="\033[2m‹"
    local i
    for (( i=best_n; i>=1; i-- )); do
        local idx=$(( (current_idx - i + count) % count ))
        carousel="${carousel} ${labels[$idx]} "
    done
    carousel="${carousel}\033[0m"

    # Active tab
    carousel="${carousel} \033[1m▸ ${labels[$current_idx]}\033[0m "

    # Right neighbors (nearest to farthest) + right arrow
    carousel="${carousel}\033[2m"
    for (( i=1; i<=best_n; i++ )); do
        local idx=$(( (current_idx + i) % count ))
        carousel="${carousel} ${labels[$idx]} "
    done
    carousel="${carousel}›\033[0m"

    # Combine carousel + minimap
    printf '%b   %s' "$carousel" "$minimap"
}

# ============================================================================
# SUB-TAB HELPERS
# ============================================================================

# Get a module's custom footer (empty string if not set)
hall_get_module_footer() {
    local mod_file
    mod_file=$(hall_find_module_file "$1")
    [ -z "$mod_file" ] && return
    HALL_MODULE_FOOTER=""
    source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
    source "$mod_file" 2>/dev/null
    printf '%s' "$HALL_MODULE_FOOTER"
}

# Source a module and echo its HALL_MODULE_SUBTABS labels (one per line)
hall_collect_module_subtabs() {
    local mod_name="$1"
    local mod_file
    mod_file=$(hall_find_module_file "$mod_name")
    [ -z "$mod_file" ] && return

    HALL_MODULE_SUBTABS=()
    source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
    source "$mod_file" 2>/dev/null
    for label in "${HALL_MODULE_SUBTABS[@]}"; do
        echo "$label"
    done
}

# Render a styled sub-tab header from index + labels
# Args: active_index label1 label2 ...
# Output: ANSI string like "▸ Global   Shared   Local"
hall_render_subtab_header() {
    local active="$1"; shift
    local -a labels=("$@")
    local count=${#labels[@]}
    [ "$count" -eq 0 ] && return

    local header="" i
    for (( i=0; i<count; i++ )); do
        if [ "$i" -eq "$active" ]; then
            header="${header}\033[1m▸ ${labels[$i]}\033[0m"
        else
            header="${header}\033[2m${labels[$i]}\033[0m"
        fi
        [ "$i" -lt $((count - 1)) ] && header="${header}   "
    done
    printf '%b' "$header"
}

# ============================================================================
# FLAT MENU (legacy — all modules in one list)
# ============================================================================

hall_build_menu() {
    local menu=""
    local discovered
    discovered=$(hall_discover_modules)

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue

        hall_parse_discovery_entry "$entry"
        local mod_name="$HALL_ENTRY_NAME"
        local label="$HALL_ENTRY_LABEL"
        local mod_file="$HALL_ENTRY_DIR/module.sh"

        local entries
        entries=$(
            source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null
            source "$mod_file" 2>/dev/null
            local fn="hall_${mod_name//-/_}_entries"
            if declare -f "$fn" &>/dev/null; then
                "$fn"
            fi
        )

        if [ -z "$entries" ]; then
            continue
        fi

        if [ -n "$label" ]; then
            menu="${menu:+${menu}
}$(hall_section_header "$label")"
        fi

        local tagged
        tagged=$(echo "$entries" | hall_tag_entries "$mod_name")
        menu="${menu:+${menu}
}${tagged}"

    done <<< "$discovered"

    echo "$menu"
}
