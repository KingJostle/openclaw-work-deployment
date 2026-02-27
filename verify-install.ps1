# OpenClaw Work Environment - Installation Verification (Windows)

$OPENCLAW_PORT = 18789
$WORKSPACE_DIR = "$env:USERPROFILE\.openclaw\workspace"
$script:Errors = 0

function Success($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Warning($msg) { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Err($msg)     { Write-Host "❌ $msg" -ForegroundColor Red; $script:Errors++ }
function Info($msg)    { Write-Host "ℹ️  $msg" -ForegroundColor Cyan }

Info "Checking PowerShell version..."
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Success "PowerShell 7+: $($PSVersionTable.PSVersion)"
} else {
    Warning "Running Windows PowerShell $($PSVersionTable.PSVersion). PowerShell 7 is recommended."
}

Info "Checking winget..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Success "winget available"
} else {
    Warning "winget not found (required for auto-installs/updates)"
}

Info "Checking Git..."
if (Get-Command git -ErrorAction SilentlyContinue) {
    Success "Git installed: $(git --version)"
} else {
    Warning "Git not found"
}

Info "Checking Node.js..."
if (Get-Command node -ErrorAction SilentlyContinue) {
    Success "Node.js installed: $(node --version)"
} else { Err "Node.js not found" }

Info "Checking npm..."
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Success "npm installed: $(npm --version)"
} else { Err "npm not found" }

Info "Checking OpenClaw..."
if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    $v = & openclaw version 2>$null; if (-not $v) { $v = "unknown" }
    Success "OpenClaw installed: $v"
} else { Err "OpenClaw not found" }

Info "Checking scheduled task..."
$task = Get-ScheduledTask -TaskName "OpenClaw" -ErrorAction SilentlyContinue
if ($task) {
    Success "Scheduled task exists (State: $($task.State))"
} else { Warning "Scheduled task 'OpenClaw' not found (auto-start may be disabled)" }

Info "Checking port $OPENCLAW_PORT..."
try {
    $null = Invoke-WebRequest -Uri "http://localhost:$OPENCLAW_PORT" -UseBasicParsing -TimeoutSec 3
    Success "Port $OPENCLAW_PORT is responding"
} catch { Warning "Port $OPENCLAW_PORT not responding" }

Info "Checking workspace..."
if (Test-Path $WORKSPACE_DIR) {
    Success "Workspace exists: $WORKSPACE_DIR"
    foreach ($f in @("AGENTS.md","SOUL.md","USER.md","IDENTITY.md","MEMORY.md","TOOLS.md","HEARTBEAT.md")) {
        if (Test-Path "$WORKSPACE_DIR\$f") { Success "  $f" } else { Err "  $f missing" }
    }
} else { Err "Workspace not found: $WORKSPACE_DIR" }

Info "Checking config..."
$cfg = "$env:USERPROFILE\.openclaw\openclaw.json"
if (Test-Path $cfg) {
    Success "Config file exists"
    try {
        $cfgJson = Get-Content -Path $cfg -Raw | ConvertFrom-Json
        if ($null -ne $cfgJson.gateway -and $cfgJson.gateway.PSObject.Properties.Name -contains 'bind') {
            Err "Known issue detected: gateway.bind is present (invalid). Fix: remove gateway.bind from ~/.openclaw/openclaw.json or run openclaw doctor --fix"
        } else {
            Success "gateway.bind not present (good)"
        }
    } catch {
        Warning "Could not parse config JSON to validate gateway.bind"
    }
} else { Err "Config missing: $cfg" }

Write-Host ""
Write-Host "=== VERIFICATION SUMMARY (Windows) ===" -ForegroundColor Cyan
if ($script:Errors -eq 0) {
    Success "All critical checks passed! ✨"
    Write-Host "`nNext: http://localhost:$OPENCLAW_PORT" -ForegroundColor Green
} else {
    Err "Found $($script:Errors) critical issues"
    Write-Host "`nTry re-running install.ps1 (or windows-install.ps1) as Administrator" -ForegroundColor Yellow
}
