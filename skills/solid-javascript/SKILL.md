---
name: solid-javascript
description: >-
  SOLID JavaScript guardrails: max 400 lines/file, max 30 methods/class, one
  view/module per file, no hand-editing generated bundles. Use when editing
  browser JS, canvas charts, dashboard views, or frontend modularity.
---

# SOLID JavaScript

## Hard limits

- Max **400 lines** per `.js` file
- Max **30 methods** per class
- One view / theme / collaborator per file

## Structure

- Prefer small view classes over god `app.js` growth
- Keep DOM wiring in the app shell; keep rendering in view modules
- Share helpers (format, hover, palette) instead of copy-paste
- Do not hand-edit generated `*.bundle.js`

## Style

- Use existing project namespace patterns when present
- Prefer clear names over clever abstractions
- Avoid optional “maybe” flags that fork control flow; extract a helper

## Checklist

- [ ] Under 400 lines / 30 methods
- [ ] No duplicated chart/fetch helpers when a shared module exists
- [ ] Bundler sources edited, not generated output
