---
name: solid-javascript
description: >-
  SOLID JavaScript guardrails: max 500 lines for dashboard/device UI modules
  (400 for other JS), max 30 methods/class, one view/module per file, no
  hand-editing generated bundles, prefer a single dashboard state source over
  local dirty flags, colocate *.test.mjs with node --test. Use when editing
  browser JS, canvas charts, dashboard views, or frontend modularity.
---

# SOLID JavaScript

## Hard limits

- Max **500 lines** per `.js` file for dashboard / device Web UI modules
- Max **400 lines** for other JavaScript (Node tools, small helpers) unless the project says otherwise
- Max **30 methods** per class
- One view / theme / collaborator per file

## Structure

- Prefer small view classes over god `app.js` growth
- Keep DOM wiring in the app shell; keep rendering in view modules
- Share helpers (format, hover, palette) instead of copy-paste
- Do not hand-edit generated `*.bundle.js` — edit sources, then rebuild (see `ops-web-asset-bundle-etag`)

## State and polling

- Prefer one dashboard state store; do not scatter mutable `_statePayload` writes
- Editable controls + ~1s poll: use a central **draft/dirty store** keyed by field id
  (`ops-ui-draft-dirty-store`) — **not** local `_isXxxDirty` flags that the poll overwrites
- Keep poll payloads lean (see `ops-api-payload-minimization`)

## Tests

- Colocate unit tests as `*.test.mjs` next to (or under `tests/` near) the module
- Run with `node --test` (see `ops-parallel-test-suites`)

## Style

- Use existing project namespace patterns when present
- Prefer clear names over clever abstractions
- Avoid optional “maybe” flags that fork control flow; extract a helper

## Checklist

- [ ] Under size limit / 30 methods
- [ ] No duplicated chart/fetch helpers when a shared module exists
- [ ] Bundler sources edited, not generated output
- [ ] No local dirty flags fighting a poll merge (`ops-ui-draft-dirty-store`)
- [ ] Tests colocated as `*.test.mjs` when adding logic
