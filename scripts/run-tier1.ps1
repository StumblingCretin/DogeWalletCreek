#Requires -Version 5.1
<#
.SYNOPSIS
    Run BTCRecover with tiered token lists.
.PARAMETER Tier
    Token tier: 1 (default), 2, or 3.
.PARAMETER ListPassOnly
    Dry run — list password candidates without testing wallet.
.PARAMETER Restore
    Resume from autosave file instead of starting fresh.
#>
param(
    [ValidateSet(1, 2, 3)]
    [int]$Tier = 1,
    [switch]$ListPassOnly,
    [string]$Restore = "",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$btcrecover = Join-Path $ProjectRoot "tools\btcrecover\btcrecover.py"
$walletPath = Join-Path $ProjectRoot "artifacts\wallet.dat"
$logDir = Join-Path $ProjectRoot "runs\logs"
$autosaveDir = Join-Path $ProjectRoot "runs\autosave"

$tokenFiles = @{
    1 = Join-Path $ProjectRoot "tokens\tier1_high_confidence.txt"
    2 = Join-Path $ProjectRoot "tokens\tier2_variations.txt"
    3 = Join-Path $ProjectRoot "tokens\tier3_typos.txt"
}

$tokenFile = $tokenFiles[$Tier]
$autosaveFile = Join-Path $autosaveDir "tier$Tier.sav"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "tier$Tier-$timestamp.log"

New-Item -ItemType Directory -Force -Path $logDir, $autosaveDir | Out-Null

if (-not (Test-Path $btcrecover)) {
    Write-Error "BTCRecover not found. Clone to tools\btcrecover first."
}

if (-not $ListPassOnly -and -not $Restore -and -not (Test-Path $walletPath)) {
    Write-Error "Wallet not found: $walletPath"
}

if (-not (Test-Path $tokenFile)) {
    Write-Error "Token file not found: $tokenFile"
}

$args = @()

if ($Restore) {
    $args += "--restore", $Restore
} else {
    $args += "--tokenlist", $tokenFile

    if ($ListPassOnly) {
        $args += "--listpass"
    } else {
        $args += "--wallet", $walletPath
        $args += "--autosave", $autosaveFile

        $addressPath = Join-Path $ProjectRoot "artifacts\target-address.txt"
        if (Test-Path $addressPath) {
            $addr = (Get-Content $addressPath -Raw).Trim()
            if ($addr -and $addr -notmatch '^DYourKnown') {
                $args += "--addrs", $addr
            }
        }

        $threads = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).NumberOfLogicalProcessors
        if (-not $threads) { $threads = 4 }
        $args += "--threads", $threads

        switch ($Tier) {
            2 {
                $args += "--typos", "1", "--typos-case", "--typos-closecase"
            }
            3 {
                $leetMap = Join-Path $ProjectRoot "typos\leet.txt"
                $args += "--typos", "2", "--typos-case", "--typos-closecase"
                if (Test-Path $leetMap) {
                    $args += "--typos-map", $leetMap
                }
            }
        }
    }
}

Write-Host "=== BTCRecover Tier $Tier ===" -ForegroundColor Cyan
Write-Host "Command: python $btcrecover $($args -join ' ')"

if ($ListPassOnly) {
    $output = & python $btcrecover @args 2>&1
    $output | Tee-Object -FilePath $logFile
    $count = ($output | Measure-Object -Line).Lines
    Write-Host "`nCandidate count: $count" -ForegroundColor Yellow
    if ($count -gt 1000000) {
        Write-Host "WARNING: Over 1M candidates — consider tightening tokens before running." -ForegroundColor Red
    }
} else {
    & python $btcrecover @args 2>&1 | Tee-Object -FilePath $logFile
    Write-Host "Log saved: $logFile"
    if (Test-Path $autosaveFile) {
        Write-Host "Autosave: $autosaveFile (resume with -Restore $autosaveFile)"
    }
}
