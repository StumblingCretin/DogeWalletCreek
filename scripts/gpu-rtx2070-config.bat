@echo off
REM Shared hashcat GPU profile for NVIDIA RTX 2070 (Turing, 8 GB VRAM).
REM Included by run-gpu-recovery.bat - do not run directly unless debugging.

REM Resolve project root (this file lives in scripts\)
set "PROJECT_ROOT=%~dp0.."
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_ROOT=%%~fI"

REM hashcat binary - prefer project-local install
set "HASHCAT_DIR=%PROJECT_ROOT%\tools\hashcat"
if exist "%HASHCAT_DIR%\hashcat.exe" (
    set "HASHCAT=%HASHCAT_DIR%\hashcat.exe"
) else (
    set "HASHCAT=hashcat.exe"
)

REM Python binary / launcher
where python >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=python"
) else (
    where py >nul 2>&1
    if not errorlevel 1 (
        set "PYTHON_CMD=py"
    ) else (
        set "PYTHON_CMD=python"
    )
)

set "HASH_FILE=%PROJECT_ROOT%\hashes\wallet.hash"
set "POTFILE=%PROJECT_ROOT%\runs\hashcat.potfile"
set "SESSION_DIR=%PROJECT_ROOT%\runs\hashcat-sessions"
set "GENERATED=%PROJECT_ROOT%\generated"
set "LOG_DIR=%PROJECT_ROOT%\runs\logs"

if not exist "%SESSION_DIR%" mkdir "%SESSION_DIR%"
if not exist "%GENERATED%" mkdir "%GENERATED%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Mode 11300 = Bitcoin/Litecoin/Dogecoin Core wallet.dat
set "HC_MODE=-m 11300"

REM RTX 2070 defaults:
REM   -D 2     GPU backends only (skip CPU OpenCL)
REM   -w 4     Nightmare workload - max throughput (expect brief UI lag)
REM   -O       Optimized kernels (faster for typical wallet passphrases)
REM   --status Timer updates every 15 s
set "HC_GPU=-D 2 -w 4 -O --status --status-timer=15"

REM Session + potfile kept inside project (not hashcat install dir)
set "HC_PERSIST=--potfile-path "%POTFILE%" --session doge-gpu"

REM Combined flags used by all GPU attack commands
set "HC_FLAGS=%HC_MODE% %HC_GPU% %HC_PERSIST%"

REM BTCRecover paths
set "BTCRECOVER=%PROJECT_ROOT%\tools\btcrecover\btcrecover.py"
set "TOKEN_T1=%PROJECT_ROOT%\tokens\tier1_high_confidence.txt"
set "TOKEN_T2=%PROJECT_ROOT%\tokens\tier2_variations.txt"
set "TOKEN_T3=%PROJECT_ROOT%\tokens\tier3_typos.txt"
