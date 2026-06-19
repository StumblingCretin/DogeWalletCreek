#Requires -Version 5.1
<#
.SYNOPSIS
    Sanity checks before running wallet recovery.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
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
    Write-Host "       Copy wallet.dat from %APPDATA%\Dogecoin\ or MultiDoge to artifacts\wallet.dat"
    $ok = $false
} else {
    $size = (Get-Item $walletPath).Length
    Write-Host "[OK]   Wallet file exists ($size bytes)" -ForegroundColor Green
    if ($size -lt 1000) {
        Write-Host "[WARN] Wallet file is very small - may not be valid" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $addressPath)) {
    Write-Host "[WARN] Missing target address: $addressPath" -ForegroundColor Yellow
    Write-Host "       Copy target-address.txt.example to target-address.txt"
} else {
    $addr = (Get-Content $addressPath -Raw).Trim()
    if ($addr -match '^D[a-km-zA-HJ-NP-Z1-9]{25,34}$') {
        Write-Host "[OK]   Target address: $addr" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Address format unexpected: $addr" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $btcrecover)) {
    Write-Host "[FAIL] BTCRecover not found: $btcrecover" -ForegroundColor Red
    Write-Host "       Run: .\scripts\setup-tools.ps1"
    $ok = $false
} else {
    Write-Host "[OK]   BTCRecover found" -ForegroundColor Green
}

try {
    $pyVersion = & python --version 2>&1
    Write-Host "[OK]   $pyVersion" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Python not in PATH" -ForegroundColor Red
    $ok = $false
}

if (-not $ok) {
    Write-Host "`nValidation failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nValidation passed." -ForegroundColor Green
