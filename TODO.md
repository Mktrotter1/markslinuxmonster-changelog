# TODO -- markslinuxmonster Changelog

## High Priority

- [x] **Unmask drkonqi — 6.6.3-1 fixed the crash loop**: Unmasked and re-enabled 2026-03-25. Both services running, no crash loop. Pickup is now a service (not socket) in 6.6.3. Ratelimit drop-in retained as safety net.

## In Progress

_(none currently tracked)_

## Backlog

- [x] **Chromium 146.0.7680.153 → 164**: Applied 2026-03-25. Security patch.
- [x] **Firefox 148.0.2 → 149.0**: Applied 2026-03-25. XDG portal file picker, PDF HW accel, security fixes.
- [x] **Linux kernel 6.19.8 → 6.19.9**: Applied 2026-03-25. btrfs transaction abort fixes, NVMe race fixes, cgroup dead-task fix. Reboot required.
- [x] **Node.js 25.8.1 → 25.8.2**: Applied 2026-03-25. Security release (9 CVEs).
- [x] **systemd 260 → 260.1**: Applied 2026-03-25. Minor bugfixes.
- [x] **Beekeeper Studio 5.5.7 → 5.6.3**: Applied 2026-03-25. Entra ID, editor font sizing, fuzzy search.
- [x] **Add check-updates-notify to CHANGELOG.md**: Documented in CHANGELOG 2026-03-25

- [ ] **Consolidate Mktrotter1 repos (24 → 8 typed repos)**: Paused while mobile-dev build is being redesigned. Plan: mobile-dev absorbs mobile-cli-desktop-worker + myfireremote; create automation, reference, personal, archive typed repos; odoo-api-pushing, hands_off_my_stuff, claude-skills stay solo. Full plan in `mobile-dev` memory (`project_repo_consolidation.md`).
- [ ] **Monitor Chromium renderer crash frequency**: Baseline is ~1 crash per 2 days (SIGILL/SIGTRAP, renderer-only). Escalate if rate increases. Current: Chromium 146.0.7680.164
- [ ] **Reduce boot time**: `NetworkManager-wait-online.service` adds 7.7s to critical chain. Total 56s (improved from 1m24s after 2026-03-25 updates). k3s-agent now 5.5s. Investigate whether NM-wait-online can be deferred
- [ ] **Bambu Studio bus_lock trap spam**: `bambustu_main` (Flatpak 2.5.0.66) triggers `x86/split lock detection: #DB` kernel warnings every ~30s. Still present on kernel 6.19.9. Upstream issue -- no fix available
- [ ] **rtw89_8851be "MAC has already powered on"**: **Not seen since kernel 6.19.9 reboot (2026-03-25)**. Monitoring — may be resolved upstream. WiFi unused (wlan0 down)
- [ ] **BlueZ hci0 config error**: **Not seen since kernel 6.19.9 reboot (2026-03-25)**. Monitoring — may be resolved upstream
