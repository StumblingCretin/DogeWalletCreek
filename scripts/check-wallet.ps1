#Requires -Version 5.1
<#
.SYNOPSIS
    Wrapper for Dogecoin wallet and environment validation.
#>
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

& (Join-Path $PSScriptRoot "validate-wallet.ps1") -ProjectRoot $ProjectRoot
exit $LASTEXITCODE
