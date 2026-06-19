#Requires -Version 5.1
<#
.SYNOPSIS
    Sanity checks before running wallet recovery.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = "Stop"
$walletPath = Join-Path $ProjectRoot "artifacts\wallet.dat"
$addressPath = Join-Path $ProjectRoot "artifacts\target-address.txt"
$btcrecover = Join-Path $ProjectRoot "tools\btcrecover\btcrecover.py"

Write-Host "=== Dogecoin wallet validation ===" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"

$ok = $true

if (-not (Test-Path $walletPath)) {
    Write-Host "[FAIL] Missing wallet copy: $walletPath" -ForegroundColor Red
    Write-Host "       Copy your wallet.dat from %APPDATA%\Dogecoin\ or MultiDoge to artifacts\wallet.dat"
    $ok = $false
} else {
    $size = (Get-Item $walletPath).Length
    Write-Host "[OK]   Wallet file exists ($size bytes)" -ForegroundColor Green
    if ($size -lt 1000) {
        Write-Host "[WARN] Wallet file is very small — may not be a valid wallet.dat" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $addressPath)) {
    Write-Host "[WARN] Missing target address: $addressPath" -ForegroundColor Yellow
    Write-Host "       Copy artifacts\target-address.txt.example to target-address.txt and add your address."
    Write-Host "       Recovery can still run but will not stop early on address match."
} else {
    $addr = (Get-Content $addressPath -Raw).Trim()
    if ($addr -match '^D[a-km-zA-HJ-NP-Z1-9]{25,34}$') {
        Write-Host "[OK]   Target address: $addr" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Address does not look like a Dogecoin address: $addr" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $btcrecover)) {
    Write-Host "[FAIL] BTCRecover not found: $btcrecover" -ForegroundColor Red
    Write-Host "       Run: git clone https://github.com/3rdIteration/btcrecover.git tools\btcrecover"
    $ok = $false
} else {
    Write-Host "[OK]   BTCRecover found" -ForegroundColor Green
}

# Check Python
try {
    $pyVersion = & python --version 2>&1
    Write-Host "[OK]   $pyVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Python not found in PATH" -ForegroundColor Red
    $ok = $false
}

# Basic wallet.dat header check (Berkeley DB / Bitcoin Core wallet magic)
if (Test-Path $walletPath) {
    $bytes = [System.IO.File]::ReadAllBytes($walletPath)
    if ($bytes.Length -ge 16) {
        $header = [BitConverter]::ToString($bytes[0..15])
        Write-Host "[INFO] File header (first 16 bytes): $header"
    }
}

if (-not $ok) {
    Write-Host "`nValidation failed. Fix the issues above before running recovery." -ForegroundColor Red
    exit 1
}

Write-Host "`nValidation passed. Next steps:" -ForegroundColor Cyan
Write-Host "  1. Fill tokens\tier1_high_confidence.txt"
Write-Host "  2. .\scripts\run-tier1.ps1 -ListPassOnly"
Write-Host "  3. .\scripts\run-tier1.ps1"
