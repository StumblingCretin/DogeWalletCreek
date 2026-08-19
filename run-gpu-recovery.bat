@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Dogecoin GPU Recovery (RTX 2070)

cd /d "%~dp0"
call "%~dp0scripts\gpu-rtx2070-config.bat"

if "%~1"=="" goto :usage
if /i "%~1"=="help" goto :usage
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="?" goto :usage

if /i "%~1"=="verify"   goto :verify
if /i "%~1"=="benchmark" goto :benchmark
if /i "%~1"=="extract"  goto :extract
if /i "%~1"=="restore"  goto :restore
if /i "%~1"=="tier"      goto :tier
if /i "%~1"=="mask"      goto :mask
if /i "%~1"=="dict"      goto :dict

echo [ERROR] Unknown command: %~1
goto :usage

REM ---------------------------------------------------------------------------
:verify
echo === GPU verification (RTX 2070 profile) ===
call :require_hashcat
if errorlevel 1 exit /b 1
echo Hashcat: %HASHCAT%
echo.
pushd "%HASHCAT_DIR%"
"%HASHCAT%" -I
popd
echo.
echo Profile: -D 2 -w 4 -O  (GPU-only, nightmare workload, optimized kernels)
echo Mode:    11300 (wallet.dat - Dogecoin Core compatible)
exit /b 0

REM ---------------------------------------------------------------------------
:benchmark
echo === Benchmark mode 11300 on GPU ===
call :require_hashcat
if errorlevel 1 exit /b 1
call :require_hash
if errorlevel 1 exit /b 1
echo Running 60-second benchmark on NVIDIA GPU...
pushd "%HASHCAT_DIR%"
"%HASHCAT%" -b %HC_MODE% %HC_GPU% --runtime=60
set "HC_EXIT=%ERRORLEVEL%"
popd
exit /b %HC_EXIT%

REM ---------------------------------------------------------------------------
:extract
echo === Extract wallet hash ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\extract-hash.ps1"
exit /b %ERRORLEVEL%

REM ---------------------------------------------------------------------------
:restore
echo === Resume hashcat session (doge-gpu) ===
call :require_hashcat
if errorlevel 1 exit /b 1
call :require_hash
if errorlevel 1 exit /b 1
pushd "%HASHCAT_DIR%"
"%HASHCAT%" --restore --session doge-gpu
set "HC_EXIT=%ERRORLEVEL%"
popd
exit /b %HC_EXIT%

REM ---------------------------------------------------------------------------
:tier
set "TIER=%~2"
if "%TIER%"=="" set "TIER=1"
if "%TIER%"=="1" set "TOKEN_FILE=%TOKEN_T1%"
if "%TIER%"=="2" set "TOKEN_FILE=%TOKEN_T2%"
if "%TIER%"=="3" set "TOKEN_FILE=%TOKEN_T3%"
if not defined TOKEN_FILE (
    echo [ERROR] Tier must be 1, 2, or 3
    exit /b 1
)
if not exist "%TOKEN_FILE%" (
    echo [ERROR] Token file missing: %TOKEN_FILE%
    exit /b 1
)

call :require_hashcat
if errorlevel 1 exit /b 1
call :require_hash
if errorlevel 1 exit /b 1

set "CANDIDATES=%GENERATED%\candidates-tier%TIER%.txt"
set "LOG_TIME=%TIME: =0%"
set "LOG=%LOG_DIR%\gpu-tier%TIER%-%DATE:~-4%%DATE:~4,2%%DATE:~7,2%-%LOG_TIME:~0,2%%LOG_TIME:~3,2%%LOG_TIME:~6,2%.log"

echo === Tier %TIER%: generate candidates (CPU) then crack on GPU ===
echo Token file: %TOKEN_FILE%
echo Output:     %CANDIDATES%
echo.

echo [1/3] Counting candidates...
%PYTHON_CMD% "%BTCRECOVER%" --listpass --tokenlist "%TOKEN_FILE%" > "%CANDIDATES%.tmp" 2>nul
for /f %%C in ('find /c /v "" ^< "%CANDIDATES%.tmp"') do set "COUNT=%%C"
echo       %COUNT% passwords to test
if %COUNT% GTR 5000000 (
    echo [WARN] Over 5M candidates - this may take a long time. Consider tightening tokens.
    set /p "CONTINUE=Continue anyway? [y/N] "
    if /i not "!CONTINUE!"=="y" (
        del "%CANDIDATES%.tmp" 2>nul
        exit /b 1
    )
)
move /y "%CANDIDATES%.tmp" "%CANDIDATES%" >nul

