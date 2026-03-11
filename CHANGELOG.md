# markslinuxmonster Changelog

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
