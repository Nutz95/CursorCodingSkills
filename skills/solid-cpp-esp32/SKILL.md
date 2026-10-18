---
name: solid-cpp-esp32
description: >-
  SOLID C++ / ESP32 firmware guardrails from AutoBalancing and SoArm projects:
  English code/docs, braces always, descriptive names, split large modules,
  FreeRTOS-safe patterns. Use when editing ESP-IDF/Arduino-ESP32 firmware.
---

# SOLID C++ ESP32

## Hard limits

- Prefer files under **400 lines**; split when a translation unit grows multiple responsibilities
- Keep functions single-purpose; extract helpers instead of mega-functions

## Language & style

- Committed code/comments/docs in **English**
- Always use braces for `if` / `for` / `while` / `switch`
- No single-line function bodies for non-trivial logic
- Descriptive names (`telemetryManager`, not `mgr` / `tmp` except trivial loop indices)
- Prefer one `namespace` block per translation unit

## Architecture

- SOLID: one responsibility per module/class
- Prefer composition over growing god objects
- Cast FreeRTOS `void*` into a named typed pointer immediately
- Prefer project helpers (e.g. safe C-string copy) over `strncpy` variants

## Validation

- Add the smallest host/unit check that fails if new logic breaks
- Build after interface changes

## Checklist

- [ ] Braces everywhere
- [ ] English identifiers/comments
- [ ] File split before it becomes a dumping ground
- [ ] No unexplained abbreviations in public APIs
