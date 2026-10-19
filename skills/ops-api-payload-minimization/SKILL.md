---
name: ops-api-payload-minimization
description: >-
  Keep HTTP/API poll payloads minimal on constrained links: light summary or
  signature endpoints, fetch heavy resources only when signatures change,
  server RAM caches, tab/context scoping. Use when designing device or
  dashboard APIs, or reducing bandwidth/CPU on periodic polls.
---

# API payload minimization

## Problem

A UI that polls every ~1s will thrash disk and saturate a slow link (USB RNDIS,
Wi‑Fi IoT, remote device) if every tick returns full configs, CSVs, and images.

## Pattern

1. **Light poll** — `GET /api/summary` (or equivalent) returns only what the
   active view needs: status flags, counters, and **signatures** / etags of heavy resources
2. **Conditional heavy fetch** — client compares signatures; calls fat endpoints
   only when a signature changed (or first load)
3. **Server RAM cache** — avoid re-reading SD/disk when content is unchanged
4. **Context scoping** — pass `active_tab` / view id so the summary omits fields
   for inactive panels
5. **Incremental updates** — after the first scan, keep indexes/counters in memory
   instead of rescanning whole trees every tick

```text
Browser poll (~1s)
  → summary (small)
  → if signature changed → GET heavy resource
  → else reuse local cache
```

## Sketch that avoids the usual traps

Server (RAM cache, not SD on every tick):

```python
def get_summary(active_tab: str, cache: dict) -> dict:
    payload = {
        "tab": active_tab,
        "status": runtime_status(),
        "config_etag": cache["config_etag"],  # not the full JSON
    }
    if active_tab != "metrics":
        return payload
    payload["live"] = live_metrics_only()
    return payload
```

Client:

```javascript
const summary = await fetch("/api/summary?active_tab=" + tab).then((r) => r.json());
if (summary.config_etag !== local.configEtag) {
  local.config = await fetch("/api/config").then((r) => r.json());
  local.configEtag = summary.config_etag;
}
```

Traps:

- Putting images or CSV bodies inside the 1s summary
- Re-reading the same JSON from SD on every poll (pair with `maixcam-sd-card-io` on device)
- A local `_isXxxDirty` flag that the poll overwrites — keep drafts in one store (`ops-ui-draft-dirty-store`)

## Payload rules

- Each message carries **only** fields the consumer needs for that tick
- Prefer signatures (`hash`, `mtime`, `row_count`, `etag`) over embedding blobs
- Prefer `304` / omit-null-fields over repeating unchanged large JSON
- Images/streams stay on dedicated endpoints (MJPEG, byte ranges) — not inside the summary JSON

## Checklist

- [ ] Summary endpoint exists and stays small
- [ ] Heavy GETs gated by signature / ETag
- [ ] Server cache invalidates on write/OTA
- [ ] Inactive UI regions do not inflate the poll
- [ ] No full file dumps on the hot path

## Related

- Static assets: `ops-web-asset-bundle-etag`
- Dashboard state merge: `solid-javascript`
