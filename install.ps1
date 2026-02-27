# OpenClaw Environment - Turnkey Installation for Windows
# Safe to run from Windows PowerShell 5.1 or PowerShell 7+

$ErrorActionPreference = "Stop"

# Configuration
$OPENCLAW_PORT = 18789
$WORK_HOME = $env:USERPROFILE
$WORKSPACE_DIR = "$WORK_HOME\.openclaw\workspace"
$CONFIG_DIR = "$WORK_HOME\.openclaw"
$INSTALL_LOG = "$WORK_HOME\openclaw-install.log"

function Write-Step($msg) { Write-Host "[STEP] $msg" -ForegroundColor Cyan }
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

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Err "winget is required but was not found. Install App Installer from Microsoft Store, then re-run."
    }
}

function Ensure-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Log "✅ Running on PowerShell $($PSVersionTable.PSVersion)"
        return
    }

    Warn "Detected Windows PowerShell $($PSVersionTable.PSVersion). Relaunching in PowerShell 7..."
    Ensure-Winget

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        Write-Step "Installing PowerShell 7 via winget"
        & winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Err "Failed to install PowerShell 7 via winget." }
        Refresh-Path
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    }

    if (-not $pwsh) { Err "PowerShell 7 install completed but pwsh.exe is still not on PATH." }

    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { Err "Could not determine script path for PowerShell 7 relaunch." }

    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    exit $LASTEXITCODE
}

function Ensure-ExecutionPolicy {
    Write-Step "Setting execution policy for current user"
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Log "✅ Execution policy set to RemoteSigned (CurrentUser)"
}

# ── Git + Node.js dependencies ─────────────────────────────────────

function Ensure-Git {
    Write-Step "Checking Git"
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Log "✅ Git installed: $(& git --version)"
        return
    }

    Ensure-Winget
    Warn "Git not found. Installing via winget..."
    & winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Err "Git installation failed." }
    Refresh-Path

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Log "✅ Git installed: $(& git --version)"
    } else {
        Err "Git install appears complete, but git is still unavailable in PATH. Open a new terminal and retry."
    }
}

function Ensure-NodeJS {
    Write-Step "Checking Node.js + npm"

    $node = Get-Command node -ErrorAction SilentlyContinue
    $npm = Get-Command npm -ErrorAction SilentlyContinue

    if ($node -and $npm) {
        $ver = & node --version
        Log "Node.js already installed: $ver"
        if ($ver -match 'v(\d+)' -and [int]$Matches[1] -ge 18) {
            Log "✅ Node.js version is sufficient"
            return
        }
        Warn "Node.js version may be too old. Upgrading via winget..."
    } else {
        Warn "Node.js/npm not found. Installing via winget..."
    }

    Ensure-Winget
    & winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Err "Node.js installation failed." }

    Refresh-Path

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Err "node.exe still not found after install." }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Err "npm.cmd still not found after install." }

    Log "✅ Node.js installed: $(& node --version)"
    Log "✅ npm installed: $(& npm --version)"
}

# ── OpenClaw ────────────────────────────────────────────────────────

function Install-OpenClaw {
    Write-Step "Installing OpenClaw"
    & npm install -g openclaw
    if ($LASTEXITCODE -ne 0) { Err "npm failed to install openclaw globally." }

    Refresh-Path

    $oc = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($oc) {
        $ver = & openclaw version 2>$null
        if (-not $ver) { $ver = & openclaw --version 2>$null }
        if (-not $ver) { $ver = "unknown" }
        Log "✅ OpenClaw installed: $ver"
    } else {
        Err "OpenClaw installation failed. Ensure npm global bin is in PATH."
    }
}

# ── Workspace ───────────────────────────────────────────────────────

function Setup-Workspace {
    Write-Step "Setting up workspace"

    New-Item -ItemType Directory -Path "$WORKSPACE_DIR\memory" -Force | Out-Null
    New-Item -ItemType Directory -Path "$WORKSPACE_DIR\scripts" -Force | Out-Null
    New-Item -ItemType Directory -Path "$WORKSPACE_DIR\tools" -Force | Out-Null

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $coreFiles = @("AGENTS.md", "SOUL.md", "USER.md", "IDENTITY.md", "TOOLS.md", "MEMORY.md", "HEARTBEAT.md", "BOOTSTRAP.md")
    foreach ($file in $coreFiles) {
        $src = Join-Path $scriptDir $file
        if (Test-Path $src) {
            Copy-Item $src -Destination "$WORKSPACE_DIR\" -Force
            Log "  ✅ $file"
        }
    }

    $memDir = Join-Path $scriptDir "memory"
    if (Test-Path $memDir) {
        Copy-Item "$memDir\*" -Destination "$WORKSPACE_DIR\memory\" -Force
        Log "  ✅ Rate limit monitoring system"
    }

    $scriptsDir = Join-Path $scriptDir "scripts"
    if (Test-Path $scriptsDir) {
        Copy-Item "$scriptsDir\*" -Destination "$WORKSPACE_DIR\scripts\" -Force
        Log "  ✅ Scripts and utilities"
    }

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
    Write-Step "Writing OpenClaw config"

    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

    $config = @"
{
  "gateway": {
    "port": $OPENCLAW_PORT,
    "bind": "0.0.0.0",
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  },
  "agents": {
    "list": [
      {
        "id": "main",
        "default": true,
        "workspace": "$($WORKSPACE_DIR -replace '\\', '\\\\')"
      }
    ]
  }
}
"@

    Set-Content -Path "$CONFIG_DIR\openclaw.json" -Value $config -Encoding UTF8
    Log "✅ OpenClaw configured for port $OPENCLAW_PORT"
}

