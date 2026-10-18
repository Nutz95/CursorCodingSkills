#Requires -Version 5.1
<#
.SYNOPSIS
  Reusable ESP32 / C++ maintainability + DI guardrails for PlatformIO (or similar) trees.

.DESCRIPTION
  General checks extracted from WattcycleEsp32Gateway-style monorepos. Projects pass
  project-specific adapter lists, roots, and optional domain-leak rules.

.PARAMETER SourceRoot
  Root folder to scan recursively for *.cpp / *.h / *.hpp.

.PARAMETER MaxLines
  Max lines per source file (default 400).

.PARAMETER MaxMethodsPerClass
  Soft max method-like declarations per file (default 30).

.PARAMETER MaxFunctionBodyLines
  If > 0, fail when a function body in matching .cpp files exceeds this (brace depth heuristic).

.PARAMETER FunctionBodyPathRegex
  Optional regex on full path; when set with MaxFunctionBodyLines, only those .cpp files are checked.

.PARAMETER OneTypePerHeaderRoots
  Optional folders where each public header may define only one primary type.

.PARAMETER ConcreteAdapterHeaders
  Leaf names of concrete adapter headers that may only be included from composition roots
  (or same-domain / self). Empty = skip DI check.

.PARAMETER TargetPrefixes
  Path prefixes stripped before DI relative-path checks (monorepo target folders).

.PARAMETER CompositionRootNamePatterns
  File name patterns allowed to include concrete adapters (default main.cpp, CompositionRoot*).

.PARAMETER ForbidUnitTestInHeaders
  Fail if UNIT_TEST appears in any .h/.hpp (default $true).

.PARAMETER ForbidUnitTestInCpp
  Fail if UNIT_TEST appears in any .cpp (default $true).

.PARAMETER PublicCommentRoots
  Folders where public methods need a preceding /// or // intent comment.

.PARAMETER CommentInterfaceNameRegex
  Case-sensitive regex for interface header file names (default ^I[A-Z][A-Za-z0-9]*\.h$).

.PARAMETER CommentAllHeadersInRoots
  When true, every header under PublicCommentRoots needs public-method comments (not only I*.h).

.PARAMETER CommentAllHeadersPathRegex
  Optional regex on full path; matching headers need public-method comments even when not I*.h.

.PARAMETER DomainLeakRules
  Optional list of hashtables: @{ Root = 'bridge_x'; ForbiddenPattern = '#include\s+"(Auth|Web)/' }

.PARAMETER ExcludeNameRegex
  Skip files whose names match (default \.gen\.(cpp|h|hpp)$).

.PARAMETER FailOnHardcodedPasswordAssign
  Scan for password\s*=\s*"...." (default $true).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [int]$MaxLines = 400,
  [int]$MaxMethodsPerClass = 30,
  [int]$MaxFunctionBodyLines = 0,
  [string]$FunctionBodyPathRegex = "",

  [string[]]$OneTypePerHeaderRoots = @(),
  [string[]]$ConcreteAdapterHeaders = @(),
  [string[]]$TargetPrefixes = @(),
  [string[]]$CompositionRootNamePatterns = @("main.cpp", "CompositionRoot*"),

  [bool]$ForbidUnitTestInHeaders = $true,
  [bool]$ForbidUnitTestInCpp = $true,

  [string[]]$PublicCommentRoots = @(),
  [string]$CommentInterfaceNameRegex = '^I[A-Z][A-Za-z0-9]*\.h$',
  [bool]$CommentAllHeadersInRoots = $false,
  [string]$CommentAllHeadersPathRegex = "",

  [hashtable[]]$DomainLeakRules = @(),

  [string]$ExcludeNameRegex = '\.gen\.(cpp|h|hpp)$',
  [bool]$FailOnHardcodedPasswordAssign = $true
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourceRoot)) {
  throw "SourceRoot not found: $SourceRoot"
}

$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$failures = New-Object System.Collections.Generic.List[string]

$sourceFiles = @(Get-ChildItem -Path $SourceRoot -Recurse -Include *.cpp, *.h, *.hpp -File |
  Where-Object { $_.Name -notmatch $ExcludeNameRegex })

function Get-RelativeInTarget {
  param([string]$RelativeNorm)
  foreach ($prefix in $TargetPrefixes) {
    $norm = ($prefix -replace '\\', '/').TrimEnd('/') + '/'
    if ($RelativeNorm.StartsWith($norm)) {
      return $RelativeNorm.Substring($norm.Length)
    }
  }
  return $RelativeNorm
}

