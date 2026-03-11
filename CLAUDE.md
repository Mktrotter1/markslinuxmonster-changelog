# markslinuxmonster-changelog

System changelog and maintenance hub for Mark's Linux desktop (`markslinuxmonster`).

## Machine Profile

| Property | Value |
|----------|-------|
| Hostname | markslinuxmonster |
| OS | Arch Linux (rolling) |
| Kernel | 6.19.6-arch1-1 |
| Desktop | KDE Plasma 6.6.2 / KWayland |
| CPU | AMD (see `lscpu`) |
| RAM | 32 GB DDR |
| Storage | 465 GB NVMe (btrfs, subvols: @, @home, @pkg, @log) |
| Boot | UEFI, systemd-boot, ESP on /dev/nvme0n1p1 (vfat) |
| GPU | AMD (DRM, card1) |
| Bluetooth | Realtek RTL8851BU USB |
| Docker | Installed, enabled |
| WireGuard | wg0 interface active |
| Swap | 16 GB zram |

## Key Services

| Service | Type | Notes |
|---------|------|-------|
| `odoo-sync-sheets-all.timer` | Timer (15min) | Syncs 7 Google Sheets to Odoo 19 |
| `odoo-nabis-order-sync.timer` | Timer (hourly) | Nabis order sync |
| `wg-quick@wg0.service` | Startup | WireGuard VPN |
| `docker.service` | Startup | Container runtime |
| `bluetooth.service` | Startup | BlueZ 5.86 |
| `NetworkManager.service` | Startup | Network management |

## Important Paths

- Projects: `/home/mark/repos/`
- Odoo scripts: `/home/mark/repos/Mktrotter1/odoo-api-pushing/`
- Claude skills: `/home/mark/repos/Mktrotter1/claude-skills/`
- Coredump config: `/etc/systemd/coredump.conf.d/limits.conf`
- Boot ESP: `/boot` (vfat, fmask=0077)

## Known Issues (Persistent)

- **BlueZ hci0 log noise**: `Failed to set default system config for hci0` — cosmetic, RTL8851BU doesn't support MGMT Set System Config. No fix needed.
- **drkonqi 6.6.2 regression**: Crash-loops on HTML notifications via `QTextDocumentFragment::fromHtml`. Socket masked at user level until upstream fix. Check on each Plasma update: `systemctl --user unmask drkonqi-coredump-pickup.socket`
- **Odoo Blend Rates Sync**: Fails because script writes `active` field to `x_blend_target` model which lacks it. Needs script or model fix in odoo-api-pushing.

## Conventions

- Changelog entries go in `CHANGELOG.md` with ISO 8601 timestamps
- One entry per session, grouped by severity
- Always note what triggered the issue, what was done, and what needs follow-up
