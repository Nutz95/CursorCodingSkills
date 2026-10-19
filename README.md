# CursorCodingSkills

Shared **SOLID / guardrail** Cursor skills, always-on rules, plus reusable
**Python** and **ESP/C++** guardrail packages you can run from project tests.

Seeded from recurring rules across projects and matured on MaixCam-style
embedded Python work: file-size limits, concrete typing, one type per file,
no nested classes/defs, no dynamic `getattr`, strict DI, portable packaging,
lean API polls, and web asset ETag bundling.

## Layers

| Layer | What | Where |
|-------|------|--------|
| **L0 generic** | `solid-*`, `ops-*`, rules, `python_guardrails` | this repo |
| **MaixCam category** | `skills/maixcam/*` (preview, device, host sim, portable deltas) | this repo |
| **Project overlay** | Product HAL layers, local gates, brand-specific portable notes | each product `.cursor/` |

Deploy installs L0 + MaixCam skills into a project; keep product-only rules in that project.

## Skills

### SOLID / language

| Skill folder | Use when editing |
|--------------|------------------|
| `skills/solid-python` | Python (+ Protocol/ABC DI, no getattr, fakes layout) |
| `skills/solid-javascript` | JavaScript (browser / Node; dashboard UI ≤500 lines) |
| `skills/solid-css` | CSS |
| `skills/solid-powershell` | PowerShell |
| `skills/solid-batch` | `.bat` / `.cmd` |
| `skills/solid-cpp-esp32` | C++ / ESP-IDF / Arduino-ESP32 / PlatformIO |
| `skills/solid-docker` | Dockerfile / Compose |
| `skills/solid-cuda-13` | CUDA 13 / GPU Python bindings |

### Ops (cross-project)

| Skill folder | Intent |
|--------------|--------|
| `skills/ops-web-asset-bundle-etag` | esbuild minify, gzip, ETag/304, `?v=` immutable |
| `skills/ops-api-payload-minimization` | Light summary/signature polls; fat GETs only on change |
| `skills/ops-ui-draft-dirty-store` | Poll-safe edits: draft store + field ids, no `_isXxxDirty` |
| `skills/ops-parallel-test-suites` | Suite layout + in-process pytest pool + `node --test` |
| `skills/ops-portable-python-package` | Host ZIP: whitelist, wheelhouse, offline venv (no simulator jargon) |

### ESP category

| Skill folder (install name) | Intent |
|-----------------------------|--------|
| `skills/esp/rgb565-color` → `esp-rgb565-color` | RGB888→RGB565 packing + sprite present endian traps |
| `skills/esp/pocket-dongle-s3-096-display` → `esp-pocket-dongle-s3-096-display` | Pocket-Dongle-S3-0.96 ST7735 pins, TFT_eSPI flags, sprites / JPEG / LVGL |

### MaixCam category

| Skill folder (install name) | Intent |
|-----------------------------|--------|
| `skills/maixcam/mjpeg-preview-stream` → `maixcam-mjpeg-preview-stream` | `JpegStreamer` on device, sim stand-in, client-side overlays |
| `skills/maixcam/device-ssh-ip` → `maixcam-device-ssh-ip` | SSH keys, USB IP autodetection examples, known_hosts |
| `skills/maixcam/device-acm-usb` → `maixcam-device-acm-usb` | ACM gadget shell examples + runtime order |
| `skills/maixcam/device-autostart` → `maixcam-device-autostart` | `/etc/init.d/S99…` example + fsync write |
| `skills/maixcam/host-simulator` → `maixcam-host-simulator` | HAL sim/maix, ONNX CPU NN, frame-source switching |
| `skills/maixcam/portable-package` → `maixcam-portable-package` | MaixCam deltas on `ops-portable-python-package` |
| `skills/maixcam/sd-card-io` → `maixcam-sd-card-io` | SD wear: RAM cache, atomic write, fsync |

`deploy.ps1` finds every directory under `skills/` that contains `SKILL.md` and
installs it as `<relative-path-with-dashes>` (nested categories supported).

### What belongs in a skill (vs not)

**Put in a skill**

- Goals, ordered steps, pitfalls, and **minimal copy-pasteable examples** (shell, PowerShell, short Python) an agent can adapt
- Cross-links to related skills
- Checklists the agent can tick

**Do not put in a skill**

- Full product trees, proprietary wheels, or one app’s branding/menus
- Entire modules copied from a living repo (skills go stale; examples stay short)
- Secrets, real Wi‑Fi passwords, production IPs of a single site

