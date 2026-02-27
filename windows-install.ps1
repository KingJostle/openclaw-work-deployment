# OpenClaw Windows Bootstrap Installer
# Run from any PowerShell window on a fresh machine.

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/KingJostle/openclaw-work-deployment.git'
$TargetDir = Join-Path $env:USERPROFILE 'openclaw-work-deployment'
$repoPath = $TargetDir
$InstallLog = Join-Path $env:USERPROFILE 'openclaw-install.log'

$script:Summary = [ordered]@{}

function Write-Step($m) { Write-Host "[STEP] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[ERR]  $m" -ForegroundColor Red }

function Write-Log($level, $message) {
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -Path $InstallLog -Value "[$ts] [$level] $message"
}

function Set-Summary($k, $v) { $script:Summary[$k] = $v }

function Pause-AfterStep($label) {
  try {
    Read-Host "[PAUSE] $label complete. Press Enter to continue"
  } catch {
    Start-Sleep -Seconds 5
  }
}

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
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
  $wingetOutput = (& winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
  $wingetExit = $LASTEXITCODE

  Refresh-Path
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) {
    throw "Git is still unavailable after winget install (exit $wingetExit). Output: $wingetOutput"
  }

  if (Test-WingetSoftSuccess -Output $wingetOutput) {
    Write-Warn 'winget reported Git as already installed or no upgrade needed; continuing.'
  }

  Write-Ok "Git installed: $(& git --version)"
  Set-Summary 'Git' 'OK (installed)'
}

function Ensure-Pwsh {
  Write-Step 'Checking PowerShell 7 (pwsh.exe)'
  $pwshPath = Get-PwshPath
  if ($pwshPath) {
    Write-Ok "pwsh present: $(& $pwshPath -NoLogo -NoProfile -ExecutionPolicy Bypass -Command '$PSVersionTable.PSVersion.ToString()')"
    Write-Log 'INFO' "PowerShell 7 path resolved: $pwshPath"
    Set-Summary 'PowerShell 7 Path' $pwshPath
    Set-Summary 'PowerShell 7' 'OK (already installed)'
    return
  }

  Ensure-Winget
  Write-Warn 'PowerShell 7 missing. Installing via winget...'
  $wingetOutput = (& winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
  $wingetExit = $LASTEXITCODE

  Refresh-Path
  $pwshPath = Get-PwshPath
  if (-not $pwshPath) {
    throw "PowerShell 7 still not found after winget call (exit $wingetExit). Output: $wingetOutput"
  }

  if (Test-WingetSoftSuccess -Output $wingetOutput) {
    Write-Warn 'winget reported PowerShell as already installed or no upgrade needed; continuing.'
  }

  Write-Ok "PowerShell 7 available at: $pwshPath"
  Write-Log 'INFO' "PowerShell 7 path resolved after winget: $pwshPath"
  Set-Summary 'PowerShell 7 Path' $pwshPath
  Set-Summary 'PowerShell 7' 'OK (installed or already present)'
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
  $wingetOutput = (& winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
  $wingetExit = $LASTEXITCODE

  Refresh-Path

  if (Test-WingetSoftSuccess -Output $wingetOutput) {
    Write-Warn 'winget reported Node.js as already installed or no upgrade needed; continuing.'
  }

  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    $npmCmd = Get-NpmCommand
    if ($npmCmd) {
      Write-Warn "node not found after PATH refresh; using npm fallback at $npmCmd"
      & $npmCmd --version | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw "Node.js unavailable after winget call (exit $wingetExit), and npm fallback failed. Output: $wingetOutput"
      }
      Set-Summary 'Node.js' 'WARN (node missing in PATH; npm fallback available)'
      return
    }

    throw "Node.js still not found after winget call (exit $wingetExit), and npm fallback is unavailable. Output: $wingetOutput"
  }

  Write-Ok "Node.js installed: $(& node --version)"
  Set-Summary 'Node.js' 'OK (installed)'
}

