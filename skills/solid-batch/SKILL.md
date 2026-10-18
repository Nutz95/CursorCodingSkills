---
name: solid-batch
description: >-
  SOLID Batch (.bat/.cmd) guardrails: thin wrappers around PowerShell/Python,
  setlocal, explicit errorlevel checks, no secrets. Use when editing Windows
  launchers or portable package entrypoints.
---

# SOLID Batch

## Hard limits

- Keep `.bat` files thin (prefer < 80 lines)
- Delegate real logic to PowerShell or Python

## Practices

- `setlocal` at the top
- `cd /d "%~dp0"` for portable relative paths
- Check `errorlevel` after critical calls
- Do not hardcode secrets or private LAN defaults when a prompt/env exists
- Echo security notes when launching network-facing tools without auth

## Checklist

- [ ] Launcher only orchestrates
- [ ] Failures exit with non-zero codes
- [ ] Paths are relative to `%~dp0`
