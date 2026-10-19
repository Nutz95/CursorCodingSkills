---
name: maixcam-mjpeg-preview-stream
description: >-
  MaixCam MJPEG preview: use maix.http.JpegStreamer on device (HW-backed stream),
  SimJpegStreamer on host, write frames without baked overlays, client draws bboxes,
  latest-frame buffer, FPS-paced clients. Use when tuning preview bandwidth.
---

# MaixCam MJPEG preview stream

## Goals

- Live preview on a slow USB/Wi‑Fi link without re-encoding per client
- **Overlays / bboxes drawn in the browser**, not burned into the JPEG
- Same HAL contract on device and PC simulator

## Device: use `maix.http.JpegStreamer` (not a home-grown encoder)

On MaixCam, the preview server should be the **MaixPy `JpegStreamer`** obtained
only through the HAL boundary (e.g. factory injected from `hal/maix`):

```text
composition root
  └── jpeg_stream_factory → maix.http.JpegStreamer(...)
domain preview loop
  └── stream.write(image_buffer)   # push latest frame into the streamer
browser
  └── <img src="http://<cam>:8000/stream">  (multipart MJPEG)
```

Why this matters:

- `JpegStreamer` is the supported streaming path on Maix; it uses the platform’s
  JPEG pipeline (hardware-assisted encode/stream as provided by MaixPy — **do not
  reimplement multipart + software JPEG on device** “for control”)
- Because **bboxes / ROI guides are client-side**, you feed a clean (or lightly
  cropped) buffer into `write()` — you are **not** forced to software-draw overlays
  before encode, which is the expensive path

Domain loop sketch:

```python
# Pseudocode — inject stream from HalBundle; never import maix in domain
while running and preview_tab_active:
    frame = capture_or_frame_source.read()
    streamable = ensure_format_accepted_by_streamer(frame)  # HAL may require contiguous RGB
    stream.write(streamable)   # JpegStreamer on device / SimJpegStreamer on host
    sleep_to_match_camera_fps()
```

## Host simulator: software stand-in

On PC (`HAL=sim`), use a **SimJpegStreamer** that mimics the same HTTP contract
(`/stream`, multipart) but encodes with host libraries (PIL/OpenCV). That is
expected — there is no Maix HW encoder on Windows.

## Client

- Prefer `<img src="…/stream">` or a paced MJPEG reader
- Draw crop rectangles / detection boxes in canvas/DOM from JSON telemetry
- Do **not** put fat JSON inside the JPEG path (`ops-api-payload-minimization`)

## Checklist

- [ ] Device path uses `maix.http.JpegStreamer` via HAL factory
- [ ] Overlays are client-side; stream frames stay “clean”
- [ ] One latest-frame write loop; slow clients do not stall capture
- [ ] Sim streamer only on host; never deploy sim encoder to SD
- [ ] Frame-source bypass documented in `maixcam-host-simulator`

## Related

- HAL / sim: `maixcam-host-simulator`
- Lean polls: `ops-api-payload-minimization`
- SD wear: `maixcam-sd-card-io`
