#!/usr/bin/env bash
# git module — Read-only git status viewer
# Built-in module for cc-hall

source "${HALL_LIB_DIR}/hall-theme.sh"

HALL_MODULE_LABEL="Git"
HALL_MODULE_ORDER=40
HALL_MODULE_ICON="○"
HALL_MODULE_PREVIEW_WINDOW="hidden"

# Keybindings: y = yank (copy) file content to clipboard
HALL_MODULE_BINDINGS=(
    "y:transform('$HALL_LIB_DIR/hall-yank.sh' {2} gs-file 1 && printf 'change-footer( ✓ yanked  ? help )')"
)
HALL_MODULE_FOOTER=" y yank  ? help "

# ── Status letter to human-readable descriptor ──────────────────

_gs_descriptor() {
    case "$1" in
        M) echo "modified:" ;;
        A) echo "new file:" ;;
        D) echo "deleted:" ;;
        R) echo "renamed:" ;;
        C) echo "copied:" ;;
        *) echo "unknown:" ;;
    esac
}

# ── Entry generator ─────────────────────────────────────────────

hall_git_entries() {
    # Guard: not a git repo
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        printf '%s\t%s\n' "$(hall_ansi_dim "Not a git repository")" "gs-noop"
        return
    fi

    local porcelain
    porcelain=$(git status --porcelain 2>/dev/null)

    # Guard: clean tree
    if [ -z "$porcelain" ]; then
        printf '%s\t%s\n' "$(hall_ansi_dim "Working tree clean")" "gs-noop"
        return
    fi

    # Parse porcelain into three buckets
    local -a staged_desc=() staged_path=()
    local -a modified_desc=() modified_path=()
    local -a untracked_path=()

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local x="${line:0:1}" y="${line:1:1}"
        local path="${line:3}"

        if [ "$x" = "?" ]; then
            untracked_path+=("$path")
        else
            # Staged changes (index status)
            if [[ "$x" =~ [MADRC] ]]; then
                staged_desc+=("$(_gs_descriptor "$x")")
                # Renamed: "old -> new" — use new path
                if [ "$x" = "R" ] || [ "$x" = "C" ]; then
                    staged_path+=("${path##* -> }")
                else
                    staged_path+=("$path")
                fi
            fi
            # Unstaged changes (worktree status)
            if [[ "$y" =~ [MD] ]]; then
                modified_desc+=("$(_gs_descriptor "$y")")
                modified_path+=("$path")
            fi
        fi
    done <<< "$porcelain"

    # Theme-aware git colors: staged=success(green), modified/untracked=marker(red)
    local _gs_green="$HALL_SUCCESS" _gs_red="$HALL_MARKER"

    local need_separator=""

    # ── Staged ──
    if [ ${#staged_path[@]} -gt 0 ]; then
        printf '%s\t%s\n' \
            "$(hall_ansi_hex "$_gs_green" "Changes to be committed:")" "gs-noop"
        for i in "${!staged_path[@]}"; do
            printf '%s\t%s\n' \
                "$(printf '        %s   %s' "$(hall_ansi_hex "$_gs_green" "${staged_desc[$i]}")" "$(hall_ansi_hex "$_gs_green" "${staged_path[$i]}")")" \
                "gs-file ${staged_path[$i]}"
        done
        need_separator=1
    fi

    # ── Modified (unstaged) ──
    if [ ${#modified_path[@]} -gt 0 ]; then
        [ -n "$need_separator" ] && printf '%s\t%s\n' " " "gs-noop"
        printf '%s\t%s\n' \
            "$(hall_ansi_hex "$_gs_red" "Changes not staged for commit:")" "gs-noop"
        for i in "${!modified_path[@]}"; do
            printf '%s\t%s\n' \
                "$(printf '        %s   %s' "$(hall_ansi_hex "$_gs_red" "${modified_desc[$i]}")" "$(hall_ansi_hex "$_gs_red" "${modified_path[$i]}")")" \
                "gs-file ${modified_path[$i]}"
        done
        need_separator=1
    fi

    # ── Untracked ──
    if [ ${#untracked_path[@]} -gt 0 ]; then
        [ -n "$need_separator" ] && printf '%s\t%s\n' " " "gs-noop"
        printf '%s\t%s\n' \
            "$(hall_ansi_hex "$_gs_red" "Untracked files:")" "gs-noop"
        for i in "${!untracked_path[@]}"; do
            printf '%s\t%s\n' \
                "$(printf '        %s' "$(hall_ansi_hex "$_gs_red" "${untracked_path[$i]}")")" \
                "gs-file ${untracked_path[$i]}"
        done
    fi
}
