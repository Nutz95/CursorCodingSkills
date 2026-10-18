# CursorCodingSkills

Shared **SOLID / guardrail** Cursor skills, always-on rules, plus reusable
**Python** and **ESP/C++** guardrail packages you can run from project tests.

Seeded from recurring rules across projects: file-size limits, concrete typing,
one type per file, no nested classes, strict DI at composition roots, no
test-ifdef instrumentation in production APIs, no hardcoded secrets.

## Skills

| Skill folder | Use when editing |
|--------------|------------------|
| `skills/solid-python` | Python (+ Protocol/ABC DI) |
| `skills/solid-javascript` | JavaScript (browser / Node) |
| `skills/solid-css` | CSS |
| `skills/solid-powershell` | PowerShell |
| `skills/solid-batch` | `.bat` / `.cmd` |
| `skills/solid-cpp-esp32` | C++ / ESP-IDF / Arduino-ESP32 / PlatformIO |
| `skills/solid-docker` | Dockerfile / Compose |
| `skills/solid-cuda-13` | CUDA 13 / GPU Python bindings |

Optional always-on rules live under `rules/*.mdc`.

## Rules (always-on when deployed to a project)

| Rule | Intent |
|------|--------|
| `file-size-limits` | Max 400 lines / file, max 30 methods / class |
| `no-nested-classes` | Ban nested types |
| `no-hardcoded-secrets` | No passwords / tokens / PMKs in source |
| `solid-di-boundaries` | Interfaces + composition roots; fakes in tests |
| `no-test-ifdefs-in-prod-headers` | No `UNIT_TEST` / test gates in production headers |
| `python-no-object-typing` | Concrete Python typing |
| `python-one-type-per-file` | One Python type per file |

## Python guardrails package

Importable package: `python_guardrails/`

| Guard | Checks |
|-------|--------|
| `FileSizeGuard` | max 400 lines/file, max 30 methods/class |
| `PythonStructureGuard` | one type/file, no nested class, no variadic/stacked tuples |
| `PythonTypingGuard` | no `Any` / `object` / bare `dict`/`list`/`tuple`/`set` |
| `check_roots` / `assert_roots_clean` | run the set in one call |

## ESP / C++ guardrails package

PowerShell scanner: `esp_cpp_guardrails/Invoke-EspCppGuardrails.ps1`

General checks (file size, nested classes, secrets, `UNIT_TEST` in headers, optional
DI adapter list, one-type-per-header, function body length, public `///`, domain leaks).
See `esp_cpp_guardrails/README.md`.

`UNIT_TEST` / test ifdefs in production headers **and** `.cpp` fail by default.
Prefer interfaces + fakes; pass `-ForbidUnitTestInCpp $false` only during migration.

### Run package self-tests

```powershell
.\run_tests.ps1
```

### Use in a project

1. Deploy into the project (installs skills/rules **and** junctions/copies packages):

```powershell
.\deploy.ps1 -ProjectPath "C:\MyProject"
```

This creates:

- `C:\MyProject\.cursor\skills` + `.cursor\rules`
- `C:\MyProject\tools\python_guardrails`
- `C:\MyProject\tools\esp_cpp_guardrails`

ESP-only project (skip Python package):

```powershell
.\deploy.ps1 -ProjectPath "C:\MyEspFw" -SkipPythonGuardrails
```

2. Hook your project script, for example:

```powershell
& .\tools\esp_cpp_guardrails\Invoke-EspCppGuardrails.ps1 `
  -SourceRoot (Join-Path $repoRoot "src") `
  -ConcreteAdapterHeaders @("EspWifiConnector.h") `
  -ForbidUnitTestInHeaders $true
```

Python projects: put `tools\` on `PYTHONPATH`, then:

```python
from pathlib import Path
from python_guardrails import assert_roots_clean

def test_source_guardrails() -> None:
    root = Path(__file__).resolve().parents[1]
    assert_roots_clean(
        size_roots=[root / "apsystem", root / "frontend"],
        python_roots=[root / "apsystem"],
    )
```

Skip all tool packages during deploy:

```powershell
.\deploy.ps1 -ProjectPath "C:\MyProject" -SkipGuardrails
```

## Deploy (skills / rules)

Install into your **user** Cursor skills directory (available in every project):

```powershell
.\deploy.ps1
```

Install into a **single project**:

```powershell
.\deploy.ps1 -ProjectPath "C:\MyProject"
```

Force copy instead of directory junctions:

```powershell
.\deploy.ps1 -Mode Copy
.\deploy.ps1 -ProjectPath "C:\MyProject" -Mode Copy
```

List what would be installed:

```powershell
.\deploy.ps1 -WhatIf
```

## After deploy

- Restart Cursor or reload the window so skills are picked up.
- Ask the agent to “follow solid-cpp-esp32 / solid-python / file-size limits” or rely on skill
  descriptions for auto-invocation when editing matching languages.
- Project rules (`*.mdc` with `alwaysApply: true`) apply automatically in that repo.
- Project tests can import `python_guardrails` when `tools\` (or this repo) is on `PYTHONPATH`.
- ESP projects can call `tools\esp_cpp_guardrails\Invoke-EspCppGuardrails.ps1`.

## Updating

Edit skills / guardrail packages in this repo, then re-run `deploy.ps1`
(junctions stay linked; copy mode overwrites). Re-run `.\run_tests.ps1` after
guardrail changes.
