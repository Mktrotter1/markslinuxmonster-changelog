# markslinuxmonster Changelog

---

## 2026-03-25T19:50:00-07:00 — System health deep dive & fixes

**Trigger**: Post-reboot crash/bug audit to assess systemic health and processor impact.

### Fixes applied

#### 1. Rebuilt github-watcher venv (was crash-looping every 60s)

`.venv/bin/python` was missing — wiped by Python 3.14 upgrade. Both `github-watcher.service` and `github-auto-pull.service` were failing with status 203/EXEC since boot (~30+ failures in journal).

```
cd /home/mark/repos/Mktrotter1/github-watcher
python -m venv .venv && .venv/bin/pip install -r requirements.txt
systemctl --user restart github-watcher.service
```

Result: Both services restored and running.

#### 2. Fixed coredump ratelimit.conf

`/etc/systemd/system/systemd-coredump@.service.d/ratelimit.conf` had `StartLimitBurst` and `StartLimitIntervalSec` in `[Service]` (wrong) — moved to `[Unit]`. Eliminates systemd warning at boot.

#### 3. Fixed ESP dirty bit

`/dev/nvme0n1p1` (FAT32 ESP) had dirty bit set from unclean unmount. Installed `dosfstools` and ran `fsck.fat -a`. Dirty bit cleared. Boot sector backup diff at offset 65 is cosmetic (not auto-fixed).

#### 4. Corrected BlueZ hci0 status in docs

Initial dmesg grep missed it, but journal confirmed `Failed to set default system config for hci0` is still present on 6.19.9. Updated CLAUDE.md accordingly.

### Crash audit summary

| Binary | Signal | Count | Window | Notes |
|--------|--------|-------|--------|-------|
| Slack (Flatpak) | SIGTRAP | 7 | Mar 23–25 | Electron renderer crashes, ~2-3/day. Mar 23 burst cascaded to portal-kde + ksecretd |
| xdg-desktop-portal-kde | SIGABRT | 4 | Mar 23 | D-Bus cascade from Slack crash |
| ksecretd | SIGABRT | 1 | Mar 23 | Part of same cascade |
| tmux 3.6a | SIGSEGV | 1 | Mar 25 | Server segfault creating claude session. Stack in tmux code, not library |

### Hardware health

All clear: CPU 42°C, GPU 43°C/17W, NVMe 38°C, zero MCE/Xid errors, 20 GiB RAM free, 370 GiB disk free.

---

## 2026-03-25T19:25:00-07:00 — drkonqi 6.6.3-1 unmasked — crash loop fixed

**Trigger**: drkonqi updated to 6.6.3-1 with Plasma 6.6.3, which is past the > 6.6.2-1 threshold for re-testing.

**Root cause (original)**: drkonqi 6.6.1-1 segfaulted in `QTextDocumentFragment::fromHtml()` via `libKF6Notifications.so.6` when rendering crash notification HTML, causing a recursive crash loop.

**Fix applied**:
```
systemctl --user unmask drkonqi-coredump-pickup.socket drkonqi-coredump-launcher.socket
systemctl --user start drkonqi-coredump-launcher.socket
systemctl --user enable --now drkonqi-coredump-pickup.service
```

**Changes in 6.6.3**:
- `drkonqi-coredump-pickup.socket` replaced by `drkonqi-coredump-pickup.service` (runs under `plasma-core.target`)
- Launcher socket unchanged, still uses ratelimit drop-in (5 launches/30s)

**Result**: Both services active, zero crash loop recurrence after 90s monitoring. No new coredumps. KDE crash dialog GUI restored.

**Follow-up**: Monitor over next few days. If crash loop recurs, re-mask: `systemctl --user mask drkonqi-coredump-launcher.socket`

---

## 2026-03-25T19:20:00-07:00 — Post-reboot verification & documentation update

Rebooted into kernel 6.19.9. Verified system health and updated all documentation.

### Version changes detected (beyond today's packages)

| Component | From | To | Notes |
|-----------|------|----|-------|
| KDE Plasma / KWin | 6.6.2 | 6.6.3 | Plasma update pulled in with packages |
| drkonqi | 6.6.2-1 | 6.6.3-1 | **Now > 6.6.2-1 — ready to unmask sockets and test** |
| Claude Code | 2.1.47 | 2.1.83 | Updated independently |
| npm | 11.11.0 | 11.12.0 | Updated with Node.js |
| systemd | 259.3 | 260.1 | Was already applied, CLAUDE.md was stale |

### Removed from system (no longer installed)

| Component | Was | Notes |
|-----------|-----|-------|
| ollama-cuda | 0.17.7 | Package removed, service inactive |
| CUDA | 13.1.1 | Package removed |

### New services

| Service | Notes |
|---------|-------|
| `k3s-agent.service` | K3s Kubernetes agent, 5.5s in boot blame |

### Boot timing (kernel 6.19.9)

```
firmware 15.5s + loader 1.1s + kernel 9.8s + userspace 16.8s = ~43s to graphical.target
systemd-analyze total: ~56s (was ~1m24s)
Top blame: odoo-sync-sheets-all 18.2s, NM-wait-online 7.7s, k3s-agent 5.5s
```

### Known issues — status after reboot

| Issue | Status |
|-------|--------|
| NVIDIA Xid 62/154 | No errors — nvidia-persistenced active |
| BlueZ hci0 "Failed to set default system config" | **Not seen** — monitoring, may be fixed in 6.19.9 |
| rtw89 "MAC has already powered on" | **Not seen** — monitoring, may be fixed in 6.19.9 |
| Bambu Studio bus_lock trap spam | Still present (confirmed in dmesg) |
| drkonqi crash loop | Still masked — **6.6.3-1 ready to test unmask** |

### Documentation updated

- CLAUDE.md: Software stack versions, removed Ollama/CUDA, added k3s-agent and check-updates-notify services, updated boot timing, updated known issues status
- TODO.md: Updated drkonqi to actionable, updated BlueZ/rtw89 status, updated boot timing numbers

---

## 2026-03-25T18:00:00-07:00 — Package updates (6 packages, 1 AUR)

Applied reviewed updates via `pacman -Syu` and `paru`.

| Package | From | To | Category |
|---------|------|----|----------|
| linux | 6.19.8.arch1-1 | 6.19.9.arch1-1 | Kernel — btrfs transaction abort fixes, NVMe race/OOB fixes, cgroup dead-task visibility fix. **Reboot required.** |
| nodejs | 25.8.1-1 | 25.8.2-1 | Security — 9 CVEs (2 high: TLS SNICallback crash, HTTP header prototype pollution) |
| chromium | 146.0.7680.153-1 | 146.0.7680.164-1 | Security patch roll |
| firefox | 148.0.2-1 | 149.0-1 | Feature + security — XDG portal file picker default on Linux, PDF HW acceleration, split view, built-in VPN |
| systemd | 260-1 | 260.1-1 | Bugfix — minor (SYSTEMD_COLORS regression, vconsole-setup, test fixes) |
| beekeeper-studio-bin | 5.5.7-1 | 5.6.3-1 | Feature — Entra ID auth, editor font sizing, fuzzy command palette, pacman dep fix (AUR) |

### Notable for this system

- **btrfs**: 7 fixes including transaction abort on file creation (hash collision DoS), snapshot overflow, set-received ioctl overflow. Directly relevant — root filesystem is btrfs.
- **NVMe**: Race in `nvme_poll_irqdisable()` and slab-out-of-bounds in `nvme_dbbuf_set`. Affects WD Blue SN580.
- **cgroup**: Dead tasks no longer visible in `cgroup.procs` — fixes incorrect systemd service state.
- **Firefox XDG portal**: File picker now routes through `xdg-desktop-portal-kde` on Plasma Wayland — native KDE dialogs instead of GTK3.
- **Node.js 9 CVEs**: Includes timing-unsafe HMAC comparison and HTTP/2 flow control crash. Relevant for Odoo sync services.

### Follow-up

- Reboot required for kernel 6.19.9 — verify NVIDIA DKMS module built successfully before rebooting
- Monitor Chromium renderer crash rate after update (baseline: ~1/2 days)

---

## 2026-03-25T00:00:00-07:00 — New: check-updates-notify user timer

Added a weekly update-check notification system via user systemd timer.

