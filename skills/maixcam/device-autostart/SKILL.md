---
name: maixcam-device-autostart
description: >-
  MaixCam boot autostart via /etc/init.d S99 script: example init shell, fsync+chmod
  when writing from Python, enable only after a healthy deploy. Use when starting
  the app on power-up.
---

# MaixCam application autostart

## Goals

- Start the app on boot without manual SSH each power cycle
- Enable only after a known-good deploy (avoid boot loops)

## Pattern

1. Deploy app files to the device app root (e.g. `/root/app`)
2. Install `/etc/init.d/S99<your_app>` (executable)
3. Optionally expose enable/disable via HTTP once the app is up
4. Reboot to verify; keep a disable path (delete script or API)

## Example init script (`/etc/init.d/S99my_maix_app`)

Adapt paths/names; keep LF line endings on the device:

```sh
#!/bin/sh
# Managed by application deploy tooling

APP_DIR="/root/app"
ENTRY="$APP_DIR/main.py"
LOG="$APP_DIR/logs/autostart.log"
DELAY=2

case "$1" in
  start)
    [ -d "$APP_DIR/logs" ] || mkdir -p "$APP_DIR/logs"
    if pgrep -f "$ENTRY" >/dev/null 2>&1; then
      exit 0
    fi
    (sleep "$DELAY"; cd "$APP_DIR" && nohup python3 "$ENTRY" >> "$LOG" 2>&1 &)
    ;;
  stop)
    pkill -f "$ENTRY" >/dev/null 2>&1 || true
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac

exit 0
```

```sh
chmod 755 /etc/init.d/S99my_maix_app
# BusyBox/sysv: S99* runs late in boot; reboot to validate
```

## Writing the script from Python on-device

MaixCam builds have been unreliable with `Path.chmod` alone. Prefer:

```python
with path.open("w", encoding="utf-8", newline="\n") as script_file:
    script_file.write(content)
    script_file.flush()
    os.fsync(script_file.fileno())
os.chmod(path, 0o755)
```

See also `maixcam-sd-card-io` for durable writes on SD.

## Checklist

- [ ] Log file path exists and is writable
- [ ] Disable = delete script or API off-switch before iterating broken builds
- [ ] `cd` + `python3` match interactive run scripts (`PYTHONPATH`, cwd)
- [ ] Marker comment so tooling can detect “managed” vs legacy scripts

## Related

- SSH/IP: `maixcam-device-ssh-ip`
- ACM recovery: `maixcam-device-acm-usb`
- SD durability: `maixcam-sd-card-io`
