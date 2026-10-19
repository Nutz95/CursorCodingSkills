---
name: ops-parallel-test-suites
description: >-
  Structure and run multi-language tests efficiently: discover suite directories,
  in-process pytest worker pool with CPU soft-cap, Node *.test.mjs via node --test,
  keep functional/remote suites sequential, single gate script. Use when designing
  test layouts or speeding up CI/local gates without pytest-xdist by default.
---

# Parallel test suites

## Goals

- Fast local/CI gates without flaky shared-process coupling
- Clear layout per language so agents know where to add tests
- Parallelize **independent suite roots**, not every test file blindly

## Suggested layout

| Kind | Location | Runner |
|------|----------|--------|
| Python unit / package | `<pkg>/tests/`, `tests/` | pytest via suite pool |
| Python quality / guardrails | `tests/quality/` | pytest (can be one suite in the pool) |
| JavaScript / Node logic | next to sources as `*.test.mjs` or `…/tests/**/*.test.mjs` | `node --test` |
| Functional / device / network | `tests/functional/` | **sequential**, often skippable locally |
| Slow packaging / bundle | dedicated suite flag | sequential or separate job |

## Python pool pattern (prefer over default xdist)

1. Discover **suite directories** (each importable / isolatable root)
2. Start N long-lived workers (`N ≈ min(CPU, max(8, ceil(CPU/2)))` soft-cap)
3. Queue suites; each worker runs `pytest` on one suite at a time
4. Env fallback to subprocess-per-suite when in-process is unsafe
5. Flag to force sequential for debugging

Why suite-level pool: shared fixtures, native extensions, and long-lived app objects often break under fine-grained xdist.

Sketch (one process, N workers, one suite directory each):

```python
# Discover suite roots, queue paths, workers call pytest.main([suite_dir])
# Soft-cap: workers = min(cpu_count, max(8, ceil(cpu_count / 2)))
# Fallback env: run each suite as a subprocess if in-process imports collide
# Flag: --sequential for debugging
```

Keep device/network suites **out** of that pool (reboot, serial, shared camera).
A slow “package ZIP + bundle” suite should be its own job or a skippable marker.

## Gate script

Provide one entry (e.g. `run_tests.ps1` / `run_tests.sh`) that:

- Runs JS `node --test` (or project equivalent)
- Runs the Python suite pool
- Optionally skips functional / remote suites by default for agents
- Returns non-zero on any failure

## Checklist

- [ ] Suites are directory-scoped and independent enough to parallelize
- [ ] Functional/device tests are sequential and skippable
- [ ] Soft-cap prevents HT oversubscription
- [ ] Fakes live under `**/tests/fakes/` (`python-test-fakes` / `solid-python`)
- [ ] Agents are told the one gate command to run after edits

## Related

- Fake layout: `solid-python`, `python-test-fakes`
- JS tests: `solid-javascript`