| Component | Details |
|-----------|---------|
| Script | `~/.local/bin/check-updates-notify` |
| Service | `~/.config/systemd/user/check-updates-notify.service` (oneshot) |
| Timer | `~/.config/systemd/user/check-updates-notify.timer` (Mon 10:00, persistent, ±30min jitter) |
| Log | `~/.local/share/check-updates-notify/check.log` |

Checks pacman and AUR for available updates, sends desktop notifications with clickable changelog links. Enabled and active.

---

## 2026-03-24T15:00:00-07:00 — System Health Fixes (btrfs balance, coredump cleanup, scrub timer)

**Trigger**: Post-purge health audit revealed fragmented btrfs allocation, coredump accumulation, stale pacman artifacts, orphan packages, and no scheduled btrfs scrub.

### Fixes applied

#### 1. Btrfs balance — reclaimed 41 GB of allocated-but-empty block groups

After the 46 GB disk purge, btrfs still had 128 GB allocated for data with only 83 GB used (65% utilization). Ran `btrfs balance start -dusage=75 /` to compact.

| | Before | After |
|---|---|---|
| Data allocated | 128.01 GiB | 87.01 GiB |
| Data utilization | 64.79% | 94.85% |
| Device unallocated | 330.74 GiB | 371.74 GiB |

#### 2. Coredump cleanup — 362 MB → 2.6 MB

Removed recurring crash dumps from known issues (not useful for debugging):

| Source | Dumps removed | Size freed | Known issue |
|--------|--------------|------------|-------------|
| Slack (Flatpak 4.46.99) | 7 | ~53 MB | Electron/Chromium SIGTRAP in Flatpak sandbox |
| xdg-desktop-portal-kde | 8 | ~8 MB | QMessageLogger fatal — KWallet dependency (kwallet 6.24.0-1) |
| ksecretd | 1 | ~600 KB | Same KWallet crash chain |
| Bambu Studio | 2 | ~132 MB | Known split-lock / crash issue |
| Chromium renderer | 2 | ~66 MB | Recurring SIGILL/SIGTRAP in renderer subprocess |
| Cpp2IL | 1 | ~3 MB | One-off from sleepdata-shell RE session |
| React Native Debugger | 2 | ~330 KB | One-off from mobile-dev |

Kept: Xorg core (2 MB, Xid 62 GPU lockup evidence) and tmux core (579 KB, one-off).

#### 3. Stale pacman download directories removed

10 empty `download-*` temp dirs in `/var/cache/pacman/pkg/` from interrupted `pacman -Syu` runs (oldest from 2026-03-02). Removed with `rm -rf`.

#### 4. Orphan packages removed

```
sudo pacman -Rns python-build python-installer python-setuptools-scm
```

Also pulled in `python-pyproject-hooks` as a dependency. Total: 4 packages, 1.15 MiB. These were leftover build dependencies with no reverse deps.

#### 5. Monthly btrfs scrub timer enabled

```
sudo systemctl enable --now btrfs-scrub@-.timer
```

Created symlink `/etc/systemd/system/timers.target.wants/btrfs-scrub@-.timer`. Scrub will run monthly on the root filesystem to detect silent bitrot. Previous scrub had run once with no errors but was not scheduled.

### Health status post-fixes

| Check | Status |
|-------|--------|
| NVMe SMART | 0% wear, 0 errors, 40°C, 100% spare |
| Btrfs device errors | All zeros |
| Btrfs scrub | Clean (no errors), now scheduled monthly |
| Btrfs allocation | 95% data utilization (was 65%) |
| Failed systemd units | 0 system, 0 user |
| Memory | 18 GB available / 30 GB, swap untouched |
| Coredumps | 2.6 MB (was 362 MB) |
| Disk | 87 GB used / 465 GB (19%) |

### Monitored (no action needed)

- **Odoo appsheet sync**: Intermittent failures at 10:00 and 12:45 today, succeeded at 14:45. Transient.
- **Slack Flatpak crashes**: ~every 2-6 hours. Upstream Electron issue. Coredumps will re-accumulate — consider periodic `rm /var/lib/systemd/coredump/core.slack.*`.
- **k3s-agent**: Running and enabled — confirmed intentional.
- **dbus Notifications duplicate**: Cosmetic log noise from duplicate service file, no impact.

---

## 2026-03-24T00:00:00-07:00 — Disk Bloat Purge (~46 GB reclaimed from Mktrotter1)

**Trigger**: Routine disk bloat audit. `/home/mark/repos/Mktrotter1/` was 48 GB; the actual source code across all repos totaled only ~2.4 GB.

**Disk state before**: 111 GB used / 465 GB total (24%)
**Disk state after**: 87 GB used / 465 GB total (19%)

### What was removed

#### Pokemon Sleep data — 23.1 GB (no longer needed, skills already captured in claude-skills)

| Path | Size | Contents |
|------|------|----------|
| `chromium-playrite-scraper/data/scraper.db` | 11 GB | Main scraper SQLite database |
| `chromium-playrite-scraper/data/raw/` | 5.5 GB | 111 raw capture JSONL files |
| `chromium-playrite-scraper/data/scraper_remote_autosync.db` (+shm/wal) | 1.4 GB | Sync copy of scraper DB |
| `chromium-playrite-scraper/logs/` | 329 MB | Scraper logs + exploration screenshots |
| `sleepdata-shell/data/` | 3.3 GB | Raw traffic captures, sleepdata.db, Frida captures |
| `sleepdata-shell/tools/apk/` | 1.6 GB | Decompiled APKs, patched APKs, native libs |

#### Build artifacts — 13.9 GB (regenerable)

| Path | Size | Regenerate with |
|------|------|-----------------|
| `hands_off_my_stuff/client/target/` | 6.5 GB | `cargo build` |
| `mobile-dev/android/app/build/` | 4.4 GB | Android Gradle build |
| `myfireremote/app/build/` | 3.0 GB | Flutter build |

#### node_modules — 6.9 GB (regenerable)

| Path | Size | Regenerate with |
|------|------|-----------------|
| `mobile-dev/node_modules/` | 6.6 GB | `npm install` |
| `marks-music-solutions/web/node_modules/` | 147 MB | `npm install` |
| `hands_off_my_stuff/dashboard/node_modules/` | 113 MB | `npm install` |
| `hands_off_my_stuff/e2e/node_modules/` | 14 MB | `npm install` |

#### Python .venvs — 2.3 GB (regenerable from requirements.txt)

| Repo | Size |
|------|------|
| `chromium-playrite-scraper` | 779 MB |
| `bee-swarm-macro` | 492 MB |
| `odoo-api-pushing` | 390 MB |
| `home-assistant-device-setups` | 186 MB |
| `github-watcher` | 169 MB |
| `sleepdata-shell` | 164 MB |
| `git-demo` | 149 MB |
| `periodically-periodic-table` | 17 MB |

#### Misc artifacts — 36 MB

| Path | Size |
|------|------|
| `odoo-api-pushing/screenshots/` | 18 MB (28 files) |
| `odoo-api-pushing/debug_screenshots/` | 16 MB (44 files) |
| `odoo-api-pushing/__pycache__/` | 2.1 MB |

### What was NOT touched

- All source code, configs, CLAUDE.md files, tests, docs
- Git history (all repos intact)
- Lock files (package-lock.json, Cargo.lock, requirements.txt)
- The `.git/` directories themselves

### Follow-up

- When resuming work on any cleaned repo, run the appropriate dependency install command
- All Pokemon Sleep data directories are gitignored — no git status impact
- Build artifacts are gitignored — no git status impact

---

## 2026-03-20T14:35:00Z — Fix NVIDIA RTX 5060 GPU Lockups (Xid 62/154)

**Trigger**: System becomes unresponsive every ~24h, requiring hard reboot. User initially attributed to "deep sleep" but sleep was already fully disabled.

**Root cause**: NVIDIA RTX 5060 (GB206, Blackwell) with driver 590.48.01 suffers Xid 62 (GSP firmware RPC timeout) and Xid 154 (GPU reset required) crashes during normal operation. The GPU's GSP firmware communication hangs, the RC watchdog detects a locked GPU, and nvidia-modeset can no longer configure the dual-monitor setup — resulting in a frozen/black display.

**Crash chain from boot -1 (2026-03-19 → 2026-03-20)**:

