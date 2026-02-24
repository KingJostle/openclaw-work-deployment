# OpenClaw Work Environment - Turnkey Installation for Windows
# Run in PowerShell (as Administrator recommended for scheduled task)

$ErrorActionPreference = "Stop"

# Configuration
$OPENCLAW_PORT = 18789
$WORK_HOME = $env:USERPROFILE
$WORKSPACE_DIR = "$WORK_HOME\.openclaw\workspace"
$CONFIG_DIR = "$WORK_HOME\.openclaw"
$INSTALL_LOG = "$WORK_HOME\openclaw-work-install.log"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line -ForegroundColor Green
    Add-Content -Path $INSTALL_LOG -Value $line
}

function Warn($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] WARNING: $msg"
    Write-Host $line -ForegroundColor Yellow
    Add-Content -Path $INSTALL_LOG -Value $line
}

function Err($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] ERROR: $msg"
    Write-Host $line -ForegroundColor Red
    Add-Content -Path $INSTALL_LOG -Value $line
    exit 1
}

# ── Node.js ─────────────────────────────────────────────────────────

function Install-NodeJS {
    Log "🔧 Checking Node.js..."

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        $ver = & node --version
        Log "Node.js already installed: $ver"
        # Check if version is 18+
        if ($ver -match 'v(\d+)' -and [int]$Matches[1] -ge 18) {
            Log "✅ Node.js version is sufficient"
            return
        }
        Warn "Node.js version may be too old, attempting upgrade"
    }

    # Try winget first, fall back to direct download
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Log "Installing Node.js via winget..."
        & winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    } else {
        Log "Installing Node.js via direct download..."
        $installerUrl = "https://nodejs.org/dist/v22.12.0/node-v22.12.0-x64.msi"
        $installerPath = "$env:TEMP\nodejs-installer.msi"
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait
        Remove-Item $installerPath -ErrorAction SilentlyContinue
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    $ver = & node --version
    $npmVer = & npm --version
    Log "✅ Node.js installed: $ver"
    Log "✅ npm installed: $npmVer"
}

# ── OpenClaw ────────────────────────────────────────────────────────

function Install-OpenClaw {
    Log "🦞 Installing OpenClaw..."

    & npm install -g openclaw

    $oc = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($oc) {
        $ver = & openclaw version 2>$null
        if (-not $ver) { $ver = & openclaw --version 2>$null }
        if (-not $ver) { $ver = "unknown" }
        Log "✅ OpenClaw installed: $ver"
    } else {
        # Refresh PATH and retry
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $oc = Get-Command openclaw -ErrorAction SilentlyContinue
        if (-not $oc) { Err "OpenClaw installation failed. Ensure npm global bin is in PATH." }
        Log "✅ OpenClaw installed"
    }
}

# ── Workspace ───────────────────────────────────────────────────────

function Setup-Workspace {
    Log "📁 Setting up work workspace..."

    New-Item -ItemType Directory -Path "$WORKSPACE_DIR\memory" -Force | Out-Null
    New-Item -ItemType Directory -Path "$WORKSPACE_DIR\scripts" -Force | Out-Null
    New-Item -ItemType Directory -Path "$WORKSPACE_DIR\tools" -Force | Out-Null

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
    if (-not $scriptDir) { $scriptDir = Get-Location }

    # Copy template files
    $coreFiles = @("AGENTS.md", "SOUL.md", "USER.md", "IDENTITY.md", "TOOLS.md", "MEMORY.md", "HEARTBEAT.md", "BOOTSTRAP.md")
    foreach ($file in $coreFiles) {
        $src = Join-Path $scriptDir $file
        if (Test-Path $src) {
            Copy-Item $src -Destination "$WORKSPACE_DIR\" -Force
            Log "  ✅ $file"
        }
    }

    # Memory files
    $memDir = Join-Path $scriptDir "memory"
    if (Test-Path $memDir) {
        Copy-Item "$memDir\*" -Destination "$WORKSPACE_DIR\memory\" -Force
        Log "  ✅ Rate limit monitoring system"
    }

    # Scripts
    $scriptsDir = Join-Path $scriptDir "scripts"
    if (Test-Path $scriptsDir) {
        Copy-Item "$scriptsDir\*" -Destination "$WORKSPACE_DIR\scripts\" -Force
        Log "  ✅ Scripts and utilities"
    }

    # Documentation
    foreach ($doc in @("README.md", "SETUP-GUIDE.md", "TRANSFER-SUMMARY.md")) {
        $src = Join-Path $scriptDir $doc
        if (Test-Path $src) {
            Copy-Item $src -Destination "$WORKSPACE_DIR\" -Force
        }
    }

    Log "✅ Work workspace created at: $WORKSPACE_DIR"
}

# ── Config ──────────────────────────────────────────────────────────

function Configure-OpenClaw {
    Log "⚙️  Configuring OpenClaw..."

    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

    $config = @"
{
  "gateway": {
    "port": $OPENCLAW_PORT,
    "host": "0.0.0.0"
  },
  "agents": {
    "main": {
      "path": "$($WORKSPACE_DIR -replace '\\', '\\\\')"
    }
  }
}
"@

    Set-Content -Path "$CONFIG_DIR\openclaw.json" -Value $config -Encoding UTF8
    Log "✅ OpenClaw configured for port $OPENCLAW_PORT"
}

