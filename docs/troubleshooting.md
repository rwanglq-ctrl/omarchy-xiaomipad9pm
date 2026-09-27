# 故障排除

## 容器无法启动

### 症状：`machinectl start arch` 失败

检查 systemd-nspawn 服务状态：
```bash
sudo systemctl status systemd-nspawn@arch
sudo journalctl -u systemd-nspawn@arch -n 50
```

常见原因：
- 根文件系统下载不完整或损坏 — 重新运行安装脚本
- 磁盘空间不足 — `df -h /var/lib/machines`
- SELinux / AppArmor 策略阻止 — 检查 `dmesg`

### 症状：容器启动后立即退出

```bash
sudo systemd-nspawn -D /var/lib/machines/arch /bin/bash
```

手动进入容器检查：
- `/etc/pacman.d/mirrorlist` 是否存在
- `pacman -Sy` 是否能正常同步

## Hyprland 无法启动

### 症状：黑屏或闪退

检查 Hyprland 配置：
```bash
# 在容器内
Hyprland --verify-config
```

常见原因：
- 缺少 Wayland socket — 确保宿主的 seatd 已启动
- llvmpipe 问题 — 检查 `LIBGL_ALWAYS_SOFTWARE=1` 是否设置
- 配置语法错误 — 查看 `~/.local/state/omarchy/hyprland.log`

### 症状：Hyprland 启动但无显示

确认 seatd socket 是否挂载：
```bash
ls -la /run/seatd.sock
```

如果不存在，检查宿主的 `arch-hyprland` 脚本是否正确传递了 seatd socket。

## 鼠标指针不可见

在 `~/.config/hypr/looknfeel.lua` 中添加：
```lua
hl.config({ cursor = { no_hardware_cursors = true } })
```

## 中文输入法问题

### fcitx5 不启动

运行 `fcitx5-autostart` 手动启动，检查输出：
```bash
~/.local/bin/fcitx5-autostart
```

脚本会等待 Wayland socket 就绪，确认有 Wayland 前端，最多重启 3 次。

### 输入法切换不工作

确认环境变量：
```bash
echo $INPUT_METHOD    # 应为 fcitx
echo $QT_IM_MODULE    # 应为 fcitx
echo $XMODIFIERS      # 应为 @im=fcitx
```

这些变量在 `~/.config/hypr/envs.lua` 中设置。

## 锁屏后无法解锁

**原因**: 用户密码处于锁定状态（`passwd -S` 显示 `L`）。

**解决**: 在解锁前先设置密码：
```bash
passwd
```

然后通过 `Super+Ctrl+I` 或运行 `omarchy toggle idle` 恢复空闲锁屏。

## 通知和托盘图标异常

### 症状：收不到通知

宿主可能已占用 `org.freedesktop.Notifications` 服务名。
容器的通知守护进程无法注册到 D-Bus 总线。

### 症状：托盘图标不显示

宿主可能已占用 `org.kde.StatusNotifierWatcher`。
这是 nspawn 容器共享宿主 D-Bus 总线的固有限制。

## 截图和屏幕共享异常

宿主可能已占用 `org.freedesktop.portal.Desktop`（后端是宿主的 xdg-desktop-portal-hyprland）。
容器中的截图/屏幕共享请求可能被路由到宿主的 portal，而宿主的 Hyprland 不在运行。

## 电源和网络面板无数据

这些面板依赖 NetworkManager、bluez、UPower 的系统总线服务，容器中没有这些服务。
属于已知限制，不影响核心功能。

## Omarchy 更新

**不要运行 `omarchy-update`** — 它会走 Omarchy 自家软件源和 channel 切换，
在容器环境中无法正常工作。

更新方式：
```bash
cd ~/.local/share/omarchy
git fetch origin
git rebase v4.0.4 arm-port  # 或 rebase 到新 tag
```

## 性能问题

参见 [性能调优](performance.md)。

快速检查：
```bash
# CPU 使用率
htop

# 内存使用
free -h

# 渲染相关进程
ps aux | grep -E 'hyprland|quickshell|foot'
```
