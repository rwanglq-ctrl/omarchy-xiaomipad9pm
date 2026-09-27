# 性能调优

## 概述

容器中的 Hyprland 使用 **llvmpipe** 进行软件渲染（CPU 渲染，无 GPU 加速）。
所有图形操作都由 CPU 完成，因此需要关闭各种视觉特效以保持流畅。

## Hyprland 渲染优化

Omarchy v4 默认已关闭 blur 和 shadow。补丁在 `~/.config/hypr/looknfeel.lua` 中进一步禁用：

```lua
-- 关闭动画
hl.config({ animations = { enabled = false } })

-- 确保模糊关闭（Omarchy 默认已关闭，这里显式确认）
hl.decoration:blur(false)
```

## 显示器配置

使用通配写法，避免硬编码显示器名称：

```lua
-- ~/.config/hypr/monitors.lua
hl.monitor({
  output = "",       -- 匹配所有显示器
  mode = "preferred",
  position = "auto",
  scale = 1
})
```

环境变量 `GDK_SCALE=1`，避免缩放带来的额外渲染开销。

## 外壳 (quickshell) 优化

- **锁屏背景模糊**: 已禁用（`shell/plugins/lock/LockView.qml` 中的 MultiEffect，blurMax 128）
- **全局动画**: quickshell 没有全局动画开关。40 处 `Behavior` 动画暂时保留，
  大多只在交互时触发且时长较短
- **不强制软件渲染**: 不设置 `QT_QUICK_BACKEND=software`，
  因为托盘图标着色、壁纸切换遮罩等 MultiEffect 会不显示

## 终端

Omarchy v4 的默认终端是 foot（轻量级 Wayland 终端，适合软件渲染环境）。
配置在 `~/.config/hyprland-xdg-terminals.list` 的第一项。

## udmabuf

宿主安装脚本会启用 udmabuf（用户空间 DMA 缓冲区），可以减少 Wayland 缓冲区的拷贝次数，
对 llvmpipe 有一定性能提升。

## 可选：Debian 侧 Mesa 和 Hyprland 损坏修复

如果宿主 Debian 的 Mesa 或 Hyprland 版本导致显示问题，可以考虑：
- 更新宿主 Mesa 到较新版本（Debian 13 的 Mesa 可能较旧）
- Hyprland 0.56.2 包含了针对损坏 (damage) 追踪的修复，可以减少不必要的重绘

## 监控

如果感觉卡顿：
1. 检查 CPU 使用率：`htop` 或 `top`
2. 检查内存：llvmpipe 会消耗较多内存用于渲染缓冲区
3. 逐个面板调整 quickshell 的 `Behavior` 动画时长
4. 考虑减少 Hyprland 窗口装饰（如边框、阴影）