If an agent cannot implement the feature from the skill alone without opening your
product repo, the skill is too thin — add an example. If the skill names only one
company product, move that to the product `.cursor` / `agent.md` (L1).

## Rules (always-on when deployed to a project)

| Rule | Intent |
|------|--------|
| `file-size-limits` | Max 400 lines/file, 30 methods/class, 60 lines/function |
| `no-nested-classes` | Ban nested types **and** nested defs (Python) |
| `no-hardcoded-secrets` | No passwords / tokens / PMKs in source |
| `solid-di-boundaries` | Interfaces + composition roots; fakes in tests |
| `no-test-ifdefs-in-prod-headers` | No `UNIT_TEST` / test gates in production headers |
| `python-no-object-typing` | Concrete Python typing |
| `python-one-type-per-file` | One Python type per file |
| `python-no-dynamic-access` | No `getattr`/`hasattr` / AttributeError masking |
| `python-no-nested-defs` | No nested `def`/`async def` in prod |
| `python-test-fakes` | Fakes under `tests/fakes/`; no monkeypatch setattr |
| `python-no-owned-positional-tuples` | No NamedTuple / namedtuple VOs |
| `no-local-plan-refs-in-shipped-docs` | No « Lot N » / `Plans/*_plan.md` in shipped text |

ESP skills live under `skills/esp/` (e.g. `esp-rgb565-color`, `esp-pocket-dongle-s3-096-display`).

Exemption markers (Python): `# solid-getattr:`, `# solid-nested-def:`,
`# solid-function-max-lines:`.

## Python guardrails package

Importable package: `python_guardrails/`

| Guard | Checks |
|-------|--------|
| `FileSizeGuard` | max 400 lines/file, max 30 methods/class (AST for Python methods) |
| `PythonStructureGuard` | one type/file, no nested class, no variadic/stacked tuples |
| `PythonTypingGuard` | no `Any` / `object` / bare `dict`/`list`/`tuple`/`set` |
| `DynamicAccessGuard` | no `getattr`/`hasattr` / `except AttributeError` |
| `NestedFunctionDefGuard` | no nested `def`/`async def` |
| `FunctionLineLimitGuard` | max 60 lines per function |
| `OwnedPositionalTupleGuard` | no `namedtuple` / `NamedTuple` |
| `InlineFakeClassGuard` | fakes under `tests/fakes/` |
| `MonkeypatchSetattrGuard` | no `monkeypatch.setattr` in tests |
| `check_roots` / `assert_roots_clean` | hard-fail all of the above |
| `assert_roots_within_baseline` | optional progressive ratchet via JSON baseline |

## ESP / C++ guardrails package

PowerShell scanner: `esp_cpp_guardrails/Invoke-EspCppGuardrails.ps1`

See `esp_cpp_guardrails/README.md`.

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

Language-filtered tool packages (prefer this over the old Skip* switches):

```powershell
# Python-only app (e.g. MaixCam host/device Python) — for CI, use Copy
.\deploy.ps1 -ProjectPath "C:\MyPythonApp" -Mode Copy -Languages Python

# ESP32 / C++ firmware only
.\deploy.ps1 -ProjectPath "C:\MyEspFw" -Mode Copy -Languages EspCpp

# Both packages
.\deploy.ps1 -ProjectPath "C:\MyMixed" -Mode Copy -Languages Python,EspCpp
```

Legacy switches `-SkipPythonGuardrails` / `-SkipEspCppGuardrails` / `-SkipGuardrails` still work.

2. Hook your project tests, for example:

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

Optional ratchet for legacy trees:

```python
from pathlib import Path
import os
from python_guardrails import assert_roots_within_baseline

def test_source_guardrails_ratchet() -> None:
    root = Path(__file__).resolve().parents[1]
    assert_roots_within_baseline(
        [root / "src"],
        root / "tests" / "quality" / "guard_baseline.json",
        update_baseline=os.getenv("UPDATE_GUARD_BASELINE") == "1",
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
- Ask the agent to follow `solid-python` / `ops-*` / `maixcam-*` or rely on skill
  descriptions for auto-invocation when editing matching languages.
- Project rules (`*.mdc` with `alwaysApply: true`) apply automatically in that repo.
- Project tests can import `python_guardrails` when `tools\` (or this repo) is on `PYTHONPATH`.
- ESP projects can call `tools\esp_cpp_guardrails\Invoke-EspCppGuardrails.ps1`.

## Updating

Edit skills / guardrail packages in this repo, then re-run `deploy.ps1`
(junctions stay linked; copy mode overwrites). Re-run `.\run_tests.ps1` after
guardrail changes.
