# markslinuxmonster-changelog

System changelog and maintenance hub for Mark's Linux desktop (`markslinuxmonster`).
Launch Claude Code from this directory for full machine context when doing system maintenance.

## Machine Profile

### Hardware

| Component | Details |
|-----------|---------|
| Motherboard | Gigabyte X870 GAMING WIFI6 (UEFI firmware F8, dated 2025-07-16) |
| CPU | AMD Ryzen 7 9700X 8-Core / 16-Thread, base/boost up to 5582 MHz |
| RAM | 32 GB DDR5 @ 4800 MT/s — 2x 16 GB G.SKILL F5-6000J3038F16G (slots 2 & 4) |
| GPU | NVIDIA GeForce RTX 5060 (GB206, rev a1) — PCIe slot 01:00.0 |
| Storage | WD Blue SN580 500 GB NVMe (S/N: 234317805732, FW: 281010WD) |
| Bluetooth | Realtek RTL8851BU USB dongle (USB 1-7) |
| Network | Onboard Ethernet (enp7s0), WiFi (wlan0, currently down), WireGuard (wg0) |

### Display Setup

Dual-monitor, side-by-side, combined 5120x1440 @ 96 DPI:

| Output | Connection | Resolution | Refresh | Position | Role |
|--------|------------|------------|---------|----------|------|
| HDMI-A-1 | HDMI | 2560x1440 | 144 Hz | 0,0 (left) | Primary |
| DP-1 | DisplayPort | 2560x1440 | 59.95 Hz | 2560,0 (right) | Secondary |

### Software Stack

| Component | Version |
|-----------|---------|
| OS | Arch Linux (rolling release) |
| Kernel | 6.19.6-arch1-1 (x86_64, PREEMPT_DYNAMIC) |
| Desktop | KDE Plasma 6.6.2 / KWin Wayland (DRM backend) |
| Display Server | Wayland (kwin_wayland) with XWayland |
| systemd | 259.3 |
| BlueZ | 5.86 |
| Docker | 29.3.0 |
| Node.js | 25.7.0 |
| npm | 11.11.0 |
| Python | 3.14 |
| Go | 1.26.1 |
| Rust | 1.94.0 |
| Claude Code | 2.1.47 |

### Filesystem Layout

```
/dev/nvme0n1p1  /boot                  vfat    1 GB ESP (fmask=0077)
/dev/nvme0n1p2  /                      btrfs   465 GB, subvol=/@
/dev/nvme0n1p2  /home                  btrfs   subvol=/@home
/dev/nvme0n1p2  /var/cache/pacman/pkg  btrfs   subvol=/@pkg
/dev/nvme0n1p2  /var/log               btrfs   subvol=/@log
/dev/zram0      [swap]                 zram    16 GB
```

Compression: zstd:3, SSD optimizations: discard=async, space_cache=v2.

### Network

| Interface | Address | Notes |
|-----------|---------|-------|
| enp7s0 | 192.168.1.158/24 | Primary LAN |
| wg0 | 10.0.0.1/24 | WireGuard VPN mesh |
| docker0 | 172.17.0.1/16 | Docker bridge |
| wlan0 | down | WiFi adapter present but unused |

## Key Services

| Service | Type | Schedule | Notes |
|---------|------|----------|-------|
| `odoo-sync-sheets-all.timer` | Timer | Every 15 min | Syncs 7 Google Sheets to Odoo 19 Enterprise |
| `odoo-nabis-order-sync.timer` | Timer | Every 60 min | Nabis order sync to Odoo |
| `wg-quick@wg0.service` | Startup | Boot | WireGuard VPN |
| `docker.service` | Startup | Boot | Container runtime, depends on network-online |
| `bluetooth.service` | Startup | Boot | BlueZ 5.86 |
| `NetworkManager.service` | Startup | Boot | Network management, ~1s startup |
| `NetworkManager-wait-online.service` | Startup | Boot | Blocks boot for ~7.6s (critical chain bottleneck) |
| `claude-dir-rotate.timer` | Timer | Daily | Rotates ~/.claude/ session/debug/telemetry files (7-day TTL, 500 MB cap) |

### Boot Timing

```
Total: ~39s (firmware 15.5s + loader 2.5s + kernel 9.8s + userspace 11.1s)
Critical chain bottleneck: NetworkManager-wait-online.service (7.6s)
```

## Important Paths

| Path | Purpose |
|------|---------|
| `/home/mark/repos/` | All project repos |
| `/home/mark/repos/Mktrotter1/odoo-api-pushing/` | Odoo sync scripts (sheets, orders) |
| `/home/mark/repos/Mktrotter1/claude-skills/` | Claude Code skills repo |
| `/etc/systemd/coredump.conf.d/limits.conf` | Custom coredump storage limits |
| `/var/lib/systemd/coredump/` | Coredump storage (capped at 1 GB) |
| `~/.config/systemd/user/drkonqi-coredump-pickup.socket` | Masked (symlink to /dev/null) |
| `scripts/claude-dir-rotate.sh` | ~/.claude/ rotation script (7-day TTL, 500 MB cap) |

## Known Issues (Persistent)

### Cosmetic / Won't Fix

- **BlueZ hci0 log noise**: `Failed to set default system config for hci0` every boot. RTL8851BU kernel driver doesn't support the MGMT Set System Configuration command. Adapter works fine. Upstream BlueZ issue.

### Masked / Awaiting Upstream Fix

- **drkonqi 6.6.2 crash loop regression**: `drkonqi-coredump-launcher` segfaults in `QTextDocumentFragment::fromHtml()` via `libKF6Notifications.so.6` when processing crash notification HTML. Creates recursive crash loop (crash handler crashes, spawning another crash handler). Socket masked at user level since 2026-03-11. **Check on each Plasma update**: `pacman -Qi drkonqi` — if version > 6.6.2-1, try `systemctl --user unmask drkonqi-coredump-pickup.socket` and monitor.

### Application-Level

- **Odoo Blend Rates Sync**: `scheduled_sheets_sync_all.py` writes `active` field to Odoo `x_blend_target` model which doesn't have that field. Throws `ValueError: Invalid field 'active' in 'x_blend_target'`. 6/7 syncs pass, 1 fails. Fix in `odoo-api-pushing`.

## User Groups

`mark : mark wheel uucp video docker openrazer`

Note: `video` group added 2026-03-11 for DRM device access (fixes kwin atomic modeset permission errors on display sleep/wake).

## Conventions

- Changelog entries go in `CHANGELOG.md` with ISO 8601 timestamps
- One entry per session, grouped by severity
- Always note: trigger, root cause, exact fix applied, what needs follow-up
- Include relevant commands, file paths, and package versions
