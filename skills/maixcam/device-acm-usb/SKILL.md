---
name: maixcam-device-acm-usb
description: >-
  Enable MaixCam ACM USB serial: patch S08usbdev gadget, optional getty mute,
  reboot, verify host ttyACM/COM. Includes shell examples and how runtime install
  relates. Use when bringing up serial console or fixing missing ACM after flash.
---

# MaixCam ACM USB serial

## What a skill gives you here

Enough to **reimplement** ACM enable on a MaixCam board: steps, pitfalls, and
**minimal shell examples**. Copy/adapt the snippets into your repo’s `ACM/`
(or similar) folder — this skill is not a copy of any application tree.

## Goals

- Expose USB **ACM** (CDC) next to the Ethernet gadget (NCM/RNDIS)
- Keep SSH as the primary deploy channel; ACM is for console / recovery

## Relation to “runtime install”

Typical host orchestrator (PowerShell/SSH) does, in order:

1. **Reach the camera** (SSH + IP — see `maixcam-device-ssh-ip`)
2. **Install MaixPy / app runtime** on device: copy `.whl`, `pip install`, optional
   vendor “online runtime” helper (Wi‑Fi creds via a short-lived JSON file on device,
   sensor/board profile if your product needs it)
3. **Deploy and run** the ACM shell script below, then **reboot**
4. Replug USB if the host does not show `COMx` / `/dev/ttyACM*`

Runtime install content varies by product; the agnostic checklist is: wheel +
system deps + (optional) Wi‑Fi/online vendor step + ACM patch + reboot.

## On-device: patch USB gadget for ACM

MaixCam device mode usually starts from `/etc/init.d/S08usbdev` (configfs gadget
under `/sys/kernel/config/usb_gadget/g0`). Before the line that binds UDC
(`ls /sys/class/udc/ | cat > UDC`), ensure an ACM function is linked into the config:

```sh
# Fragment to insert inside S08usbdev (device mode), before UDC bind:
# ACM (USB serial)
    mkdir -p functions/acm.usb0
    rm -rf configs/c.1/acm.usb0
    ln -s functions/acm.usb0 configs/c.1/
```

Idempotent installer example (`InitializeACM.sh` pattern):

```sh
#!/bin/sh
# Run on the MaixCam as root (after scp). Reboots at the end.

S08USBDEV="/etc/init.d/S08usbdev"
ACM_SECTION="mkdir -p functions/acm.usb0"

if ! grep -q "$ACM_SECTION" "$S08USBDEV"; then
  sed -i '/ls \/sys\/class\/udc\/ | cat > UDC/i \\# ACM (USB serial)\n    mkdir -p functions/acm.usb0\n    rm -rf configs/c.1/acm.usb0\n    ln -s functions/acm.usb0 configs/c.1/' "$S08USBDEV"
  echo "ACM section added to $S08USBDEV"
else
  echo "ACM section already present"
fi

# Optional: disable getty on ttyGS0 if it fights your serial use-case
INITTAB="/etc/inittab"
GETTY_LINE="acm::respawn:/sbin/getty -L ttyGS0 0 vt100"
if grep -q "^${GETTY_LINE}" "$INITTAB" 2>/dev/null; then
  sed -i "s|^${GETTY_LINE}|#${GETTY_LINE}|" "$INITTAB"
fi

echo "Rebooting to apply USB gadget change..."
reboot
```

Manual check on device after reboot:

```sh
ls /sys/kernel/config/usb_gadget/g0/functions
# expect acm.usb0 among gadget functions when in device mode
```

## Host verification

- Windows: new COM port after replug
- Linux: `/dev/ttyACM*`
- SSH may show **host key changed** after reboot — scrub `known_hosts` (`maixcam-device-ssh-ip`)

## Checklist

- [ ] ACM patch is idempotent
- [ ] Reboot / replug expectation documented
- [ ] Runtime (MaixPy wheel) installed before relying on app-level serial features
- [ ] Do not invent undocumented MaixPy USB APIs — use configfs / vendor init scripts

## Related

- SSH/IP: `maixcam-device-ssh-ip`
- Autostart: `maixcam-device-autostart`