# ── Scheduled Task (auto-start) ────────────────────────────────────

function Create-ScheduledTask {
    Log "🔄 Creating scheduled task for auto-start..."

    $openclaw = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
    $node = (Get-Command node -ErrorAction SilentlyContinue).Source

    if (-not $openclaw -or -not $node) {
        Warn "Could not locate openclaw or node binary. Skipping scheduled task."
        return
    }

    $taskName = "OpenClaw-Work"

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction `
        -Execute $node `
        -Argument "`"$openclaw`" gateway --config=`"$CONFIG_DIR\openclaw.json`"" `
        -WorkingDirectory $WORKSPACE_DIR

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Days 365)

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "OpenClaw Work Environment" `
        -RunLevel Highest `
        -ErrorAction Stop | Out-Null

    Log "✅ Scheduled task '$taskName' created (starts at login)"
}

# ── Firewall ────────────────────────────────────────────────────────

function Setup-Firewall {
    Log "🔥 Configuring firewall..."

    $ruleName = "OpenClaw Work (Port $OPENCLAW_PORT)"
    $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

    if (-not $existing) {
        try {
            New-NetFirewallRule `
                -DisplayName $ruleName `
                -Direction Inbound `
                -Action Allow `
                -Protocol TCP `
                -LocalPort $OPENCLAW_PORT | Out-Null
            Log "✅ Firewall rule added for port $OPENCLAW_PORT"
        } catch {
            Warn "Could not add firewall rule (may need Administrator). Run as Admin if needed."
        }
    } else {
        Log "✅ Firewall rule already exists"
    }
}

# ── Start Service ───────────────────────────────────────────────────

function Start-OpenClaw {
    Log "🚀 Starting OpenClaw..."

    $taskName = "OpenClaw-Work"
    try {
        Start-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 3

        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$OPENCLAW_PORT" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Log "✅ OpenClaw is running at http://localhost:$OPENCLAW_PORT"
        } catch {
            Warn "Service may still be starting. Check http://localhost:$OPENCLAW_PORT in a moment."
        }
    } catch {
        Warn "Could not start scheduled task. Try: Start-ScheduledTask -TaskName '$taskName'"
    }
}

# ── Shortcuts ───────────────────────────────────────────────────────

function Create-Shortcuts {
    Log "🔗 Creating convenience shortcuts..."

    # Add PowerShell profile aliases
    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    $marker = "# OpenClaw Work Environment"
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent.Contains($marker)) {
        Log "Shortcuts already present in PowerShell profile, skipping"
        return
    }

    $aliases = @"

$marker
function openclaw-work { Set-Location "$WORKSPACE_DIR" }
function openclaw-work-status {
    try {
        `$null = Invoke-WebRequest -Uri "http://localhost:$OPENCLAW_PORT" -UseBasicParsing -TimeoutSec 3
        Write-Host "✅ Running" -ForegroundColor Green
    } catch {
        Write-Host "❌ Not running" -ForegroundColor Red
    }
}
function openclaw-work-restart {
    Stop-ScheduledTask -TaskName "OpenClaw-Work" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-ScheduledTask -TaskName "OpenClaw-Work"
    Write-Host "✅ Restarted" -ForegroundColor Green
}
function openclaw-work-stop {
    Stop-ScheduledTask -TaskName "OpenClaw-Work" -ErrorAction SilentlyContinue
    Write-Host "✅ Stopped" -ForegroundColor Green
}
"@

    Add-Content -Path $PROFILE -Value $aliases
    Log "✅ Shortcuts added to PowerShell profile"
}

# ── Final Instructions ──────────────────────────────────────────────

function Show-Instructions {
    Log "📋 Installation complete!"
    Write-Host ""
    Write-Host "🔗 Access your OpenClaw work environment:" -ForegroundColor Cyan
    Write-Host "   http://localhost:$OPENCLAW_PORT"
    Write-Host ""
    Write-Host "📁 Your workspace is located at:" -ForegroundColor Cyan
    Write-Host "   $WORKSPACE_DIR"
    Write-Host ""
    Write-Host "⚙️  Complete setup by:" -ForegroundColor Cyan
    Write-Host "   1. Open a new PowerShell window (to load aliases)"
    Write-Host "   2. Run: openclaw-work"
    Write-Host "   3. Follow the BOOTSTRAP.md checklist"
    Write-Host "   4. Customize USER.md, IDENTITY.md, etc."
    Write-Host ""
    Write-Host "🔧 Useful commands:" -ForegroundColor Cyan
    Write-Host "   openclaw-work-status     # Check if running"
    Write-Host "   openclaw-work-restart    # Restart service"
    Write-Host "   openclaw-work-stop       # Stop service"
    Write-Host "   openclaw-work            # Go to workspace"
    Write-Host ""
    Write-Host "📝 Installation log: $INSTALL_LOG" -ForegroundColor Cyan
    Write-Host ""
}

# ── Main ────────────────────────────────────────────────────────────

function Main {
    Log "🦞 Starting OpenClaw Work Environment Installation (Windows)"
    Log "📊 Installation log: $INSTALL_LOG"

    Install-NodeJS
    Install-OpenClaw
    Setup-Workspace
    Configure-OpenClaw
    Create-ScheduledTask
    Setup-Firewall
    Start-OpenClaw
    Create-Shortcuts
    Show-Instructions

    Log "🎉 Installation completed successfully!"
}

Main
