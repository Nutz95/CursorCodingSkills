#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Invoker = Join-Path $Root "esp_cpp_guardrails\Invoke-EspCppGuardrails.ps1"
$OkRoot = Join-Path $Root "tests\fixtures\esp_cpp_ok"
$BadRoot = Join-Path $Root "tests\fixtures\esp_cpp_bad"

function Invoke-GuardrailsExitCode {
  param(
    [string]$SourceRoot,
    [hashtable]$ExtraParams = @{}
  )
  $splat = @{ SourceRoot = $SourceRoot }
  foreach ($key in $ExtraParams.Keys) {
    $splat[$key] = $ExtraParams[$key]
  }
  # Capture scanner chatter so expected failures do not look like a broken run.
  $null = & $Invoker @splat *>&1
  return $LASTEXITCODE
}

Write-Host "==> esp_cpp_guardrails fixture tests" -ForegroundColor Cyan

$okCode = Invoke-GuardrailsExitCode -SourceRoot $OkRoot -ExtraParams @{
  PublicCommentRoots       = @($OkRoot)
  CommentAllHeadersInRoots = $true
}
if ($okCode -ne 0) {
  throw "Expected clean fixture to pass, exit=$okCode"
}
Write-Host "  - clean fixture OK"

Write-Host "  - bad fixture should fail (nested class + UNIT_TEST in header)..."
$badCode = Invoke-GuardrailsExitCode -SourceRoot $BadRoot
if ($badCode -eq 0) {
  throw "Expected nested-class / UNIT_TEST header fixture to fail"
}
Write-Host "  - bad fixture failed as expected (guardrails working)"

Write-Host "esp_cpp_guardrails fixture tests OK." -ForegroundColor Green
exit 0
