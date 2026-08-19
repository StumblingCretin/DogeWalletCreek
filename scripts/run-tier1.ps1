#Requires -Version 5.1
<#
.SYNOPSIS
    Run BTCRecover with tiered Dogecoin token lists.
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
    Write-Host "[ERROR] BTCRecover not found at: $btcrecover`nRun .\scripts\setup-tools.ps1 first." -ForegroundColor Red
    exit 1
}

if (-not $ListPassOnly -and -not $Restore -and -not (Test-Path $walletPath)) {
    Write-Host "[ERROR] Dogecoin wallet not found at: $walletPath`nCopy your wallet.dat from %APPDATA%\Dogecoin\ to artifacts\wallet.dat" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $tokenFile)) {
    Write-Host "[ERROR] Token file not found at: $tokenFile" -ForegroundColor Red
    exit 1
}

# Locate python
$pyCmd = "python"
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        $pyCmd = "py"
    }
}

$btcrecoverArgs = @()

if ($Restore) {
    $btcrecoverArgs += "--restore", $Restore
} else {
    $btcrecoverArgs += "--tokenlist", $tokenFile

    if ($ListPassOnly) {
        $btcrecoverArgs += "--listpass"
    } else {
        $btcrecoverArgs += "--wallet", $walletPath
        $btcrecoverArgs += "--autosave", $autosaveFile

        $addressPath = Join-Path $ProjectRoot "artifacts\target-address.txt"
        if (Test-Path $addressPath) {
            $addr = (Get-Content $addressPath -Raw).Trim()
            if ($addr -and ($addr -match '^D[1-9A-HJ-NP-Za-km-z]{25,34}$' -or $addr -match '^[9A][1-9A-HJ-NP-Za-km-z]{25,34}$')) {
                Write-Host "Target Dogecoin address configured: $addr" -ForegroundColor Green
                $btcrecoverArgs += "--addrs", $addr
            } elseif ($addr -and $addr -notmatch '^DYourKnown') {
                Write-Host "Target address note: $addr" -ForegroundColor Gray
                $btcrecoverArgs += "--addrs", $addr
            }
        }

        $threads = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).NumberOfLogicalProcessors
        if (-not $threads) { $threads = 4 }
        $btcrecoverArgs += "--threads", $threads

        switch ($Tier) {
            2 {
                $btcrecoverArgs += "--typos", "1", "--typos-case", "--typos-closecase"
            }
            3 {
                $leetMap = Join-Path $ProjectRoot "typos\leet.txt"
                $btcrecoverArgs += "--typos", "2", "--typos-case", "--typos-closecase"
                if (Test-Path $leetMap) {
                    $btcrecoverArgs += "--typos-map", $leetMap
                }
            }
        }
    }
}

Write-Host "=== Dogecoin BTCRecover Tier $Tier ===" -ForegroundColor Cyan
Write-Host "Command: $pyCmd $btcrecover $($btcrecoverArgs -join ' ')"
Write-Host ""

$ErrorActionPreference = "Continue"

if ($ListPassOnly) {
    # Stream live to screen and log file
    & $pyCmd $btcrecover @btcrecoverArgs 2>&1 | Tee-Object -FilePath $logFile
    
    if (Test-Path $logFile) {
        $count = 0
        foreach ($line in [System.IO.File]::ReadLines($logFile)) {
            if ($line -notmatch '^\s*Starting btcrecover' -and 
                $line -notmatch '^\s*Loaded ' -and 
                $line -notmatch 'password combinations' -and
                $line.Trim() -ne "") {
                $count++
            }
        }
        Write-Host "`nTotal Candidate Passwords: $count" -ForegroundColor Yellow
        if ($count -gt 500000) {
            Write-Host "[NOTE] Over 500k candidates. Tier 1 is best kept under 50k for fast CPU testing." -ForegroundColor Yellow
        }
    }
} else {
    & $pyCmd $btcrecover @btcrecoverArgs 2>&1 | Tee-Object -FilePath $logFile
    Write-Host "`nLog saved: $logFile"
    if (Test-Path $autosaveFile) {
        Write-Host "Autosave: $autosaveFile (resume with -Restore $autosaveFile)"
    }
}
