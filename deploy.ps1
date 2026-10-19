#Requires -Version 5.1
<#
.SYNOPSIS
  Deploys CursorCodingSkills into the user skills folder and/or a project .cursor.
  Optionally installs reusable python_guardrails and/or esp_cpp_guardrails.

.PARAMETER Languages
  Which tool packages to install under <Project>/tools when -ProjectPath is set.
  All (default) | Python | EspCpp — combine as needed, e.g. -Languages Python
  or -Languages Python,EspCpp. Ignored when -SkipGuardrails is set.

.PARAMETER Mode
  Junction (default): link into this repo (local only; do not commit junctions).
  Copy: real files for CI / vendoring into the project git tree.

.NOTES
  Skills: any directory under skills/ that contains SKILL.md (nested OK).
  Install name = relative path under skills/ with separators replaced by '-'.

  Junction safety: never Remove-Item -Recurse a reparse point (that can wipe the
  SOURCE tree on Windows). Always rmdir the junction link only.
#>
param(
    [string]$ProjectPath = "",
    [ValidateSet("Junction", "Copy")]
    [string]$Mode = "Junction",
    [ValidateSet("All", "Python", "EspCpp")]
    [string[]]$Languages = @("All"),
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

function Test-IsReparsePoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    return [bool]((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Remove-DeployTarget {
    param([Parameter(Mandatory = $true)][string]$TargetPath)

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return
    }
    # CRITICAL: Remove-Item -Recurse on a Windows junction can delete the TARGET
    # directory contents (the CodingSkills source). Only rmdir the link.
    if (Test-IsReparsePoint -Path $TargetPath) {
        cmd /c "rmdir `"$TargetPath`""
        if (Test-Path -LiteralPath $TargetPath) {
            throw "Failed to remove junction: $TargetPath"
        }
        return
    }
    Remove-Item -LiteralPath $TargetPath -Recurse -Force
}

function Get-SkillLeaves {
    param([Parameter(Mandatory = $true)][string]$SkillsRoot)

    $leaves = @()
    Get-ChildItem -Path $SkillsRoot -Recurse -Filter "SKILL.md" -File | ForEach-Object {
        $skillDir = $_.Directory
        $relative = $skillDir.FullName.Substring($SkillsRoot.Length).TrimStart("\", "/")
        $installName = ($relative -replace "[\\/]", "-")
        $leaves += [pscustomobject]@{
            Name      = $installName
            SourceDir = $skillDir.FullName
        }
    }
    return $leaves | Sort-Object Name
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

    Remove-DeployTarget -TargetPath $target

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
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-Host "Skip $PackageName : missing at $SourceDir" -ForegroundColor Yellow
        return
    }
    $sourceFiles = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File -ErrorAction SilentlyContinue)
    if ($sourceFiles.Count -eq 0) {
        throw "Refusing to deploy empty package '$PackageName' from $SourceDir (source has 0 files)."
    }

    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    Remove-DeployTarget -TargetPath $target

    if ($Mode -eq "Junction") {
        New-Item -ItemType Junction -Path $target -Target $SourceDir | Out-Null
    } else {
        Copy-Item -Path $SourceDir -Destination $target -Recurse -Force
    }
    Write-Host "Installed $PackageName into $target ($($sourceFiles.Count) files, $Mode)"
}

function Resolve-GuardrailInstallFlags {
    $installPython = $false
    $installEsp = $false
    if ($SkipGuardrails) {
        return @{ Python = $false; EspCpp = $false }
    }

    $wantAll = ($Languages -contains "All") -or ($Languages.Count -eq 0)
    if ($wantAll) {
        $installPython = -not $SkipPythonGuardrails
        $installEsp = -not $SkipEspCppGuardrails
    } else {
        $installPython = ($Languages -contains "Python") -and (-not $SkipPythonGuardrails)
        $installEsp = ($Languages -contains "EspCpp") -and (-not $SkipEspCppGuardrails)
    }
    return @{ Python = $installPython; EspCpp = $installEsp }
}

Write-Step "CursorCodingSkills deploy ($Mode)"
$skillLeaves = @(Get-SkillLeaves -SkillsRoot $SkillsSource)
if ($skillLeaves.Count -eq 0) {
    Write-Host "No SKILL.md leaves found under $SkillsSource" -ForegroundColor Yellow
}
foreach ($leaf in $skillLeaves) {
    Install-SkillLink -Name $leaf.Name -SourceDir $leaf.SourceDir -DestinationDir $UserSkills
}

$guardFlags = Resolve-GuardrailInstallFlags

if ($ProjectPath) {
    $project = (Resolve-Path $ProjectPath).Path
    $projectSkills = Join-Path $project ".cursor\skills"
    $projectRules = Join-Path $project ".cursor\rules"
    Write-Step "Project target: $project"
    Write-Host "Guardrail packages: Python=$($guardFlags.Python) EspCpp=$($guardFlags.EspCpp)"
    foreach ($leaf in $skillLeaves) {
        Install-SkillLink -Name $leaf.Name -SourceDir $leaf.SourceDir -DestinationDir $projectSkills
    }
    Install-Rules -DestinationRules $projectRules
    if ($guardFlags.Python) {
        Install-ToolPackage -ProjectRoot $project -PackageName "python_guardrails" -SourceDir $PythonGuardrailsSource
    }
    if ($guardFlags.EspCpp) {
        Install-ToolPackage -ProjectRoot $project -PackageName "esp_cpp_guardrails" -SourceDir $EspCppGuardrailsSource
    }
}

Write-Host ""
Write-Host "Done. Reload Cursor to pick up skills." -ForegroundColor Green
Write-Host "User skills: $UserSkills"
if ($ProjectPath) {
    Write-Host "Project: $ProjectPath"
    if ($guardFlags.Python) {
        Write-Host "Python guardrails: $ProjectPath\tools\python_guardrails"
    }
    if ($guardFlags.EspCpp) {
        Write-Host "ESP/C++ guardrails: $ProjectPath\tools\esp_cpp_guardrails"
    }
}
