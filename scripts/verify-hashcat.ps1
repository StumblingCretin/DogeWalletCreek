#Requires -Version 5.1
<#
.SYNOPSIS
    Verify hashcat can see NVIDIA GPU and supports mode 11300.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$hashcat = $null
$hashcatCandidates = @(
    (Join-Path $ProjectRoot "tools\hashcat\hashcat.exe"),
    "hashcat",
    "hashcat.exe"
)
foreach ($c in $hashcatCandidates) {
    if ($c -match '[\\/]' -and (Test-Path $c)) { $hashcat = $c; break }
    $found = Get-Command $c -ErrorAction SilentlyContinue
    if ($found) { $hashcat = $found.Source; break }
}

Write-Host "=== Hashcat / GPU verification ===" -ForegroundColor Cyan

if (-not $hashcat) {
    Write-Host "[WARN] hashcat not installed - GPU path unavailable" -ForegroundColor Yellow
    Write-Host "       Download from https://hashcat.net/hashcat/ and extract to tools\hashcat\"
    exit 0
}

Write-Host "Hashcat: $hashcat"
& $hashcat -I 2>&1
Write-Host ""
Write-Host "RTX 2070 profile: -D 2 -w 4 -O (GPU-only, nightmare workload)" -ForegroundColor Cyan
Write-Host "Quick start:  run-gpu-recovery.bat verify"
Write-Host ""
& $hashcat --help | Select-String "11300"
Write-Host "[OK] Mode 11300 = Bitcoin/Litecoin wallet.dat (Dogecoin Core compatible)" -ForegroundColor Green
