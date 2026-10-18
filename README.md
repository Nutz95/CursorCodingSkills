# CursorCodingSkills

Shared **SOLID / guardrail** Cursor skills, one pack per language.

Seeded from recurring rules used across APSystem, AutoBalancingAIBot (ESP32),
SoArm101, and related projects: file-size limits, concrete typing, modularity.

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

## Deploy (recommended)

Install into your **user** Cursor skills directory (available in every project):

```powershell
.\deploy.ps1
```

Install into a **single project** (`.cursor/skills` + `.cursor/rules`):

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

## Updating

Edit skills in this repo, then re-run `deploy.ps1` (junctions stay linked;
copy mode overwrites).
