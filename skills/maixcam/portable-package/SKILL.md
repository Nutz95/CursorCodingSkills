---
name: maixcam-portable-package
description: >-
  MaixCam deltas on top of ops-portable-python-package: force HAL=sim for host
  ZIPs, exclude NPU/device artefacts, keep modular JS (not OTA bundles) in the
  portable tree, pin host Python. Agnostic of any single product branding.
---

# MaixCam portable package (deltas)

## Base skill first

Follow **`ops-portable-python-package`** for whitelist, wheelhouse, offline venv,
launcher, and exclusions. This skill only adds **MaixCam / host-tool** deltas.

## MaixCam-specific deltas

1. **Force host backend** — portable ZIP targets PC; configure `HAL=sim` (or equivalent) so MaixPy is not required at runtime
2. **Exclude device artefacts** — device NPU blobs, camera firmware, SD layout mirrors, ACM gadget scripts (those belong on the device image, not the host ZIP)
3. **JS assets** — portable host trees usually keep **modular** static JS for debuggability; **minified bundles** belong to device/OTA packaging (`ops-web-asset-bundle-etag`)
4. **Pin host Python minor** — match wheels used by the sim extras you ship
5. **Optional extras** — decode / onnx / vision as separate requirement files if they bloat the default wheelhouse (`maixcam-host-simulator`)

## Keep out of this skill (and out of CCS)

Product-org specifics stay in the **application repo** (L1), for example:

- Internal wheel build menus / vendor export tools
- Multiple machine “modes” or branded launcher names
- Company OTA channel layout

This skill must stay reusable across MaixCam projects without naming one product.

## Checklist

- [ ] Builds on `ops-portable-python-package` checklist
- [ ] Runs without MaixPy installed
- [ ] No device-only NPU / firmware payloads in the ZIP
- [ ] README states `HAL=sim` and Python minor
- [ ] Cross-link: `maixcam-host-simulator`

## Related

- Generic portable: `ops-portable-python-package`
- Simulator architecture: `maixcam-host-simulator`
- Device bundles: `ops-web-asset-bundle-etag`
