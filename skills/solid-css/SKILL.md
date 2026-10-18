---
name: solid-css
description: >-
  SOLID CSS guardrails: max 400 lines per CSS file, one theme/concern per file,
  CSS variables for brand tokens, no hand-editing generated bundles. Use when
  editing stylesheets, layout, or design tokens.
---

# SOLID CSS

## Hard limits

- Max **400 lines** per `.css` file
- One concern / theme per file (hero, metrics, chart, tabs, …)

## Practices

- Define colors/fonts/spacing as CSS variables in a tokens file
- Prefer composition over deep nesting
- Do not hand-edit generated `*.bundle.css`
- Keep selectors local to a view when possible

## Checklist

- [ ] File under 400 lines
- [ ] Tokens reused instead of magic hex scatter
- [ ] Source CSS edited, then rebuilt if a bundler exists
