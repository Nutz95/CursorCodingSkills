#Requires -Version 5.1
<#
.SYNOPSIS
  Deploys CursorCodingSkills into the user skills folder and/or a project .cursor.
  Optionally installs reusable python_guardrails and esp_cpp_guardrails into the project.
#>
param(
    [string]$ProjectPath = "",
    [ValidateSet("Junction", "Copy")]
    [string]$Mode = "Junction",
    [switch]$SkipGuardrails,
    [switch]$SkipPythonGuardrails,
    [switch]$SkipEspCppGuardrails,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSource = Join-Path $Root "skills"
$RulesSource = Join-Path $Root "rules"
$PythonGuardrailsSource = Join-Path $Root "python_guardrails"
$EspCppGuardrailsSource = Join-Path $Root "esp_cpp_guardrails"
$UserSkills = Join-Path $env:USERPROFILE ".cursor\skills"

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Install-SkillLink {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )

    $target = Join-Path $DestinationDir $Name
    if ($WhatIf) {
        Write-Host "WHATIF: $Mode $SourceDir -> $target"
        return
    }

    if (Test-Path $target) {
        if ((Get-Item $target).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            cmd /c rmdir "$target" | Out-Null
        } else {
            Remove-Item -Recurse -Force $target
        }
    }

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    if ($Mode -eq "Junction") {
        New-Item -ItemType Junction -Path $target -Target $SourceDir | Out-Null
    } else {
        Copy-Item -Path $SourceDir -Destination $target -Recurse -Force
    }
    Write-Host "Installed skill: $Name"
}

function Install-Rules {
    param([Parameter(Mandatory = $true)][string]$DestinationRules)

    if (-not (Test-Path $RulesSource)) {
        return
    }
    if ($WhatIf) {
        Write-Host "WHATIF: copy rules -> $DestinationRules"
        return
    }
    New-Item -ItemType Directory -Force -Path $DestinationRules | Out-Null
    Copy-Item -Path (Join-Path $RulesSource "*.mdc") -Destination $DestinationRules -Force
    Write-Host "Installed rules into $DestinationRules"
}

function Install-ToolPackage {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$PackageName,
        [Parameter(Mandatory = $true)][string]$SourceDir
    )

    $toolsDir = Join-Path $ProjectRoot "tools"
    $target = Join-Path $toolsDir $PackageName
    if ($WhatIf) {
        Write-Host "WHATIF: $Mode $SourceDir -> $target"
        return
    }
    if (-not (Test-Path $SourceDir)) {
        Write-Host "Skip $PackageName : missing at $SourceDir" -ForegroundColor Yellow
        return
    }
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    if (Test-Path $target) {
        if ((Get-Item $target).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            cmd /c rmdir "$target" | Out-Null
        } else {
            Remove-Item -Recurse -Force $target
        }
    }
    if ($Mode -eq "Junction") {
        New-Item -ItemType Junction -Path $target -Target $SourceDir | Out-Null
    } else {
        Copy-Item -Path $SourceDir -Destination $target -Recurse -Force
    }
    Write-Host "Installed $PackageName into $target"
}

Write-Step "CursorCodingSkills deploy ($Mode)"
$skillDirs = Get-ChildItem -Path $SkillsSource -Directory
foreach ($dir in $skillDirs) {
    Install-SkillLink -Name $dir.Name -SourceDir $dir.FullName -DestinationDir $UserSkills
}

if ($ProjectPath) {
    $project = (Resolve-Path $ProjectPath).Path
    $projectSkills = Join-Path $project ".cursor\skills"
    $projectRules = Join-Path $project ".cursor\rules"
    Write-Step "Project target: $project"
    foreach ($dir in $skillDirs) {
        Install-SkillLink -Name $dir.Name -SourceDir $dir.FullName -DestinationDir $projectSkills
    }
    Install-Rules -DestinationRules $projectRules
    if (-not $SkipGuardrails) {
        if (-not $SkipPythonGuardrails) {
            Install-ToolPackage -ProjectRoot $project -PackageName "python_guardrails" -SourceDir $PythonGuardrailsSource
        }
        if (-not $SkipEspCppGuardrails) {
            Install-ToolPackage -ProjectRoot $project -PackageName "esp_cpp_guardrails" -SourceDir $EspCppGuardrailsSource
        }
    }
}

Write-Host ""
Write-Host "Done. Reload Cursor to pick up skills." -ForegroundColor Green
Write-Host "User skills: $UserSkills"
if ($ProjectPath) {
    Write-Host "Project: $ProjectPath"
    if (-not $SkipGuardrails) {
        if (-not $SkipPythonGuardrails) {
            Write-Host "Python guardrails: $ProjectPath\tools\python_guardrails"
        }
        if (-not $SkipEspCppGuardrails) {
            Write-Host "ESP/C++ guardrails: $ProjectPath\tools\esp_cpp_guardrails"
        }
    }
}
