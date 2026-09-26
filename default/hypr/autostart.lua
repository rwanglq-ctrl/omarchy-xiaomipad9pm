hl.on("hyprland.start", function()
  -- ARM 容器移植：没有 systemd --user，也不能用 dbus-update-activation-environment
  -- （D-Bus 会话总线属于宿主 Debian，把环境推过去会让宿主按容器的环境激活服务）。
  -- 已移除：systemctl --user import-environment、dbus-update-activation-environment、
  --         omarchy-powerprofiles-init（需要 power-profiles-daemon）、
  --         udiskie（需要 udisks2 系统服务）。

  hl.exec_cmd("omarchy-launch-shell")
  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))

  -- 原本由 systemd 用户服务常驻的程序，改由 Hyprland 启动时拉起（等同 exec-once）。
  -- omarchy-fcitx5.service
  -- fcitx5-autostart（从 Debian 移植）：等 Wayland 就绪、确认有 wayland 前端、再刷新焦点
  hl.exec_cmd("$HOME/.local/bin/fcitx5-autostart")
  -- omarchy-migrate-notify.service
  hl.exec_cmd("sleep 5 && omarchy-migrate-notify")

  -- Run post-boot hooks after startup config has loaded.
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
end)
