# omarchy-xiaomipad9pm

**Omarchy v4.0.4 桌面环境，运行在 Arch Linux ARM (aarch64) 的 systemd-nspawn 容器中，
通过 seatd 在宿主 Debian 13 桌面上显示。**

适用于 Android 16 的 Linux Terminal（AVF 虚拟机）环境。

---

## 层级结构

```
┌─────────────────────────────────────────────────────────────────┐
│  Android 16 Linux Terminal（AVF 虚拟机）                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Debian 13 (宿主操作系统)                                  │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  systemd-nspawn 容器 (Arch Linux ARM aarch64)       │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │  Omarchy v4.0.4 + ARM 移植补丁                │  │  │  │
│  │  │  │  Hyprland (llvmpipe 软件渲染)                  │  │  │  │
│  │  │  │  quickshell 外壳                               │  │  │  │
│  │  │  │  fcitx5 + 雾凇拼音 (中文输入)                  │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │  seatd ── 把容器 Hyprland 画面转发到宿主显示               │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 系统要求

- **设备**: aarch64 架构（如 Pixel、ARM 服务器等）
- **宿主系统**: Debian 13 (trixie) aarch64
- **虚拟化**: Android 16 Linux Terminal（AVF）
- **磁盘**: ≥ 4 GB 可用空间
- **网络**: 需要互联网连接（下载 Arch Linux ARM 根文件系统和软件包）

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/rwanglq-ctrl/omarchy-xiaomipad9pm/main/install.sh | bash
```

或者克隆仓库后手动运行：

```bash
git clone https://github.com/rwanglq-ctrl/omarchy-xiaomipad9pm.git
cd omarchy-xiaomipad9pm
./install.sh
```

安装脚本支持以下选项：

```
./install.sh [--dry-run] [--user NAME] [--profile core|full] [--yes]
```

- `--dry-run` — 仅打印操作，不做任何修改
- `--user NAME` — 指定用户名（默认当前用户）
- `--profile core` — 最小安装：Omarchy 桌面 + 中文输入
- `--profile full` — 完整安装：core + 额外的 aarch64 可用应用

## 安装配置文件

| 配置 | 说明 |
|------|------|
| `core` | Omarchy 桌面环境 + fcitx5 中文输入法 + 雾凇拼音 |
| `full` | core + 额外应用（如 qalculate-gtk 等 aarch64 可用的工具） |

## 切换会话

安装完成后，默认会话为 Debian 桌面。切换到 Arch 容器的 Hyprland：

```bash
hypr-switch arch --now
```

切回 Debian：

```bash
hypr-switch debian --now
```

## 已知限制

- **软件渲染 (llvmpipe)**: 没有 GPU 加速，所有渲染由 CPU 完成。已关闭动画、模糊等特效以提升性能。
- **无 systemd --user**: 容器内没有用户级 systemd。原本由 systemd 用户服务管理的进程改为 Hyprland 启动时直接拉起。
- **宿主总线服务名冲突**: 宿主可能已占用 `org.freedesktop.Notifications`、`org.kde.StatusNotifierWatcher` 等服务名，可能导致通知、托盘图标异常。
- **锁屏密码警告**: 如果用户密码处于锁定状态，锁屏后将无法解锁。请先设置密码再使用锁屏功能。
- **x86-only 应用跳过**: 1Password、Spotify、Signal、Steam 等仅提供 x86 版本的应用不会安装。

## 卸载

```bash
# 停止并删除容器
sudo machinectl stop arch
sudo rm -rf /var/lib/machines/arch

# 删除宿主启动器
rm ~/.local/bin/{arch-hyprland,archbox,archsh,hypr-switch,hypr-session}

# 删除 systemd drop-in（如已安装）
rm ~/.config/systemd/user/weston.service.d/hyprland.conf
systemctl --user daemon-reload
```

## 架构文档

详细技术文档见 `docs/` 目录：

- [架构设计](docs/architecture.md) — uwsm/systemd-user 替代方案
- [软件包清单](docs/packages.md) — 跳过的包及原因
- [性能调优](docs/performance.md) — llvmpipe 优化和 udmabuf
- [故障排除](docs/troubleshooting.md) — 常见问题及解决方法

## 许可证

本项目基于 [MIT 许可证](LICENSE) 发布。

## 致谢

- [Omarchy](https://github.com/basecamp/omarchy) by Basecamp — 框架本身，MIT 许可证
- [Arch Linux ARM](https://archlinuxarm.org/) — aarch64 发行版
- [Hyprland](https://hyprland.org/) — Wayland 合成器
- [fcitx5](https://fcitx5.org/) + [Rime](https://rime.im/) + 雾凇拼音 — 中文输入方案
