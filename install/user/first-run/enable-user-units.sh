#!/bin/bash

# Enable AND start the user systemd units we ship. Runs at first-run rather
# than at finalize-user time because the user manager isn't live during the
# ISO chroot — by first-run, the Hyprland/uwsm session is up and
# `systemctl --user enable --now` both writes the correct .wants symlinks
# (based on each unit's [Install]/WantedBy) and starts the services so the
# first session has bluetooth pairing, sleep lock, etc. live immediately
# instead of waiting for the next login. ConditionPath* in the unit files
# keep the enabled units inert on hardware they don't apply to.

set -euo pipefail

omarchy-input-method configure --defaults || echo "Input method defaults deferred; run omarchy setup input after login." >&2

# ARM 容器移植：容器里没有 systemd --user，以下用户单元全部跳过。
# 需要的（fcitx5、omarchy-migrate-notify）已改到 default/hypr/autostart.lua
# 用 Hyprland 启动；其余（蓝牙配对、睡眠锁、内置屏恢复、崩溃监控）依赖
# bluez / logind / journald，在容器里不适用。
exit 0

systemctl --user daemon-reload

# One at a time: given a list, systemctl enables none of it when it cannot find
# one unit, and that should not cost the session its bluetooth agent as well.
failed=0
for unit in \
  bt-agent.service \
  owed.service \
  omarchy-recover-internal-monitor.service \
  omarchy-sleep-lock.service \
  omarchy-migrate-notify.service \
  omarchy-fcitx5.service \
  omarchy-crash-watch.service; do
  systemctl --user enable --now "$unit" || failed=1
done

omarchy-hook-install theme-set /usr/share/owe/10-owe-sync
exit "$failed"
