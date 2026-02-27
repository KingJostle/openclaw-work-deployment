# OpenClaw Windows Bootstrap Installer
# Run from any PowerShell window on a fresh machine.

$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/KingJostle/openclaw-work-deployment.git'
$TargetDir = Join-Path $env:USERPROFILE 'openclaw-work-deployment'

$script:Summary = [ordered]@{}

function Write-Step($m) { Write-Host "[STEP] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[ERR]  $m" -ForegroundColor Red }

function Set-Summary($k, $v) { $script:Summary[$k] = $v }

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user"
}

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is required but not found. Install App Installer from the Microsoft Store, then retry.'
  }
}

function Ensure-Admin {
  Write-Step 'Checking Administrator privileges'
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if ($isAdmin) {
    Write-Ok 'Running elevated as Administrator'
    Set-Summary 'Elevation' 'OK (already elevated)'
    return
  }

  Write-Warn 'Not elevated. Relaunching this script as Administrator...'
  $selfPath = $MyInvocation.MyCommand.Path
  if (-not $selfPath) {
    throw 'Cannot relaunch elevated because script path is unavailable.'
  }

  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $selfPath))
  Set-Summary 'Elevation' 'Relaunched with UAC prompt'
  exit 0
}

function Set-ExecutionPolicySafe {
  Write-Step 'Setting ExecutionPolicy (CurrentUser: RemoteSigned)'
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
  Write-Ok 'ExecutionPolicy updated'
  Set-Summary 'ExecutionPolicy' 'OK'
}

function Ensure-Git {
  Write-Step 'Checking Git'
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "Git present: $(& git --version)"
    Set-Summary 'Git' 'OK (already installed)'
    return
  }

  Ensure-Winget
  Write-Warn 'Git missing. Installing via winget...'
  & winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { throw 'Failed to install Git via winget.' }

  Refresh-Path
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git install reported success but git is not in PATH.'
  }

  Write-Ok "Git installed: $(& git --version)"
  Set-Summary 'Git' 'OK (installed)'
}

function Ensure-Pwsh {
  Write-Step 'Checking PowerShell 7 (pwsh.exe)'
  if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Ok "pwsh present: $(& pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')"
    Set-Summary 'PowerShell 7' 'OK (already installed)'
    return
  }

  Ensure-Winget
  Write-Warn 'PowerShell 7 missing. Installing via winget...'
  & winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { throw 'Failed to install PowerShell 7 via winget.' }

  Refresh-Path
  if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    throw 'PowerShell 7 install reported success but pwsh.exe is not in PATH.'
  }

  Write-Ok 'PowerShell 7 installed'
  Set-Summary 'PowerShell 7' 'OK (installed)'
}

function Ensure-Node {
  Write-Step 'Checking Node.js'
  if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Ok "Node.js present: $(& node --version)"
    Set-Summary 'Node.js' 'OK (already installed)'
    return
  }

  Ensure-Winget
  Write-Warn 'Node.js missing. Installing via winget...'
  & winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { throw 'Failed to install Node.js via winget.' }

  Refresh-Path
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js install reported success but node is not in PATH.'
  }

  Write-Ok "Node.js installed: $(& node --version)"
  Set-Summary 'Node.js' 'OK (installed)'
}

function Ensure-OpenClaw {
  Write-Step 'Installing OpenClaw globally via npm'
  & npm install -g openclaw
  if ($LASTEXITCODE -ne 0) { throw 'npm install -g openclaw failed.' }

  Refresh-Path
  if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
    throw 'OpenClaw installed but command not available in PATH.'
  }

  Write-Ok 'OpenClaw installed'
  Set-Summary 'OpenClaw' 'OK'
}

function Ensure-Repo {
  Write-Step 'Preparing repository'

  if (Test-Path (Join-Path $TargetDir '.git')) {
    Write-Ok "Repo already present at $TargetDir"
    Push-Location $TargetDir
    & git pull --ff-only
    if ($LASTEXITCODE -ne 0) {
      Pop-Location
      throw 'git pull failed in existing repository.'
    }
    Pop-Location
    Set-Summary 'Repository' 'OK (updated)'
    return
  }

  if (Test-Path $TargetDir) {
    $backup = "$TargetDir.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item -Path $TargetDir -Destination $backup -Force
    Write-Warn "Existing non-repo directory moved to: $backup"
  }

  & git clone $RepoUrl $TargetDir
  if ($LASTEXITCODE -ne 0) { throw 'Failed to clone repository.' }

  Write-Ok "Repository cloned to $TargetDir"
  Set-Summary 'Repository' 'OK (cloned)'
}

function Run-InstallScript {
  Write-Step 'Running install.ps1 via pwsh.exe'
  $installScript = Join-Path $TargetDir 'install.ps1'
  if (-not (Test-Path $installScript)) {
    throw "install.ps1 not found at $installScript"
  }

  & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $installScript
  if ($LASTEXITCODE -ne 0) {
    throw "install.ps1 failed (exit code: $LASTEXITCODE)"
  }

  Write-Ok 'install.ps1 completed'
  Set-Summary 'Main install' 'OK'
}

function Print-Summary {
  Write-Host ''
  Write-Host '========== Windows Install Summary ==========' -ForegroundColor Cyan
  foreach ($entry in $script:Summary.GetEnumerator()) {
    Write-Host ('- {0}: {1}' -f $entry.Key, $entry.Value) -ForegroundColor Green
  }
  Write-Host ''
  Write-Host 'If Scheduled Task setup was skipped due to permissions, rerun install.ps1 in an elevated shell later.' -ForegroundColor Yellow
  Write-Host 'OpenClaw UI: http://localhost:18789' -ForegroundColor Cyan
}

try {
  Write-Host 'OpenClaw Windows bootstrap starting...' -ForegroundColor Cyan
  Ensure-Admin
  Set-ExecutionPolicySafe
  Ensure-Git
  Ensure-Pwsh
  Ensure-Node
  Refresh-Path
  Ensure-OpenClaw
  Ensure-Repo
  Set-Location $TargetDir
  Run-InstallScript
  Print-Summary
} catch {
  Write-Err $_.Exception.Message
  Write-Host 'Install stopped. Fix the issue above and rerun this script.' -ForegroundColor Yellow
  exit 1
}
