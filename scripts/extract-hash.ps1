#Requires -Version 5.1
<#
.SYNOPSIS
    Extract Dogecoin Core wallet.dat master key hash for hashcat mode 11300.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$walletPath = Join-Path $ProjectRoot "artifacts\wallet.dat"
$hashDir = Join-Path $ProjectRoot "hashes"
$rawPath = Join-Path $hashDir "wallet.raw"
$hashPath = Join-Path $hashDir "wallet.hash"
$johnScript = Join-Path $ProjectRoot "tools\bitcoin2john.py"

Write-Host "=== Dogecoin Core Hash Extraction (Hashcat Mode 11300) ===" -ForegroundColor Cyan

if (-not (Test-Path $walletPath)) {
    Write-Host "[ERROR] Dogecoin wallet not found at: $walletPath`nCopy your wallet.dat from %APPDATA%\Dogecoin\ to artifacts\wallet.dat first." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $johnScript)) {
    Write-Host "[ERROR] bitcoin2john.py not found at: $johnScript`nRun .\scripts\setup-tools.ps1 to download it." -ForegroundColor Red
    exit 1
}

# Resolve Python command / launcher
$pyCmd = "python"
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        $pyCmd = "py"
    }
}

New-Item -ItemType Directory -Force -Path $hashDir | Out-Null

Write-Host "Running bitcoin2john on Dogecoin wallet.dat..."

$ErrorActionPreference = "Continue"
$raw = & $pyCmd $johnScript $walletPath 2>&1
$rawString = ($raw -join "`n")

if ($rawString -match "not encrypted" -or $rawString -match "unencrypted" -or $rawString -match "No encrypted keys") {
    Write-Host "`n[ALERT] Wallet appears to be UNENCRYPTED!" -ForegroundColor Yellow
    Write-Host "Dogecoin wallets created in early 2013-2014 without a passphrase do not have an encrypted master key."
    Write-Host "You can open this wallet directly in Dogecoin Core or dump the keys without running hashcat/BTCRecover."
    $raw | Out-File -FilePath $rawPath -Encoding utf8
    exit 0
}

if ($LASTEXITCODE -ne 0 -and -not $raw) {
    Write-Host "[ERROR] bitcoin2john failed to process $walletPath. Output: $rawString" -ForegroundColor Red
    exit 1
}

$raw | Out-File -FilePath $rawPath -Encoding utf8

# Clean output: single line, no filename prefix (hashcat format)
$line = ($raw | Where-Object { $_ -match '\$bitcoin\$|\$btc\$' } | Select-Object -First 1)
if (-not $line) {
    $line = ($raw -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 1)
}

# Strip "wallet.dat:" or similar filename prefix
if ($line -match '^[^:]+:\s*(\$(?:bitcoin|btc)\$.+)$') {
    $line = $Matches[1].Trim()
}

if (-not $line -or ($line -notmatch '^\$(?:bitcoin|btc)\$')) {
    Write-Host "[ERROR] Could not parse a valid `$bitcoin`$ hash from bitcoin2john output.`nSee raw output in: $rawPath`nIf the wallet is unencrypted, no hash is needed." -ForegroundColor Red
    exit 1
}

# Write pure ASCII with no BOM or trailing newline for hashcat mode 11300
[System.IO.File]::WriteAllText($hashPath, $line, [System.Text.Encoding]::ASCII)

Write-Host "[OK] Dogecoin hash extracted successfully!" -ForegroundColor Green
Write-Host "     Hash saved to: $hashPath"
Write-Host "     Preview: $($line.Substring(0, [Math]::Min(80, $line.Length)))..."

Write-Host "`nReady for GPU attack:"
Write-Host "  run-gpu-recovery.bat tier 1"
Write-Host "  run-gpu-recovery.bat mask Much?d?d?d?d"
