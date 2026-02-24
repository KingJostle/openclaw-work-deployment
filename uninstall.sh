#!/bin/bash
# OpenClaw Environment - Uninstall Script
# Cleanly removes all OpenClaw service, aliases, and (optionally) config

set -euo pipefail

WORK_HOME="$HOME"
OPENCLAW_CONFIG_DIR="$WORK_HOME/.openclaw"
LAUNCHD_PLIST="$WORK_HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
SYSTEMD_UNIT="/etc/systemd/system/openclaw.service"
BACKUP_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$WORK_HOME/.openclaw.backup-$BACKUP_TIMESTAMP"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn()  { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }

detect_os() {
    case "$(uname -s)" in
        Darwin) OS="macos" ;;
        Linux)  OS="linux" ;;
        *)      error "Unsupported OS: $(uname -s)" ;;
    esac
}

confirm() {
    read -r -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

stop_service() {
    log "🛑 Stopping OpenClaw service..."

    if [[ "$OS" == "macos" ]]; then
        if [[ -f "$LAUNCHD_PLIST" ]]; then
            launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
            log "✅ LaunchAgent unloaded"
        else
            log "No LaunchAgent found at $LAUNCHD_PLIST"
        fi
    else
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl stop openclaw.service 2>/dev/null || true
            sudo systemctl disable openclaw.service 2>/dev/null || true
            log "✅ systemd service stopped and disabled"
        fi
    fi
}

remove_service_files() {
    log "🗑️  Removing service files..."

    if [[ "$OS" == "macos" ]]; then
        if [[ -f "$LAUNCHD_PLIST" ]]; then
            rm -f "$LAUNCHD_PLIST"
            log "✅ Removed: $LAUNCHD_PLIST"
        fi
    else
        if [[ -f "$SYSTEMD_UNIT" ]]; then
            sudo rm -f "$SYSTEMD_UNIT"
            sudo systemctl daemon-reload
            log "✅ Removed: $SYSTEMD_UNIT"
        fi
        # Linux desktop shortcut
        rm -f "$HOME/Desktop/OpenClaw.desktop" 2>/dev/null || true
    fi
}

remove_shell_aliases() {
    log "🔗 Removing shell aliases..."

    local SHELL_RC
    if [[ "$OS" == "macos" ]]; then
        SHELL_RC="$WORK_HOME/.zshrc"
    else
        SHELL_RC="$WORK_HOME/.bashrc"
    fi

    if [[ -f "$SHELL_RC" ]] && grep -q "# OpenClaw Environment" "$SHELL_RC"; then
        # Remove the OpenClaw block (comment + all following alias lines until empty line)
        sed -i.bak '/^# OpenClaw Environment/,/^$/d' "$SHELL_RC"
        log "✅ Removed aliases from $SHELL_RC (backup at ${SHELL_RC}.bak)"
    else
        log "No OpenClaw aliases found in $SHELL_RC"
    fi
}

backup_config() {
    if [[ -d "$OPENCLAW_CONFIG_DIR" ]]; then
        log "💾 Backing up $OPENCLAW_CONFIG_DIR → $BACKUP_PATH"
        cp -r "$OPENCLAW_CONFIG_DIR" "$BACKUP_PATH"
        log "✅ Backup created at: $BACKUP_PATH"
    fi
}

remove_config() {
    if [[ -d "$OPENCLAW_CONFIG_DIR" ]]; then
        if confirm "Remove ~/.openclaw config directory? (your workspace files and settings will be deleted)"; then
            rm -rf "$OPENCLAW_CONFIG_DIR"
            log "✅ Removed: $OPENCLAW_CONFIG_DIR"
        else
            log "⏭️  Keeping $OPENCLAW_CONFIG_DIR"
        fi
    fi
}

remove_npm_package() {
    log "📦 Removing openclaw npm package..."
    if command -v openclaw >/dev/null 2>&1; then
        if [[ "$OS" == "macos" ]]; then
            npm uninstall -g openclaw || warn "Could not remove npm package (may need manual removal)"
        else
            sudo npm uninstall -g openclaw || warn "Could not remove npm package (may need manual removal)"
        fi
        log "✅ openclaw npm package removed"
    else
        log "openclaw not found in PATH, skipping npm uninstall"
    fi
}

main() {
    detect_os

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     OpenClaw Environment Uninstaller     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo "This will remove:"
    echo "  • OpenClaw gateway service (launchd/systemd)"
    echo "  • Shell aliases"
    echo "  • Optionally: ~/.openclaw config directory"
    echo "  • Optionally: openclaw npm package"
    echo ""

    if ! confirm "Proceed with uninstall?"; then
        log "Uninstall cancelled."
        exit 0
    fi

    # Back up config before doing anything
    backup_config

    stop_service
    remove_service_files
    remove_shell_aliases

    if confirm "Remove openclaw npm package (the binary)?"; then
        remove_npm_package
    fi

    remove_config

    echo ""
    log "✅ OpenClaw uninstall complete."
    if [[ -d "$BACKUP_PATH" ]]; then
        echo -e "${BLUE}Your config was backed up to: $BACKUP_PATH${NC}"
    fi
    echo ""
}

main "$@"
