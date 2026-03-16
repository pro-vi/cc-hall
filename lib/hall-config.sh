#!/usr/bin/env bash
# hall-config.sh — Shared config loader and mutator for cc-hall
# Reads/writes $HALL_CONFIG_FILE (shared with cc-reflection)

[ -n "${_HALL_CONFIG_LOADED:-}" ] && return 0; _HALL_CONFIG_LOADED=1

# Ensure constants are available
HALL_LIB_DIR="${HALL_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$HALL_LIB_DIR/hall-common.sh" 2>/dev/null

# ============================================================================
# CONFIG LOADER
# ============================================================================

_hall_load_config() {
    _PA_MODEL="sonnet"
    _PA_SKIP_PERMS="false"
    _PA_TMUX_MODE="true"
    _PA_THEME="mirrors"
    _PA_MEMORY_EDITOR="vim"
    [ -f "$HALL_CONFIG_FILE" ] || return 0
    local content=$(<"$HALL_CONFIG_FILE")
    [[ "$content" =~ \"model\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MODEL="${BASH_REMATCH[1]}" || true
    [[ "$content" =~ \"skip_permissions\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_SKIP_PERMS="${BASH_REMATCH[1]}" || true
    [[ "$content" =~ \"tmux_mode\"[[:space:]]*:[[:space:]]*(true|false) ]] && _PA_TMUX_MODE="${BASH_REMATCH[1]}" || true
    [[ "$content" =~ \"theme\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_THEME="${BASH_REMATCH[1]}" || true
    [[ "$content" =~ \"memory_editor\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && _PA_MEMORY_EDITOR="${BASH_REMATCH[1]}" || true

    # disabled_modules: extract JSON array contents as space-separated string
    _PA_DISABLED_MODULES=""
    if [[ "$content" =~ \"disabled_modules\"[[:space:]]*:[[:space:]]*\[([^]]*)\] ]]; then
        _PA_DISABLED_MODULES="${BASH_REMATCH[1]}"
    fi
}

# Check if a module is disabled
# Usage: hall_is_module_disabled "module-name" && echo "disabled"
hall_is_module_disabled() {
    local name="$1"
    [[ "$_PA_DISABLED_MODULES" == *"\"$name\""* ]]
}

# ============================================================================
# BUN DEPENDENCY CHECK
# ============================================================================

# Check if bun is available for JSON mutation.
# Returns 0 if available, 1 if not. Caches result.
hall_has_bun() {
    if [ -z "${_HALL_HAS_BUN:-}" ]; then
        command -v bun &>/dev/null && _HALL_HAS_BUN=1 || _HALL_HAS_BUN=0
    fi
    [ "$_HALL_HAS_BUN" = "1" ]
}

hall_config_prepare_file() {
    local file="$1"
    hall_has_bun || { hall_log_error "bun required for config mutation"; return 1; }

    if [ -f "$file" ] && [ -s "$file" ]; then
        if ! bun -e "
            const raw = await Bun.file('$file').text();
            if (raw.trim() !== '') JSON.parse(raw);
        " >/dev/null 2>&1; then
            hall_log_error "Refusing to mutate invalid JSON file: $file"
            local display_file="$file"
            [ -n "${HOME:-}" ] && display_file="${display_file/#$HOME/~}"
            hall_set_footer_message " Invalid JSON in ${display_file}. Fix it before changing settings. "
            echo "Error: Invalid JSON in $file. Fix it before changing settings." >&2
            return 1
        fi
    fi

    mkdir -p "$(dirname "$file")"
}

# ============================================================================
# CONFIG MUTATION HELPERS
# ============================================================================
# Centralized JSON mutation via bun. Modules call these instead of
# embedding bun -e inline. All helpers require bun (checked via hall_has_bun).

# Set a root-level string key in a JSON file.
# Args: $1=file, $2=key, $3=value (or "null" to delete)
hall_config_set_string() {
    local file="$1" key="$2" value="$3"
    hall_config_prepare_file "$file" || return 1
    bun -e "
        const f = Bun.file('$file');
        let c = {}; try { c = JSON.parse(await f.text()); } catch {}
        if ('$value' === 'null') { delete c['$key']; }
        else { c['$key'] = '$value'; }
        await Bun.write(f, JSON.stringify(c, null, 2));
    " 2>/dev/null
}

# Toggle a root-level boolean in a settings JSON file.
# Args: $1=file, $2=key, $3=default (true|false), $4=mode (binary|three_state)
hall_config_toggle_bool() {
    local file="$1" key="$2" default="$3" mode="$4"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!('$key' in c)) { c['$key'] = true; }
            else if (c['$key'] === true) { c['$key'] = false; }
            else { delete c['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            const val = '$key' in c ? c['$key'] : $default;
            c['$key'] = !val;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle a root-level boolean whose default is "on" when unset.
# Args: $1=file, $2=key, $3=mode (binary|three_state)
hall_config_toggle_bool_default_on() {
    local file="$1" key="$2" mode="$3"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!('$key' in c)) { c['$key'] = true; }
            else if (c['$key'] === true) { c['$key'] = false; }
            else { delete c['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            const cur = '$key' in c ? c['$key'] : true;
            if (cur === true) { c['$key'] = false; }
            else { delete c['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle an env var with "1"/absent pattern.
# Args: $1=file, $2=key, $3=mode (binary|three_state)
hall_config_toggle_env_1() {
    local file="$1" key="$2" mode="$3"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === undefined || c.env['$key'] === null) { c.env['$key'] = '1'; }
            else if (c.env['$key'] === '1') { c.env['$key'] = '0'; }
            else { delete c.env['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === '1') { delete c.env['$key']; }
            else { c.env['$key'] = '1'; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle Tool Search using Claude Code's documented auto/true/false values.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_tool_search() {
    local file="$1" mode="$2"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const cur = c.env.ENABLE_TOOL_SEARCH;
            const state = cur == null
              ? 'unset'
              : (cur === 'true' || cur === '1')
                ? 'on'
                : (cur === 'false' || cur === '0')
                  ? 'off'
                  : String(cur).startsWith('auto')
                    ? 'auto'
                    : 'auto';
            if (state === 'unset') c.env.ENABLE_TOOL_SEARCH = 'auto';
            else if (state === 'auto') c.env.ENABLE_TOOL_SEARCH = 'true';
            else if (state === 'on') c.env.ENABLE_TOOL_SEARCH = 'false';
            else delete c.env.ENABLE_TOOL_SEARCH;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const cur = c.env.ENABLE_TOOL_SEARCH;
            const state = cur == null
              ? 'auto'
              : (cur === 'true' || cur === '1')
                ? 'on'
                : (cur === 'false' || cur === '0')
                  ? 'off'
                  : String(cur).startsWith('auto')
                    ? 'auto'
                    : 'auto';
            if (state === 'auto') c.env.ENABLE_TOOL_SEARCH = 'true';
            else if (state === 'on') c.env.ENABLE_TOOL_SEARCH = 'false';
            else delete c.env.ENABLE_TOOL_SEARCH;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle Background Tasks using the documented disable flag while cleaning
# the transient enable alias from older Hall versions.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_background_tasks() {
    local file="$1" mode="$2"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const cur = c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS;
            const compat = c.env.CLAUDE_CODE_ENABLE_BACKGROUND_TASKS;
            const state = cur != null
              ? (cur === '1' ? 'off' : 'on')
              : compat != null
                ? (compat === '0' ? 'off' : 'on')
                : 'unset';
            if (state === 'unset') c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS = '0';
            else if (state === 'on') c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS = '1';
            else delete c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS;
            delete c.env.CLAUDE_CODE_ENABLE_BACKGROUND_TASKS;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const cur = c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS;
            const compat = c.env.CLAUDE_CODE_ENABLE_BACKGROUND_TASKS;
            const enabled = cur !== '1' && compat !== '0';
            if (enabled) c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS = '1';
            else delete c.env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS;
            delete c.env.CLAUDE_CODE_ENABLE_BACKGROUND_TASKS;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle Task Tracking using the documented enable flag while cleaning the
# transient disable alias from older Hall versions.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_task_tracking() {
    local file="$1" mode="$2"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const cur = c.env.CLAUDE_CODE_ENABLE_TASKS;
            const compat = c.env.DISABLE_TASKS;
            const state = cur != null
              ? (cur === 'false' ? 'off' : 'on')
              : compat != null
                ? (compat === '1' ? 'off' : 'on')
                : 'unset';
            if (state === 'unset') c.env.CLAUDE_CODE_ENABLE_TASKS = 'true';
            else if (state === 'on') c.env.CLAUDE_CODE_ENABLE_TASKS = 'false';
            else delete c.env.CLAUDE_CODE_ENABLE_TASKS;
            delete c.env.DISABLE_TASKS;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const cur = c.env.CLAUDE_CODE_ENABLE_TASKS;
            const compat = c.env.DISABLE_TASKS;
            const enabled = cur !== 'false' && compat !== '1';
            if (enabled) c.env.CLAUDE_CODE_ENABLE_TASKS = 'false';
            else delete c.env.CLAUDE_CODE_ENABLE_TASKS;
            delete c.env.DISABLE_TASKS;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle a default-on root boolean while cleaning a legacy disable env alias.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_root_default_on_compat() {
    local file="$1" key="$2" legacy_key="$3" mode="$4"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const hasRoot = '$key' in c;
            const legacyOff = c.env['$legacy_key'] === '1';
            if (!hasRoot && !legacyOff) c['$key'] = true;
            else if (hasRoot && c['$key'] === true) c['$key'] = false;
            else delete c['$key'];
            delete c.env['$legacy_key'];
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const hasRoot = '$key' in c;
            const legacyOff = c.env['$legacy_key'] === '1';
            const enabled = hasRoot ? c['$key'] === true : !legacyOff;
            if (enabled) c['$key'] = false;
            else delete c['$key'];
            delete c.env['$legacy_key'];
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle Auto Memory using the canonical root setting while cleaning
# the legacy disable env alias.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_auto_memory() {
    hall_config_toggle_root_default_on_compat "$1" "autoMemoryEnabled" "CLAUDE_CODE_DISABLE_AUTO_MEMORY" "$2"
}

# Toggle Fast Mode using the canonical root setting while cleaning
# the legacy disable env alias.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_fast_mode() {
    hall_config_toggle_root_default_on_compat "$1" "fastMode" "CLAUDE_CODE_DISABLE_FAST_MODE" "$2"
}


# Toggle inverted DISABLE env var ("1" = off, absent = on).
# Args: $1=file, $2=key, $3=mode (binary|three_state)
hall_config_toggle_env_disable() {
    local file="$1" key="$2" mode="$3"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === undefined || c.env['$key'] === null) { c.env['$key'] = '0'; }
            else if (c.env['$key'] === '0') { c.env['$key'] = '1'; }
            else { delete c.env['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === '1') { delete c.env['$key']; }
            else { c.env['$key'] = '1'; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle env var with "true"/"false" pattern.
# Args: $1=file, $2=key, $3=mode (binary|three_state)
hall_config_toggle_env_true() {
    local file="$1" key="$2" mode="$3"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === undefined || c.env['$key'] === null) { c.env['$key'] = 'true'; }
            else if (c.env['$key'] === 'true') { c.env['$key'] = 'false'; }
            else { delete c.env['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === 'true') { c.env['$key'] = 'false'; }
            else { c.env['$key'] = 'true'; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle default-on env var ("false" to disable, absent = on).
# Args: $1=file, $2=key, $3=mode (binary|three_state)
hall_config_toggle_env_default_on() {
    local file="$1" key="$2" mode="$3"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === undefined || c.env['$key'] === null) { c.env['$key'] = 'true'; }
            else if (c.env['$key'] === 'true') { c.env['$key'] = 'false'; }
            else { delete c.env['$key']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            if (c.env['$key'] === 'false') { delete c.env['$key']; }
            else { c.env['$key'] = 'false'; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Cycle effort level env var.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_effort() {
    local file="$1" mode="$2"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const levels = ['low', 'medium', 'high'];
            const cur = c.env['CLAUDE_CODE_EFFORT_LEVEL'];
            if (!cur) { c.env['CLAUDE_CODE_EFFORT_LEVEL'] = 'low'; }
            else {
                const idx = levels.indexOf(cur);
                if (idx >= levels.length - 1) { delete c.env['CLAUDE_CODE_EFFORT_LEVEL']; }
                else { c.env['CLAUDE_CODE_EFFORT_LEVEL'] = levels[idx + 1]; }
            }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const levels = ['low', 'medium', 'high'];
            const cur = c.env['CLAUDE_CODE_EFFORT_LEVEL'] || 'high';
            const next = levels[(levels.indexOf(cur) + 1) % 3];
            if (next === 'high') { delete c.env['CLAUDE_CODE_EFFORT_LEVEL']; }
            else { c.env['CLAUDE_CODE_EFFORT_LEVEL'] = next; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Cycle effort level using the canonical root-level key while cleaning
# the legacy env var form.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_effort_level() {
    local file="$1" mode="$2"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const levels = ['low', 'medium', 'high'];
            const cur = c.effortLevel || '';
            if (!cur) { c.effortLevel = 'low'; }
            else {
                const idx = levels.indexOf(cur);
                if (idx >= levels.length - 1) { delete c.effortLevel; }
                else { c.effortLevel = levels[idx + 1]; }
            }
            delete c.env.CLAUDE_CODE_EFFORT_LEVEL;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            if (!c.env) c.env = {};
            const levels = ['low', 'medium', 'high'];
            const cur = c.effortLevel || c.env.CLAUDE_CODE_EFFORT_LEVEL || 'high';
            const next = levels[(levels.indexOf(cur) + 1) % 3];
            if (next === 'high') { delete c.effortLevel; }
            else { c.effortLevel = next; }
            delete c.env.CLAUDE_CODE_EFFORT_LEVEL;
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Toggle auto updates channel.
# Args: $1=file, $2=mode (binary|three_state)
hall_config_toggle_updates_channel() {
    local file="$1" mode="$2"
    hall_config_prepare_file "$file" || return 1
    if [ "$mode" = "three_state" ]; then
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            const cur = c['autoUpdatesChannel'] || '';
            if (!cur) { c['autoUpdatesChannel'] = 'latest'; }
            else if (cur === 'latest' || cur === 'beta') { c['autoUpdatesChannel'] = 'stable'; }
            else { delete c['autoUpdatesChannel']; }
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    else
        bun -e "
            const f = Bun.file('$file');
            let c = {}; try { c = JSON.parse(await f.text()); } catch {}
            const cur = c['autoUpdatesChannel'] || 'latest';
            if (cur === 'stable') delete c['autoUpdatesChannel'];
            else c['autoUpdatesChannel'] = 'stable';
            await Bun.write(f, JSON.stringify(c, null, 2));
        " 2>/dev/null
    fi
}

# Cycle a root-level string through named values.
# Args: $1=file, $2=key, $3=mode (binary|three_state), $4...=values
hall_config_toggle_named_cycle() {
    local file="$1" key="$2" mode="$3"; shift 3
    local vals_json
    vals_json=$(printf '"%s",' "$@" | sed 's/,$//')
    hall_config_prepare_file "$file" || return 1
    bun -e "
        const f = Bun.file('$file');
        let c = {}; try { c = JSON.parse(await f.text()); } catch {}
        const vals = [$vals_json];
        const cur = c['$key'] || '';
        const idx = vals.indexOf(cur);
        if (!cur) { c['$key'] = vals[0]; }
        else if (idx >= vals.length - 1) {
            if ('$mode' === 'three_state') { delete c['$key']; }
            else { c['$key'] = vals[0]; }
        }
        else { c['$key'] = vals[idx + 1]; }
        await Bun.write(f, JSON.stringify(c, null, 2));
    " 2>/dev/null
}

# Cycle an env var string through named values.
# Args: $1=file, $2=key, $3=mode (binary|three_state), $4...=values
hall_config_toggle_env_named_cycle() {
    local file="$1" key="$2" mode="$3"; shift 3
    local vals_json
    vals_json=$(printf '"%s",' "$@" | sed 's/,$//')
    hall_config_prepare_file "$file" || return 1
    bun -e "
        const f = Bun.file('$file');
        let c = {}; try { c = JSON.parse(await f.text()); } catch {}
        if (!c.env) c.env = {};
        const vals = [$vals_json];
        const cur = c.env['$key'] || '';
        const idx = vals.indexOf(cur);
        if (!cur) { c.env['$key'] = vals[0]; }
        else if (idx >= vals.length - 1) {
            if ('$mode' === 'three_state') { delete c.env['$key']; }
            else { c.env['$key'] = vals[0]; }
        }
        else { c.env['$key'] = vals[idx + 1]; }
        await Bun.write(f, JSON.stringify(c, null, 2));
    " 2>/dev/null
}

# Toggle a module in the disabled_modules array.
# Args: $1=file, $2=module_name
hall_config_toggle_module() {
    local file="$1" mod_name="$2"
    hall_config_prepare_file "$file" || return 1
    bun -e "
        const f = Bun.file('$file');
        let c = {}; try { c = JSON.parse(await f.text()); } catch {}
        const arr = Array.isArray(c.disabled_modules) ? c.disabled_modules : [];
        const idx = arr.indexOf('$mod_name');
        if (idx >= 0) { arr.splice(idx, 1); } else { arr.push('$mod_name'); }
        c.disabled_modules = arr;
        await Bun.write(f, JSON.stringify(c, null, 2));
    " 2>/dev/null
}

# ============================================================================
# SUBTAB STATE ACCESSOR
# ============================================================================

# Get the current subtab index for the active module.
# Returns: index (defaults to 0)
hall_get_subtab_index() {
    local idx=0
    if [ -n "${HALL_STATE_DIR:-}" ] && [ -f "$HALL_STATE_DIR/module-subtab" ]; then
        idx=$(<"$HALL_STATE_DIR/module-subtab")
    fi
    echo "${idx:-0}"
}

# Set the current subtab index.
# Args: $1=index
hall_set_subtab_index() {
    if [ -n "${HALL_STATE_DIR:-}" ]; then
        echo "$1" > "$HALL_STATE_DIR/module-subtab"
    fi
}
