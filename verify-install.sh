#!/bin/bash
# OpenClaw Work Environment - Installation Verification
# Supports macOS and Ubuntu/Debian

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

OPENCLAW_PORT="18789"
WORKSPACE_DIR="$HOME/.openclaw-work/workspace"
ERRORS=0

# Detect OS
case "$(uname -s)" in
    Darwin) OS="macos" ;;
    *)      OS="linux" ;;
esac

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; ((ERRORS++)); }
info()    { echo -e "${BLUE}ℹ️  $1${NC}"; }

check_nodejs() {
    info "Checking Node.js installation..."
    if command -v node &> /dev/null; then
        success "Node.js installed: $(node --version)"
    else
        error "Node.js not found"
    fi
}

check_openclaw() {
    info "Checking OpenClaw installation..."
    if command -v openclaw &> /dev/null; then
        success "OpenClaw installed: $(openclaw version 2>/dev/null || openclaw --version 2>/dev/null || echo 'unknown')"
    else
        error "OpenClaw not found"
    fi
}

check_service() {
    info "Checking OpenClaw work service..."
    if [[ "$OS" == "macos" ]]; then
        local PLIST="$HOME/Library/LaunchAgents/com.openclaw.work.plist"
        if [[ -f "$PLIST" ]]; then
            success "LaunchAgent plist exists"
            if launchctl list | grep -q "com.openclaw.work"; then
                success "LaunchAgent is loaded"
            else
                warning "LaunchAgent exists but is not loaded"
            fi
        else
            error "LaunchAgent plist not found"
        fi
    else
        if systemctl is-enabled --quiet openclaw-work.service 2>/dev/null; then
            success "Service is enabled (will start on boot)"
            if systemctl is-active --quiet openclaw-work.service; then
                success "Service is running"
            else
                warning "Service is enabled but not currently running"
            fi
        else
            error "Service is not enabled or doesn't exist"
        fi
    fi
}

check_port() {
    info "Checking port $OPENCLAW_PORT..."
    if curl -s --connect-timeout 3 "http://localhost:$OPENCLAW_PORT" > /dev/null 2>&1; then
        success "Port $OPENCLAW_PORT is responding (OpenClaw running)"
    else
        warning "Port $OPENCLAW_PORT not responding (service may not be running)"
    fi
}

check_workspace() {
    info "Checking workspace setup..."
    if [[ -d "$WORKSPACE_DIR" ]]; then
        success "Workspace directory exists: $WORKSPACE_DIR"
        local key_files=("AGENTS.md" "SOUL.md" "USER.md" "IDENTITY.md" "MEMORY.md" "TOOLS.md" "HEARTBEAT.md")
        for file in "${key_files[@]}"; do
            if [[ -f "$WORKSPACE_DIR/$file" ]]; then
                success "  $file exists"
            else
                error "  $file missing"
            fi
        done
        if [[ -d "$WORKSPACE_DIR/memory" ]]; then
            success "  memory/ directory exists"
        else
            error "  memory/ directory missing"
        fi
    else
        error "Workspace directory doesn't exist: $WORKSPACE_DIR"
    fi
}

check_config() {
    info "Checking OpenClaw configuration..."
    local config_file="$HOME/.openclaw-work/openclaw.json"
    if [[ -f "$config_file" ]]; then
        success "Configuration file exists"
        if grep -q "\"port\": $OPENCLAW_PORT" "$config_file"; then
            success "  Port $OPENCLAW_PORT configured correctly"
        else
            warning "  Port configuration may be incorrect"
        fi
    else
        error "Configuration file missing: $config_file"
    fi
}

check_shortcuts() {
    info "Checking convenience shortcuts..."
    local SHELL_RC
    if [[ "$OS" == "macos" ]]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
    if grep -q "openclaw-work" "$SHELL_RC" 2>/dev/null; then
        success "Shell aliases installed in $(basename "$SHELL_RC")"
    else
        warning "Shell aliases not found (may need to restart shell)"
    fi
}

show_status() {
    echo ""
    echo -e "${BLUE}=== VERIFICATION SUMMARY ($OS) ===${NC}"
    if [[ $ERRORS -eq 0 ]]; then
        success "All checks passed! ✨"
        echo ""
        echo -e "${GREEN}🎉 Your OpenClaw work environment is ready!${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "1. Visit: http://localhost:$OPENCLAW_PORT"
        echo "2. Go to workspace: openclaw-work (or cd $WORKSPACE_DIR)"
        echo "3. Follow BOOTSTRAP.md checklist"
        echo "4. Customize USER.md, IDENTITY.md for your work context"
    else
        error "Found $ERRORS issues that need attention"
        echo ""
        echo -e "${YELLOW}Common fixes:${NC}"
        if [[ "$OS" == "macos" ]]; then
            echo "• Service issues: openclaw-work-restart"
            echo "• View logs: openclaw-work-logs"
            echo "• Manual start: openclaw gateway --config=~/.openclaw-work/openclaw.json"
        else
            echo "• Service issues: sudo systemctl restart openclaw-work.service"
            echo "• View logs: journalctl -u openclaw-work.service -f"
        fi
        echo "• Port conflicts: edit ~/.openclaw-work/openclaw.json"
        echo "• Missing files: re-run ./install.sh"
    fi
    echo ""
}

main() {
    echo -e "${BLUE}🦞 OpenClaw Work Environment Verification ($OS)${NC}"
    echo ""
    check_nodejs
    check_openclaw
    check_service
    check_port
    check_workspace
    check_config
    check_shortcuts
    show_status
}

main "$@"
