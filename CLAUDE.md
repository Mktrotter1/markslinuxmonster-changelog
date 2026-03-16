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
| Bluetooth | Realtek USB (VID:PID 0bda:b850, firmware rtl_bt/rtl8851bu_fw.bin) — USB 1-7, btusb+btrtl drivers |
| WiFi | Realtek RTL8851BE PCIe 802.11ax (08:00.0) — rtw89_8851be driver, interface wlan0 (down) |
| Network | Realtek RTL8125 2.5GbE (enp7s0), WireGuard (wg0) |
| GPU Driver | NVIDIA Open 590.48.01 (nvidia-open-dkms) |

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
| BlueZ | 5.86-4 |
| NVIDIA Driver | 590.48.01 (open-dkms) |
| CUDA | 13.1.1 |
| Ollama | 0.17.7 (ollama-cuda, systemd service, enabled) |
| Docker | 29.3.0 |
| Node.js | 25.7.0 |
| npm | 11.11.0 |
| Python | 3.14.3 |
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
/dev/zram0      [swap]                 zram    15.5 GB (zstd compression)
```

Compression: zstd:3, SSD optimizations: discard=async, space_cache=v2.

### Network

| Interface | Address | Notes |
|-----------|---------|-------|
| enp7s0 | 192.168.1.158/24 | Primary LAN |
| wg0 | 10.0.0.1/24 | WireGuard VPN mesh |
| tailscale0 | 100.120.20.39/32 | CEO's tailnet (`philip.a.greene@`) — DO NOT TOUCH |
| tailscale1 | 100.70.191.17/32 | Mark's personal tailnet (`markntrotter@`) — passive (no DNS, no netfilter) |
| docker0 | 172.17.0.1/16 | Docker bridge |
| wlan0 | down | WiFi adapter present but unused |

## Key Services

| Service | Type | Schedule | Notes |
|---------|------|----------|-------|
| `odoo-sync-sheets-all.timer` | Timer | Every 15 min | Syncs 7 Google Sheets to Odoo 19 Enterprise |
| `odoo-sync-appsheet-sheet.timer` | Timer | Every 15 min | Odoo AppSheet Product Sheet Sync |
| `odoo-sync-supervisor.timer` | Timer | Every 15 min | Odoo Cutting Plan Sync — Supervisor |
| `odoo-nabis-order-sync.timer` | Timer | Every 60 min | Nabis order sync to Odoo |
| `odoo-sync-admin.timer` | Timer | Daily 5AM | Odoo Cutting Plan Sync — Admin |
| `tailscaled.service` | Startup | Boot | CEO's Tailscale (`philip.a.greene@`, tailscale0, port 41641) — DO NOT MODIFY |
| `tailscaled-personal.service` | Startup | Boot | Mark's Tailscale (`markntrotter@`, tailscale1, port 41643). Must `up` with `--accept-dns=false --netfilter-mode=off` |
| `ollama.service` | Startup | Boot | Ollama LLM server (CUDA-accelerated) |
| `wg-quick@wg0.service` | Startup | Boot | WireGuard VPN |
| `docker.service` | Startup | Boot | Container runtime, depends on network-online |
| `bluetooth.service` | Startup | Boot | BlueZ 5.86-4 |
| `NetworkManager.service` | Startup | Boot | Network management, ~1s startup |
| `NetworkManager-wait-online.service` | Startup | Boot | Blocks boot for ~7.8s (critical chain bottleneck) |
| `claude-dir-rotate.timer` | Timer (user) | Daily | Rotates ~/.claude/ session/debug/telemetry files (7-day TTL, 500 MB cap) |
| `github-auto-pull.timer` | Timer (user) | Daily | Auto-pulls GitHub repos |

### Boot Timing

```
To graphical.target: ~36s (firmware 15.8s + loader 3.5s + kernel 4.9s + userspace 11.4s)
systemd-analyze total: ~1m24s (inflated by post-graphical Odoo sync timers firing at boot)
Critical chain bottleneck: NetworkManager-wait-online.service (7.8s)
Top blame: odoo-sync-sheets-all.service 44s, odoo-nabis-order-sync 8.8s, NM-wait-online 7.8s
```

## Important Paths

| Path | Purpose |
|------|---------|
| `/home/mark/repos/` | All project repos |
| `/home/mark/repos/Mktrotter1/odoo-api-pushing/` | Odoo sync scripts (sheets, orders) |
| `/home/mark/repos/Mktrotter1/claude-skills/` | Claude Code skills repo |
| `/var/lib/systemd/coredump/` | Coredump storage (capped at 1 GB) |
| `~/.config/systemd/user/drkonqi-coredump-pickup.socket` | Masked (symlink to /dev/null) — boot-time crash pickup |
| `~/.config/systemd/user/drkonqi-coredump-launcher.socket` | Masked (symlink to /dev/null) — real-time crash handler activation |
| `~/.config/systemd/user/drkonqi-coredump-launcher.socket.d/ratelimit.conf` | Ratelimit drop-in (inert while socket masked): TriggerLimitBurst=5, TriggerLimitIntervalSec=30s |
| `scripts/claude-dir-rotate.sh` | ~/.claude/ rotation script (7-day TTL, 500 MB cap) |
| `/etc/systemd/coredump.conf.d/limits.conf` | Coredump limits: MaxUse=1G, KeepFree=2G, ExternalSizeMax=512M, ProcessSizeMax=256M |

## Known Issues (Persistent)

### Cosmetic / Won't Fix

- **BlueZ hci0 log noise**: `Failed to set default system config for hci0` every boot. Realtek BT USB adapter's btrtl driver doesn't support the MGMT Set System Configuration command. Adapter works fine. Upstream BlueZ issue.
- **rtw89_8851be "MAC has already powered on"**: Kernel error at boot from WiFi PCIe driver. Cosmetic — interface works if brought up. WiFi currently unused (wlan0 down).

### Fully Disabled — Awaiting Upstream Fix

- **drkonqi 6.6.1+ crash loop regression**: `drkonqi-coredump-launcher` segfaults in `QTextDocumentFragment::fromHtml()` via `libKF6Notifications.so.6` when processing crash notification HTML. Creates recursive crash loop. Regression started with drkonqi 6.6.1-1 (installed 2026-03-02, crashes began by 2026-03-05). Both activation paths are now masked:
  - **Boot-time pickup**: `drkonqi-coredump-pickup.socket` — masked since 2026-03-11
  - **Real-time launcher**: `drkonqi-coredump-launcher.socket` — masked since 2026-03-13 (was ratelimited 2026-03-12 to 2026-03-13)
  - Crash diagnostics remain fully available via `coredumpctl` and `journalctl`. Only the KDE crash GUI dialog is disabled.
  - **Check on each Plasma update**: `pacman -Qi drkonqi` — if version > 6.6.2-1, unmask both sockets and monitor:
    ```
    systemctl --user unmask drkonqi-coredump-pickup.socket drkonqi-coredump-launcher.socket
    systemctl --user start drkonqi-coredump-launcher.socket
    ```

### Application-Level

- **KWallet disabled** (2026-03-16): kwalletd6 enters zombie state — responds to `isEnabled` but hangs on all wallet access (`wallets`, `isOpen`, `open`). Portal registration fails (`App info not found for 'org.kde.kwalletd'`). Disabled via `~/.config/kwalletrc` (`Enabled=false`). Chromium uses `--password-store=basic` via `~/.config/chromium-flags.conf`. Old wallet backed up to `~/.local/share/kwalletd/backup-20260316/`. Re-enable after Plasma update and test via KDE Wallet Manager GUI with PAM auto-unlock.
- **Bambu Studio bus_lock trap spam**: `bambustu_main` (Flatpak com.bambulab.BambuStudio 2.5.0.66) triggers `x86/split lock detection: #DB` kernel warnings every ~30 seconds while running. ~10 traps per burst, `handle_bus_lock` suppression messages in between. Cosmetic performance warning — split-lock operations are slow but functional. Upstream Bambu Studio issue.
- **Chromium renderer crashes**: Renderer subprocesses occasionally crash (SIGILL/SIGTRAP). Coredumps are truncated at 53+ MB. Not a regression — has been occurring across boots. Monitor frequency.

## User Groups

`mark : mark wheel uucp video docker openrazer`

Note: `video` group added 2026-03-11 for DRM device access (fixes kwin atomic modeset permission errors on display sleep/wake).

## Conventions

- Changelog entries go in `CHANGELOG.md` with ISO 8601 timestamps
- One entry per session, grouped by severity
- Always note: trigger, root cause, exact fix applied, what needs follow-up
- Include relevant commands, file paths, and package versions
