#!/usr/bin/env bash
# skill-viewer module — Browse and invoke Claude Code skills
# Built-in module for cc-hall

# Metadata
HALL_MODULE_LABEL="Skills"
HALL_MODULE_ORDER=30
HALL_MODULE_ICON="◆"

_hall_skill_assign_trimmed() {
    local var_name="$1"
    local value="$2"

    value="${value#"${value%%[![:space:]]*}"}"
    case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac

    printf -v "$var_name" '%s' "$value"
}

# Extract skill metadata from YAML frontmatter in a single pass.
# Sets: HALL_SKILL_NAME, HALL_SKILL_DESC
_hall_skill_read_meta() {
    local file="$1"
    local line value
    local frontmatter_block=0

    HALL_SKILL_NAME=""
    HALL_SKILL_DESC=""

    while IFS= read -r line; do
        if [ "$line" = "---" ]; then
            frontmatter_block=$((frontmatter_block + 1))
            [ "$frontmatter_block" -ge 2 ] && break
            continue
        fi

        [ "$frontmatter_block" -eq 1 ] || continue

        case "$line" in
            name:*)
                _hall_skill_assign_trimmed HALL_SKILL_NAME "${line#name:}"
                ;;
            description:*)
                _hall_skill_assign_trimmed HALL_SKILL_DESC "${line#description:}"
                ;;
        esac

        [ -n "$HALL_SKILL_NAME" ] && [ -n "$HALL_SKILL_DESC" ] && break
    done < "$file"
}

# Emit skill entries from a directory, prefixed with │ box line
# Args: skills_dir
_hall_skill_emit_group() {
    local skills_dir="$1"
    local skill_icon="$2"
    local found=1
    local dir dir_name skill_file name desc

    for dir in "$skills_dir"/*/; do
        [ -d "$dir" ] || continue
        skill_file=""
        if [ -f "${dir}SKILL.md" ]; then
            skill_file="${dir}SKILL.md"
        elif [ -f "${dir}skill.md" ]; then
            skill_file="${dir}skill.md"
        else
            continue
        fi

        _hall_skill_read_meta "$skill_file"
        name="$HALL_SKILL_NAME"
        desc="$HALL_SKILL_DESC"
        dir_name="${dir%/}"
        dir_name="${dir_name##*/}"
        [ -z "$name" ] && name="$dir_name"

        if [ -n "$desc" ]; then
            [ "${#desc}" -gt 60 ] && desc="${desc:0:57}..."
            printf '\033[2m│\033[0m %s \033[1m%s\033[0m \033[2m— %s\033[0m\t%s %s %s\n' \
                "$skill_icon" "$name" "$desc" "skill-invoke" "$dir_name" "$skill_file"
        else
            printf '\033[2m│\033[0m %s \033[1m%s\033[0m\t%s %s %s\n' \
                "$skill_icon" "$name" "skill-invoke" "$dir_name" "$skill_file"
        fi
        found=0
    done
    return "$found"
}

# Entry generator
hall_skill_viewer_entries() {
    local guide_icon skill_icon
    # Guide entry (preview shows help, select is no-op)
    hall_has_nerd_fonts >/dev/null
    guide_icon=$(hall_icon guide)
    skill_icon=$(hall_icon skill)
    printf '%s \033[1mGuide\033[0m\t%s\n' "$guide_icon" "skill-info guide"

    local _sv_group_open=false

    _sv_open_group() {
        if $_sv_group_open; then
            printf '\033[2m╰─\033[0m\t%s\n' "skill-noop"
        fi
        printf '\033[2m╭─ %s ──\033[0m\t%s\n' "$1" "skill-noop"
        _sv_group_open=true
    }

    # Project-local skills
    if [ -d ".claude/skills" ]; then
        _sv_open_group "Project"
        _hall_skill_emit_group ".claude/skills" "$skill_icon" || \
            printf '\033[2m│\033[0m \033[2m(none)\033[0m\t%s\n' "skill-noop"
    fi

    # Global skills
    if [ -d "${HOME}/.claude/skills" ]; then
        _sv_open_group "Global"
        _hall_skill_emit_group "${HOME}/.claude/skills" "$skill_icon" || \
            printf '\033[2m│\033[0m \033[2m(none)\033[0m\t%s\n' "skill-noop"
    fi

    # Close final group
    if $_sv_group_open; then
        printf '\033[2m╰─\033[0m\t%s\n' "skill-noop"
    fi
}
