#Requires -Version 5.1
<#
.SYNOPSIS
  Deploys CursorCodingSkills into the user skills folder and/or a project .cursor.
  Optionally installs the reusable python_guardrails package into the project.
#>
param(
    [string]$ProjectPath = "",
    [ValidateSet("Junction", "Copy")]
    [string]$Mode = "Junction",
    [switch]$SkipGuardrails,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSource = Join-Path $Root "skills"
$RulesSource = Join-Path $Root "rules"
$GuardrailsSource = Join-Path $Root "python_guardrails"
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

function Install-Guardrails {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $toolsDir = Join-Path $ProjectRoot "tools"
    $target = Join-Path $toolsDir "python_guardrails"
    if ($WhatIf) {
        Write-Host "WHATIF: $Mode $GuardrailsSource -> $target"
        return
    }
    if (-not (Test-Path $GuardrailsSource)) {
        Write-Host "Skip guardrails: package missing at $GuardrailsSource" -ForegroundColor Yellow
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
        New-Item -ItemType Junction -Path $target -Target $GuardrailsSource | Out-Null
    } else {
        Copy-Item -Path $GuardrailsSource -Destination $target -Recurse -Force
    }
    Write-Host "Installed python_guardrails into $target"
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
        Install-Guardrails -ProjectRoot $project
    }
}

Write-Host ""
Write-Host "Done. Reload Cursor to pick up skills." -ForegroundColor Green
Write-Host "User skills: $UserSkills"
if ($ProjectPath) {
    Write-Host "Project: $ProjectPath"
    if (-not $SkipGuardrails) {
        Write-Host "Guardrails: $ProjectPath\tools\python_guardrails"
        Write-Host "Put tools\ on PYTHONPATH (see run_tests.ps1 examples)."
    }
}
