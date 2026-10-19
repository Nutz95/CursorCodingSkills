---
name: ops-web-asset-bundle-etag
description: >-
  Package web static assets for device or constrained deploy: esbuild minify
  bundles, gzip, ETag/304, cache-busting ?v= with Cache-Control immutable.
  Never hand-edit generated bundles. Use when bundling JS/CSS for deploy, OTA,
  embedded dashboards, or tuning static HTTP cache headers.
---

# Web asset bundle + ETag caching

## Goals

- Ship **minified bundles** on device / OTA paths (smaller SD + faster first load)
- Keep **modular sources** in the repo for development and unit tests
- Serve static assets with **gzip**, **ETag / 304**, and optional **immutable** versioned URLs

## Dev vs deploy

| Mode | What the browser loads | Edit |
|------|------------------------|------|
| Development | ES modules / unbundled sources | Source `.js` / `.css` only |
| Deploy / OTA | Generated `*.bundle.js` (and CSS if any) | Never hand-edit the bundle — rebuild |

## Build example (esbuild)

Install once (`npm ci` with `esbuild` in `devDependencies`), then:

```text
esbuild static/js/app.js ^
  --bundle --minify --format=esm --platform=browser --target=es2020 ^
  --outfile=static/js/app.bundle.js
```

Pitfalls already hit in practice:

- Hand-editing `*.bundle.js` then losing the change on the next package
- Shipping both every module **and** the bundle onto a small SD card
- `Cache-Control: immutable` with a **fixed** URL — browsers never pick up a new bundle

## Serve example

1. Hash file bytes (or use a build id) as `ETag`
2. If `If-None-Match` equals that tag → `304` empty body
3. Else gzip when `Accept-Encoding` allows it, set `ETag`, body = bytes
4. HTML loads `app.bundle.js?v=<etag-or-build-id>` so immutable caching is safe

Packaging for the device ZIP should **omit** the unbundled module tree when the
HTML only references the bundle.

## Server checklist

- [ ] `ETag` derived from content (or stable build id)
- [ ] Honor `If-None-Match` with `304` and empty body
- [ ] Gzip when client accepts it (or pre-gzip on disk)
- [ ] Version query or hashed filename so immutable caching is safe

## Client checklist

- [ ] Load the **bundle** URL in production HTML, modules in dev
- [ ] Do not bypass cache incorrectly on every poll (static ≠ API)
- [ ] After changing sources, run the project’s bundle script before packaging

## Anti-patterns

- Editing `*.bundle.js` by hand
- `Cache-Control: immutable` without a changing `?v=` / hash (stuck clients)
- Shipping both full module trees and bundles on a tiny SD card without need

## Related

- Lean API polling: `ops-api-payload-minimization`
- JS modularity limits: `solid-javascript`