| Time | Event |
|------|-------|
| 10:16:01 | `Xid 62` — GSP firmware RPC failure (`_kgspRpcRecvPoll` Call Trace) |
| 10:16:01 | `Xid 154` — GPU recovery action changed to "GPU Reset Required" |
| 13:48–13:50 | `RC watchdog: GPU is probably locked!` repeating every 8s |
| 13:50:13 | `nvidia-modeset: ERROR: display configuration not supported on this GPU` |
| 13:50:31 | User forced reboot (SDDM stopped, system shutdown) |

**Contributing factors**:

| Factor | State Before | Problem |
|--------|-------------|---------|
| NVIDIA Persistence Mode | Disabled | GPU enters aggressive idle power states, triggering GSP firmware instability |
| nvidia-suspend/hibernate services | Disabled | GPU power state transitions not properly managed |
| PreserveVideoMemoryAllocations | Not set | No modprobe.d config existed for NVIDIA |

**Fixes applied**:

1. **Created `/etc/modprobe.d/nvidia.conf`**:
   ```
   options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
   ```

2. **Enabled NVIDIA power management services**:
   ```bash
   sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate
   ```

3. **Enabled NVIDIA persistence daemon**:
   ```bash
   sudo systemctl enable --now nvidia-persistenced
   ```
   Persistence Mode now active — keeps the GPU driver loaded and in a stable managed state, preventing idle power state transitions that trigger Xid 62.

**Note**: Sleep remains fully disabled per user preference (`/etc/systemd/sleep.conf.d/10-s2idle.conf` unchanged — `AllowSuspend=no`).

**Verification after next 24h+ uptime**:

| Check | Expected |
|-------|----------|
| `nvidia-smi -q \| grep Persistence` | `Persistence Mode: Enabled` |
| `journalctl -b -k \| grep "Xid"` | No Xid 62/154 errors |
| `journalctl -b -k \| grep "GPU is probably locked"` | No RC watchdog warnings |
| System uptime > 24h without freeze | No forced reboots needed |

### Files Created/Modified

| File | Change |
|------|--------|
| `/etc/modprobe.d/nvidia.conf` | **Created** — VRAM preservation + temp file path |
| `nvidia-suspend.service` | **Enabled** (was disabled) |
| `nvidia-resume.service` | Already enabled (unchanged) |
| `nvidia-hibernate.service` | **Enabled** (was disabled) |
| `nvidia-persistenced.service` | **Enabled + started** (was disabled) |

### Follow-up

- [ ] **Monitor for 48h** — if Xid 62 recurs with persistence enabled, escalate: file NVIDIA bug for RTX 5060 Xid 62 on Linux 6.19 / driver 590.48
- [ ] **After next kernel or nvidia-open-dkms update**: verify `/etc/modprobe.d/nvidia.conf` still applies (`cat /sys/module/nvidia/parameters/NVreg_PreserveVideoMemoryAllocations` should return `1`)

---

## 2026-03-17T15:07:00Z — Weekly Maintenance Automation & System Hardening Exercise

**Trigger**: Learning exercise to understand Arch Linux internals (pacman, systemd, security basics).

**Changes applied**:

### 1. Automated Weekly Maintenance (systemd timer)

Created a systemd service + timer that runs every Sunday at 3 AM:

- Refreshes pacman mirrors via `reflector` (if installed)
- Cleans package cache, keeping last 2 versions (`paccache -rk2`) — first run freed **684 MB**
- Checks for failed systemd units
- Detects unmerged `.pacnew`/`.pacsave` config files
- Logs disk usage on `/`, `/home`, `/boot`

| File | Purpose |
|------|---------|
| `/usr/local/bin/arch-maintain.sh` | Maintenance script |
| `/etc/systemd/system/arch-maintain.service` | Oneshot service unit |
| `/etc/systemd/system/arch-maintain.timer` | Weekly timer (Sun 03:00, Persistent=true) |
| `/var/log/arch-maintain.log` | Output log |

### 2. Installed `pacman-contrib`

Required for `paccache` (cache cleanup) and `checkupdates` (pending update count). Was not previously installed — caused initial `exit 127` failures on the service until installed.

### 3. System Report Alias

Added `sysreport` alias to `~/.bashrc` — one-command system health overview showing kernel, uptime, package counts, pending updates, orphans, failed units, pacnew files, and disk usage.

### Packages Installed

| Package | Reason |
|---------|--------|
| `pacman-contrib` | Provides `paccache`, `checkupdates`, and other pacman utilities |

### Files Modified

| File | Change |
|------|--------|
| `/usr/local/bin/arch-maintain.sh` | Created — maintenance script |
| `/etc/systemd/system/arch-maintain.service` | Created — systemd oneshot unit |
| `/etc/systemd/system/arch-maintain.timer` | Created — weekly timer |
| `~/.bashrc` | Added `sysreport` alias |

---

## 2026-03-16T20:15:00Z — Fix Deep Sleep (S3) Causing Unrecoverable Hang

**Trigger**: Computer falls into deep sleep (S3) and cannot wake — requires hard power cycle. Previous fix (`/etc/systemd/sleep.conf.d/10-s2idle.conf` with `MemorySleepMode=s2idle`) was insufficient.

**Root cause**: The systemd sleep drop-in only controls what systemd requests from the kernel, but the kernel's own default was still `deep` (S3). Confirmed by `cat /sys/power/mem_sleep` showing `s2idle [deep]` — brackets indicate the kernel-selected mode. On AMD X870 + NVIDIA RTX 5060, S3 deep sleep is unreliable — the GPU fails to reinitialize on wake, causing a black screen / hard hang.

**Why the original fix didn't work**: `MemorySleepMode=s2idle` in `sleep.conf.d` tells systemd to write `s2idle` to `/sys/power/mem_sleep` at suspend time. But the kernel parameter `mem_sleep_default` controls the **default** selection, and without it the ACPI tables on this AMD board select `deep`. If anything triggers suspend outside of systemd (e.g., ACPI lid/button event, KDE power management), the kernel's own default (`deep`) is used instead of s2idle.

**Fix applied**: Added `mem_sleep_default=s2idle` to the kernel command line in the systemd-boot loader entry:

```
# /boot/loader/entries/2026-02-19_21-34-48_linux.conf
options root=PARTUUID=... zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs pcie_aspm=off mem_sleep_default=s2idle
```

**Bonus fix**: AMD microcode (`amd-ucode.img`) was present on disk but **not loaded** — the initrd line was missing it. Added as the first initrd:

```
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
```

**Verification required after reboot**:

| Check | Expected |
|-------|----------|
| `cat /sys/power/mem_sleep` | `[s2idle] deep` (s2idle in brackets = selected) |
| `cat /proc/cmdline` | Contains `mem_sleep_default=s2idle` |
| `dmesg \| grep -i microcode` | Shows AMD microcode loaded |
| Suspend/wake cycle | System wakes normally from sleep |

### Files Modified

| File | Change |
|------|--------|
| `/boot/loader/entries/2026-02-19_21-34-48_linux.conf` | Added `mem_sleep_default=s2idle` to options, added `initrd /amd-ucode.img` |
| `/etc/systemd/sleep.conf.d/10-s2idle.conf` | Unchanged (still valid as defense-in-depth) |

---

## 2026-03-16T20:00:00Z — Personal Tailscale Instance Removed

**Trigger**: Personal Tailscale instance (`markntrotter@`, `tailscaled-personal.service`) did not work reliably despite the dual-instance coexistence fixes applied earlier this session.

**Decision**: Stop, disable, and remove the personal Tailscale instance entirely.

**Actions performed**:

1. **Stopped** the service: `sudo systemctl stop tailscaled-personal.service`
2. **Disabled** the service: `sudo systemctl disable tailscaled-personal.service`
3. **Removed** the service unit and state:
   - `/etc/systemd/system/tailscaled-personal.service` — removed
   - `/var/lib/tailscale-personal/` — state directory removed
   - `sudo systemctl daemon-reload`

**Result**: Only the CEO's Tailscale instance (`philip.a.greene@`, `tailscaled.service`, `tailscale0`) remains. No personal tailnet on this machine.

**Network interfaces after removal**:

