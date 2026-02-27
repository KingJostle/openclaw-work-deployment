# OpenClaw Environment - Turnkey Installation for Windows
# Safe to run from Windows PowerShell 5.1 or PowerShell 7+

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
$ErrorActionPreference = "Stop"

# Configuration
$OPENCLAW_PORT = 18789
$WORK_HOME = $env:USERPROFILE
$WORKSPACE_DIR = "$WORK_HOME\.openclaw\workspace"
$CONFIG_DIR = "$WORK_HOME\.openclaw"
$INSTALL_LOG = "$WORK_HOME\openclaw-install.log"
$script:Summary = [ordered]@{}

function Set-Summary($k, $v) { $script:Summary[$k] = $v }
function Write-Step($msg) { Write-Host "[STEP] $msg" -ForegroundColor Cyan }
function Pause-AfterStep($label) {
    try {
        Read-Host "[PAUSE] $label complete. Press Enter to continue"
    } catch {
        Start-Sleep -Seconds 5
    }
}
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
    throw $msg
}

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Get-NpmCommand {
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if ($npm) { return $npm.Source }

    $fallback = 'C:\Program Files\nodejs\npm.cmd'
    if (Test-Path $fallback) { return $fallback }

    return $null
}

function Get-PwshPath {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }

    $knownPaths = @(
        'C:\Program Files\PowerShell\7\pwsh.exe',
        'C:\Program Files\PowerShell\pwsh.exe'
    )

    foreach ($path in $knownPaths) {
        if (Test-Path $path) { return $path }
    }

    return $null
}

function Test-WingetSoftSuccess {
    param([string]$Output)

    if (-not $Output) { return $false }

    return ($Output -match 'No available upgrade found' -or
        $Output -match 'No newer package versions are available' -or
        $Output -match 'Found an existing package already installed' -or
        $Output -match 'Successfully installed')
}

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Err "winget is required but was not found. Install App Installer from Microsoft Store, then re-run."
    }
}

function Ensure-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Log "✅ Running on PowerShell $($PSVersionTable.PSVersion)"
        Set-Summary 'PowerShell 7' 'OK (already running pwsh)'
        return
    }

    Warn "Detected Windows PowerShell $($PSVersionTable.PSVersion). Relaunching in PowerShell 7..."
    Ensure-Winget

    $pwshPath = Get-PwshPath
    if ($pwshPath) {
        Log "✅ PowerShell 7 resolved at: $pwshPath"
        Set-Summary 'PowerShell 7 Path' $pwshPath
    }

    if (-not $pwshPath) {
        Write-Step "Installing PowerShell 7 via winget"
        $wingetOutput = (& winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
        $wingetExit = $LASTEXITCODE
        Refresh-Path
        $pwshPath = Get-PwshPath

        if (-not $pwshPath) {
            Err "PowerShell 7 still not found after winget call (exit $wingetExit). Output: $wingetOutput"
        }

        if (Test-WingetSoftSuccess -Output $wingetOutput) {
            Warn "winget reported PowerShell as already installed or no upgrade needed; continuing."
        }
        Log "✅ PowerShell 7 resolved after winget at: $pwshPath"
        Set-Summary 'PowerShell 7 Path' $pwshPath
    }

    Set-Summary 'PowerShell 7' 'OK (installed/relaunching)'

    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) { Err "Could not determine script path for PowerShell 7 relaunch." }

    & $pwshPath -NoProfile -ExecutionPolicy Bypass -File $scriptPath
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
        Set-Summary 'Git' 'OK (already installed)'
        return
    }

    Ensure-Winget
    Warn "Git not found. Installing via winget..."
    $wingetOutput = (& winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
    $wingetExit = $LASTEXITCODE
    Refresh-Path

    if (Get-Command git -ErrorAction SilentlyContinue) {
        if (Test-WingetSoftSuccess -Output $wingetOutput) {
            Warn "winget reported Git as already installed or no upgrade needed; continuing."
        }
        Log "✅ Git installed: $(& git --version)"
        Set-Summary 'Git' 'OK (installed)'
    } else {
        Err "Git still unavailable after winget call (exit $wingetExit). Output: $wingetOutput"
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
            Set-Summary 'Node.js' 'OK (already installed)'
            return
        }
        Warn "Node.js version may be too old. Upgrading via winget..."
    } else {
        Warn "Node.js/npm not found. Installing via winget..."
    }

    Ensure-Winget
    $wingetOutput = (& winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
    $wingetExit = $LASTEXITCODE

    Refresh-Path

    if (Test-WingetSoftSuccess -Output $wingetOutput) {
        Warn "winget reported Node.js as already installed or no upgrade needed; continuing."
    }

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $npmCmd = Get-NpmCommand

    if (-not $nodeCmd) {
        if ($npmCmd) {
            Warn "node.exe still not found after PATH refresh; testing npm fallback at $npmCmd"
            & $npmCmd --version | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Err "Node.js unavailable after winget call (exit $wingetExit), and npm fallback failed. Output: $wingetOutput"
            }
            Set-Summary 'Node.js' 'WARN (node missing in PATH; npm fallback available)'
            return
        }
        Err "Node.js still not found after winget call (exit $wingetExit), and npm fallback is unavailable. Output: $wingetOutput"
    }

    if (-not $npmCmd) { Err "npm.cmd still not found after install." }

    Log "✅ Node.js installed: $(& node --version)"
    Log "✅ npm installed: $(& $npmCmd --version)"
    Set-Summary 'Node.js' 'OK (installed)'
}