function Ensure-OpenClaw {
  Write-Step 'Installing OpenClaw globally via npm'
  $npmCmd = Get-NpmCommand
  if (-not $npmCmd) {
    throw 'npm is unavailable. Node.js installation appears incomplete.'
  }

  & $npmCmd install -g openclaw
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

function Remove-InvalidGatewayBind {
  $cfg = Join-Path $env:USERPROFILE '.openclaw\openclaw.json'
  if (-not (Test-Path $cfg)) { return $false }

  try {
    $json = Get-Content -Path $cfg -Raw | ConvertFrom-Json
    if ($null -ne $json.gateway -and $json.gateway.PSObject.Properties.Name -contains 'bind') {
      $json.gateway.PSObject.Properties.Remove('bind')
      $json | ConvertTo-Json -Depth 20 | Set-Content -Path $cfg -Encoding UTF8
      Write-Warn 'Removed invalid gateway.bind from openclaw.json to prevent configure failures.'
      return $true
    }
  } catch {
    Write-Warn "Failed to inspect/patch openclaw.json: $($_.Exception.Message)"
  }

  return $false
}

function Run-InstallScript {
  Write-Step 'Running install.ps1 via pwsh.exe'
  $installScript = Join-Path $TargetDir 'install.ps1'
  if (-not (Test-Path $installScript)) {
    throw "install.ps1 not found at $installScript"
  }

  $pwshPath = Get-PwshPath
  if (-not $pwshPath) {
    throw 'Cannot run install.ps1 because pwsh.exe was not found.'
  }

  & "$pwshPath" -ExecutionPolicy Bypass -File "$repoPath\install.ps1"
  if ($LASTEXITCODE -ne 0) {
    throw "install.ps1 failed (exit code: $LASTEXITCODE)"
  }

  Write-Ok 'install.ps1 completed'
  Set-Summary 'Main install' 'OK'
}

function Validate-DoctorAndPatchBind {
  Write-Step 'Running post-install doctor validation'
  try {
    $doctorOut = (& openclaw doctor 2>&1 | Out-String)
    if ($doctorOut -match 'gateway\.bind: Invalid input') {
      Write-Warn 'Detected gateway.bind: Invalid input. Applying automatic config patch...'
      $changed = Remove-InvalidGatewayBind
      if ($changed) {
        & openclaw doctor --fix | Out-Null
        Write-Ok 'Patched gateway.bind and re-ran openclaw doctor --fix'
        Set-Summary 'Doctor validation' 'Patched invalid gateway.bind'
      } else {
        Write-Warn 'gateway.bind error detected, but no patch was applied. Check ~/.openclaw/openclaw.json manually.'
        Set-Summary 'Doctor validation' 'Warning (manual fix may be needed)'
      }
    } else {
      & openclaw doctor --fix | Out-Null
      Write-Ok 'Doctor validation passed'
      Set-Summary 'Doctor validation' 'OK'
    }
  } catch {
    Write-Warn "Doctor validation failed: $($_.Exception.Message)"
    Set-Summary 'Doctor validation' 'Warning (doctor command failed)'
  }
}

function Print-Summary {
  Write-Host ''
  Write-Host '========== Windows Install Summary ==========' -ForegroundColor Cyan

  if ($script:Summary.Count -eq 0) {
    Write-Host '- No steps were recorded.' -ForegroundColor Yellow
  }

  foreach ($entry in $script:Summary.GetEnumerator()) {
    $color = 'Green'
    if ($entry.Value -match 'FAILED|ERR') { $color = 'Red' }
    elseif ($entry.Value -match 'WARN|Warning') { $color = 'Yellow' }
    Write-Host ('- {0}: {1}' -f $entry.Key, $entry.Value) -ForegroundColor $color
  }

  Write-Host ''
  Write-Host "Detailed log: $InstallLog" -ForegroundColor Cyan
  Write-Host 'If Scheduled Task setup was skipped due to permissions, rerun install.ps1 in an elevated shell later.' -ForegroundColor Yellow
  Write-Host 'OpenClaw UI: http://localhost:18789' -ForegroundColor Cyan
}

try {
  Write-Log 'INFO' 'OpenClaw Windows bootstrap starting'
  Write-Host 'OpenClaw Windows bootstrap starting...' -ForegroundColor Cyan

  Ensure-Admin
  Set-ExecutionPolicySafe

  Ensure-Git
  Pause-AfterStep 'Git install/check'

  Ensure-Pwsh
  Pause-AfterStep 'PowerShell 7 install/check'

  Ensure-Node
  Pause-AfterStep 'Node.js install/check'

  Refresh-Path
  Ensure-OpenClaw
  [void](Remove-InvalidGatewayBind)
  Ensure-Repo
  Set-Location $TargetDir
  Run-InstallScript
  Validate-DoctorAndPatchBind

  Set-Summary 'Result' 'SUCCESS'
  Print-Summary
} catch {
  $err = $_
  $msg = $err.Exception.Message
  $detail = $err | Out-String

  Set-Summary 'Result' 'FAILED'
  Set-Summary 'Error' $msg

  Write-Err $msg
  Write-Log 'ERROR' $detail
  Print-Summary
  Write-Host 'Installation failed — see openclaw-install.log for details' -ForegroundColor Red
  exit 1
} finally {
  try {
    Read-Host 'Press Enter to close'
  } catch {
    Start-Sleep -Seconds 5
  }
}