echo [2/3] Starting hashcat dictionary attack on GPU...
echo [3/3] Log: %LOG%
echo.
pushd "%HASHCAT_DIR%"
"%HASHCAT%" -a 0 %HC_FLAGS% "%HASH_FILE%" "%CANDIDATES%"
set "HC_EXIT=%ERRORLEVEL%"
popd
call :show_potfile
exit /b %HC_EXIT%

REM ---------------------------------------------------------------------------
:mask
set "MASK=%~2"
if "%MASK%"=="" (
    echo [ERROR] Mask required.
    echo Example: run-gpu-recovery.bat mask MuchWow?d?d?d?d
    exit /b 1
)
call :require_hashcat
if errorlevel 1 exit /b 1
call :require_hash
if errorlevel 1 exit /b 1
echo === GPU mask attack ===
echo Mask: %MASK%
pushd "%HASHCAT_DIR%"
"%HASHCAT%" -a 3 %HC_FLAGS% "%HASH_FILE%" "%MASK%"
set "HC_EXIT=%ERRORLEVEL%"
popd
call :show_potfile
exit /b %HC_EXIT%

REM ---------------------------------------------------------------------------
:dict
set "WORDLIST=%~2"
if "%WORDLIST%"=="" (
    echo [ERROR] Wordlist path required.
    echo Example: run-gpu-recovery.bat dict generated\candidates-tier1.txt
    exit /b 1
)
if not exist "%WORDLIST%" (
    echo [ERROR] Wordlist not found: %WORDLIST%
    exit /b 1
)
call :require_hashcat
if errorlevel 1 exit /b 1
call :require_hash
if errorlevel 1 exit /b 1
echo === GPU dictionary attack ===
echo Wordlist: %WORDLIST%
pushd "%HASHCAT_DIR%"
"%HASHCAT%" -a 0 %HC_FLAGS% "%HASH_FILE%" "%WORDLIST%"
set "HC_EXIT=%ERRORLEVEL%"
popd
call :show_potfile
exit /b %HC_EXIT%

REM ---------------------------------------------------------------------------
:require_hashcat
if exist "%HASHCAT%" (
    if not defined HASHCAT_DIR set "HASHCAT_DIR=%PROJECT_ROOT%\tools\hashcat"
    exit /b 0
)
where "%HASHCAT%" >nul 2>&1
if not errorlevel 1 exit /b 0
where hashcat >nul 2>&1
if not errorlevel 1 (
    set "HASHCAT=hashcat.exe"
    exit /b 0
)
echo [FAIL] hashcat not found at: %HASHCAT%
echo        Run: powershell -ExecutionPolicy Bypass -File scripts\install-hashcat.ps1
exit /b 1

:require_hash
if not exist "%HASH_FILE%" (
    echo Hash file missing - extracting from wallet.dat...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\extract-hash.ps1"
)
if not exist "%HASH_FILE%" (
    echo [FAIL] No hash at %HASH_FILE%
    echo        Copy artifacts\wallet.dat first, then: run-gpu-recovery.bat extract
    exit /b 1
)
if not exist "%PROJECT_ROOT%\artifacts\wallet.dat" (
    echo [WARN] artifacts\wallet.dat not found - hash may be stale
)
exit /b 0

:show_potfile
if exist "%POTFILE%" (
    echo.
    echo === Potfile (recovered passwords) ===
    findstr /i "bitcoin btc" "%POTFILE%" 2>nul
    if errorlevel 1 type "%POTFILE%"
)
exit /b 0

REM ---------------------------------------------------------------------------
:usage
echo.
echo Dogecoin GPU Recovery - NVIDIA RTX 2070 profile
echo Project: %PROJECT_ROOT%
echo.
echo Usage:
echo   run-gpu-recovery.bat verify              List GPUs and hashcat backends
echo   run-gpu-recovery.bat benchmark           60s benchmark for mode 11300
echo   run-gpu-recovery.bat extract             Extract wallet.dat hash
echo   run-gpu-recovery.bat tier [1|2|3]      Token list -^> GPU dictionary attack
echo   run-gpu-recovery.bat mask MASK           GPU mask attack
echo   run-gpu-recovery.bat dict FILE           GPU dictionary from wordlist
echo   run-gpu-recovery.bat restore             Resume interrupted hashcat session
echo.
echo Recommended flow:
echo   1. Copy wallet to artifacts\wallet.dat
echo   2. Fill tokens\tier1_high_confidence.txt
echo   3. run-gpu-recovery.bat verify
echo   4. run-gpu-recovery.bat tier 1
echo.
echo GPU flags: -D 2 -w 4 -O  (GPU-only, max workload, optimized kernels)
echo.
exit /b 0
