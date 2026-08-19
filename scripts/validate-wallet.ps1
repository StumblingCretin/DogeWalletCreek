#Requires -Version 5.1
<#
.SYNOPSIS
    Sanity checks and environment validation for Dogecoin wallet recovery.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$walletPath = Join-Path $ProjectRoot "artifacts\wallet.dat"
$addressPath = Join-Path $ProjectRoot "artifacts\target-address.txt"
$btcrecover = Join-Path $ProjectRoot "tools\btcrecover\btcrecover.py"
$hashcatExe = Join-Path $ProjectRoot "tools\hashcat\hashcat.exe"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Dogecoin Wallet Recovery Validator" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host ""

$ok = $true

# 1. Wallet Artifact Check
Write-Host "[1/5] Checking Dogecoin wallet artifact..." -ForegroundColor Yellow
if (-not (Test-Path $walletPath)) {
    $altWallets = Get-ChildItem (Join-Path $ProjectRoot "artifacts") -Filter "*.dat" -ErrorAction SilentlyContinue
    $multiDogeWallets = Get-ChildItem (Join-Path $ProjectRoot "artifacts") -Filter "*.wallet" -ErrorAction SilentlyContinue
    
    Write-Host "  [FAIL] Missing wallet copy at: artifacts\wallet.dat" -ForegroundColor Red
    if ($altWallets) {
        $altNames = ($altWallets | ForEach-Object { $_.Name }) -join ", "
        Write-Host "         Found other .dat file(s): $altNames. Rename to artifacts\wallet.dat" -ForegroundColor Yellow
    }
    if ($multiDogeWallets) {
        $mdNames = ($multiDogeWallets | ForEach-Object { $_.Name }) -join ", "
        Write-Host "         Found MultiDoge wallet: $mdNames. MultiDoge files can be recovered directly via BTCRecover." -ForegroundColor Yellow
    }
    Write-Host "         Instructions: Copy %APPDATA%\Dogecoin\wallet.dat to artifacts\wallet.dat"
    $ok = $false
} else {
    $size = (Get-Item $walletPath).Length
    Write-Host "  [OK]   Wallet file exists ($size bytes)" -ForegroundColor Green
    if ($size -lt 1000) {
        Write-Host "  [WARN] Wallet file is unusually small (< 1 KB) - verify it is a valid wallet.dat" -ForegroundColor Yellow
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($walletPath)
        if ($bytes.Length -ge 16) {
            $hex = [BitConverter]::ToString($bytes[0..15])
            if ($hex -match "00-05-31-62" -or $hex -match "62-31-05-00" -or $hex -match "00-06-15-61" -or $hex -match "61-15-06-00") {
                Write-Host "  [OK]   Berkeley DB format recognized (Dogecoin Core compatible)" -ForegroundColor Green
            } else {
                Write-Host "  [INFO] Header bytes: $hex" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  [WARN] Could not inspect wallet header: $_" -ForegroundColor Yellow
    }
}

# 2. Target Dogecoin Address Check
Write-Host ""
Write-Host "[2/5] Checking target Dogecoin address..." -ForegroundColor Yellow
if (-not (Test-Path $addressPath)) {
    Write-Host "  [WARN] Missing target address file: artifacts\target-address.txt" -ForegroundColor Yellow
    Write-Host "         Copy artifacts\target-address.txt.example to artifacts\target-address.txt and add your address."
    Write-Host "         (Recovery can still run, but providing a target address enables instant early termination upon match)"
} else {
    $addr = (Get-Content $addressPath -Raw).Trim()
    if ($addr -match "^DYourKnown") {
        Write-Host "  [WARN] target-address.txt still contains example placeholder: $addr" -ForegroundColor Yellow
        Write-Host "         Please edit artifacts\target-address.txt with your real Dogecoin address."
    } elseif ($addr -match "^D[1-9A-HJ-NP-Za-km-z]{25,34}$") {
        Write-Host "  [OK]   Valid Dogecoin P2PKH address format (starts with D): $addr" -ForegroundColor Green
    } elseif ($addr -match "^[9A][1-9A-HJ-NP-Za-km-z]{25,34}$") {
        Write-Host "  [OK]   Valid Dogecoin P2SH multisig address format (starts with 9 or A): $addr" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Address format does not match standard Dogecoin prefixes (D, 9, or A): $addr" -ForegroundColor Yellow
    }
}

# 3. BTCRecover Tool & Dependencies
Write-Host ""
Write-Host "[3/5] Checking BTCRecover and Python dependencies..." -ForegroundColor Yellow
if (-not (Test-Path $btcrecover)) {
    Write-Host "  [FAIL] BTCRecover not found at: $btcrecover" -ForegroundColor Red
    Write-Host "         Run: .\scripts\setup-tools.ps1"
    $ok = $false
} else {
    Write-Host "  [OK]   BTCRecover script found" -ForegroundColor Green
}

try {
    $pyVersion = & python --version 2>&1
    Write-Host "  [OK]   Python: $pyVersion" -ForegroundColor Green
    
    $pyTestCode = "import sys`ntry:`n import Crypto`n print('pycryptodome: OK')`nexcept ImportError:`n print('pycryptodome: MISSING')`ntry:`n import coincurve`n print('coincurve: OK')`nexcept ImportError:`n print('coincurve: MISSING')`n"
    $cryptoCheck = & python -c $pyTestCode 2>&1
    foreach ($line in ($cryptoCheck -split "`n")) {
        $clean = $line.Trim()
        if ($clean -match 'OK') {
            Write-Host "  [OK]   $clean" -ForegroundColor Green
        } elseif ($clean -match 'MISSING') {
            Write-Host "  [WARN] $clean (recommended for max speed; run .\scripts\setup-tools.ps1)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  [FAIL] Python not found in PATH" -ForegroundColor Red
    $ok = $false
}

# 4. Hashcat (GPU Recovery)
Write-Host ""
Write-Host "[4/5] Checking Hashcat GPU tooling..." -ForegroundColor Yellow
$hcFound = $null
if (Test-Path $hashcatExe) {
    $hcFound = $hashcatExe
} else {
    $found = Get-Command "hashcat" -ErrorAction SilentlyContinue
    if ($found) { $hcFound = $found.Source }
}

if ($hcFound) {
    Write-Host "  [OK]   Hashcat found: $hcFound" -ForegroundColor Green
    Write-Host "  [INFO] Hashcat mode 11300 supported (Dogecoin Core wallet.dat)" -ForegroundColor Gray
} else {
    Write-Host "  [INFO] Hashcat not installed in tools\hashcat (GPU recovery optional)" -ForegroundColor Gray
    Write-Host "         To install GPU tools: powershell -ExecutionPolicy Bypass -File .\scripts\install-hashcat.ps1"
}

# 5. Token Files
Write-Host ""
Write-Host "[5/5] Checking token files..." -ForegroundColor Yellow
$t1 = Join-Path $ProjectRoot "tokens\tier1_high_confidence.txt"
if (Test-Path $t1) {
    $t1Lines = @(Get-Content $t1 | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") })
    if ($t1Lines.Count -gt 0) {
        Write-Host "  [OK]   Tier 1 token file contains $($t1Lines.Count) active token rule(s)" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Tier 1 token file is empty or only comments - edit tokens\tier1_high_confidence.txt before running" -ForegroundColor Gray
    }
} else {
    Write-Host "  [WARN] Tier 1 token file missing at: $t1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if (-not $ok) {
    Write-Host "Validation FAILED. Please resolve the required issues above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Validation PASSED. Ready for Dogecoin recovery." -ForegroundColor Green
    Write-Host "Next steps:"
    Write-Host "  1. Add your password fragments to tokens\tier1_high_confidence.txt"
    Write-Host "  2. Test candidate space: .\scripts\run-tier1.ps1 -ListPassOnly"
    Write-Host "  3. Execute CPU recovery: .\scripts\run-tier1.ps1"
    Write-Host "  4. Or GPU recovery:      .\run-gpu-recovery.bat tier 1"
}
