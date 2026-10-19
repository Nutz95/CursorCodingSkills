---
name: ops-portable-python-package
description: >-
  Make a Python application portable/packagable: whitelist the app tree, build a
  binary wheelhouse (pip download --only-binary), pin the host Python minor,
  offline venv bootstrap, launcher scripts, exclude caches/tests/secrets. Use
  when creating a ZIP-distributable host app or offline install — not tied to
  any emulator or camera platform.
---

# Portable Python package

## Goal

Ship a **host** Python app as a ZIP (or folder) that another machine can run
**offline** after a one-shot venv create from bundled wheels — without assuming
a particular product, simulator, or hardware HAL.

## Steps

1. **Whitelist the tree** — copy only runtime packages, configs, static assets, launchers
2. **Exclude** — `__pycache__`, `.venv`, tests, quality baselines, secrets, huge optional assets the host does not need
3. **Pin Python minor** — document and enforce `3.x` matching the wheelhouse ABI
4. **Wheelhouse** — `pip download --only-binary=:all: -d wheelhouse -r requirements.txt` (and any extra constraints) on a clean builder matching that minor
5. **Offline install script** — create `.venv` and `pip install --no-index --find-links=wheelhouse -r requirements.txt`
6. **Launcher** — `RunApp.cmd` / shell script that activates venv and starts the entry module
7. **README** — host OS notes, Python version, “first run installs from wheelhouse”

## Layout sketch

```text
MyApp-Portable/
  app/                 # whitelisted sources
  wheelhouse/          # *.whl
  requirements.txt
  SetupVenv.cmd        # offline pip install
  RunApp.cmd
  README.txt
```

## Checklist

- [ ] No secrets or machine-local paths baked in
- [ ] Wheels are binary-only for the target OS/arch/Python minor
- [ ] First-run path works with network disabled
- [ ] Entry point and working directory are explicit
- [ ] Optional native deps documented (VC++ runtime, etc.)

## Orthogonal concerns

- **Device/OTA JS minify** is not this skill — see `ops-web-asset-bundle-etag`
- Platform-specific host tools (e.g. MaixCam HAL=sim) belong in a thin overlay skill, not here

## Anti-patterns

- Shipping a prebuilt `.venv` across machines (path / OS fragile)
- Mixing source installs that need a compiler on the customer PC
- Bundling unrelated device firmware blobs into a host portable ZIP
