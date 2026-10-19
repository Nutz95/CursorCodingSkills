---
name: maixcam-host-simulator
description: >-
  MaixCam PC host simulator: HAL sim vs maix, ONNX Runtime as local NPU stand-in,
  frame-source switching (sensor/pattern/webcam/user stills), SimJpegStreamer.
  Use when adding or extending a MaixCam simulator on Windows/Linux hosts.
---

# MaixCam host simulator

## Goals

- Run the **same domain code** on a PC without MaixPy / device NPU
- Swap backends only at the composition root
- Never invent undocumented MaixPy APIs

## Architecture

```text
domain / app services  →  Protocol ports only
composition root
  ├── HAL=sim  → hal/sim/*   (OpenCV/PIL, ONNX Runtime CPU, SimJpegStreamer, …)
  └── HAL=maix → hal/maix/*  (MaixPy camera, device NPU, JpegStreamer, …)
```

| Port idea | `sim` adapter | `maix` adapter |
|-----------|---------------|----------------|
| Camera / frames | Webcam, pattern, still library, remote MJPEG | Sensor + ISP |
| Preview out | `SimJpegStreamer` (software JPEG) | `maix.http.JpegStreamer` |
| NN / “NPU” | **ONNX Runtime CPU** (see below) | Device NPU / Maix NN |
| GPIO | In-memory pin map | Maix GPIO |

## Local NN stand-in (Windows/Linux): ONNX Runtime

Device NPU models are **not** run as-is on the host. Pattern:

1. Export or keep a **`.onnx`** sibling of the device model under e.g. `models/simulator/…`
2. Load with `onnxruntime.InferenceSession(..., providers=["CPUExecutionProvider"])`
3. Implement the same **NN port** the domain already uses (`forward(tensors) → outputs`)
4. Optional extras (decode, onnx) as a separate requirements set so the default sim stays light

```python
# Narrative example — put this in hal/sim/nn/, not in domain
import onnxruntime

def load_cpu_session(onnx_path: Path):
    return onnxruntime.InferenceSession(
        str(onnx_path),
        providers=["CPUExecutionProvider"],
    )

def forward(session, feed: dict[str, object]):
    return session.run(None, feed)
```

Pin the host Python minor to the wheelhouse ABI (`ops-portable-python-package`).

## Frame sources — switch without rewriting capture

Keep `ImageCapture.read()` stable; put a **router** behind it:

```text
ImageCapture.read
  └── FrameSourceRouter
        ├── mode=nominal → NominalCaptureRegistry
        │     kinds: sensor | pattern | webcam | … (announce via UI capabilities)
        └── mode=user    → indexed still library (0.png, 01_slot.jpg, …)
```

Operator UX (typical):

| Mode | Use |
|------|-----|
| Nominal / sensor | Live camera (device) or pattern/webcam (sim) |
| User still library | Bypass optics; step `<>` through indexed images for decode/regression |
| Webcam (sim) | Host camera at exact configured resolution |

Rules:

- Domain never imports OpenCV webcam details — only the sim nominal adapter does
- Indexed names: leading digits + optional suffix + image ext; sort numerically
- Product-specific trigger semantics stay in the **product** repo, not this skill

## Preview

See `maixcam-mjpeg-preview-stream`: device = `JpegStreamer`, host = `SimJpegStreamer`.

## Checklist

- [ ] Ports are Protocols; only adapters import MaixPy / onnxruntime / cv2
- [ ] `HAL=sim` selected explicitly at bootstrap
- [ ] ONNX models live under a simulator models tree, not on the device SD image
- [ ] Frame-source kinds are capability-driven (UI shows what the HAL supports)
- [ ] Simulator **not** packaged onto the camera SD

## Related

- Preview: `maixcam-mjpeg-preview-stream`
- Portable ZIP: `ops-portable-python-package` + `maixcam-portable-package`
- DI: `solid-python`
