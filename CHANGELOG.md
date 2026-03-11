# markslinuxmonster Changelog

## 2026-03-11T14:22:00Z — System Health Audit & Remediation

**Trigger**: Slow Claude Code startup after fresh boot. Deep dive requested.

### Root Cause: DrKonqi Crash Loop (14 hours)

KDE's crash handler (`drkonqi-coredump-launcher` 6.6.2-1) entered a SIGSEGV crash loop from 00:00 to 14:15 UTC. The crash occurred in `QTextDocumentFragment::fromHtml()` via `libKF6Notifications.so.6` — when DrKonqi tried to display a notification about a crash, the HTML in the notification triggered another segfault, creating a recursive crash loop.

- **Original trigger**: Chromium crash (signal TRAP) on Mar 9 at 19:31
- **Impact**: 2,525 coredumps generated, 2.1 GB of coredump storage consumed, 2,900 files in `/var/lib/systemd/coredump/`
- **Introduced by**: KDE Plasma 6.6.1 → 6.6.2 upgrade on Mar 9

### Fixes Applied

#### HIGH — DrKonqi crash loop
- [x] Deleted 2,899 drkonqi coredump files, reclaimed 2.1 GB → 4.7 MB remaining
- [x] Masked `drkonqi-coredump-pickup.socket` at user level to prevent recurrence
- [x] Added coredump storage limits: `/etc/systemd/coredump.conf.d/limits.conf` (MaxUse=1G, KeepFree=2G, ExternalSizeMax=512M)

#### MEDIUM — kwin_wayland display config failures
- [x] Root cause: `mark` user was not in `video` group. DRM device `card1` is `root:video`. When displays disconnected (sleep/wake), atomic modeset tests failed with "Permission denied"
- [x] Added `mark` to `video` group. Takes effect on next login session.

#### LOW — Duplicate dbus Notifications service
- [x] Orphan file `/usr/share/dbus-1/services/org.freedesktop.Notifications.service` (no package owner) was duplicate of `org.kde.plasma.Notifications.service`. Removed.

#### LOW — /boot permissions (security)
- [x] ESP partition (`/boot`, vfat) was world-readable (fmask=0022). Updated fstab to fmask=0077, dmask=0077. systemd mount unit regenerated. Takes effect on next boot (vfat can't change masks on live remount).

#### LOW — Bluetooth hci0 config error
- [x] Investigated: Known BlueZ 5.86 + Realtek RTL8851BU issue. Adapter fully functional despite log error. No action needed — upstream cosmetic issue.

### Discovered (Not Fixed This Session)

- **Odoo Blend Rates Sync**: Fails every 15min. Script writes `active` field to `x_blend_target` Odoo model, but the model doesn't have that field. 6/7 syncs pass, 1 fails. Needs fix in `/home/mark/repos/Mktrotter1/odoo-api-pushing/`.

### Post-Fix State

| Metric | Before | After |
|--------|--------|-------|
| Coredump storage | 2.1 GB | 4.7 MB |
| Coredumps this boot | 2,525 (prev boot) | 0 |
| Failed systemd units | Multiple | 1 (Odoo blend rates — pre-existing) |
| Disk free (/) | 388 GB | 390 GB |
| Load average | 0.72 (boot) | 0.15 |

### Follow-up Items

- [ ] Unmask drkonqi socket after next Plasma update (check if 6.6.3+ fixes the HTML notification crash)
- [ ] Fix Blend Rates sync script — remove or conditionally write `active` field for `x_blend_target`
- [ ] Verify `/boot` permissions are 700 after next reboot
- [ ] Verify kwin display reconnection works after next sleep/wake cycle (video group fix)
