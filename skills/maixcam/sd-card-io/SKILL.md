---
name: maixcam-sd-card-io
description: >-
  Preserve MaixCam SD card life and avoid corruption: RAM read caches, avoid
  write-on-every-poll, atomic JSON replace, fsync file + parent directory, optional
  os.sync. Use when persisting config/logs on device SD or reviewing flash wear.
---

# MaixCam SD card I/O (wear + durability)

## Why a dedicated skill

USB bandwidth skills (`ops-api-payload-minimization`) reduce **network** traffic.
This skill reduces **flash wear** and **corruption risk** on the camera SD — related
but not the same problem.

## Goals

1. **Read less from SD** — cache in RAM; invalidate on write/OTA
2. **Write less often** — never persist on every 1s UI poll
3. **Write durably when you must** — atomic replace + fsync so a power cut mid-write does not leave a half JSON

## Read path: RAM cache

```text
HTTP GET config/summary
  → ConfigReadCache (mtime / signature)
       hit  → return RAM copy
       miss → read SD once → store in RAM
HTTP PUT / migrate / OTA
  → mutate SD → invalidate cache
```

Rules:

- Hot poll endpoints must not `open()` the same JSON every tick
- Pair with signature/ETag polls so fat GETs are rare (`ops-api-payload-minimization`)

## Write path: atomic + fsync

Pattern for config (and similar small JSON):

```python
# 1) Write temp file in the same directory as the target
# 2) flush + os.fsync(temp)
# 3) os.replace(temp, target)   # atomic on same filesystem
# 4) fsync parent directory (POSIX) so the rename itself is durable
# 5) optional os.sync() on embedded boards after critical config

with os.fdopen(fd, "w", encoding="utf-8") as output_file:
    json.dump(payload, output_file, indent=2)
    output_file.flush()
    os.fsync(output_file.fileno())
os.replace(temp_path, target_path)
# parent dir fsync — best-effort on Linux/MaixCam
dir_fd = os.open(parent_dir, os.O_DIRECTORY)
try:
    os.fsync(dir_fd)
finally:
    os.close(dir_fd)
```

Also useful when installing init scripts (`maixcam-device-autostart`): `flush` + `fsync` + `chmod`.

## What not to put on the hot path

| Bad | Better |
|-----|--------|
| Rewrite full config every poll | Dirty flag / explicit Save |
| Append log line per preview frame | Ring buffer in RAM; flush periodically or on error |
| Rescan whole SD tree every second | Keep counters/index in RAM; refresh on signature change |

## Checklist

- [ ] Config/read cache exists and is invalidated on write
- [ ] No SD write on the 1s summary poll
- [ ] Persisted JSON uses temp + `replace` + `fsync`
- [ ] Power-cut test: kill mid-write leaves previous good file or new good file — not truncated garbage
- [ ] Logs/datasets have size/rotation policy (SD fills kill devices too)

## Related

- API poll minimization: `ops-api-payload-minimization`
- Autostart script durability: `maixcam-device-autostart`
- Bundled static assets (less SD thrash on HTTP): `ops-web-asset-bundle-etag`
