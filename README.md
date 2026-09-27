# omarchy-xiaomipad9pm

**Omarchy v4.0.4 桌面环境，运行在 Arch Linux ARM (aarch64) 的 systemd-nspawn 容器中，
通过 seatd 在宿主 Debian 13 桌面上显示。**

适用于 Android 16 的 Linux Terminal（AVF 虚拟机）环境。

**测试设备**：Xiaomi Pad 9 Pro Max（Android 16 Linux Terminal，Debian 13 aarch64）。

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

- **设备**: 支持 Android 16 Linux Terminal 的 aarch64 设备（已在 Xiaomi Pad 9 Pro Max 上测试）
- **宿主系统**: Debian 13 (trixie) aarch64
- **虚拟化**: Android 16 Linux Terminal（AVF）
- **磁盘**: ≥ 10 GB 可用空间（`core` 档装完约 7.5 GB，含软件包缓存）
- **网络**: 需要互联网连接（下载 Arch Linux ARM 根文件系统和软件包）

## 从零开始：在 Xiaomi Pad 9 Pro Max 上安装

> 以下菜单名称以 HyperOS（Android 16）为准，不同系统版本的叫法可能略有差异。

1. **打开开发者选项**：进入「设置 → 我的设备 → 全部参数与信息」，连续点击「OS 版本」7 次，
   按提示验证锁屏密码，看到「您已处于开发者模式」即可。
2. **打开 Linux 开发环境**：进入「设置 → 更多设置 → 开发者选项」，打开
   「Linux 开发环境」（Linux development environment），桌面上会出现「终端」（Terminal）应用。
3. **初始化 Debian**：打开「终端」应用，首次启动会下载并安装 Debian 13 镜像
   （几百 MB，建议连接 Wi-Fi），完成后进入命令行。
4. **扩大磁盘**：在终端右上角菜单进入「设置 → 调整磁盘大小」，调到 **≥ 16 GB**
   （`core` 档装完约 7.5 GB，留出空间给软件包缓存和个人文件）。
5. **运行一键安装**（见下一节）。脚本会先配置 Debian 宿主，再下载并配置 Arch Linux ARM 容器，
   整个过程需要下载数 GB 的软件包，耗时取决于网速。
6. **切换到 Omarchy 桌面**：运行 `hypr-switch arch`，然后点击终端顶部的
   「显示」按钮（显示器图标）打开图形界面，就会进入 Arch 容器里的 Hyprland / Omarchy。
   以后想回到 Debian 图形会话，运行 `hypr-switch debian --now`。

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

- **没有 GPU 硬件虚拟化支持**: 当前 Android 16 Linux Terminal 不提供 GPU 硬件加速，图形界面由 CPU 软件绘制（Mesa llvmpipe）。
  已关闭动画、模糊、阴影等特效，日常使用（终端、浏览器、办公）性能流畅；3D 游戏、视频剪辑等重度图形任务不适合。
- **暂不支持声音输入输出**: 扬声器、耳机和麦克风在容器桌面里暂时都不可用。
- **无 systemd --user**: 容器内没有用户级 systemd。原本由 systemd 用户服务管理的进程改为 Hyprland 启动时直接拉起。
- **宿主总线服务名冲突**: 宿主可能已占用 `org.freedesktop.Notifications`、`org.kde.StatusNotifierWatcher` 等服务名，可能导致通知、托盘图标异常。
- **锁屏密码警告**: 如果用户密码处于锁定状态，锁屏后将无法解锁。请先设置密码再使用锁屏功能。
- **x86-only 应用跳过**: 1Password、Spotify、Signal、Steam 等仅提供 x86 版本的应用不会安装。

## 卸载

```bash
# 停止并删除容器（桌面运行时注册的机器名是 arch-desktop）
sudo machinectl terminate arch-desktop 2>/dev/null || true
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
- [Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max) — 本项目的测试设备，采用 Xiaomi XRING O3 最新旗舰处理器

---

## English

**Omarchy v4.0.4 on Arch Linux ARM (aarch64), running in a systemd-nspawn container on the
Debian 13 VM of Android 16's Linux Terminal, and shown on its display through seatd.**

**Tested device**: [Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max), powered by Xiaomi's latest flagship XRING O3 processor (Android 16 Linux Terminal, Debian 13 aarch64).

### Requirements

- An aarch64 device with Android 16's Linux Terminal (tested on Xiaomi Pad 9 Pro Max)
- The Terminal's Debian 13 (trixie) aarch64 VM
- ≥ 10 GB free disk space (the `core` profile takes about 7.5 GB, package cache included)
- An internet connection

### From scratch on Xiaomi Pad 9 Pro Max

Menu names follow HyperOS (Android 16) and may differ slightly between versions.

1. **Enable developer options**: *Settings → My device → All specs*, tap *OS version* 7 times
   and confirm with your lock-screen password.
2. **Enable the Linux development environment**: *Settings → Additional settings → Developer options*,
   turn on *Linux development environment*. A *Terminal* app appears.
3. **Set up Debian**: open *Terminal*. The first launch downloads and installs the Debian 13 image
   (a few hundred MB, Wi-Fi recommended) and drops you into a shell.
4. **Grow the disk**: *Terminal menu → Settings → Resize disk*, set it to **≥ 16 GB**.
5. **Run the one-command installer** below. It prepares the Debian host, then downloads and configures
   the Arch Linux ARM container; expect several GB of downloads.
6. **Switch to the Omarchy desktop**: run `hypr-switch arch`, then tap the Terminal's *Display* button
   (monitor icon). To go back to Debian's session later: `hypr-switch debian --now`.

### One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/rwanglq-ctrl/omarchy-xiaomipad9pm/main/install.sh | bash
```

Or clone and run it:

```bash
git clone https://github.com/rwanglq-ctrl/omarchy-xiaomipad9pm.git
cd omarchy-xiaomipad9pm
./install.sh [--dry-run] [--user NAME] [--profile core|full] [--yes]
```

- `core`: the Omarchy desktop plus Chinese input (fcitx5 + Rime / rime-ice)
- `full`: core plus extra apps that exist for aarch64

### Known limitations

- **No GPU hardware virtualization**: Android 16's Linux Terminal offers no GPU acceleration yet, so the
  GUI is drawn by the CPU (Mesa llvmpipe). With animations, blur and shadows turned off, everyday use
  (terminals, browser, office apps) runs smoothly; 3D games and video editing are not a good fit.
- **No audio input or output yet**: speakers, headphones and the microphone don't work in the container desktop.
- **No systemd --user in the container**: services Omarchy runs as user units are started by Hyprland instead.
- **Host D-Bus name conflicts**: the host may already own notification and tray service names, so
  notifications or tray icons can misbehave.
- **Lock screen**: if your password is locked or unset you cannot unlock the lock screen. Set a password first.
- **x86-only apps are skipped** (1Password, Spotify, Signal, Steam, ...).

### Tests

`tests/run.sh --quick` (syntax, ShellCheck, privacy scan, patches, package names, dry-runs, Lua, hygiene)
runs on every push; `tests/run.sh --full` installs the `core` profile into a fresh Arch Linux ARM rootfs
and checks that a second run changes nothing (run it from the *Actions* tab).

Details: [docs/](docs/) (in Chinese). License: [MIT](LICENSE). Built on
[Omarchy](https://github.com/basecamp/omarchy) by Basecamp.
Thanks to the [Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max) with Xiaomi's latest flagship XRING O3 processor, the device this project was built and tested on.