| Interface | Address | Notes |
|-----------|---------|-------|
| tailscale0 | 100.120.20.39/32 | CEO's tailnet — unchanged |
| tailscale1 | — | **Removed** (was Mark's personal) |

### Files Modified

| File | Change |
|------|--------|
| `/etc/systemd/system/tailscaled-personal.service` | **Removed** |
| `/var/lib/tailscale-personal/` | **Removed** (state directory) |

---

## 2026-03-16T19:35:00Z — Dual Tailscale: Fix Personal Instance Coexistence with CEO's Tailnet

**Trigger**: Enabling Mark's personal Tailscale instance killed all internet connectivity. Two Tailscale instances fighting over DNS (`/etc/resolv.conf`), iptables/netfilter rules, and routing policy tables.

**Context**: Machine runs two tailnets — CEO's (`philip.a.greene@`, `tailscaled.service`) which cannot be modified, and Mark's personal (`markntrotter@`, `tailscaled-personal.service`). A third instance (`tailscaled-mark.service`) also existed but was redundant.

---

### Issue 1: Personal Tailscale Breaks Internet [HIGH → FIXED]

**Status**: FIXED

**Symptom**: Activating the personal Tailscale instance caused total loss of internet connectivity. DNS resolution failed, routing broke.

**Root cause (three problems)**:

| Problem | Detail |
|---------|--------|
| **DNS hijack** | Both instances defaulted to `--accept-dns=true`, fighting over `/etc/resolv.conf`. Whichever wrote last pointed all DNS to its own MagicDNS (`100.100.100.100`), which may not forward non-tailnet queries properly. |
| **Netfilter stomping** | Both instances defaulted to `--netfilter-mode=on`, each installing their own iptables/nftables chains and policy routing rules (table 52, fwmark rules 5210-5270). On restart, one would blow away the other's rules. |
| **Port collision** | `tailscaled-personal.service` and the now-removed `tailscaled-mark.service` both used `--port=41642`. Only one could bind. |

**Note**: This is NOT an officially supported Tailscale configuration. Running multiple `tailscaled` instances on one host is a community workaround (GitHub issue #183). Tailscale's internal codename for proper support is "personas" — no timeline. The key insight from Tailscale docs and community guides: secondary instances **must** use `--netfilter-mode=off` (at `tailscale up` time) and `--accept-dns=false` to avoid stomping the primary.

**Fixes applied**:

1. **Removed redundant `tailscaled-mark.service`**:
   ```bash
   # Service was already stopped/not-found by systemd
   sudo rm -rf /var/lib/tailscale-mark/   # state dir cleanup
   sudo systemctl daemon-reload
   ```

2. **Fixed port collision** in `/etc/systemd/system/tailscaled-personal.service`:
   ```
   # Before: --port=41642 (same as the removed mark instance, near CEO's 41641)
   # After:  --port=41643 (unique, no collision)
   ```

3. **Brought up personal instance with passive flags**:
   ```bash
   sudo tailscale --socket=/run/tailscale-personal/tailscaled.sock up \
     --accept-dns=false \
     --netfilter-mode=off
   ```
   - `--accept-dns=false` → personal instance does not touch `/etc/resolv.conf`
   - `--netfilter-mode=off` → personal instance does not touch iptables or routing tables

**Result**: Both tailnets running simultaneously, internet unaffected:

| Instance | Socket | Tun | Port | DNS | Netfilter | Status |
|----------|--------|-----|------|-----|-----------|--------|
| CEO (`philip.a.greene@`) | `/run/tailscale/tailscaled.sock` | `tailscale0` | 41641 | owns DNS | owns rules | Active |
| Personal (`markntrotter@`) | `/run/tailscale-personal/tailscaled.sock` | `tailscale1` | 41643 | passive | passive | Active |

**Post-fix verification**:

| Check | Result |
|-------|--------|
| CEO's Tailscale status | All 9 nodes visible, direct connection to meridian (18ms) |
| Personal Tailscale status | 2 nodes visible (markslinuxmonster, marks-z-fold6) |
| `/etc/resolv.conf` | Local routers (192.168.1.1, 192.168.100.1) — not MagicDNS |
| Default route | `192.168.1.1 via enp7s0` — normal ethernet |
| `ip rule list` | Unchanged from pre-fix state |

### Files Modified

| File | Change |
|------|--------|
| `/etc/systemd/system/tailscaled-personal.service` | `--port=41642` → `--port=41643` |
| `/etc/systemd/system/tailscaled-mark.service` | **Removed** (redundant instance) |
| `/var/lib/tailscale-mark/` | **Removed** (state dir for removed instance) |

### Important: Future `tailscale up` Commands

When restarting the personal instance, **always** include the passive flags:
```bash
sudo tailscale --socket=/run/tailscale-personal/tailscaled.sock up \
  --accept-dns=false \
  --netfilter-mode=off
```

Without these flags, it will revert to default behavior and break connectivity again. These are `tailscale up` flags (not daemon flags) and must be passed each time the node is brought up.

### Limitation

With `--netfilter-mode=off`, the personal instance has no automatic firewall rules. Exit node support, MSS clamping, and stateful filtering for that tailnet are not available. Direct node-to-node connectivity (via DERP or direct) still works.

---

## 2026-03-16T18:48:00Z — Chromium Hang: KWallet D-Bus Deadlock

**Trigger**: Chromium pages hanging indefinitely (infinite load spinner). All other network tools working fine.

**Boot context**: System booted 2026-03-16 17:59 UTC. No failed systemd units.

---

### Issue 1: Chromium Pages Hang / Won't Load [HIGH → FIXED]

**Status**: FIXED

**Symptom**: All Chromium page loads hung forever. Existing TCP connections stayed alive, but no new pages would load. Firefox, curl, ping, dig all worked normally.

**Diagnostic path**:

| Check | Result |
|-------|--------|
| `ping 8.8.8.8` | OK (0% loss, ~18ms) |
| `curl https://www.google.com` | OK (200, 109ms) |
| `dig google.com @100.100.100.100` | OK (1ms via Tailscale DNS) |
| `python3 socket.getaddrinfo('google.com', 80)` | OK (42ms) |
| `firefox --headless --screenshot` | OK (56KB screenshot) |
| `chromium --headless --dump-dom` | HANG (even fresh profile, no sandbox, plain HTTP) |
| `strace -f -e connect chromium --headless` | **Zero AF_INET connect() calls** — only Unix sockets |
| `chromium --enable-logging --v=1` | Log stops dead after 41 lines at ~0.4s |

**Root cause**: Chromium's OS-crypt backend initialization blocks the entire browser. The backend selection chain is:

1. **KWallet (kwalletd6)** — selected by default on KDE
2. **gnome-keyring** — fallback
3. **basic** — plaintext fallback

KWallet (PID 18643) was in a **zombie state**: it responded to trivial D-Bus queries (`isEnabled` → `true`) but hung indefinitely on any actual wallet access (`wallets`, `isOpen`, `open`, `networkWallet`). Chromium would call `open` during startup, block forever waiting for the D-Bus reply, and never proceed to create the network service or load any pages.

```
$ timeout 3 qdbus6 org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.isEnabled
true

$ timeout 5 qdbus6 org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.wallets
(timed out — exit 124)
```

Even after killing and restarting kwalletd6, it exhibited the same behavior — responded to metadata queries, hung on wallet access. The kwalletd6 startup also showed portal registration errors:

```
GLib-GIO-CRITICAL: g_dbus_proxy_get_object_path: assertion 'G_IS_DBUS_PROXY (proxy)' failed
qt.qpa.services: Failed to register with host portal QDBusError("org.freedesktop.portal.Error.Failed",
  "Could not register app ID: App info not found for 'org.kde.kwalletd'")
```

**Proof**: `chromium --password-store=basic --headless --dump-dom http://example.com` loaded instantly on every test.

With KWallet disabled, Chromium's fallback to gnome-keyring also hung (gnome-keyring not running on this KDE system), so without `--password-store=basic`, Chromium still blocked.

**Fix applied**:

1. Disabled KWallet:
   ```
   # ~/.config/kwalletrc
   [Wallet]
   Enabled=false
   First Use=false
   ```

2. Backed up and removed corrupt wallet files:
   ```
   ~/.local/share/kwalletd/backup-20260316/   ← backup of kdewallet.kwl, .salt, _attributes.json
   ~/.local/share/kwalletd/                    ← emptied
   ```

3. Created permanent Chromium flags (`~/.config/chromium-flags.conf`):
   ```
   --password-store=basic
   --disable-features=AsyncDns
   --disable-gpu-compositing
   --enable-features=VaapiVideoDecodeLinuxGL
   --ozone-platform-hint=auto
   ```

4. Killed all Chromium processes and relaunched. Pages load normally.

**Files modified**:

| File | Action |
|------|--------|
| `~/.config/kwalletrc` | Created — KWallet disabled |
| `~/.config/chromium-flags.conf` | Created — `--password-store=basic` + existing flags |
| `~/.local/share/kwalletd/kdewallet.kwl` | Backed up to `backup-20260316/`, removed |
| `~/.local/share/kwalletd/kdewallet.salt` | Backed up to `backup-20260316/`, removed |
| `~/.local/share/kwalletd/kdewallet_attributes.json` | Backed up to `backup-20260316/`, removed |

### Follow-up

- [ ] Investigate why kwalletd6 enters zombie state (portal registration failure? wallet corruption?)
- [ ] Consider re-enabling KWallet with PAM auto-unlock (`pam_kwallet5.so` already in `/etc/pam.d/sddm`) after creating a fresh wallet with login-password encryption via the KDE Wallet Manager GUI
- [ ] On next Plasma update: test if kwalletd6 portal registration is fixed

---

## 2026-03-13T18:00:00Z — drkonqi Revised Analysis, Journal Cleanup & Issue Triage

**Trigger**: Deep investigation of drkonqi crash loop revealed previous documentation was incorrect about regression version, socket architecture, and mitigation status.

**Boot context**: System booted 2026-03-13 14:09 UTC. No failed systemd units.

---

### Issue 1: drkonqi Crash Loop — Revised Understanding [HIGH → MITIGATED]

**Status**: RATELIMITED + PICKUP MASKED — WORKING CORRECTLY

Previous documentation stated the regression started with drkonqi 6.6.2-1 (installed 2026-03-09). Investigation revealed:

| Fact | Old Understanding | Validated Reality |
|------|-------------------|-------------------|
| Regression version | 6.6.2-1 (Mar 9 upgrade) | **6.6.1-1** (installed Mar 2, crashes started by Mar 5) |
| Masked socket | `drkonqi-coredump-pickup.socket` | That's the **boot-time pickup** path, not the real-time path |
| Real-time activation path | (not documented) | `drkonqi-coredump-launcher.socket` — was still active |
| Mar 12 crashes (2,511) | (not documented) | Occurred despite pickup mask — came through the **launcher** socket |
| Ratelimit drop-in | (not documented) | `ratelimit.conf` added 2026-03-12 (5 triggers/30s) by a previous session |
| Today's behavior | — | drkonqi launched twice (old crash + Chromium), **did not crash** (0 drkonqi coredumps today) |
| Total historical entries | ~2,525 | **22,420** across 8 days (Mar 5–12) |

#### drkonqi activation architecture

```
Process crashes → systemd-coredump → journal entry
                                   ↓
              drkonqi-coredump-processor@.service (SYSTEM level)
                                   ↓
              /run/user/UID/drkonqi-coredump-launcher (unix socket)
                                   ↓
              drkonqi-coredump-launcher.socket (USER level) ← ACTIVE, ratelimited
                                   ↓
              drkonqi-coredump-launcher@.service → shows notification → CRASH (sometimes)

At boot:
              drkonqi-coredump-pickup.socket (USER level) ← MASKED
                                   ↓
              drkonqi-coredump-pickup.service → processes old crashes from journal
```

#### Mitigation history

1. **Pickup socket masked** (2026-03-11): Prevents boot-time reprocessing of old crashes
2. **Launcher socket ratelimited** (2026-03-12): `TriggerLimitBurst=5, TriggerLimitIntervalSec=30s` — temporary measure
3. **Coredump storage limits** (2026-03-11): `MaxUse=1G, KeepFree=2G, ExternalSizeMax=512M, ProcessSizeMax=256M`
4. **Launcher socket masked** (2026-03-13): Both sockets now masked — drkonqi fully disabled

#### Decision: Fully disable drkonqi

The ratelimit was a mitigation, not a solution. Masking both sockets completely disables drkonqi. Crash diagnostics remain fully available via `coredumpctl` and `journalctl` — only the KDE crash GUI dialog is lost. Unmask both sockets after a future Plasma update to re-test.

#### Cleanup performed

- Purged old journal entries: `sudo journalctl --vacuum-time=3d` (removed 22K+ orphaned drkonqi coredump entries)
- Updated CLAUDE.md: corrected regression version (6.6.1, not 6.6.2), documented both sockets and ratelimit

### Issue 2: Bambu Studio Bus Lock Trap Spam [LOW / COSMETIC]

**Status**: NO ACTION — UPSTREAM ISSUE

No change from previous scan. `bambustu_main` triggers `x86/split lock detection: #DB` kernel warnings every ~30 seconds while running. `kernel.split_lock_mitigate=1` (default) correctly serializes offending operations and logs warnings. Disabling mitigation would remove the protection — not recommended. Upstream Bambu Studio code quality issue.

### Issue 3: Chromium Renderer Crashes [LOW]

**Status**: NO ACTION — MONITOR ONLY

4 crashes across Mar 5–13 (~1 per 2 days). Mix of SIGILL and SIGTRAP — both are normal V8/Chromium mechanisms (debug assertions, JIT code traps). Renderer-only (tabs reload, browser stays up). Running Chromium 145.0.7632.159 (latest Arch). This rate is normal and not a regression.

**Baseline**: ~1 renderer crash per 2 days. Escalate if frequency increases significantly.

### CLAUDE.md Updates Applied

| Field | Old Value | New Value |
|-------|-----------|-----------|
| drkonqi regression version | 6.6.2 | 6.6.1 |
| drkonqi Known Issues section | Single masked socket | Both sockets documented (pickup=masked, launcher=ratelimited) |
| Important Paths | Only pickup socket | Added launcher socket path and ratelimit.conf drop-in |
| Follow-up instructions | unmask pickup if > 6.6.2-1 | unmask pickup + remove ratelimit drop-in if > 6.6.2-1 |

### All Follow-up Items

- [ ] **Unmask drkonqi** after next Plasma update if version > 6.6.2-1: `systemctl --user unmask drkonqi-coredump-pickup.socket drkonqi-coredump-launcher.socket`
- [ ] **Monitor Chromium crash frequency** — baseline ~1/2 days; investigate if rate increases
- [ ] **Consider reducing boot time** — `NetworkManager-wait-online.service` adds 7.8s; Odoo sync timers add 44s to systemd-analyze total (but don't block desktop)

---

## 2026-03-13T15:35:00Z — Full System Scan & Validation

**Trigger**: User-requested comprehensive system scan to validate all documented claims and update repo.

**Boot context**: System booted 2026-03-13 14:09 UTC, uptime ~1.5h at scan time. No failed systemd units. 0 failed system units, 0 failed user units.

---

### Follow-up Items Resolved (from 2026-03-11 session)

| Item | Status | Evidence |
|------|--------|----------|
| /boot permissions (fmask=0077) | **CONFIRMED FIXED** | `stat -c "%a" /boot` returns `700` |
| kwin display reconnection (video group fix) | **CONFIRMED FIXED** | Zero `kwin.*failed` or `modeset.*failed` journal entries this boot |
| dbus duplicate Notifications service | **CONFIRMED FIXED** | Zero `duplicate` journal entries this boot |
| /boot security hole warning | **CONFIRMED FIXED** | Zero `world accessible` or `security hole` journal entries this boot |
| Odoo Blend Rates Sync failure | **CONFIRMED FIXED** | Last two runs show `7 OK, 0 FAILED` (was 6/7 pass, 1/7 fail). Fix was applied upstream in `odoo-api-pushing` |
| drkonqi socket masked | **STILL MASKED** | `LoadState=masked, ActiveState=inactive`. Still needed — 22,420 drkonqi coredump entries in `coredumpctl list` from previous boots. drkonqi 6.6.2-1 still installed |

### New Packages Since Last Session

| Package | Version | Installed | Notes |
|---------|---------|-----------|-------|
| ollama | 0.17.7-1 | 2026-03-12 | LLM server |
| ollama-cuda | 0.17.7-1 | 2026-03-12 | CUDA acceleration for Ollama |
| cuda | 13.1.1-1 | 2026-03-12 | NVIDIA CUDA toolkit |
| opencl-nvidia | 590.48.01-4 | 2026-03-12 | OpenCL support |
| xclip | 0.13-6 | 2026-03-11 | X clipboard CLI |
| strace | 6.19-1 | 2026-03-11 | System call tracer |

New system service: `ollama.service` (active, enabled at boot).

### New Timers Discovered (not previously documented)

| Timer | Schedule | Description |
|-------|----------|-------------|
| `odoo-sync-appsheet-sheet.timer` | Every 15 min | Odoo AppSheet Product Sheet Sync |
| `odoo-sync-supervisor.timer` | Every 15 min | Odoo Cutting Plan Sync — Supervisor |
| `odoo-sync-admin.timer` | Daily 5AM | Odoo Cutting Plan Sync — Admin |
| `github-auto-pull.timer` (user) | Daily | Auto-pulls GitHub repos |

### New Issues Discovered

#### Bambu Studio Bus Lock Trap Spam [LOW / COSMETIC]

**Status**: DOCUMENTED — UPSTREAM ISSUE

Bambu Studio (Flatpak `com.bambulab.BambuStudio 2.5.0.66`) process `bambustu_main` (PID 3497) triggers `x86/split lock detection: #DB` kernel warnings every ~30 seconds while running. Each burst contains ~10 traps at various addresses, with `handle_bus_lock: 20 callbacks suppressed` messages between bursts.

This is a performance issue in the Bambu Studio binary — split-lock operations are serialized by the CPU and slow down execution. The kernel's split-lock detection is working correctly by trapping these. Functional impact is minimal (slight slowdown in Bambu Studio).

No fix available — upstream Bambu Studio issue.

#### Chromium Renderer Crash (SIGILL) [LOW]

**Status**: DOCUMENTED — RECURRING

Chromium renderer subprocess (PID 9276) crashed with SIGILL at 14:26 UTC this boot. Coredump: 53.1 MB (truncated). This is a renderer process crash (not the main browser process), so it self-recovers by respawning the tab. Previous boots also show Chromium crashes (SIGTRAP on Mar 9, SIGILL on Mar 13). Not a new regression.

#### rtw89_8851be "MAC has already powered on" [LOW / COSMETIC]

**Status**: DOCUMENTED — UPSTREAM

Kernel error at boot: `rtw89_8851be 0000:08:00.0: MAC has already powered on`. WiFi PCIe driver (RTL8851BE) encounters stale hardware state on boot. Cosmetic — interface can be brought up if needed. WiFi currently unused (wlan0 down).

### CLAUDE.md Corrections Applied

| Field | Old Value | New Value | Reason |
|-------|-----------|-----------|--------|
| Bluetooth | `Realtek RTL8851BU USB dongle` | `Realtek USB (VID:PID 0bda:b850, firmware rtl_bt/rtl8851bu_fw.bin)` | USB device doesn't self-identify as RTL8851BU; documented factual VID:PID and firmware path |
| WiFi | Not listed separately | `Realtek RTL8851BE PCIe 802.11ax (08:00.0)` | Was conflated with Bluetooth; they're separate devices (PCIe vs USB) |
| Network chip | `Onboard Ethernet` | `Realtek RTL8125 2.5GbE` | Added specific chip identification |
| Python | `3.14` | `3.14.3` | More precise version |
| BlueZ | `5.86` | `5.86-4` | Full package version |
| zram | `16 GB` | `15.5 GB (zstd compression)` | Actual size from `zramctl` |
| Boot timing | `~39s total` | `~36s to graphical.target, ~1m24s systemd-analyze total` | Previous values were from different boot; Odoo sync timers inflate the total |
| NM-wait-online | `7.6s` | `7.8s` | Current boot measurement |
| Odoo Blend Rates | Listed as known issue | Removed (fixed) | Now passing 7/7 syncs |
| Key Services | Missing 5 services | Added ollama, appsheet-sheet, supervisor, admin, github-auto-pull timers | Discovered during timer enumeration |
| GPU Driver | Not listed | `NVIDIA Open 590.48.01` | Added for completeness |
| CUDA/Ollama | Not listed | `CUDA 13.1.1, Ollama 0.17.7` | New packages installed Mar 12 |
| Coredump limits | `MaxUse/KeepFree/ExternalSizeMax` | Added `ProcessSizeMax=256M` | Was in config file but not documented |

### Current System State

| Metric | Value |
|--------|-------|
| Uptime | ~1.5h (booted 14:09 UTC) |
| Failed units | 0 system, 0 user |
| Disk used (/) | 86 GB (379 GB free, 19%) |
| Memory | 13 GB used / 30 GB total |
| Swap (zram) | 4 KB / 15.5 GB |
| Coredump storage | 137 MB (5 files: 1 bambu-studio, 1 chromium, 3 slack) |
| Odoo sync status | 7/7 passing (last run: 33.0s total) |
| drkonqi socket | masked (still needed — 6.6.2-1 installed) |
| /boot permissions | 700 (fixed) |
| Boot to desktop | ~36s |

### All Follow-up Items

- [ ] **Unmask drkonqi** after next Plasma update if version > 6.6.2-1
- [ ] **Monitor Chromium crash frequency** — if crashes increase, investigate SIGILL cause
- [ ] **Consider reducing boot time** — `NetworkManager-wait-online.service` adds 7.8s; Odoo sync timers add 44s to systemd-analyze total (but don't block desktop)

---

## 2026-03-11T17:24:00Z — ~/.claude/ Rotation Rule Enforcement

**Trigger**: Previous session discovered ~/.claude/ had grown to 1.9 GB (1,092 session JSONLs, 246 MB debug, 70 MB telemetry) causing 5-15 second Claude Code startup lag. Manual cleanup brought it to 7.3 MB. This session adds automated rotation to prevent recurrence.

**Root Cause**: The workspace rule "Rotate by size (10 MB) or time (7 days), never silently discard" was being applied to application logs but never to Claude Code's own ~/.claude/ directory. Session transcripts, debug logs, and telemetry accumulated indefinitely.

### What Was Created

| File | Purpose |
|------|---------|
| `scripts/claude-dir-rotate.sh` | 4-phase rotation script with `--dry-run` flag |
| `systemd/claude-dir-rotate.timer` | Daily systemd user timer (randomized 5-min delay) |
| `systemd/claude-dir-rotate.service` | Oneshot service, output to journal |
| `logs/.gitkeep` | Ensures logs dir exists in git |
| `.gitignore` | Excludes `logs/*.jsonl` from version control |

### Rotation Phases

1. **Time-based cleanup (7-day TTL)**: Session JSONLs, UUID dirs, debug `.txt`, telemetry, file-history, ephemeral dirs (todos, plans, tasks, backups, paste-cache, shell-snapshots, session-env). Empty dirs cleaned up.
2. **history.jsonl truncation**: If over 10 MB, keep last 1000 lines via atomic `tail` + `mv`.
3. **Hard cap (500 MB)**: If still over cap, delete oldest session JSONLs until under.
4. **Audit log**: JSONL entry at `logs/claude-dir-rotate.jsonl` with bytes reclaimed + final size.

### Protected (never touched)

`settings.json`, `settings.local.json`, `.credentials.json`, `CLAUDE.md` symlink, `SKILLS.md`, `DIRECTORY.md`, `CROSS_PROJECT.md`, `skills/`, `plugins/`, `cache/`, `commands/`, any `*/memory/*` path.

### Installation

```bash
chmod +x scripts/claude-dir-rotate.sh
ln -sf $(pwd)/systemd/claude-dir-rotate.service ~/.config/systemd/user/
ln -sf $(pwd)/systemd/claude-dir-rotate.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now claude-dir-rotate.timer
```

### Verification

- `--dry-run`: clean JSONL output, no deletions
- Manual run: completed, audit log written
- Timer: active (waiting), next trigger midnight UTC
- Service: `status=0/SUCCESS` via both manual and timer-triggered runs
- Journal output: clean, all 4 phases logged
- Protected files confirmed untouched

### Updated

- `CLAUDE.md`: Added `claude-dir-rotate.timer` to Key Services, `scripts/claude-dir-rotate.sh` to Important Paths

---

## 2026-03-11T14:22:00Z — System Health Audit & Remediation

**Trigger**: Claude Code was slow to start. User requested deep dive with systemic health scan and crash report review.

**Context**: System had just rebooted (~2 min uptime at session start). The previous boot had been running since 2026-03-09T19:21:39Z (nearly 43 hours). A massive 136-package upgrade was performed on Mar 9 including KDE Plasma 6.6.1 → 6.6.2, Linux kernel 6.18.13 → 6.19.6, and numerous Qt6/KDE framework updates.

---

### Issue #1: DrKonqi Crash Loop [HIGH]

**Status**: FIXED + MITIGATED

#### What Happened

KDE's crash reporter (`drkonqi-coredump-launcher`, package `drkonqi 6.6.2-1`) entered a self-perpetuating SIGSEGV crash loop that ran for **14 hours and 15 minutes** continuously, generating **2,525 coredump files** consuming **2.1 GB** of disk in `/var/lib/systemd/coredump/`.

#### Timeline

| Time (UTC) | Event |
|------------|-------|
| 2026-03-09 16:25:38 | `drkonqi` upgraded from 6.6.1-1 to 6.6.2-1 (part of 136-package system update) |
| 2026-03-09 19:21:39 | System booted into new kernel 6.19.6 + Plasma 6.6.2 |
| 2026-03-09 19:31:49 | **Chromium** (PID 1984) crashed with signal 5 (TRAP) — this was the original trigger |
| 2026-03-09 19:31:50 | systemd-coredump processed the Chromium crash, DrKonqi launched to handle it |
| 2026-03-10 00:07:38 | **Slack** (PID 1632) crashed with signal 5 (TRAP) — secondary Electron crash |
| 2026-03-10 00:08:04 | First drkonqi SIGSEGV recorded — **crash loop begins** |
| 2026-03-10 00:08:04–2026-03-11 14:15:10 | Continuous crash loop: drkonqi crashes → systemd-coredump records it → drkonqi spawns to handle it → drkonqi crashes again |
| 2026-03-11 ~14:19 | System rebooted (by user), ending the loop |
| 2026-03-11 14:22 | Claude Code session begins, discovers the aftermath |

#### Crash Rate Analysis

The crash loop ran at approximately **2-3 crashes per minute** with slight variation by hour:

| Hour (UTC) | Crashes | Rate |
|------------|---------|------|
| 00:00 | 662 | ~11/min |
| 01:00 | 798 | ~13/min |
| 02:00–13:00 | ~885/hr | ~15/min |
| 14:00 (partial) | 135 | (system rebooted at 14:19) |

Total journal entries related to drkonqi coredumps: **12,582** (includes processing, dumping, and launcher entries per crash).

#### Root Cause: Stack Trace Analysis

```
Signal: 11 (SIGSEGV)
Executable: /usr/lib/drkonqi-coredump-launcher

Stack trace of main thread (PID 207452):
#0  QVariant::QVariant(QString const&)                    libQt6Core.so.6
#1  (anonymous)                                           libQt6Gui.so.6
#2  (anonymous)                                           libQt6Gui.so.6
#3  QTextDocumentFragment::fromHtml(QString, QTextDocument*)  libQt6Gui.so.6   <-- CRASH HERE
#4  (anonymous)                                           libKF6Notifications.so.6
#5  (anonymous)                                           libKF6Notifications.so.6
#6  (anonymous)                                           libKF6Notifications.so.6
#7  (anonymous)                                           libQt6Core.so.6
#8  (anonymous)                                           libQt6DBus.so.6
#9  QObject::event(QEvent*)                               libQt6Core.so.6
#10 QCoreApplication::notifyInternal2(QObject*, QEvent*)  libQt6Core.so.6
#11 QCoreApplicationPrivate::sendPostedEvents(...)        libQt6Core.so.6
#12–#18 (event loop: glib → Qt → QCoreApplication::exec)
#19–#23 (drkonqi-coredump-launcher main + libc startup)
```

**Interpretation**: When drkonqi-coredump-launcher processes a crash, it sends a desktop notification via KDE's `KNotifications` framework. The notification content includes HTML markup. `KNotifications` calls `QTextDocumentFragment::fromHtml()` to parse this HTML, which triggers a segfault inside Qt6's HTML parser. This is a **regression in drkonqi 6.6.2-1** (or possibly in the Qt6/KF6 stack that shipped alongside it).

The crash is self-reinforcing because:
1. DrKonqi crashes (SIGSEGV) while trying to display a notification
2. systemd-coredump catches the crash and writes a coredump
3. DrKonqi's systemd socket activation spawns a new instance to handle the new crash
4. The new instance tries to display a notification about *its predecessor's crash*
5. The HTML parsing crashes again → goto 2

#### Fixes Applied

**1. Coredump cleanup** — Deleted 2,899 drkonqi coredump files:
```bash
sudo rm /var/lib/systemd/coredump/core.drkonqi-*
# Before: 2.1 GB (2,900 files) → After: 4.7 MB (1 file — original Chromium crash)
```

**2. Masked drkonqi socket** — Prevents the crash loop from restarting:
```bash
systemctl --user mask drkonqi-coredump-pickup.socket
# Created symlink ~/.config/systemd/user/drkonqi-coredump-pickup.socket → /dev/null
```

**3. Added coredump storage limits** — Prevents runaway disk consumption even if another crash loop occurs:
```bash
# Created /etc/systemd/coredump.conf.d/limits.conf
[Coredump]
MaxUse=1G        # Total coredump storage cap (was unlimited)
KeepFree=2G      # Always keep at least 2G free on the partition
ExternalSizeMax=512M  # Max size per individual coredump (was 32G)
```

#### Follow-up Required
- [ ] After each Plasma update, check drkonqi version: `pacman -Qi drkonqi`
- [ ] If version > 6.6.2-1: `systemctl --user unmask drkonqi-coredump-pickup.socket`, reboot, and monitor for crashes

---

### Issue #2: kwin_wayland Display Configuration Failures [MEDIUM]

**Status**: FIXED (takes effect next login)

#### What Happened

kwin_wayland logged "Applying output configuration failed!" multiple times during the previous boot session. This occurred when monitors went to sleep or disconnected:

```
Mar 10 16:10:33 kwin_wayland: Atomic modeset test failed! Permission denied
Mar 10 16:10:33 org_kde_powerdevil: DDCA_EVENT_DISPLAY_DISCONNECTED, card1-DP-1
Mar 10 16:10:33 kwin_wayland: Applying output configuration failed!

Mar 10 21:27:00 kwin_wayland: Atomic modeset test failed! Permission denied
Mar 10 21:27:00 org_kde_powerdevil: DDCA_EVENT_DISPLAY_DISCONNECTED, card1-DP-1
Mar 10 21:27:00 kwin_wayland: Applying output configuration failed!

Mar 10 21:53:51 kwin_wayland: Atomic modeset test failed! Permission denied
Mar 10 21:53:51 org_kde_powerdevil: DDCA_EVENT_DISPLAY_DISCONNECTED, card1-HDMI-A-1
Mar 10 21:53:51 kwin_wayland: Applying output configuration failed!
```

#### Root Cause

The DRM device `/dev/dri/card1` is owned by `root:video` with permissions `crw-rw----`. While logind provides an ACL entry (`+`) for the active session, when displays disconnect/reconnect (sleep/wake), kwin's atomic modeset tests require group-level DRM access that the ACL alone doesn't reliably provide during the transition.

```
crw-rw----+ 1 root video 226, 1 Mar 11 14:20 /dev/dri/card1
```

User `mark` was NOT in the `video` group:
```
mark : mark wheel uucp docker openrazer    # video missing!
```

#### Fix Applied

```bash
sudo usermod -aG video mark
# Verified: mark : mark wheel uucp video docker openrazer
```

This requires a logout/login or reboot to take effect (group membership is set at session creation).

#### Follow-up Required
- [ ] After next sleep/wake cycle, verify no more "Atomic modeset test failed! Permission denied" in journal

---

### Issue #3: Duplicate dbus Notifications Service File [LOW]

**Status**: FIXED

#### What Happened

Every boot, dbus-broker logged:
```
Ignoring duplicate name 'org.freedesktop.Notifications' in service file
'/usr/share//dbus-1/services/org.kde.plasma.Notifications.service'
```

#### Root Cause

Two service files both claimed the `org.freedesktop.Notifications` D-Bus name:

| File | Owner | Content |
|------|-------|---------|
| `org.kde.plasma.Notifications.service` | `plasma-workspace 6.6.2-1` | `Exec=/usr/bin/plasma_waitforname org.freedesktop.Notifications` |
| `org.freedesktop.Notifications.service` | **No package** (orphan) | Identical content |

The orphan file was likely left behind from a previous package version or manual installation.

#### Fix Applied

```bash
# Verified orphan status:
pacman -Qo /usr/share/dbus-1/services/org.freedesktop.Notifications.service
# error: No package owns /usr/share/dbus-1/services/org.freedesktop.Notifications.service

sudo rm /usr/share/dbus-1/services/org.freedesktop.Notifications.service
```

No follow-up needed. The duplicate warning will not appear on next boot.

---

### Issue #4: /boot ESP World-Accessible [LOW / SECURITY]

**Status**: FIXED (takes effect next boot)

#### What Happened

systemd-boot reported on every boot:
```
Mount point '/boot' which backs the random seed file is world accessible, which is a security hole!
Random seed file '/boot/loader/random-seed' is world accessible, which is a security hole!
```

#### Root Cause

`/boot` is a VFAT (EFI System Partition) mounted with `fmask=0022,dmask=0022`, making all files and directories world-readable (755/644). This exposes the bootloader random seed and kernel images to any local user.

#### Fix Applied

Updated `/etc/fstab` mount options for the ESP:
```
# Before:
UUID=1EAA-2E44  /boot  vfat  rw,relatime,fmask=0022,dmask=0022,...

# After:
UUID=1EAA-2E44  /boot  vfat  rw,relatime,fmask=0077,dmask=0077,...
```

Ran `systemctl daemon-reload` to regenerate the `boot.mount` unit. Verified the unit has the correct options:
```
Options=rw,relatime,fmask=0077,dmask=0077,...
```

**Note**: VFAT does not support changing fmask/dmask on a live remount. The fix will apply on next boot. Verified by checking `systemctl cat boot.mount` shows the updated options.

#### Follow-up Required
- [ ] After next reboot, verify: `stat -c "%a" /boot` shows `700` (not `755`)

---

### Issue #5: Bluetooth hci0 Config Error [LOW / COSMETIC]

**Status**: DOCUMENTED — NO FIX NEEDED

#### What Happened

Every boot:
```
bluetoothd[665]: Failed to set default system config for hci0
```

#### Root Cause

BlueZ 5.86's `bluetoothd` attempts to set system configuration via the Bluetooth Management Interface (MGMT) `Set System Configuration` command. The Realtek RTL8851BU USB adapter's kernel driver does not implement this command. The adapter still initializes correctly and operates at full functionality:

```
Controller 50:EE:32:8F:D7:6A
  Name: markslinuxmonster
  Powered: yes
  Firmware: rtl_bt/rtl8851bu_fw.bin (version 0x048ad230)
  AOSP extensions: v1.00
  A2DP codecs: LDAC, aptx_hd, aptx_ll, SBC, AAC
```

This is a known upstream issue affecting Realtek USB Bluetooth adapters with BlueZ 5.86+. The error is cosmetic and does not affect Bluetooth pairing, audio, or file transfer.

---

### Issue #6 (Discovered): Odoo Blend Rates Sync Failure [MEDIUM / APPLICATION]

**Status**: NOT FIXED — PRE-EXISTING, SEPARATE FROM SYSTEM HEALTH

#### What Happened

The `odoo-sync-sheets-all.service` timer runs every 15 minutes and executes 7 sync operations. 6 succeed, but **Blend Rates Sync** fails consistently:

```
15:00:49 INFO [START] Blend Rates Sync
15:00:51 ERROR [FAIL] Blend Rates Sync: exit 1 in 2.1s
```

#### Root Cause

The sync script attempts to write an `active` field to the Odoo `x_blend_target` model, but this field does not exist on that model:

```
xmlrpc.client.Fault: <Fault 1: 'Traceback (most recent call last):
  File ".../odoo/orm/models.py", line 4378, in write
    self._check_field_access(self._fields[field_name], 'write')
KeyError: 'active'
...
ValueError: Invalid field 'active' in 'x_blend_target''>
```

The error originates from the Odoo server side (`odoo/orm/models.py` line 4378), called via XML-RPC from `scheduled_sheets_sync_all.py`.

#### Location

Script: `/home/mark/repos/Mktrotter1/odoo-api-pushing/.venv/bin/python scheduled_sheets_sync_all.py`
Service: `/etc/systemd/system/odoo-sync-sheets-all.service`
Timer: `/etc/systemd/system/odoo-sync-sheets-all.timer` (every 15 min)

#### Fix Required
- [ ] Either add an `active` Boolean field to the `x_blend_target` model in Odoo, or remove the `active` field write from the Blend Rates sync script

---

### Package Upgrade Context (2026-03-09)

The following upgrade was performed at 16:25 UTC on March 9, totaling **136 packages** (133 upgraded, 3 newly installed). Notable changes:

#### Kernel & System
| Package | From | To |
|---------|------|----|
| linux | 6.18.13.arch1-1 | 6.19.6.arch1-1 |
| linux-headers | 6.18.13.arch1-1 | 6.19.6.arch1-1 |
| systemd | 259.2-1 | 259.3-1 |
| networkmanager | 1.54.3-1 | 1.56.0-1 |

#### KDE Plasma (6.6.1 → 6.6.2) — 40+ packages
| Package | From | To |
|---------|------|----|
| **drkonqi** | **6.6.1-1** | **6.6.2-1** (regressed) |
| kwin | 6.6.1-3 | 6.6.2-1 |
| plasma-workspace | 6.6.1-1 | 6.6.2-1 |
| plasma-desktop | 6.6.1-1 | 6.6.2-1 |
| kscreenlocker | 6.6.1-1 | 6.6.2-1 |
| libkscreen | 6.6.1-1 | 6.6.2-1 |
| kscreen | 6.6.1-1 | 6.6.2-1 |
| powerdevil | 6.6.1-1 | 6.6.2-1 |
| libplasma | 6.6.1-1 | 6.6.2-1 |
| xdg-desktop-portal-kde | 6.6.1-1 | 6.6.2-1 |
| *(~30 more Plasma packages)* | 6.6.1 | 6.6.2 |

#### Audio (PipeWire 1.4.10 → 1.6.0)
| Package | From | To |
|---------|------|----|
| pipewire | 1.4.10-2 | 1.6.0-2 |
| pipewire-audio | 1.4.10-2 | 1.6.0-2 |
| pipewire-pulse | 1.4.10-2 | 1.6.0-2 |
| pipewire-jack | 1.4.10-2 | 1.6.0-2 |

#### Development Tools
| Package | From | To |
|---------|------|----|
| chromium | 145.0.7632.116 | 145.0.7632.159 |
| docker | 29.2.1 | 29.3.0 |
| go | 1.26.0 | 1.26.1 |
| rust | 1.93.1 | 1.94.0 |
| npm | 11.10.1 | 11.11.0 |

#### New Packages Installed
- `scrcpy 3.3.4-1` (Android screen mirroring)
- `spandsp 0.0.6-7` (telephony DSP, PipeWire dependency)
- `oxygen-icons 6.1.0-2`

---

### Post-Fix System State

| Metric | Before (pre-reboot) | After (post-fixes) |
|--------|---------------------|-------------------|
| Coredump storage | 2.1 GB (2,900 files) | 4.7 MB (1 file) |
| Coredumps this boot | 2,525 on prev boot | 0 |
| DrKonqi crash loop | Active (14 hrs) | Masked |
| Coredump limits | Unlimited | MaxUse=1G, KeepFree=2G |
| `mark` in `video` group | No | Yes |
| Orphan dbus service | Present | Removed |
| /boot fstab fmask | 0022 (world-readable) | 0077 (root-only) |
| Failed systemd units | Multiple | 1 (Odoo blend rates — pre-existing) |
| Disk used (/) | 76 GB (388 GB free) | 74 GB (390 GB free) |
| Memory | 5.2 GB / 30 GB | 9.6 GB / 30 GB (normal desktop use) |
| Swap | 0 B | 0 B |
| Load average | 0.72 (fresh boot) | 0.15 (settled) |

### All Follow-up Items

- [ ] **Unmask drkonqi** after next Plasma update if version > 6.6.2-1
- [ ] **Fix Blend Rates sync** — remove `active` field write for `x_blend_target` in odoo-api-pushing
- [ ] **Verify /boot permissions** show 700 after next reboot
- [ ] **Verify kwin display reconnection** works after next sleep/wake cycle (video group fix)
- [ ] **Consider reducing boot time** — `NetworkManager-wait-online.service` adds 7.6s; may be deferrable if nothing critical needs it
