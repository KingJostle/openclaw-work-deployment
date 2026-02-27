# OpenClaw Windows Bootstrap Installer
# One-file bootstrap for fresh machines (handles Git + PowerShell 7 + clone + install)

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/KingJostle/openclaw-work-deployment.git"
$TargetDir = Join-Path $env:USERPROFILE "openclaw-work-deployment"

function Step($m) { Write-Host "[STEP] $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Die($m) { Write-Host "[ERR]  $m" -ForegroundColor Red; exit 1 }

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Die "winget is required but missing. Install App Installer from Microsoft Store and retry."
    }
}

function Ensure-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Ok "Running on PowerShell $($PSVersionTable.PSVersion)"
        return
    }

    Warn "Detected Windows PowerShell $($PSVersionTable.PSVersion). Switching to PowerShell 7..."
    Ensure-Winget

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        Step "Installing PowerShell 7"
        & winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Die "Failed to install PowerShell 7 via winget." }
        Refresh-Path
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    }

    if (-not $pwsh) { Die "PowerShell 7 install finished but pwsh.exe is not available in PATH." }

    $self = $MyInvocation.MyCommand.Path
    if (-not $self) { Die "Cannot determine bootstrap script path for relaunch." }

    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $self
    exit $LASTEXITCODE
}

function Ensure-ExecutionPolicy {
    Step "Setting execution policy"
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Ok "Execution policy set (CurrentUser: RemoteSigned)"
}

function Ensure-Git {
    Step "Checking Git"
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Ok "Git found: $(& git --version)"
        return
    }

    Ensure-Winget
    Warn "Git not found. Installing via winget..."
    & winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Die "Failed to install Git via winget." }

    Refresh-Path
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Ok "Git installed: $(& git --version)"
    } else {
        Die "Git installation completed but git is still unavailable in PATH."
    }
}

function Clone-Or-UpdateRepo {
    Step "Preparing repository"

    if (Test-Path (Join-Path $TargetDir ".git")) {
        Ok "Repo already exists at $TargetDir. Pulling latest changes..."
        Push-Location $TargetDir
        & git pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Die "git pull failed in existing repo."
        }
        Pop-Location
        return
    }

    if (Test-Path $TargetDir) {
        Warn "Directory exists but is not a git repo: $TargetDir"
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backup = "$TargetDir.backup.$timestamp"
        Move-Item -Path $TargetDir -Destination $backup -Force
        Warn "Moved existing directory to: $backup"
    }

    & git clone $RepoUrl $TargetDir
    if ($LASTEXITCODE -ne 0) { Die "Failed to clone $RepoUrl" }
    Ok "Repository cloned to $TargetDir"
}

function Run-MainInstaller {
    Step "Launching install.ps1"

    $installScript = Join-Path $TargetDir "install.ps1"
    if (-not (Test-Path $installScript)) {
        Die "install.ps1 not found at $installScript"
    }

    & pwsh -NoProfile -ExecutionPolicy Bypass -File $installScript
    if ($LASTEXITCODE -ne 0) { Die "install.ps1 failed with exit code $LASTEXITCODE" }

    Ok "Install completed"
}

Step "Starting OpenClaw Windows bootstrap install"
Ensure-PowerShell7
Ensure-ExecutionPolicy
Ensure-Winget
Ensure-Git
Clone-Or-UpdateRepo
Run-MainInstaller

Write-Host "" 
Write-Host "Done. OpenClaw should be available at http://localhost:18789" -ForegroundColor Green
