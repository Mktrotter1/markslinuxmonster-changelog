# TODO -- markslinuxmonster Changelog

## High Priority

_(none currently tracked)_

## In Progress

_(none currently tracked)_

## Completed (2026-04-09)

- [x] **Propagate hard-earned rules to project CLAUDE.md files** — Audited 62 feedback memories across 18 project directories. Propagated missing rules to 4 CLAUDE.md files: `odoo-api-pushing` (11 hard assertions + 3 working style rules: read-before-write, believe-and-fix, verify-in-Odoo), `3d-model-projects` (8 hard assertions: no pkill, preserve originals, mesh surgery), `mobile-dev` (4 rules: full-stack check, ttyd debugging), `odoo-implementation` (3 rules: transformation framing, no credentials, no silent exceptions). Phone sessions now have all critical behavioral rules via CLAUDE.md.

- [x] **System update (241 packages)**: Kernel 6.19.9→6.19.11, NVIDIA 590.48→595.58, Plasma 6.6.3→6.6.4, Qt6→6.11.0, Docker 29.3→29.4, Go 1.26.1→1.26.2, Rust 1.94.0→1.94.1, Node 25.8→25.9, and 230+ more. Reboot pending.
- [x] **Cache cleanup (~2.1 GB)**: Cleared paru build cache (1.2 GB), pip cache (594 MB), Go build cache (325 MB).
- [x] **Disabled Docker**: No images/containers/volumes in use. Service and socket disabled. Re-enable on demand.
- [x] **NVIDIA suspend/hibernate services auto-removed**: Driver 595.58.03 removed nvidia-suspend/hibernate/resume (not needed with open kernel modules).

## Completed (2026-03-25)

- [x] **Unmask drkonqi — 6.6.3-1 fixed the crash loop**: Unmasked and re-enabled 2026-03-25. Pickup is now a service (not socket) in 6.6.3. Ratelimit drop-in retained as safety net.
- [x] **Rebuild github-watcher venv**: Python 3.14 upgrade wiped venv. Rebuilt 2026-03-25. Both github-watcher.service and github-auto-pull.service restored.
- [x] **Fix coredump ratelimit.conf**: Moved `StartLimitBurst`/`StartLimitIntervalSec` from `[Service]` to `[Unit]`. Eliminated systemd warning at boot.
- [x] **Fix ESP dirty bit**: Ran `fsck.fat -a /dev/nvme0n1p1` to clear dirty bit from unclean unmount. Boot sector backup diff (offset 65) is cosmetic.
- [x] **Package updates (6 packages)**: Chromium 164, Firefox 149, kernel 6.19.9, Node.js 25.8.2, systemd 260.1, Beekeeper Studio 5.6.3.
- [x] **Add check-updates-notify to CHANGELOG.md**: Documented in CHANGELOG 2026-03-25.

## Backlog

- [ ] **Build Claude CLI chat interface** — Interactive terminal chat using Anthropic SDK with streaming responses, prompt_toolkit (readline history, autocomplete), rich (markdown rendering), Click command groups (`/history`, `/clear`, `/model`), Ctrl+C handling, .env config. Follows existing Click + tabulate + dotenv patterns from sleepdata-shell and marksclock. ~2-3 hour build. Target repo TBD.
- [ ] **Investigate update: chromium 146.0.7680.177 → 147.0.7727.55** (2026-04-13): Review scope and effect before applying. [Changelog](https://chromereleases.googleblog.com/)
- [ ] **Merge mirrorlist.pacnew**: `/etc/pacman.d/mirrorlist.pacnew` created by pacman-mirrorlist 20260406-1. Merge when convenient.
- [ ] **Re-test KWallet after Plasma 6.6.4**: KWallet disabled since 2026-03-16. Plasma 6.6.4 landed — test via KDE Wallet Manager GUI with PAM auto-unlock.
- [ ] **AUR updates pending**: android-sdk-build-tools, beekeeper-studio-bin, mycli, qbz-bin — run `yay -Sua` when ready.
- [ ] **Consolidate Mktrotter1 repos (24 → 8 typed repos)**: Paused while mobile-dev build is being redesigned. Plan: mobile-dev absorbs mobile-cli-desktop-worker + myfireremote; create automation, reference, personal, archive typed repos; odoo-api-pushing, hands_off_my_stuff, claude-skills stay solo. Full plan in `mobile-dev` memory (`project_repo_consolidation.md`).
- [ ] **Monitor Slack crash frequency**: 7 SIGTRAP crashes across Mar 23–25 (~2-3/day). Electron renderer crashes, not system-level. Mar 23 burst also cascaded to xdg-desktop-portal-kde (4x SIGABRT) and ksecretd (1x SIGABRT).
- [ ] **Monitor Chromium renderer crash frequency**: Baseline is ~1 crash per 2 days (SIGILL/SIGTRAP, renderer-only). Escalate if rate increases. Current: Chromium 146.0.7680.177
- [ ] **Monitor tmux SIGSEGV**: Single segfault 2026-03-25 03:22 in tmux 3.6a server while creating claude session. Stack trace in tmux's own code. Watch for recurrence.
- [ ] **Reduce boot time**: `NetworkManager-wait-online.service` adds 7.7s to critical chain. Total 56s (improved from 1m24s after 2026-03-25 updates). k3s-agent now 5.5s. Investigate whether NM-wait-online can be deferred
- [ ] **Bambu Studio bus_lock trap spam**: `bambustu_main` (Flatpak 2.5.0.66) triggers `x86/split lock detection: #DB` kernel warnings every ~30s. Still present on kernel 6.19.9. Upstream issue -- no fix available
- [ ] **rtw89_8851be "MAC has already powered on"**: Not seen in dmesg since kernel 6.19.9 reboot (2026-03-25). Monitoring — may be resolved upstream. WiFi unused (wlan0 down)
- [ ] **BlueZ hci0 config error**: Still present on kernel 6.19.9 (confirmed in journal). Cosmetic — adapter works fine. Upstream BlueZ issue
