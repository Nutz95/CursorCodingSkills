---
name: maixcam-device-ssh-ip
description: >-
  MaixCam SSH and USB IP bring-up: ed25519 keys, USB NCM/RNDIS IP autodetection
  examples, known_hosts refresh after reflash/ACM reboot. Use when connecting over
  USB networking or fixing host key verification failed.
---

# MaixCam SSH + USB IP

## Goals

- First-time SSH without guessing a single hard-coded IP
- Key-based auth after bootstrap
- Recover after reflash / ACM reboot when host keys change

## Typical flow

1. USB gadget in **device** mode (NCM or RNDIS) — host gets a virtual NIC
2. Generate or reuse workstation **ed25519** key (`ssh-keygen -t ed25519`)
3. **Autodetect** candidate camera IPs (snippet below)
4. First login may need password + askpass; install `authorized_keys` on the device
5. On “REMOTE HOST IDENTIFICATION HAS CHANGED”: remove stale `known_hosts` lines and retry

## IP autodetection (Windows PowerShell example)

Reuse this pattern instead of inventing a new scanner each project:

```powershell
# 1) Find host adapters that look like USB NCM / RNDIS
$adapters = Get-NetAdapter | Where-Object {
  $_.Status -eq 'Up' -and
  $_.InterfaceDescription -match '(?i)UsbNcm|Remote\s+NDIS|RNDIS'
}

$candidates = [System.Collections.Generic.List[string]]::new()
foreach ($adapter in $adapters) {
  $hostIps = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '*.255' } |
    Select-Object -ExpandProperty IPAddress

  # Neighbors on that NIC (camera often appears here)
  $neighbors = Get-NetNeighbor -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.State -in @('Reachable','Stale','Delay','Probe','Permanent') } |
    Select-Object -ExpandProperty IPAddress

  foreach ($ip in @($neighbors + $hostIps)) {
    if ($ip -and -not $candidates.Contains($ip)) { [void]$candidates.Add($ip) }
  }

  # Heuristic: same /24 as host, try .1 .. .5 (gadget cameras often use .1/.2/.3)
  foreach ($hostIp in $hostIps) {
    $parts = $hostIp.Split('.')
    if ($parts.Count -ne 4) { continue }
    $prefix = "{0}.{1}.{2}" -f $parts[0], $parts[1], $parts[2]
    foreach ($last in 1..5) {
      $guess = "$prefix.$last"
      if ($guess -ne $hostIp -and -not $candidates.Contains($guess)) {
        [void]$candidates.Add($guess)
      }
    }
  }
}

# 2) Project-documented fallbacks (fill with YOUR gadget docs — not product names)
$fallbacks = @('192.168.x.y')  # replace with IPs from your board/USB profile docs
foreach ($ip in $fallbacks) {
  if ($ip -and -not $candidates.Contains($ip)) { [void]$candidates.Add($ip) }
}

$candidates | ConvertTo-Json -Compress
```

Then probe with `ssh -o ConnectTimeout=2 root@<candidate> true` (or `Test-NetConnection`).

## known_hosts refresh

```powershell
ssh-keygen -R <camera-ip>
# or remove the offending line, then:
ssh -o StrictHostKeyChecking=accept-new root@<camera-ip>
```

## Checklist

- [ ] ed25519 key; private key never committed
- [ ] Autodetect + documented fallbacks (no single hard-coded IP in shared scripts)
- [ ] known_hosts scrub path for post-reflash / post-ACM
- [ ] If several USB IP maps exist in one org, keep them in **project** config — not in this skill

## Related

- ACM: `maixcam-device-acm-usb`
- Autostart: `maixcam-device-autostart`
