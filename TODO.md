# TODO -- markslinuxmonster Changelog

## High Priority

_(none currently)_

## In Progress

_(none currently tracked)_

## Completed (2026-03-25)

- [x] **Unmask drkonqi — 6.6.3-1 fixed the crash loop**: Unmasked and re-enabled 2026-03-25. Pickup is now a service (not socket) in 6.6.3. Ratelimit drop-in retained as safety net.
- [x] **Rebuild github-watcher venv**: Python 3.14 upgrade wiped venv. Rebuilt 2026-03-25. Both github-watcher.service and github-auto-pull.service restored.
- [x] **Fix coredump ratelimit.conf**: Moved `StartLimitBurst`/`StartLimitIntervalSec` from `[Service]` to `[Unit]`. Eliminated systemd warning at boot.
- [x] **Fix ESP dirty bit**: Ran `fsck.fat -a /dev/nvme0n1p1` to clear dirty bit from unclean unmount. Boot sector backup diff (offset 65) is cosmetic.
- [x] **Package updates (6 packages)**: Chromium 164, Firefox 149, kernel 6.19.9, Node.js 25.8.2, systemd 260.1, Beekeeper Studio 5.6.3.
- [x] **Add check-updates-notify to CHANGELOG.md**: Documented in CHANGELOG 2026-03-25.

## Backlog

- [ ] **Consolidate Mktrotter1 repos (24 → 8 typed repos)**: Paused while mobile-dev build is being redesigned. Plan: mobile-dev absorbs mobile-cli-desktop-worker + myfireremote; create automation, reference, personal, archive typed repos; odoo-api-pushing, hands_off_my_stuff, claude-skills stay solo. Full plan in `mobile-dev` memory (`project_repo_consolidation.md`).
- [ ] **Monitor Slack crash frequency**: 7 SIGTRAP crashes across Mar 23–25 (~2-3/day). Electron renderer crashes, not system-level. Mar 23 burst also cascaded to xdg-desktop-portal-kde (4x SIGABRT) and ksecretd (1x SIGABRT).
- [ ] **Monitor Chromium renderer crash frequency**: Baseline is ~1 crash per 2 days (SIGILL/SIGTRAP, renderer-only). Escalate if rate increases. Current: Chromium 146.0.7680.164
- [ ] **Monitor tmux SIGSEGV**: Single segfault 2026-03-25 03:22 in tmux 3.6a server while creating claude session. Stack trace in tmux's own code. Watch for recurrence.
- [ ] **Reduce boot time**: `NetworkManager-wait-online.service` adds 7.7s to critical chain. Total 56s (improved from 1m24s after 2026-03-25 updates). k3s-agent now 5.5s. Investigate whether NM-wait-online can be deferred
- [ ] **Bambu Studio bus_lock trap spam**: `bambustu_main` (Flatpak 2.5.0.66) triggers `x86/split lock detection: #DB` kernel warnings every ~30s. Still present on kernel 6.19.9. Upstream issue -- no fix available
- [ ] **rtw89_8851be "MAC has already powered on"**: Not seen in dmesg since kernel 6.19.9 reboot (2026-03-25). Monitoring — may be resolved upstream. WiFi unused (wlan0 down)
- [ ] **BlueZ hci0 config error**: Still present on kernel 6.19.9 (confirmed in journal). Cosmetic — adapter works fine. Upstream BlueZ issue
