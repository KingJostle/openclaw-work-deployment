#!/bin/bash
# OpenClaw Environment - Turnkey Installation
# Supports macOS and Ubuntu/Debian

set -e

# Configuration
OPENCLAW_PORT="18789"
WORK_USER="$(whoami)"
WORK_HOME="$HOME"
WORKSPACE_DIR="$WORK_HOME/.openclaw/workspace"
INSTALL_LOG="$HOME/openclaw-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin) OS="macos" ;;
        Linux)
            if command -v apt-get &> /dev/null; then
                OS="linux"
            else
                error "Unsupported Linux distribution (requires apt-get). Debian/Ubuntu only."
            fi
            ;;
        *) error "Unsupported operating system: $(uname -s)" ;;
    esac
    log "🖥️  Detected platform: $OS ($(uname -s) $(uname -m))"
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$INSTALL_LOG"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$INSTALL_LOG"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$INSTALL_LOG"
    exit 1
}

install_nodejs() {
    log "🔧 Installing Node.js..."

    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log "Node.js already installed: $NODE_VERSION"
        if [[ "$NODE_VERSION" == v1[8-9]* ]] || [[ "$NODE_VERSION" == v2* ]]; then
            log "✅ Node.js version is sufficient"
            return 0
        else
            warn "Node.js version may be too old, continuing with installation"
        fi
    fi

    if [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            log "Installing Homebrew first..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install node
    else
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log "✅ Node.js installed: $NODE_VERSION"
    log "✅ npm installed: $NPM_VERSION"
}

install_dependencies() {
    log "📦 Installing system dependencies..."
    if [[ "$OS" == "macos" ]]; then
        # Xcode CLI tools cover git, build tools, curl
        if ! xcode-select -p &> /dev/null; then
            log "Installing Xcode Command Line Tools..."
            xcode-select --install
            warn "Xcode CLT install may require a GUI prompt. Re-run this script after it completes."
            exit 0
        fi
        log "✅ Xcode Command Line Tools present"
    else
        sudo apt-get update
        sudo apt-get install -y curl wget git build-essential
        log "✅ System dependencies installed"
    fi
}

install_openclaw() {
    log "🦞 Installing OpenClaw..."

    if [[ "$OS" == "macos" ]]; then
        npm install -g openclaw
    else
        sudo npm install -g openclaw
    fi

    if command -v openclaw &> /dev/null; then
        OPENCLAW_VERSION=$(openclaw version 2>/dev/null || openclaw --version 2>/dev/null || echo "unknown")
        log "✅ OpenClaw installed: $OPENCLAW_VERSION"
    else
        error "OpenClaw installation failed"
    fi
}

setup_workspace() {
    log "📁 Setting up work workspace..."

    mkdir -p "$WORKSPACE_DIR"/{memory,scripts,tools}

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    for file in AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md MEMORY.md HEARTBEAT.md BOOTSTRAP.md; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            cp "$SCRIPT_DIR/$file" "$WORKSPACE_DIR/"
            log "  ✅ $file"
        fi
    done

    if [[ -d "$SCRIPT_DIR/memory" ]]; then
        cp -r "$SCRIPT_DIR/memory"/* "$WORKSPACE_DIR/memory/"
        log "  ✅ Rate limit monitoring system"
    fi

    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        cp -r "$SCRIPT_DIR/scripts"/* "$WORKSPACE_DIR/scripts/"
        chmod +x "$WORKSPACE_DIR/scripts"/*.sh 2>/dev/null || true
        log "  ✅ Scripts and utilities"
    fi

    for doc in README.md SETUP-GUIDE.md TRANSFER-SUMMARY.md; do
        if [[ -f "$SCRIPT_DIR/$doc" ]]; then
            cp "$SCRIPT_DIR/$doc" "$WORKSPACE_DIR/"
        fi
    done

    log "✅ Work workspace created at: $WORKSPACE_DIR"
}

configure_openclaw() {
    log "⚙️  Configuring OpenClaw for work environment..."

    mkdir -p "$WORK_HOME/.openclaw"

    cat > "$WORK_HOME/.openclaw/openclaw.json" << EOF
{
  "gateway": {
    "port": $OPENCLAW_PORT,
    "host": "0.0.0.0"
  },
  "agents": {
    "main": {
      "path": "$WORKSPACE_DIR"
    }
  }
}
EOF

    log "✅ OpenClaw configured for port $OPENCLAW_PORT"
}

# ── Linux: systemd ──────────────────────────────────────────────────

create_systemd_service() {
    log "🔄 Creating systemd service for auto-start..."

    sudo tee /etc/systemd/system/openclaw.service > /dev/null << EOF
[Unit]
Description=OpenClaw Environment
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=$WORK_USER
Environment=NODE_ENV=production
WorkingDirectory=$WORKSPACE_DIR
ExecStart=$(which openclaw) gateway --config=$WORK_HOME/.openclaw/openclaw.json
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable openclaw.service
    log "✅ Systemd service created and enabled"
}

setup_firewall_linux() {
    log "🔥 Configuring firewall for OpenClaw..."
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow $OPENCLAW_PORT/tcp comment "OpenClaw"
        log "✅ Firewall rule added for port $OPENCLAW_PORT"
    else
        warn "UFW not active or installed - firewall not configured"
    fi
}

start_service_linux() {
    log "🚀 Starting OpenClaw work service..."
    sudo systemctl start openclaw.service
    sleep 3
    if systemctl is-active --quiet openclaw.service; then
        log "✅ OpenClaw work service is running"
    else
        warn "Service may not have started properly. Check: journalctl -u openclaw.service"
    fi
}

# ── macOS: launchd ──────────────────────────────────────────────────

create_launchd_agent() {
    log "🔄 Creating LaunchAgent for auto-start..."

    local PLIST_DIR="$WORK_HOME/Library/LaunchAgents"
    local PLIST_NAME="ai.openclaw.gateway.plist"
    local PLIST_PATH="$PLIST_DIR/$PLIST_NAME"
    local OPENCLAW_BIN
    local NODE_BIN

    OPENCLAW_BIN="$(which openclaw)"
    NODE_BIN="$(which node)"

    mkdir -p "$PLIST_DIR"

    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.openclaw.gateway</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_BIN</string>
        <string>$OPENCLAW_BIN</string>
        <string>gateway</string>
        <string>--config=$WORK_HOME/.openclaw/openclaw.json</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$WORKSPACE_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$WORK_HOME/.openclaw/openclaw.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$WORK_HOME/.openclaw/openclaw.stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>production</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF

    log "✅ LaunchAgent created at: $PLIST_PATH"
}

start_service_macos() {
    log "🚀 Starting OpenClaw work service..."
    local PLIST_PATH="$WORK_HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"

    # Unload first if already loaded (ignore errors)
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load -w "$PLIST_PATH"

    sleep 3
    if curl -s --connect-timeout 3 "http://localhost:$OPENCLAW_PORT" > /dev/null 2>&1; then
        log "✅ OpenClaw work service is running"
    else
        warn "Service may still be starting. Check logs at: ~/.openclaw/openclaw.stderr.log"
    fi
}

# ── Shortcuts ───────────────────────────────────────────────────────

create_shortcuts() {
    log "🔗 Creating convenience shortcuts..."

    local SHELL_RC
    if [[ "$OS" == "macos" ]]; then
        SHELL_RC="$WORK_HOME/.zshrc"
    else
        SHELL_RC="$WORK_HOME/.bashrc"
    fi

    # Avoid duplicate entries
    if grep -q "# OpenClaw Environment" "$SHELL_RC" 2>/dev/null; then
        log "Shortcuts already present in $SHELL_RC, skipping"
        return 0
    fi

    if [[ "$OS" == "macos" ]]; then
        cat >> "$SHELL_RC" << 'EOF'

# OpenClaw Environment
alias openclaw-ws="cd ~/.openclaw/workspace"
alias openclaw-logs="tail -f ~/.openclaw/openclaw.stderr.log"
alias openclaw-status="curl -sf http://localhost:18789 > /dev/null && echo '✅ Running' || echo '❌ Not running'"
alias openclaw-restart="launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null; launchctl load -w ~/Library/LaunchAgents/ai.openclaw.gateway.plist && echo '✅ Restarted'"
alias openclaw-stop="launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null && echo '✅ Stopped'"
EOF
    else
        cat >> "$SHELL_RC" << 'EOF'

# OpenClaw Environment
alias openclaw-ws="cd ~/.openclaw/workspace"
alias openclaw-logs="journalctl -u openclaw.service -f"
alias openclaw-status="systemctl status openclaw.service"
alias openclaw-restart="sudo systemctl restart openclaw.service"
EOF

        # Desktop shortcut for GUI environments
        if [[ -n "$DISPLAY" ]] && [[ -d "$HOME/Desktop" ]]; then
            cat > "$HOME/Desktop/OpenClaw.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenClaw
Comment=Access OpenClaw Environment
Exec=xdg-open http://localhost:$OPENCLAW_PORT
Icon=applications-internet
Terminal=false
Categories=Development;
EOF
            chmod +x "$HOME/Desktop/OpenClaw.desktop"
            log "✅ Desktop shortcut created"
        fi
    fi

    log "✅ Convenience shortcuts added to $(basename "$SHELL_RC")"
}

# ── Final output ────────────────────────────────────────────────────

final_setup_instructions() {
    log "📋 Installation complete! Next steps:"
    echo ""
    echo -e "${BLUE}🔗 Access your OpenClaw work environment:${NC}"
    echo "   http://localhost:$OPENCLAW_PORT"
    echo ""
    echo -e "${BLUE}📁 Your workspace is located at:${NC}"
    echo "   $WORKSPACE_DIR"
    echo ""
    echo -e "${BLUE}⚙️  Complete setup by:${NC}"
    echo "   1. Opening your workspace: openclaw-ws"
    echo "   2. Following the BOOTSTRAP.md checklist"
    echo "   3. Customizing USER.md, IDENTITY.md, etc. for your work context"
    echo ""
    echo -e "${BLUE}🔧 Useful commands:${NC}"
    if [[ "$OS" == "macos" ]]; then
        echo "   openclaw-status     # Check if running"
        echo "   openclaw-logs       # View real-time logs"
        echo "   openclaw-restart    # Restart service"
        echo "   openclaw-stop       # Stop service"
        echo "   openclaw-ws            # Go to workspace"
    else
        echo "   openclaw-status     # Check service status"
        echo "   openclaw-logs       # View real-time logs"
        echo "   openclaw-restart    # Restart service"
        echo "   openclaw-ws       # Go to workspace"
    fi
    echo ""
    echo -e "${BLUE}📝 Installation log saved to:${NC} $INSTALL_LOG"
    echo ""
}

# ── Main ────────────────────────────────────────────────────────────

main() {
    log "🦞 Starting OpenClaw Work Environment Installation"
    log "📊 Installation log: $INSTALL_LOG"

    detect_os
    install_dependencies
    install_nodejs
    install_openclaw
    setup_workspace
    configure_openclaw

    if [[ "$OS" == "macos" ]]; then
        create_launchd_agent
        start_service_macos
    else
        create_systemd_service
        setup_firewall_linux
        start_service_linux
    fi

    create_shortcuts
    final_setup_instructions

    log "🎉 Installation completed successfully!"
}

main "$@"
