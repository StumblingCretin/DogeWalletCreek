#Requires -Version 5.1
<#
.SYNOPSIS
    Download and extract hashcat portable into tools\hashcat\
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$hashcatDir = Join-Path $ProjectRoot "tools\hashcat"
$hashcatExe = Join-Path $hashcatDir "hashcat.exe"

if (Test-Path $hashcatExe) {
    Write-Host "[OK] hashcat already installed: $hashcatExe" -ForegroundColor Green
    & $hashcatExe -I 2>&1 | Select-Object -First 25
    exit 0
}

Write-Host "=== Install hashcat (portable) ===" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $hashcatDir | Out-Null

$releasesUrl = "https://api.github.com/repos/hashcat/hashcat/releases/latest"
Write-Host "Fetching latest release info..."
$release = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
$asset = $release.assets | Where-Object { $_.name -match 'hashcat.*\.7z$' } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Could not find hashcat .7z asset. Download manually from https://hashcat.net/hashcat/"
}

$zipPath = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name)..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

$7z = @(
    "${env:ProgramFiles}\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($7z) {
    Write-Host "Extracting with 7-Zip..."
    & $7z x $zipPath "-o$hashcatDir" -y | Out-Null
    # hashcat extracts to hashcat-6.x.x subfolder — flatten if needed
    $sub = Get-ChildItem $hashcatDir -Directory | Where-Object { $_.Name -match '^hashcat' } | Select-Object -First 1
    if ($sub -and -not (Test-Path $hashcatExe)) {
        Get-ChildItem $sub.FullName | Move-Item -Destination $hashcatDir -Force
        Remove-Item $sub.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[WARN] 7-Zip not found. Extract $zipPath manually into $hashcatDir"
    Write-Host "       Install 7-Zip from https://www.7-zip.org/ then re-run this script."
    exit 1
}

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

if (Test-Path $hashcatExe) {
    Write-Host "[OK] Installed: $hashcatExe" -ForegroundColor Green
    & $hashcatExe -I 2>&1 | Select-Object -First 25
} else {
    Write-Error "Extraction finished but hashcat.exe not found in $hashcatDir"
}
