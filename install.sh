#!/usr/bin/env bash
set -e

# cc-hall installer
# Installs the menu host and registers as Claude Code's EDITOR

# Detect piped execution (curl | bash) — BASH_SOURCE is empty or not a real file
if [ -z "${BASH_SOURCE[0]:-}" ] || [ ! -f "${BASH_SOURCE[0]}" ]; then
    echo ""
    echo "  Streamed install is not supported."
    echo ""
    echo "  cc-hall must be cloned locally so the symlink has a real target:"
    echo ""
    echo "    git clone https://github.com/pro-vi/cc-hall.git"
    echo "    cd cc-hall && ./install.sh"
    echo ""
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
HALL_MODULES_DIR="${HOME}/.claude/hall/modules"
HALL_LOG_DIR="${HOME}/.claude/hall/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

echo ""
echo "  cc-hall — Extensible Ctrl-G menu for Claude Code"
echo ""

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

check_dep() {
    local name="$1"
    local install_hint="$2"
    if command -v "$name" &>/dev/null; then
        info "$name found"
        return 0
    else
        error "$name not found — $install_hint"
        return 1
    fi
}

deps_ok=true
check_dep "fzf"   "brew install fzf"    || deps_ok=false
check_dep "tmux"  "brew install tmux"   || deps_ok=false
check_dep "bun"   "curl -fsSL https://bun.sh/install | bash"  || deps_ok=false

if [ "$deps_ok" = false ]; then
    echo ""
    error "Missing dependencies. Install them and try again."
    exit 1
fi

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

mkdir -p "$INSTALL_DIR"
mkdir -p "$HALL_MODULES_DIR"
mkdir -p "$HALL_LOG_DIR"

info "Directories created"

# ============================================================================
# SYMLINK BINARY
# ============================================================================

ln -sf "$SCRIPT_DIR/bin/cc-hall" "$INSTALL_DIR/cc-hall"
info "Symlinked cc-hall → $INSTALL_DIR/cc-hall"

# ============================================================================
# COPY BUILT-IN MODULES
# ============================================================================

# Built-in modules are auto-discovered from the repo's modules/ dir
info "Built-in modules: editor, hall, usage, config, skills, memory (auto-discovered from $SCRIPT_DIR/modules/)"

# ============================================================================
# REGISTER AS EDITOR IN CLAUDE CODE
# ============================================================================

CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

register_editor() {
    if [ ! -f "$CLAUDE_SETTINGS" ]; then
        warn "Claude Code settings not found at $CLAUDE_SETTINGS"
        warn "To register manually, add to your Claude Code settings:"
        warn '  "env": { "EDITOR": "cc-hall" }'
        return
    fi

    # Check if EDITOR is already set
    if command -v jq &>/dev/null; then
        current_editor=$(jq -r '.env.EDITOR // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
        if [ "$current_editor" = "cc-hall" ]; then
            info "EDITOR already set to cc-hall in Claude Code settings"
            return
        fi

        if [ -n "$current_editor" ]; then
            warn "EDITOR currently set to '$current_editor' in Claude Code settings"
            echo -n "  Overwrite with cc-hall? [y/N]: "
            read -r confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                warn "Skipped EDITOR registration. Set manually:"
                warn "  jq '.env.EDITOR = \"cc-hall\"' $CLAUDE_SETTINGS | sponge $CLAUDE_SETTINGS"
                return
            fi
        fi

        # Set EDITOR
        local tmp
        tmp=$(mktemp)
        jq '.env.EDITOR = "cc-hall"' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
        info "Registered cc-hall as EDITOR in Claude Code settings"
    else
        warn "jq not found — cannot auto-register EDITOR"
        warn "Add manually to $CLAUDE_SETTINGS:"
        warn '  "env": { "EDITOR": "cc-hall" }'
    fi
}

register_editor

# ============================================================================
# PATH CHECK
# ============================================================================

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    warn "$INSTALL_DIR is not in PATH"
    warn "Add to your shell profile:"
    warn "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

# ============================================================================
# VERIFY
# ============================================================================

echo ""
if command -v cc-hall &>/dev/null; then
    info "Installation complete! cc-hall is ready."
    echo ""
    echo "  Press Ctrl-G in Claude Code to open the menu."
    echo "  Install modules to: $HALL_MODULES_DIR"
    echo ""
else
    warn "cc-hall installed but not in PATH yet."
    warn "Restart your shell or run: export PATH=\"$INSTALL_DIR:\$PATH\""
fi
