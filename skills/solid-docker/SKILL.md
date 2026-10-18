---
name: solid-docker
description: >-
  SOLID Docker/Compose guardrails: small Dockerfiles, non-root when practical,
  no secrets in images, pinned base tags, clear multi-stage builds. Use when
  editing Dockerfile or compose files.
---

# SOLID Docker

## Hard limits

- Keep Dockerfiles readable and short; split stages instead of mega-layers
- One service concern per image when practical

## Practices

- Pin base image tags (avoid floating `latest` in production)
- Prefer multi-stage builds to keep runtime images small
- Never bake secrets, tokens, or private keys into layers
- Use `.dockerignore` to exclude `.venv`, `data/`, `.git`, local configs
- Run as non-root in the final stage when the stack allows it
- Document required env vars instead of hardcoding host IPs

## Checklist

- [ ] No secrets in image
- [ ] Build context minimized
- [ ] Runtime image only contains what it needs
