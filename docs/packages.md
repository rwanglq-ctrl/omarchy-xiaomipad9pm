# 软件包清单

## 概述

Omarchy v4 的软件包分三类：
1. **官方源包** — 从 Arch Linux ARM (ALARM) 官方仓库安装
2. **AUR 包** — 通过 yay 从 AUR 源码编译
3. **跳过的包** — 因架构限制或环境约束无法安装

完整的跳过清单及原因见 `packages/skip.txt`。

## 官方源包

Omarchy 的 `omarchy-base.packages` 中列出的包，凡在 ALARM 官方源可用且不在跳过名单中的，
均会安装（约 104 个）。

额外补装的包：

| 包 | 用途 |
|----|------|
| `neovim` | 替代 nvim（ALARM 中包名不同） |
| `vi` | 基础编辑器 |
| `fcitx5-rime` | Rime 输入法引擎 |
| `fcitx5-configtool` | fcitx5 配置工具 |
| `qt6-5compat` | Qt6 兼容层 |
| `qt6-svg` | SVG 支持 |
| `qt6-wayland` | Qt6 Wayland 集成 |
| `pipewire-pulse` | PulseAudio 兼容层（仅客户端） |
| `qalculate-gtk` | 计算器（替代 omacalc） |
| `jq` | JSON 处理工具 |

## AUR 包

通过 yay 从 AUR 源码编译：

| 包 | 说明 | 备注 |
|----|------|------|
| `yay` | AUR 助手 | 源码编译版（非 yay-bin） |
| `ttf-ia-writer` | iA Writer 字体 | — |
| `rime-ice-git` | 雾凇拼音输入方案 | — |
| `yaru-icon-theme` | Yaru 图标主题 | — |
| `cliamp` | 音乐 TUI 播放器 | Go 语言 |
| `aether` | 主题设计器 | — |
| `tensaku` | 截图标注工具 | PKGBUILD 仅标 x86_64，使用 `--ignorearch` 编译 |
| `omawrite` | Omarchy 写作工具 | PKGBUILD 仅标 x86_64，使用 `--ignorearch` 编译 |

编译配置：`BUILDDIR=$HOME/.cache/makepkg`，`TMPDIR=~/.cache/tmp`
（避免 `/tmp` 的 tmpfs 空间不足导致 Rust 编译失败）。

## 跳过的包

### 系统服务 / 引导 / 登录管理器 / 固件驱动

在 nspawn 容器中无法工作的系统级包：

- **网络**: avahi, nss-mdns, networkmanager
- **蓝牙**: bluez, bluez-tools, bluez-utils
- **打印**: cups, cups-filters, cups-pk-helper, system-config-printer
- **容器**: docker, docker-buildx, docker-compose, lazydocker
- **防火墙**: ufw, ufw-docker
- **电源**: power-profiles-daemon
- **引导**: plymouth, limine, mkinitcpio 相关钩子
- **登录**: sddm, uwsm
- **固件**: linux-firmware, wireless-regdb, kernel-modules-hook
- **GPU**: nvidia 驱动, gpu-screen-recorder（需要 GPU 编码）
- **其他**: bolt, ddcutil（显示器硬件控制）, udiskie（需要 udisks2）, tzupdate

Omarchy 的 `etc/` 目录中的配置文件全部跳过（cups, docker, limine, mkinitcpio,
NetworkManager, plymouth, sddm, systemd, sudoers, sysctl 等）。

### 仅 x86 或无 aarch64 编译源

| 包 | 处理方式 | 原因 |
|----|---------|------|
| `mise-bin` | 跳过 | ALARM 和 AUR 均无可编译版本；因此通过 mise 安装的 AI CLI 工具均未安装 |
| `obsidian` | 不在容器内安装 | Electron 二进制仅 x86；可通过 host-run 在宿主上运行 |
| `obs-studio` | 跳过 | ALARM 无此包 |
| `pinta` | 跳过 | 依赖 dotnet |
| `dotnet-runtime` | 跳过 | — |
| `qemu-user-static-binfmt` | 跳过 | — |
| `herdr` | 跳过 | 需要从源码编译 zig 0.15 及对应 LLVM |
| `localsend` | 跳过 | 需要 flutter/fvm 工具链（fvm 仅 x86_64） |

### Omarchy 自家源包（不可公开获取）

| 包 | 替代方案 |
|----|---------|
| `omacalc` | 使用 `qalculate-gtk`，快捷键重新绑定 |
| `omacut` | 跳过（已安装 kdenlive） |
| `omarchy-nvim` | 使用 LazyVim 官方 starter 配置 |
| `hyprland-preview-share-picker` | 使用 xdph 自带的 `hyprland-share-picker` |
| `ttfx` | 跳过（屏保，脚本会检测命令不存在） |
| `tobi-try` | 跳过 |
| `asdcontrol` | 跳过 |

### 字体替代

| 原包 | 替代 |
|------|------|
| `ttf-jetbrains-mono-nerd-basic` | 官方源的 `ttf-jetbrains-mono-nerd` |

## 编译注意事项

对于 PKGBUILD 中仅标记 `x86_64` 但实际是源码编译的包（如 tensaku、omawrite），
使用 `makepkg --ignorearch` 强制编译。这些包使用 Rust 或 C++ 编写，源码本身支持 aarch64。