# ── Scheduled Task (auto-start) ────────────────────────────────────

function Create-ScheduledTask {
    Write-Step "Creating scheduled task"

    $openclaw = (Get-Command openclaw -ErrorAction SilentlyContinue).Source
    $node = (Get-Command node -ErrorAction SilentlyContinue).Source

    if (-not $openclaw -or -not $node) {
        Warn "Could not locate openclaw or node binary. Skipping scheduled task."
        return
    }

    $taskName = "OpenClaw"

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

    try {
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Description "OpenClaw Environment" `
            -RunLevel Highest `
            -ErrorAction Stop | Out-Null

        Log "✅ Scheduled task '$taskName' created (starts at login)"
    } catch {
        Warn "Could not register scheduled task (usually requires Administrator). Continuing without auto-start."
        Warn "Details: $($_.Exception.Message)"
    }
}

# ── Firewall ────────────────────────────────────────────────────────

function Setup-Firewall {
    Write-Step "Configuring firewall"

    $ruleName = "OpenClaw (Port $OPENCLAW_PORT)"
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
    Write-Step "Starting OpenClaw"

    $taskName = "OpenClaw"
    try {
        Start-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 3

        try {
            $null = Invoke-WebRequest -Uri "http://localhost:$OPENCLAW_PORT" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Log "✅ OpenClaw is running at http://localhost:$OPENCLAW_PORT"
        } catch {
            Warn "Service may still be starting. Check http://localhost:$OPENCLAW_PORT in a moment."
        }
    } catch {
        Warn "Could not start scheduled task. Trying direct launch..."
        try {
            Start-Process -FilePath "node" -ArgumentList "`"$((Get-Command openclaw).Source)`" gateway --config=`"$CONFIG_DIR\openclaw.json`"" -WorkingDirectory $WORKSPACE_DIR -WindowStyle Hidden
            Log "✅ Started OpenClaw directly (without scheduled task)."
        } catch {
            Warn "Direct launch failed. Run manually: openclaw gateway --config=`"$CONFIG_DIR\openclaw.json`""
        }
    }
}

# ── Shortcuts ───────────────────────────────────────────────────────

function Create-Shortcuts {
    Write-Step "Creating PowerShell shortcuts"

    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }

    $marker = "# OpenClaw Environment"
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent.Contains($marker)) {
        Log "Shortcuts already present in PowerShell profile, skipping"
        return
    }

    $aliases = @"

$marker
function openclaw-ws { Set-Location "$WORKSPACE_DIR" }
function openclaw-status {
    try {
        `$null = Invoke-WebRequest -Uri "http://localhost:$OPENCLAW_PORT" -UseBasicParsing -TimeoutSec 3
        Write-Host "✅ Running" -ForegroundColor Green
    } catch {
        Write-Host "❌ Not running" -ForegroundColor Red
    }
}
function openclaw-restart {
    Stop-ScheduledTask -TaskName "OpenClaw" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-ScheduledTask -TaskName "OpenClaw"
    Write-Host "✅ Restarted" -ForegroundColor Green
}
function openclaw-stop {
    Stop-ScheduledTask -TaskName "OpenClaw" -ErrorAction SilentlyContinue
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
    Write-Host "   2. Run: openclaw-ws"
    Write-Host "   3. Follow the BOOTSTRAP.md checklist"
    Write-Host "   4. Customize USER.md, IDENTITY.md, etc."
    Write-Host ""
    Write-Host "🔧 Useful commands:" -ForegroundColor Cyan
    Write-Host "   openclaw-status     # Check if running"
    Write-Host "   openclaw-restart    # Restart service"
    Write-Host "   openclaw-stop       # Stop service"
    Write-Host "   openclaw-ws         # Go to workspace"
    Write-Host ""
    Write-Host "📝 Installation log: $INSTALL_LOG" -ForegroundColor Cyan
    Write-Host ""
}

# ── Main ────────────────────────────────────────────────────────────

function Main {
    Log "🦞 Starting OpenClaw Installation (Windows)"
    Log "📊 Installation log: $INSTALL_LOG"

    Ensure-PowerShell7
    Ensure-ExecutionPolicy
    Ensure-Winget
    Ensure-Git
    Ensure-NodeJS
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