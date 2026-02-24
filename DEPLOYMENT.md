# Deployment Instructions

Supports **macOS** (launchd) and **Ubuntu/Debian** (systemd).

## What's Ready for GitHub

Complete turnkey OpenClaw work environment deployment package:

```
openclaw-work-deployment/
├── README.md                    # Main documentation
├── DEPLOYMENT.md               # This file
├── .gitignore                  # Git ignore rules
├── install.sh                  # Complete installation script ⭐
├── quick-install.sh            # One-command wrapper ⭐
├── verify-install.sh           # Post-install verification ⭐
│
├── Templates
├── AGENTS.md                   # Session startup patterns
├── SOUL.md                     # Professional persona
├── USER.md                     # Work context template
├── IDENTITY.md                 # Assistant identity template
├── MEMORY.md                   # Work memory template
├── TOOLS.md                    # Infrastructure notes template
├── HEARTBEAT.md                # Work monitoring template
├── BOOTSTRAP.md                # Setup checklist
│
├── Documentation
├── SETUP-GUIDE.md              # Detailed setup guide
├── TRANSFER-SUMMARY.md         # What transfers vs what's fresh
│
├── memory/                     # Rate limit monitoring system
├── rate-limit-monitor.md
├── rate-limit-functions.md
├── rate-limit-state.json
│
└── scripts/                    # Utilities
    └── setup-work-openclaw.sh  # Alternative setup script
```

## GitHub Repository Setup

Repository: `KingJostle/openclaw-work-deployment` (public, no sensitive data)

## Install Commands (any platform)

```bash
git clone https://github.com/KingJostle/openclaw-work-deployment.git
cd openclaw-work-deployment
chmod +x install.sh verify-install.sh
./install.sh
./verify-install.sh   # optional verification
```

The installer auto-detects macOS vs Linux and uses the appropriate service manager.

## What Happens During Install

1. **System setup** (Node.js, dependencies, OpenClaw)
2. **Service creation** (launchd on macOS, systemd on Linux)
3. **Workspace creation** (`~/.openclaw/workspace`)
4. **Template deployment** (proven workspace patterns)
5. **Configuration** (port 18789, firewall rules on Linux)
6. **Shell aliases** (platform-appropriate convenience commands)

## Post-Install

1. **Access:** `http://localhost:18789`
2. **Workspace:** `openclaw-work` command or `cd ~/.openclaw/workspace`
3. **Customize:** Follow BOOTSTRAP.md checklist
4. **Service:** Auto-starts on boot/login

## What Gets Installed

### Software
- Node.js (latest LTS)
- OpenClaw (latest version)
- System dependencies (build tools, git, etc.)

### Services
- **macOS:** `com.openclaw.work` (LaunchAgent) - auto-start on login
- **Linux:** `openclaw-work.service` (systemd) - auto-start on boot
- Port 18789 (configurable)
- Firewall rules (Linux/UFW only)

### Work Environment
- Complete workspace with proven patterns
- Rate limit monitoring system
- Professional assistant persona
- Work-focused templates
- Backup procedures
- Convenience aliases

## Security Notes

✅ **Safe for work environment:**
- No personal data included
- No personal credentials
- Professional communication patterns
- Work-appropriate monitoring
- Complete isolation from other OpenClaw instances

❌ **Excluded (by design):**
- Personal memories and planning
- Personal API keys or credentials
- Personal communication patterns
- Home automation configs
- Personal project history

## Verification

Run `./verify-install.sh` or manually:

```bash
# Web access
curl -s http://localhost:18789 > /dev/null && echo "✅ OpenClaw accessible"

# Workspace check
ls -la ~/.openclaw/workspace/

# Service status (macOS)
launchctl list | grep com.openclaw.work

# Service status (Linux)
systemctl status openclaw-work.service
```

## Ready to Deploy!

This package supports one-command deployment on both macOS and Ubuntu/Debian. The entire work environment will be operational within minutes of running the install script.
