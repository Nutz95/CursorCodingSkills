# CursorCodingSkills

Shared **SOLID / guardrail** Cursor skills, plus a reusable **Python guardrail
package** you can run from project tests.

Seeded from recurring rules used across multiple projects: file-size limits, concrete typing, one type per
file, no nested classes, no variadic / stacked tuple returns.

## Skills

| Skill folder | Use when editing |
|--------------|------------------|
| `skills/solid-python` | Python |
| `skills/solid-javascript` | JavaScript (browser / Node) |
| `skills/solid-css` | CSS |
| `skills/solid-powershell` | PowerShell |
| `skills/solid-batch` | `.bat` / `.cmd` |
| `skills/solid-cpp-esp32` | C++ / ESP-IDF / Arduino-ESP32 |
| `skills/solid-docker` | Dockerfile / Compose |
| `skills/solid-cuda-13` | CUDA 13 / GPU Python bindings |

Optional always-on rules live under `rules/*.mdc`.

## Python guardrails package

Importable package: `python_guardrails/`

| Guard | Checks |
|-------|--------|
| `FileSizeGuard` | max 400 lines/file, max 30 methods/class |
| `PythonStructureGuard` | one type/file, no nested class, no variadic/stacked tuples |
| `PythonTypingGuard` | no `Any` / `object` / bare `dict`/`list`/`tuple`/`set` |
| `check_roots` / `assert_roots_clean` | run the set in one call |

### Run package self-tests

```powershell
.\run_tests.ps1
```

### Use in a project

1. Deploy into the project (installs skills/rules **and** junctions/copies the package):

```powershell
.\deploy.ps1 -ProjectPath "E:\AI\APSystem"
```

This creates `E:\AI\APSystem\tools\python_guardrails`.

2. Put `tools\` on `PYTHONPATH`, then in a test:

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

Sibling layout also works without deploy: if `../CursorCodingSkills` exists, add
that folder to `PYTHONPATH` instead of `tools\`.

Skip installing the package during deploy:

```powershell
.\deploy.ps1 -ProjectPath "E:\AI\APSystem" -SkipGuardrails
```

## Deploy (skills / rules)

Install into your **user** Cursor skills directory (available in every project):

```powershell
.\deploy.ps1
```

Install into a **single project** (`.cursor/skills` + `.cursor/rules` + `tools/python_guardrails`):

```powershell
.\deploy.ps1 -ProjectPath "E:\AI\APSystem"
```

Force copy instead of directory junctions:

```powershell
.\deploy.ps1 -Mode Copy
.\deploy.ps1 -ProjectPath "E:\AI\PeopleCounter" -Mode Copy
```

List what would be installed:

```powershell
.\deploy.ps1 -WhatIf
```

## After deploy

- Restart Cursor or reload the window so skills are picked up.
- Ask the agent to “follow solid-python / file-size limits” or rely on skill
  descriptions for auto-invocation when editing matching languages.
- Project rules (`*.mdc` with `alwaysApply: true`) apply automatically in that repo.
- Project tests can import `python_guardrails` when `tools\` (or this repo) is on `PYTHONPATH`.

## Updating

Edit skills / `python_guardrails` in this repo, then re-run `deploy.ps1`
(junctions stay linked; copy mode overwrites). Re-run `.\run_tests.ps1` after
guardrail changes.
