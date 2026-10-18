#Requires -Version 5.1
<#
.SYNOPSIS
  Runs CursorCodingSkills python_guardrails self-tests.
#>
param(
    [string]$PythonExe = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

if (-not $PythonExe) {
    $PythonExe = "python"
}

$env:PYTHONPATH = $Root

Write-Host "==> python_guardrails tests" -ForegroundColor Cyan
$failed = 0
Get-ChildItem -Path (Join-Path $Root "tests") -Filter "test_*.py" | Sort-Object Name | ForEach-Object {
    Write-Host "  - $($_.Name)"
    & $PythonExe $_.FullName
    if ($LASTEXITCODE -ne 0) {
        $failed += 1
    }
}

if ($failed -gt 0) {
    throw "$failed test file(s) failed."
}

Write-Host "All guardrail tests OK." -ForegroundColor Green
