#Requires -Version 5.1
<#
.SYNOPSIS
    Extract wallet.dat hash for hashcat mode 11300.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$walletPath = Join-Path $ProjectRoot "artifacts\wallet.dat"
$hashDir = Join-Path $ProjectRoot "hashes"
$rawPath = Join-Path $hashDir "wallet.raw"
$hashPath = Join-Path $hashDir "wallet.hash"
$johnScript = Join-Path $ProjectRoot "tools\bitcoin2john.py"

Write-Host "=== Extract wallet hash for hashcat -m 11300 ===" -ForegroundColor Cyan

if (-not (Test-Path $walletPath)) {
    Write-Error "Wallet not found: $walletPath"
}

if (-not (Test-Path $johnScript)) {
    Write-Error "bitcoin2john.py not found: $johnScript`nDownload from hashcat examples or John the Ripper blechschmidt fork."
}

New-Item -ItemType Directory -Force -Path $hashDir | Out-Null

Write-Host "Running bitcoin2john on wallet copy..."
$raw = & python $johnScript $walletPath 2>&1
if ($LASTEXITCODE -ne 0 -and -not $raw) {
    Write-Error "bitcoin2john failed: $raw"
}

$raw | Out-File -FilePath $rawPath -Encoding utf8

# Clean output: single line, no filename prefix (hashcat format)
$line = ($raw | Where-Object { $_ -match '\$bitcoin\$|\$btc\$' } | Select-Object -First 1)
if (-not $line) {
    $line = ($raw -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 1)
}

# Strip "wallet.dat:" or similar filename prefix
if ($line -match '^[^:]+:\s*(.+)$') {
    $line = $Matches[1].Trim()
}

if (-not $line) {
    Write-Error "Could not parse hash from bitcoin2john output. See $rawPath"
}

$line | Out-File -FilePath $hashPath -Encoding ascii -NoNewline
Write-Host "[OK] Hash written to: $hashPath" -ForegroundColor Green
Write-Host "     Preview: $($line.Substring(0, [Math]::Min(80, $line.Length)))..."

Write-Host "`nTest with hashcat:"
Write-Host "  hashcat -m 11300 -a 3 $hashPath `"?d?d?d?d`" --status"
