# TODO -- markslinuxmonster Changelog

## High Priority

- [ ] **Unmask drkonqi after next Plasma update**: If `pacman -Qi drkonqi` shows version > 6.6.2-1, unmask both sockets and monitor:
  ```
  systemctl --user unmask drkonqi-coredump-pickup.socket drkonqi-coredump-launcher.socket
  systemctl --user start drkonqi-coredump-launcher.socket
  ```
  Both sockets currently masked (pickup since 2026-03-11, launcher since 2026-03-13). Regression is in drkonqi 6.6.1-1 (crash in `QTextDocumentFragment::fromHtml()` via `libKF6Notifications.so.6`).

## In Progress

_(none currently tracked)_

## Backlog

- [ ] **Monitor Chromium renderer crash frequency**: Baseline is ~1 crash per 2 days (SIGILL/SIGTRAP, renderer-only). Escalate if rate increases. Current: Chromium 145.0.7632.159
- [ ] **Reduce boot time**: `NetworkManager-wait-online.service` adds 7.8s to critical chain. Odoo sync timers add 44s to `systemd-analyze` total (but do not block desktop). Investigate whether NM-wait-online can be deferred
- [ ] **Bambu Studio bus_lock trap spam**: `bambustu_main` (Flatpak 2.5.0.66) triggers `x86/split lock detection: #DB` kernel warnings every ~30s. Upstream issue -- no fix available. Monitor for upstream release
- [ ] **rtw89_8851be "MAC has already powered on"**: Cosmetic kernel error at boot from WiFi PCIe driver (RTL8851BE). WiFi currently unused (wlan0 down). Upstream issue
- [ ] **BlueZ hci0 config error**: `Failed to set default system config for hci0` every boot. Realtek BT USB adapter's btrtl driver doesn't support MGMT Set System Configuration. Cosmetic -- adapter works fine
