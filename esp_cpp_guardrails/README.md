# ESP / C++ guardrails

Reusable PowerShell scanner for ESP32 / PlatformIO (or similar) C++ trees.

## Checks (opt-in where noted)

| Check | Default |
|-------|---------|
| Max 400 lines / file | on |
| Max ~30 methods / file | on |
| Nested classes | on |
| Hardcoded `password = "..."` | on |
| `UNIT_TEST` in headers | on |
| `UNIT_TEST` in `.cpp` | on |
| DI boundary (concrete adapter includes) | when adapter list provided |
| One type per header | when roots provided |
| Function body length | when `MaxFunctionBodyLines` > 0 |
| Public `///` on interface methods | when roots provided |
| Domain leak includes | when rules provided |

## Usage

```powershell
& .\esp_cpp_guardrails\Invoke-EspCppGuardrails.ps1 `
  -SourceRoot "C:\MyFw\src" `
  -ConcreteAdapterHeaders @("EspWifiConnector.h", "NvsCredentialStore.h") `
  -CompositionRootNamePatterns @("main.cpp", "CompositionRoot*") `
  -ForbidUnitTestInHeaders $true
```

After `deploy.ps1 -ProjectPath ...`, the same script is available at:

`.\tools\esp_cpp_guardrails\Invoke-EspCppGuardrails.ps1`

## Design note

`#ifndef UNIT_TEST` in production sources is a SOLID smell. Prefer interfaces + fakes.
Both headers and `.cpp` fail by default; pass `-ForbidUnitTestInCpp $false` only
during a temporary migration.
