#!/usr/bin/env bash
# hall-yank.sh — Copy a file's content to clipboard
# Args: $1 = tagged fzf field (module\x1fcommand <args...> <filepath>)
#        $2 = command prefix that identifies file entries (e.g. "mv-open", "skill-invoke")
#        $3 = number of space-delimited words to skip after stripping module tag
#             to reach the file path (e.g. 2 for "skill-invoke dirname /path")
raw="${1#*$'\x1f'}"
prefix="$2"
skip="${3:-1}"

# Only act on entries whose command starts with the expected prefix
case "$raw" in "$prefix "*)  ;; *) exit 1 ;; esac

for (( i=0; i<skip; i++ )); do
    raw="${raw#* }"
done
[ -f "$raw" ] && /usr/bin/pbcopy < "$raw"
