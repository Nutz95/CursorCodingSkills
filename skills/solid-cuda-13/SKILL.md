---
name: solid-cuda-13
description: >-
  SOLID CUDA 13 / GPU pipeline guardrails for Python+CUDA apps (e.g. NVDEC):
  concrete typing at boundaries, small modules, explicit device/resource
  lifetimes, no silent Any leakage. Use when editing CUDA 13, PyNvCodec,
  GPU decode/inference code.
---

# SOLID CUDA 13

## Hard limits

- Max **400 lines** per source file when practical
- Max **30 methods** per class
- Keep decoder / pipeline / telemetry modules separate

## Typing & boundaries

- Prefer concrete types over `Any` at public boundaries
- Wrap vendor SDK objects behind narrow adapters
- Name GPU resources clearly (`surface`, `decoder`, `stream`)
- Document device ownership and reset/reopen behavior

## Reliability

- Treat stream reconnect / decoder reset as first-class paths
- Fail with explicit errors; do not swallow CUDA init failures
- Keep CPU orchestration thin; heavy work stays on device code paths

## Checklist

- [ ] No new `Any` at API boundaries without a typed wrapper plan
- [ ] Resource lifetime (create/reset/close) is obvious
- [ ] File/module stays focused on one GPU concern
