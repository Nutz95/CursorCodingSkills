---
name: solid-cpp-esp32
description: >-
  SOLID C++ / ESP32 firmware guardrails: file/class size, no nested classes,
  strict DI at composition roots, no UNIT_TEST / test ifdefs in production
  headers (and avoid them in .cpp), no hardcoded secrets, one type per public
  header, public API /// comments, dual-core radio pinning (PRO_CPU 0 /
  APP_CPU 1), FreeRTOS-safe patterns. Use when editing ESP-IDF, Arduino-ESP32,
  PlatformIO firmware, or ESP-NOW / BLE / Wi-Fi tasks.
---

# SOLID C++ ESP32

## Hard limits

- Prefer files under **400 lines**; split when a translation unit grows multiple responsibilities
- Max **~30 methods** per class
- Prefer function bodies under **~60 lines** (extract helpers)
- **No nested classes** — move inner types to their own header/TU
- **Exactly one** primary type (`class` / `struct` / `enum` / `enum class`) per public header
  when the project’s guardrails enable one-type-per-header on that root. Do not pack
  `enum` + `struct` + `I*` into one `.h`; split them.

Wire the check with your repo’s guardrail tool (e.g. `esp_cpp_guardrails` /
`-OneTypePerHeaderRoots` listing the trees you care about — board HAL, bridges, etc.).

## Language & style

- Committed code/comments/docs in **English**
- Always use braces for `if` / `for` / `while` / `switch`
- No single-line function bodies for non-trivial logic
- Descriptive names (`telemetryManager`, not `mgr` / `tmp` / `spr` except trivial loop indices).
  Prefer pronounceable words (`canvas`, `frameBuffer`) over cryptic abbreviations
- Prefer one `namespace` block per translation unit
- Headers declare intent; `.cpp` files stay boring and direct
- Public methods on `I*.h` interfaces (and other opted-in public headers) need a one-line `///` intent comment

## Architecture (SOLID + DI)

- Prefer **interfaces** (`I*`) at domain boundaries
- Depend on abstractions in application / domain code; construct **concrete adapters only** in `main.cpp` or an explicit composition root
- Hardware (BLE, Wi-Fi, display, NVS, buses) stays behind interfaces so host unit tests use fakes — not `#ifdef` surgery
- Prefer small pure parsers unit-tested on `native` / host builds
- Prefer composition over growing god objects
- Cast FreeRTOS `void*` into a named typed pointer immediately
- Prefer project helpers (e.g. safe C-string copy) over `strncpy` variants

### Domain / layer isolation

- Keep hub-only stacks (web, auth, OTA, HTTP API) out of bridge / leaf targets
- Do not `#include` concrete adapter headers from the wrong layer; if a guardrail lists adapter names, obey it

## No test instrumentation in production APIs

Production code must **not** be shaped by test build flags.

- **Forbidden in headers and `.cpp`**: `UNIT_TEST`, `#ifdef UNIT_TEST`, `#ifndef UNIT_TEST`, `#if defined(UNIT_TEST)`, or any equivalent test-only gate (esp_cpp_guardrails fails hard by default)
- Prefer DI: extract an interface, inject a fake in host tests, or **exclude** device adapter TUs from the `native` / host `build_src_filter` — never ifdef-stub production sources
- Platform detection (`__has_include(<esp_random.h>)`, `ESP_PLATFORM`) is fine; test build flags that reshape production logic are not
- Keep portable types in headers (`std::mutex`, etc.) or unconditional device includes in device-only TUs

Smell → fix:

| Smell | Fix |
|-------|-----|
| `#ifndef UNIT_TEST` around Wi-Fi / BLE calls in a service | Inject `IWifiConnector` / `IBleClient`; fake in host tests |
| Header stubs different types when `UNIT_TEST` | Portable type always, or split device adapter |
| God class needs ifdefs to compile on host | Split responsibilities; composition root wires adapters |

## Secrets

- **Never** hardcode Wi-Fi passwords, OTA / web passwords, device secrets, PMKs, tokens, or LAN credentials in source
- Inject secrets via environment variables / build flags consumed by PlatformIO (or equivalent) — never commit `.env` with real secrets

## Dual-core FreeRTOS (ESP32)

Classic ESP32 has two cores:

| Core | ID | Typical use |
|------|----|-------------|
| **PRO_CPU** | **0** | Wi-Fi / BT / radio-adjacent work (ESP-NOW TX/RX loops, BLE/SPP radio tasks) |
| **APP_CPU** | **1** | Heavier app work: display UI, HTTP/web, parsing bursts, SD, non-radio loops |

Defaults (override only with a documented special case):

- Pin radio / stack-sensitive tasks with `xTaskCreatePinnedToCore(..., kRadioCoreId)` where `kRadioCoreId = 0`
- Pin UI / heavy non-radio tasks to `kAppCoreId = 1`
- Avoid long blocking work on core 0; it starves the radio stack
- Prefer named constants (`kRadioCoreId` / `kAppCoreId`) over magic `0` / `1`

## Validation

- Run the project’s guardrail script (or `tools/esp_cpp_guardrails`) after structural changes
- Add the smallest host/unit check that fails if new logic breaks
- Build after interface changes
- Update README when behavior, scripts, hardware assumptions, or architecture change
- Prefer a blocking code-quality review before merge when the project requires it

## Checklist

- [ ] Braces everywhere; English identifiers/comments
- [ ] Under ~400 lines / ~30 methods; no nested class
- [ ] Concrete adapters only at composition root; domain depends on `I*`
- [ ] No `UNIT_TEST` / test ifdefs in headers; avoid them in `.cpp`
- [ ] No hardcoded secrets
- [ ] `///` on new public interface methods
- [ ] Radio tasks on core 0; heavy app work on core 1 (unless documented exception)
- [ ] Guardrails / tests green
