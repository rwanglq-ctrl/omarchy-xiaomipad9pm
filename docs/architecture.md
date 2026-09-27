# 架构设计

## 概述

omarchy-alarm-nspawn 在 systemd-nspawn 容器中运行 Omarchy v4.0.4 桌面环境。
由于容器环境的限制，需要对 Omarchy 的系统管理部分进行适配。

## 核心问题：uwsm 和 systemd --user

### 问题背景

Omarchy v4 使用 [uwsm](https://github.com/Vladimir-csp/uwsm) (Universal Wayland Session Manager)
来管理应用生命周期。uwsm 会将应用注册为 systemd 用户服务，实现：
- 应用自动重启
- 会话退出时清理所有应用
- 日志通过 journald 收集

但在 nspawn 容器中：
1. **PID 1 不是 systemd** — 容器内没有 `systemd --user` 实例
2. **D-Bus 会话总线属于宿主** — `$XDG_RUNTIME_DIR/bus` 是宿主的总线
3. **如果调用真正的 uwsm-app** — 程序会被注册到宿主的 systemd --user，实际跑在宿主上

### 解决方案

#### 1. uwsm-app 替身 (`/usr/local/bin/uwsm-app`)

一个极简的 shell 脚本，丢弃 uwsm 的参数（`-s/-t/-a/-S`、`--`），直接 `exec` 后面的命令。
配置里已尽量不再调用它，仅作为兜底。

#### 2. 批量移除 `uwsm-app -- ` 前缀

Omarchy 仓库中有 38 个文件使用了 `uwsm-app -- <command>` 的调用方式。
补丁将其改为直接调用命令：

```lua
-- 之前
hl.exec_cmd("uwsm-app -- foot")
-- 之后
hl.exec_cmd("foot")
```

涉及范围：`bin/`、`default/`、`config/`、`shell/` 中的脚本和配置文件。

#### 3. systemd-run 替代

| 原始调用 | 替代方案 | 原因 |
|----------|---------|------|
| `systemd-run --user ... omarchy-launch-browser` | `setsid $BROWSER &` | 浏览器需要独立进程 |
| `systemd-run --user ... omarchy-system-shutdown` | `hyprctl dispatch exit()` | 容器无权关机 |
| `systemd-run --user ... omarchy-system-reboot` | `hyprctl dispatch exit()` | 容器无权重启 |
| `systemd-cat` / `logger` | 写日志到 `~/.local/state/omarchy/shell.log` | 无 journald |

#### 4. 用户服务替代

原本由 systemd 用户服务常驻的程序，改为在 Hyprland 启动时通过 `exec_cmd` 拉起：

| 原服务 | 替代方式 |
|--------|---------|
| `omarchy-fcitx5.service` | `~/.local/bin/fcitx5-autostart` 脚本 |
| `omarchy-migrate-notify.service` | `sleep 5 && omarchy-migrate-notify` |

跳过的用户服务（在容器中无法工作）：
- `bt-agent` — 需要蓝牙硬件
- `omarchy-sleep-lock` — 需要 logind/systemd-inhibit
- `omarchy-recover-internal-monitor` — 需要硬件访问
- `omarchy-crash-watch` — 需要 journald/coredump
- `omarchy-speaker-tuning` — 音频由宿主管理
- `omarchy-tailscale-receive` — 需要 Tailscale 服务

#### 5. 会话环境变量

原来由 uwsm 读取 `default/uwsm/default` 和 `/usr/lib/environment.d/` 提供的环境变量，
改为在 `default/hypr/envs.lua` 中用 `hl.env` 设置：

```lua
hl.env("TERMINAL", "foot")
hl.env("EDITOR", "nvim")
hl.env("INPUT_METHOD", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. os.getenv("PATH"))
```

#### 6. GSETTINGS_BACKEND=keyfile

gsettings 默认通过 D-Bus 调用 dconf-service。由于 D-Bus 总线是宿主的，
写入会污染宿主配置。改为使用 keyfile 后端，写入本地的
`~/.config/glib-2.0/settings/keyfile`。

## fcitx5 自启动

由于容器中 fcitx5 的启动时序与直接安装不同，使用专门的 `fcitx5-autostart` 脚本：

1. 等待 Wayland socket 就绪
2. 确认 fcitx5 有 Wayland 前端（否则重启，最多 3 次）
3. 切换一次工作区以刷新焦点

不向宿主 D-Bus 推送环境变量（`dbus-update-activation-environment` 会污染宿主总线）。

## host-run：跨容器运行宿主程序

`~/.local/bin/host-run` 通过共享的 D-Bus 调用宿主的 `systemd --user`，
让程序在宿主 Debian 上运行，但显示在容器的 Hyprland 窗口中。

使用 `systemd-run --wait`（而非默认的 `$XDG_RUNTIME_DIR/systemd/private`，
因为跨容器认证失败）。

宿主的 `arch-hyprland` 启动脚本加了 `--bind=/tmp`，
使宿主的 X11 程序能连接到容器中的 XWayland。
