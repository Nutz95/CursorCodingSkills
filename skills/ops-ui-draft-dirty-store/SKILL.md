---
name: ops-ui-draft-dirty-store
description: >-
  Keep in-progress UI edits when a dashboard polls every ~1s: central draft/dirty
  store keyed by field id, overlay server values only when not dirty, confirm after
  save matches signature. Avoid local _isXxxDirty flags. Use for device dashboards
  or any polled form UI.
---

# UI draft / dirty store (poll-safe edits)

## Problem

A live dashboard polls the server (~1s). Without care, each poll **rewrites the DOM
or state** and **wipes** the slider / text / geometry the operator is mid-editing.
Local booleans like `_isIsoDirty` scattered per panel fight each other and miss merges.

## Pattern

1. **One draft store** for the page (or shell), keyed by **stable field ids**
2. On user edit → `beginEdit(fieldId, pendingValue)` (field becomes dirty)
3. On poll / hydrate → for each field: `display = store.overlay(fieldId, serverValue)`
   (dirty → keep pending; clean → take server)
4. After successful save → `confirm(fieldId, serverValue)` only if the server value
   **matches** the pending signature; else keep dirty or show conflict
5. Cancel → `revert(fieldId)`

```text
poll summary / config
  → for each editable field
       if dirty(fieldId): keep draft
       else: apply server value to UI
user moves slider
  → beginEdit(fieldId, newValue)
user Save
  → POST → on OK confirm(fieldId, echoedValue)
```

## Minimal store (copy / adapt)

```javascript
export class DraftStore {
  constructor() {
    this._drafts = new Map(); // fieldId -> { pendingValue, pendingSignature }
  }

  beginEdit(fieldId, pendingValue) {
    this._drafts.set(fieldId, {
      pendingValue,
      pendingSignature: signatureOf(pendingValue),
    });
  }

  isDirty(fieldId) {
    return this._drafts.has(fieldId);
  }

  overlay(fieldId, serverValue) {
    const draft = this._drafts.get(fieldId);
    return draft ? draft.pendingValue : serverValue;
  }

  /** Clear dirty only when server echoes the same logical value. */
  confirm(fieldId, serverValue) {
    const draft = this._drafts.get(fieldId);
    if (!draft) return false;
    if (draft.pendingSignature !== signatureOf(serverValue)) return false;
    this._drafts.delete(fieldId);
    return true;
  }

  revert(fieldId) {
    this._drafts.delete(fieldId);
  }
}

function signatureOf(value) {
  if (typeof value === "boolean") return value ? "true" : "false";
  if (value !== null && typeof value === "object") return JSON.stringify(value);
  return String(value);
}
```

## Field ids

- Central enum / frozen map of known ids (`camera.iso`, `capture.geometry.crop`, …)
- Reject unknown ids in `beginEdit` / `overlay` so typos fail fast
- One id per independently editable control (or coherent draft object)

## Merge on poll (do this, not per-panel flags)

```javascript
function applyServerSnapshot(store, snapshot, bind) {
  bind.iso.value = store.overlay("camera.iso", snapshot.camera.iso);
  bind.crop = store.overlay("capture.geometry.crop", snapshot.crop);
  // live metrics that are never user-edited: always take server
  bind.fps.textContent = snapshot.fps;
}
```

## Traps already hit in practice

| Trap | Fix |
|------|-----|
| `_isIsoDirty` on the panel controller | Central `DraftStore` + field id |
| Poll always assigns `input.value = server` | Gate with `overlay` / `if (!store.isDirty(id))` |
| `confirm` on HTTP 200 without checking body | Compare signature to echoed / re-fetched value |
| Dirty geometry while drag active | Keep dirty until drag ends **and** confirm/revert |
| Two stores for the same field | One store owned by the shell / dashboard |

## Checklist

- [ ] Every editable control has a stable field id
- [ ] Poll path uses `overlay` (or skips assign when dirty)
- [ ] Save path uses `confirm` with signature match
- [ ] Cancel / navigation away uses `revert` or `revertAll`
- [ ] No new `_isXxxDirty` booleans on controllers
- [ ] Unit test: poll does not clobber an in-progress edit

## Related

- Lean polls: `ops-api-payload-minimization`
- JS structure: `solid-javascript`
