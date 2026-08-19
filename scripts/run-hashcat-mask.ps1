#Requires -Version 5.1
<#
.SYNOPSIS
    Run hashcat mode 11300 against extracted Dogecoin wallet hash.
.PARAMETER Mode
    Attack mode: dictionary (0), mask (3), or hybrid from generated candidates.
.PARAMETER Mask
    Hashcat mask string (required for -Mode mask).
.PARAMETER Wordlist
    Path to wordlist (for dictionary mode).
.PARAMETER Tier
    Generate candidates from token tier via BTCRecover --listpass, then run hashcat.
.PARAMETER GpuProfile
    GPU tuning profile. rtx2070 = -D 2 -w 4 -O (default).
#>
param(
    [ValidateSet("dictionary", "mask", "from-tier")]
    [string]$Mode = "mask",
    [string]$Mask = "",
    [string]$Wordlist = "",
    [ValidateSet(1, 2, 3)]
    [int]$Tier = 1,
    [ValidateSet("rtx2070", "balanced")]
    [string]$GpuProfile = "rtx2070",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$hashPath = Join-Path $ProjectRoot "hashes\wallet.hash"
$generatedDir = Join-Path $ProjectRoot "generated"
$logDir = Join-Path $ProjectRoot "runs\logs"
$sessionDir = Join-Path $ProjectRoot "runs\hashcat-sessions"
$potfile = Join-Path $ProjectRoot "runs\hashcat.potfile"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "hashcat-$timestamp.log"

New-Item -ItemType Directory -Force -Path $logDir, $generatedDir, $sessionDir | Out-Null

if (-not (Test-Path $hashPath)) {
    Write-Host "Hash file missing. Running extract-hash.ps1..." -ForegroundColor Yellow
    & (Join-Path $ProjectRoot "scripts\extract-hash.ps1") -ProjectRoot $ProjectRoot
}

if (-not (Test-Path $hashPath)) {
    Write-Host "[ERROR] Hash file still missing: $hashPath`nCopy your Dogecoin wallet to artifacts\wallet.dat and extract first." -ForegroundColor Red
    exit 1
}

# Locate hashcat
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

if (-not $hashcat) {
    Write-Host "[ERROR] hashcat not found. Run: .\scripts\install-hashcat.ps1" -ForegroundColor Red
    exit 1
}

# RTX 2070 profile: GPU-only, nightmare workload, optimized kernels
$gpuFlags = switch ($GpuProfile) {
    "rtx2070" { @("-D", "2", "-w", "4", "-O", "--status", "--status-timer", "15") }
    "balanced" { @("-D", "2", "-w", "3", "-O", "--status", "--status-timer", "15") }
}

$hcBase = @("-m", "11300") + $gpuFlags + @(
    "--potfile-path", $potfile,
    "--session", "doge-gpu"
)

# Resolve Python command / launcher
$pyCmd = "python"
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    if (Get-Command "py" -ErrorAction SilentlyContinue) {
        $pyCmd = "py"
    }
}

$ErrorActionPreference = "Continue"

switch ($Mode) {
    "mask" {
        if (-not $Mask) {
            Write-Host "[ERROR] Mask required for mask mode. Example: -Mask 'MuchWow?d?d?d?d'" -ForegroundColor Red
            exit 1
        }
        $hcArgs = @("-a", "3") + $hcBase + @($hashPath, $Mask)
    }
    "dictionary" {
        if (-not $Wordlist) {
            Write-Host "[ERROR] Wordlist path required for dictionary mode." -ForegroundColor Red
            exit 1
        }
        $hcArgs = @("-a", "0") + $hcBase + @($hashPath, $Wordlist)
    }
    "from-tier" {
        $tokenFiles = @{
            1 = Join-Path $ProjectRoot "tokens\tier1_high_confidence.txt"
            2 = Join-Path $ProjectRoot "tokens\tier2_variations.txt"
            3 = Join-Path $ProjectRoot "tokens\tier3_typos.txt"
        }
        $tokenFile = $tokenFiles[$Tier]
        $btcrecover = Join-Path $ProjectRoot "tools\btcrecover\btcrecover.py"
        $candidates = Join-Path $generatedDir "candidates-tier$Tier.txt"

        if (-not (Test-Path $tokenFile)) {
            Write-Host "[ERROR] Token file not found: $tokenFile" -ForegroundColor Red
            exit 1
        }

        Write-Host "Generating Dogecoin candidates from tier $Tier (CPU)..."
        $rawCand = & $pyCmd $btcrecover --listpass --tokenlist $tokenFile 2>&1
        $rawCand | Out-File -FilePath $candidates -Encoding utf8

        $count = (Get-Content $candidates | Measure-Object -Line).Lines
        Write-Host "Candidate count: $count"
        if ($count -gt 5000000) {
            Write-Warning "Over 5M candidates - consider tightening tokens."
        }

        $hcArgs = @("-a", "0") + $hcBase + @($hashPath, $candidates)
    }
}

Write-Host "=== Hashcat Mode 11300 Dogecoin GPU Recovery ($GpuProfile profile) ===" -ForegroundColor Cyan
Write-Host "Command: $hashcat $($hcArgs -join ' ')"

$hashcatDir = Join-Path $ProjectRoot "tools\hashcat"
Push-Location $hashcatDir
try {
    & $hashcat @hcArgs 2>&1 | Tee-Object -FilePath $logFile
} finally {
    Pop-Location
}

Write-Host "Log saved: $logFile"

if (Test-Path $potfile) {
    $match = Select-String -Path $potfile -Pattern '\$bitcoin\$|\$btc\$' -SimpleMatch:$false | Select-Object -Last 1
    if ($match) {
        Write-Host "Recovered Dogecoin password recorded in: $potfile" -ForegroundColor Green
        Get-Content $potfile | Select-Object -Last 3
    }
}
