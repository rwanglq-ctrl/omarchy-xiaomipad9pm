require("default.hypr.startup-cursor")

hl.on("hyprland.start", function()
  -- Applications inherit the user's cursor; only the compositor starts blank.
  if omarchy_startup_cursor_pending then
    hl.env("XCURSOR_PATH", omarchy_startup_cursor.path)
    hl.env("XCURSOR_THEME", omarchy_startup_cursor.xcursor)
  end

  -- ARM 容器移植：没有 systemd --user，也不能用 dbus-update-activation-environment
  -- （D-Bus 会话总线属于宿主 Debian，把环境推过去会让宿主按容器的环境激活服务）。
  -- 已移除：dbus-update-activation-environment、omarchy-powerprofiles-init
  -- （需要 power-profiles-daemon）、udiskie（需要 udisks2 系统服务）。

  hl.exec_cmd("omarchy-launch-shell")
  hl.exec_cmd("omarchy-provision-first-run")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))

  -- 原本由 systemd 用户服务常驻的程序，改由 Hyprland 启动时拉起（等同 exec-once）。
  -- omarchy-fcitx5.service
  hl.exec_cmd("fcitx5 -d --replace --disable notificationitem")
  -- omarchy-migrate-notify.service
  hl.exec_cmd("sleep 5 && omarchy-migrate-notify")

  -- Start the herdr server inside the graphical session so its panes inherit
  -- WAYLAND_DISPLAY. Otherwise the first SSH login from a remote herdr starts
  -- it with a tty environment, and agents in its panes can't read the clipboard.
  hl.exec_cmd(o.launch("herdr server"))

  -- Run post-boot hooks after startup config has loaded.
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")
end)
