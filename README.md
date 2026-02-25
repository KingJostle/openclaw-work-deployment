# OpenClaw Work Environment - Turnkey Deployment

**One-command installation** of OpenClaw with proven professional patterns for **macOS, Windows, and Ubuntu/Debian** work environments.

## 🚀 Quick Start

### macOS / Linux
```bash
git clone https://github.com/KingJostle/openclaw-work-deployment.git
cd openclaw-work-deployment
chmod +x install.sh
./install.sh
```

### Windows (PowerShell as Administrator)
```powershell
git clone https://github.com/KingJostle/openclaw-work-deployment.git
cd openclaw-work-deployment
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

**That's it!** The installer detects your OS and sets everything up. OpenClaw will be running at `http://localhost:18789` with your work environment ready to customize.

## 📋 What This Installs

### Core System
- ✅ **Node.js** (latest LTS via Homebrew / winget / NodeSource)
- ✅ **OpenClaw** (latest version, globally installed)
- ✅ **Auto-start service** (launchd / Task Scheduler / systemd)
- ✅ **Work workspace** (`~/.openclaw/workspace`)

### Platform-Specific
| Feature | macOS | Windows | Linux |
|---------|-------|---------|-------|
| Installer | `install.sh` | `install.ps1` | `install.sh` |
| Service manager | launchd (LaunchAgent) | Task Scheduler | systemd |
| Package manager | Homebrew | winget | apt-get |
| Shell config | ~/.zshrc | PowerShell $PROFILE | ~/.bashrc |
| Firewall | Not needed (localhost) | Windows Firewall rule | UFW rules |
| Logs | ~/.openclaw/*.log | ~/.openclaw/*.log | journalctl |

### Proven Patterns (cross-platform)
- ✅ **Rate limit monitoring** (prevents API timeouts)
- ✅ **Professional assistant persona** (work-appropriate responses)
- ✅ **Session startup patterns** (loads work context automatically)
- ✅ **Heartbeat monitoring** (proactive work task management)
- ✅ **Backup procedures** (protect your work context)
- ✅ **Communication framework** (professional email/messaging style)

### Work Templates
- ✅ **USER.md** - Work context (customize for your workplace)
- ✅ **IDENTITY.md** - Professional assistant identity
- ✅ **MEMORY.md** - Work relationships and project tracking
- ✅ **TOOLS.md** - Work infrastructure notes
- ✅ **HEARTBEAT.md** - Work-hours monitoring schedule

## 🔧 Post-Install Setup

### 1. Complete Bootstrap Process
```bash
openclaw  # Go to workspace
# Follow BOOTSTRAP.md checklist
# Delete BOOTSTRAP.md when complete
```

### 2. Customize for Your Work
- **USER.md** → Add your actual work context, stakeholders, projects
- **IDENTITY.md** → Choose your work assistant name and persona
- **MEMORY.md** → Replace templates with real work information
- **TOOLS.md** → Add your work infrastructure details
- **HEARTBEAT.md** → Set your business hours and monitoring preferences

### 3. Test Core Functionality
- Access OpenClaw at `http://localhost:18789`
- Test session startup (should read work files automatically)
- Verify rate limit monitoring is active
- Test communication patterns match your professional style

## 🛠️ Management Commands

### macOS
```bash
openclaw-status     # Check if running
openclaw-restart    # Restart service
openclaw-stop       # Stop service
openclaw-logs       # View real-time logs
openclaw            # Go to workspace directory
```

### Windows (PowerShell)
```powershell
openclaw-status     # Check if running
openclaw-restart    # Restart service
openclaw-stop       # Stop service
openclaw            # Go to workspace directory
```

### Linux
```bash
openclaw-status     # Check if running
openclaw-restart    # Restart service
openclaw-logs       # View real-time logs
openclaw       # Go to workspace directory
```

## 📁 Directory Structure

```
~/.openclaw/
├── openclaw.json           # OpenClaw configuration (port 18789)
├── openclaw.*.log     # Service logs (macOS only)
└── workspace/              # Your work environment
    ├── AGENTS.md            # Session startup patterns
    ├── SOUL.md             # Professional persona
    ├── USER.md             # Work context (customize!)
    ├── IDENTITY.md         # Assistant identity (customize!)
    ├── MEMORY.md           # Work memory (customize!)
    ├── TOOLS.md            # Infrastructure notes (customize!)
    ├── HEARTBEAT.md        # Monitoring schedule (customize!)
    ├── memory/             # Daily logs and system state
    │   ├── rate-limit-*.md # Rate limit monitoring system
    │   └── YYYY-MM-DD.md   # Daily work logs
    └── scripts/            # Utilities and helpers
```

## 🔐 Security & Isolation

### What's Included
- Work-appropriate assistant persona
- Professional communication patterns
- Business-hours monitoring schedule
- Work-focused memory structure

### What's Excluded (by design)
- ❌ Personal data, credentials, or memories
- ❌ Personal communication patterns
- ❌ Home automation or personal tool configs
- ❌ Personal API keys or service accounts

### Data Boundaries
- Work data stays in work environment (`~/.openclaw/`)
- No personal data contamination
- Separate service, separate config, separate workspace
- Complete isolation from other OpenClaw instances

## 🚨 Troubleshooting

### macOS
```bash
# Check service
openclaw-status

# View logs
tail -f ~/.openclaw/openclaw.stderr.log

# Manual start for debugging
openclaw gateway --config=~/.openclaw/openclaw.json

# Reload LaunchAgent
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load -w ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

### Windows
```powershell
# Check service
openclaw-status

# View scheduled task
Get-ScheduledTask -TaskName "openclaw"

# Manual start for debugging
openclaw gateway --config="$env:USERPROFILE\.openclaw\openclaw.json"

# Restart task
Stop-ScheduledTask -TaskName "openclaw"
Start-ScheduledTask -TaskName "openclaw"
```

### Linux
```bash
# Check service
sudo systemctl status openclaw.service

# View logs
journalctl -u openclaw.service -f

# Manual start for debugging
openclaw gateway --config=~/.openclaw/openclaw.json
```

### Port Conflicts (both platforms)
```bash
# Check what's using the port
lsof -i :18789    # macOS
ss -tulpn | grep :18789  # Linux

# Edit config and restart
nano ~/.openclaw/openclaw.json
# Change port, then restart
```

## 🔄 Updates & Maintenance

### Update OpenClaw
```bash
# macOS
npm update -g openclaw && openclaw-restart

# Linux
sudo npm update -g openclaw
sudo systemctl restart openclaw.service
```

### Verify Installation
```bash
./verify-install.sh          # macOS / Linux
.\verify-install.ps1         # Windows
```

## 📊 Success Metrics

You'll know it's working when:
- ✅ Service auto-starts on boot/login
- ✅ Sessions begin with work context automatically loaded
- ✅ Communication style matches professional preferences
- ✅ Rate limit monitoring prevents API issues
- ✅ Work memory builds naturally across sessions

## 📞 Support

**Installation Issues:** Check the installation log at `~/openclaw-install.log`

**Configuration Help:** See `SETUP-GUIDE.md` in your workspace for detailed configuration guidance
