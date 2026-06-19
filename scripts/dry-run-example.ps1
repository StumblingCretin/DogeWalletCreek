#Requires -Version 5.1
<#
.SYNOPSIS
    Dry-run BTCRecover with example tokens (no wallet required).
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$btcrecover = Join-Path $ProjectRoot "tools\btcrecover\btcrecover.py"
$tokenFile = Join-Path $ProjectRoot "tokens\tier1_dryrun.example.txt"

if (-not (Test-Path $btcrecover)) {
    Write-Error "Run .\scripts\setup-tools.ps1 first."
}

Write-Host "=== Dry-run: example token combinations ===" -ForegroundColor Cyan
python $btcrecover --listpass --tokenlist $tokenFile --dsw 2>&1