# ── OpenClaw ────────────────────────────────────────────────────────

function Install-OpenClaw {
    Write-Step "Installing OpenClaw"
    $npmCmd = Get-NpmCommand
    if (-not $npmCmd) { Err "npm is unavailable. Node.js installation appears incomplete." }

    & $npmCmd install -g openclaw
    if ($LASTEXITCODE -ne 0) { Err "npm failed to install openclaw globally." }

    Refresh-Path

    $oc = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($oc) {
        $ver = & openclaw version 2>$null
        if (-not $ver) { $ver = & openclaw --version 2>$null }
        if (-not $ver) { $ver = "unknown" }
        Log "✅ OpenClaw installed: $ver"
        Set-Summary 'OpenClaw' 'OK'
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

function Remove-InvalidGatewayBind {
    $cfg = "$CONFIG_DIR\openclaw.json"
    if (-not (Test-Path $cfg)) { return }

    try {
        $json = Get-Content -Path $cfg -Raw | ConvertFrom-Json
        if ($null -ne $json.gateway -and $json.gateway.PSObject.Properties.Name -contains 'bind') {
            $json.gateway.PSObject.Properties.Remove('bind')
            $json | ConvertTo-Json -Depth 20 | Set-Content -Path $cfg -Encoding UTF8
            Warn "Removed invalid gateway.bind from openclaw.json to prevent config corruption"
        }
    } catch {
        Warn "Could not validate/patch gateway.bind: $($_.Exception.Message)"
    }
}

function Run-DoctorAndPatchBind {
    Write-Step "Running openclaw doctor"
    try {
        $doctorOut = (& openclaw doctor 2>&1 | Out-String)
        if ($doctorOut -match 'gateway\.bind: Invalid input') {
            Warn "Detected invalid gateway.bind from doctor output; patching config automatically"
            Remove-InvalidGatewayBind
            & openclaw doctor --fix
            if ($LASTEXITCODE -eq 0) {
                Log "✅ openclaw doctor --fix completed after gateway.bind patch"
            } else {
                Warn "openclaw doctor --fix exited with code $LASTEXITCODE (continuing)"
            }
        } else {
            & openclaw doctor --fix
            if ($LASTEXITCODE -eq 0) {
                Log "✅ openclaw doctor --fix completed"
            } else {
                Warn "openclaw doctor --fix exited with code $LASTEXITCODE (continuing)"
            }
        }
    } catch {
        Warn "openclaw doctor validation/fix failed: $($_.Exception.Message)"
    }
}

function Print-Summary {
    Write-Host ""
    Write-Host "========== Install Summary ==========" -ForegroundColor Cyan

    if ($script:Summary.Count -eq 0) {
        Write-Host "- No steps were recorded." -ForegroundColor Yellow
    }

    foreach ($entry in $script:Summary.GetEnumerator()) {
        $color = 'Green'
        if ($entry.Value -match 'FAILED|ERROR') { $color = 'Red' }
        elseif ($entry.Value -match 'WARN|Warning') { $color = 'Yellow' }
        Write-Host ("- {0}: {1}" -f $entry.Key, $entry.Value) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "Installation log: $INSTALL_LOG" -ForegroundColor Cyan
}

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
    Pause-AfterStep 'PowerShell 7 install/check'

    Ensure-ExecutionPolicy
    Ensure-Winget

    Ensure-Git
    Pause-AfterStep 'Git install/check'

    Ensure-NodeJS
    Pause-AfterStep 'Node.js install/check'

    Install-OpenClaw
    Setup-Workspace
    Configure-OpenClaw
    Remove-InvalidGatewayBind
    Create-ScheduledTask
    Setup-Firewall
    Start-OpenClaw
    Create-Shortcuts
    Show-Instructions
    Run-DoctorAndPatchBind
    Set-Summary 'Result' 'SUCCESS'
    Log "🎉 Installation completed successfully!"
}

try {
    Main
    Print-Summary
} catch {
    $err = $_
    $detail = $err | Out-String
    Set-Summary 'Result' 'FAILED'
    Set-Summary 'Error' $err.Exception.Message
    Add-Content -Path $INSTALL_LOG -Value $detail
    Print-Summary
    Write-Host "Installation failed — see openclaw-install.log for details" -ForegroundColor Red
    exit 1
} finally {
    try {
        Read-Host "Press Enter to close"
    } catch {
        Start-Sleep -Seconds 5
    }
}