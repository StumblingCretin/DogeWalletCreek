#Requires -Version 5.1
<#
.SYNOPSIS
    Clone BTCRecover and install Python dependencies.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$toolsDir = Join-Path $ProjectRoot "tools"
$btcrecoverDir = Join-Path $toolsDir "btcrecover"
$repo = "https://github.com/3rdIteration/btcrecover.git"

New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

if (-not (Test-Path (Join-Path $btcrecoverDir ".git"))) {
    Write-Host "Cloning BTCRecover..."
    git clone --depth 1 $repo $btcrecoverDir
} else {
    Write-Host "BTCRecover already cloned at $btcrecoverDir"
}

Write-Host "Installing Python dependencies..."
Push-Location $btcrecoverDir
try {
    if (Test-Path "requirements.txt") {
        python -m pip install -r requirements.txt
    } elseif (Test-Path "requirements-full.txt") {
        python -m pip install -r requirements-full.txt
    } else {
        python -m pip install pycryptodome coincurve ecdsa
    }
} finally {
    Pop-Location
}

# Download bitcoin2john if missing
$johnPath = Join-Path $toolsDir "bitcoin2john.py"
if (-not (Test-Path $johnPath)) {
    Write-Host "Downloading bitcoin2john.py..."
    $url = "https://raw.githubusercontent.com/openwall/john/bleeding-jumbo/run/bitcoin2john.py"
    Invoke-WebRequest -Uri $url -OutFile $johnPath -UseBasicParsing
}

Write-Host "[OK] Tools setup complete" -ForegroundColor Green
Write-Host "Next: .\scripts\check-wallet.ps1"