function Test-IsCompositionRoot {
  param([string]$FileName, [string]$RelativeInTarget)
  foreach ($pattern in $CompositionRootNamePatterns) {
    if ($FileName -like $pattern) { return $true }
    if ((Split-Path -Leaf $RelativeInTarget) -like $pattern) { return $true }
    if ($RelativeInTarget -like $pattern) { return $true }
  }
  return $false
}

foreach ($file in $sourceFiles) {
  $lines = @(Get-Content -Path $file.FullName)
  if ($lines.Count -gt $MaxLines) {
    $failures.Add("FILE SIZE: $($file.FullName) has $($lines.Count) lines (max $MaxLines)")
  }

  $content = Get-Content -Path $file.FullName -Raw
  if ($null -eq $content) { $content = "" }

  if ($content -match '(?m)^[ \t]+class\s+\w+') {
    $failures.Add("NESTED CLASS: $($file.FullName)")
  }

  $functionMatches = [regex]::Matches(
    $content,
    '(?m)^\s+(?:virtual\s+)?(?:static\s+)?[\w:<>,\s\*&]+?\s+\w+\s*\([^;{]*\)\s*(?:const\s*)?(?:override\s*)?(?:;|\{)'
  )
  if ($functionMatches.Count -gt $MaxMethodsPerClass) {
    $failures.Add("TOO MANY METHODS: $($file.FullName) ~$($functionMatches.Count) (max $MaxMethodsPerClass)")
  }

  if ($MaxFunctionBodyLines -gt 0 -and $file.Extension -eq ".cpp") {
    $pathOk = [string]::IsNullOrEmpty($FunctionBodyPathRegex) -or ($file.FullName -match $FunctionBodyPathRegex)
    if ($pathOk) {
      $depth = 0
      $bodyStack = New-Object System.Collections.Generic.List[object]
      for ($li = 0; $li -lt $lines.Count; $li++) {
        $line = $lines[$li]
        $opens = ([regex]::Matches($line, '\{')).Count
        $closes = ([regex]::Matches($line, '\}')).Count
        if ($opens -gt 0 -and $line -match '\)\s*(?:const\s*)?(?:override\s*)?\{') {
          $bodyStack.Add([pscustomobject]@{ Start = $li; Depth = ($depth + 1) })
        }
        $depth += $opens - $closes
        if ($depth -lt 0) { $depth = 0 }
        while ($bodyStack.Count -gt 0 -and $depth -lt $bodyStack[$bodyStack.Count - 1].Depth) {
          $finished = $bodyStack[$bodyStack.Count - 1]
          $bodyStack.RemoveAt($bodyStack.Count - 1)
          $bodyLen = $li - $finished.Start + 1
          if ($bodyLen -gt $MaxFunctionBodyLines) {
            $failures.Add(("LONG FUNCTION: {0}:{1} ~{2} lines (max {3})" -f `
              $file.FullName, ($finished.Start + 1), $bodyLen, $MaxFunctionBodyLines))
          }
        }
      }
    }
  }
}

foreach ($root in $OneTypePerHeaderRoots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  $headers = Get-ChildItem -Path $root -Recurse -Include *.h, *.hpp -File |
    Where-Object { $_.Name -notmatch $ExcludeNameRegex }
  foreach ($header in $headers) {
    $content = Get-Content -Path $header.FullName -Raw
    if ($null -eq $content) { continue }
    $typeMatches = [regex]::Matches(
      $content,
      '(?m)^(template\s*<[^>]+>\s*)?(enum\s+class|enum|struct|class)\s+\w+'
    )
    if ($typeMatches.Count -gt 1) {
      $failures.Add(("ONE TYPE PER HEADER: {0} defines {1} types" -f `
        $header.FullName, $typeMatches.Count))
    }
  }
}

if ($FailOnHardcodedPasswordAssign) {
  $secretHits = $sourceFiles | Select-String -Pattern 'password\s*=\s*"[^"]{4,}"'
  foreach ($hit in $secretHits) {
    $failures.Add("HARDCODED SECRET: $($hit.Path):$($hit.LineNumber)")
  }
}

if ($ConcreteAdapterHeaders.Count -gt 0) {
  foreach ($file in $sourceFiles) {
    $relative = $file.FullName.Substring($SourceRoot.Length).TrimStart('\', '/')
    $relativeNorm = $relative -replace '\\', '/'
    $relativeInTarget = Get-RelativeInTarget $relativeNorm

    $includes = Select-String -Path $file.FullName -Pattern '#include\s+"([^"]+)"' -AllMatches
    foreach ($match in $includes.Matches) {
      $included = Split-Path -Leaf $match.Groups[1].Value
      if ($ConcreteAdapterHeaders -notcontains $included) {
        continue
      }

      $allowed = $false
      if (Test-IsCompositionRoot -FileName $file.Name -RelativeInTarget $relativeInTarget) {
        $allowed = $true
      }
      if ($file.Name -eq $included) { $allowed = $true }
      if ($file.BaseName -eq ([IO.Path]::GetFileNameWithoutExtension($included))) { $allowed = $true }

      $includePath = ($match.Groups[1].Value -replace '\\', '/')
      $domain = ($includePath -split '/')[0]
      if ($relativeInTarget.StartsWith($domain + '/')) {
        $allowed = $true
      }

      if (-not $allowed) {
        $failures.Add("DI BOUNDARY: $($file.FullName) includes concrete adapter '$included'")
      }
    }
  }
}

foreach ($file in $sourceFiles) {
  $isHeader = $file.Extension -in @(".h", ".hpp")
  $isCpp = $file.Extension -eq ".cpp"
  if (($isHeader -and $ForbidUnitTestInHeaders) -or ($isCpp -and $ForbidUnitTestInCpp)) {
    $hits = Select-String -Path $file.FullName -Pattern 'UNIT_TEST' -SimpleMatch
    foreach ($hit in $hits) {
      $kind = if ($isHeader) { "HEADER" } else { "CPP" }
      $failures.Add(("UNIT_TEST IN {0}: {1}:{2} - prefer DI / fakes over test gates" -f `
        $kind, $hit.Path, $hit.LineNumber))
    }
  }
}

foreach ($rule in $DomainLeakRules) {
  $bridgeRoot = $rule.Root
  $pattern = $rule.ForbiddenPattern
  if (-not $bridgeRoot -or -not $pattern) { continue }
  if (-not (Test-Path -LiteralPath $bridgeRoot)) { continue }
  $forbidden = Get-ChildItem -Path $bridgeRoot -Recurse -Include *.cpp, *.h, *.hpp -File |
    Select-String -Pattern $pattern
  foreach ($hit in $forbidden) {
    $failures.Add("DOMAIN LEAK: $($hit.Path):$($hit.LineNumber) matches /$pattern/")
  }
}

foreach ($root in $PublicCommentRoots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  $headers = Get-ChildItem -Path $root -Recurse -Include *.h, *.hpp -File |
    Where-Object { $_.Name -notmatch $ExcludeNameRegex }
  foreach ($header in $headers) {
    $isInterface = $header.Name -cmatch $CommentInterfaceNameRegex
    $pathForcesAll = -not [string]::IsNullOrEmpty($CommentAllHeadersPathRegex) -and (
      $header.FullName -match $CommentAllHeadersPathRegex
    )
    $commentAll = $CommentAllHeadersInRoots -or $pathForcesAll
    if (-not $isInterface -and -not $commentAll) { continue }

    $lines = @(Get-Content -Path $header.FullName)
    $inPublic = $isInterface
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      if ($line -match '^\s*public\s*:') { $inPublic = $true; continue }
      if ($line -match '^\s*private\s*:') { $inPublic = $false; continue }
      if ($line -match '^\s*protected\s*:') { $inPublic = $false; continue }
      if (-not $inPublic) { continue }

      if ($line -notmatch '^\s+(?:virtual\s+)?(?:static\s+)?[\w:<>,\s\*&~]+?\s+\w+\s*\([^;{]*\)\s*(?:const\s*)?(?:override\s*)?(?:noexcept\s*)?[;{]') {
        continue
      }
      if ($line -match '^\s+(?:using|friend|enum|struct|class)\b') { continue }

      $hasComment = $false
      for ($back = $i - 1; $back -ge 0 -and ($i - $back) -le 4; $back--) {
        $prev = $lines[$back].Trim()
        if ($prev -eq '') { continue }
        if ($prev -match '^///' -or $prev -match '^//[^/]' -or $prev -match '^/\*' -or $prev -match '^\*') {
          $hasComment = $true
        }
        break
      }
      if (-not $hasComment) {
        $failures.Add(("PUBLIC API COMMENT: {0}:{1} - add /// intent comment" -f $header.FullName, ($i + 1)))
      }
    }
  }
}

if ($failures.Count -gt 0) {
  Write-Host "Guardrail failures:" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "ESP/C++ guardrails OK ($($sourceFiles.Count) source files scanned under $SourceRoot)" -ForegroundColor Green
exit 0
