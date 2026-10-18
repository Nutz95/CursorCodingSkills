---
name: solid-powershell
description: >-
  SOLID PowerShell guardrails for setup/package/deploy scripts: small focused
  scripts, explicit ErrorActionPreference, no secrets in repo, clear steps.
  Use when writing or reviewing .ps1 tooling.
---

# SOLID PowerShell

## Hard limits

- Prefer scripts under **400 lines**; split helpers into separate `.ps1` files
- One primary responsibility per script (`setup`, `build`, `package`, `deploy`)

## Practices

- `#Requires -Version 5.1` (or higher when needed)
- `$ErrorActionPreference = "Stop"` unless a block must tolerate stderr noise
- Parameterize paths; avoid hardcoded machine-specific secrets
- Prefer env vars / prompted input for host IPs and credentials
- Write progress with clear `Write-Host` / `Write-Step` sections
- Do not embed API tokens or passwords in scripts committed to git

## Checklist

- [ ] Script stays focused and short enough to scan
- [ ] Failures throw instead of silently continuing
- [ ] No LAN IPs / secrets committed as defaults when avoidable
