# omarchy-xiaomipad9pm

**Omarchy v4.0.4 桌面环境，运行在 Arch Linux ARM (aarch64) 的 systemd-nspawn 容器中，
通过 seatd 在宿主 Debian 13 桌面上显示。**

适用于 Android 16 的 Linux Terminal（AVF 虚拟机）环境。

**测试设备**：[Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max)（Android 16 Linux Terminal，Debian 13 aarch64），采用 Xiaomi XRING O3 最新旗舰 AI 处理器。

---

## 系统要求

- **设备**: 支持 Android 16 Linux Terminal 的 aarch64 设备（已在 Xiaomi Pad 9 Pro Max 上测试）
- **宿主系统**: Debian 13 (trixie) aarch64
- **虚拟化**: Android 16 Linux Terminal（AVF）
- **磁盘**: 建议 ≥ 20 GB 可用空间（桌面、AI 程序、软件包及下载缓存）
- **网络**: 需要互联网连接（下载 Arch Linux ARM 根文件系统和软件包）

## 从零开始：在 Xiaomi Pad 9 Pro Max 上安装

> 以下菜单名称以 HyperOS（Android 16）为准，不同系统版本的叫法可能略有差异。

1. **打开开发者选项**：进入「设置 → 我的设备 → 全部参数与信息」，连续点击「OS 版本」7 次，
   按提示验证锁屏密码，看到「您已处于开发者模式」即可。
2. **打开 Linux 开发环境**：进入「设置 → 更多设置 → 开发者选项」，打开
   「Linux 开发环境」（Linux development environment），桌面上会出现「终端」（Terminal）应用。
3. **初始化 Debian**：打开「终端」应用，首次启动会下载并安装 Debian 13 镜像
   （几百 MB，建议连接 Wi-Fi），完成后进入命令行。
4. **扩大磁盘**：在终端右上角菜单进入「设置 → 调整磁盘大小」，调到 **≥ 24 GB**
   （`core` 包含桌面和 AI 程序，另留空间给缓存和个人文件）。
5. **运行一键安装**（见下一节）。脚本会先配置 Debian 宿主，再下载并配置 Arch Linux ARM 容器，
   整个过程需要下载数 GB 的软件包，耗时取决于网速。
6. **切换到 Omarchy 桌面**：运行 `hypr-switch arch`，然后点击终端顶部的
   「显示」按钮（显示器图标）打开图形界面，就会进入 Arch 容器里的 Hyprland / Omarchy。
   以后想回到 Debian 图形会话，运行 `hypr-switch debian`。

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/rwanglq-ctrl/omarchy-xiaomipad9pm/main/install.sh | OMARCHY_ALARM_REF=main bash
```

安装会自动进入 `omarchy-install` tmux 会话。终端待机或 SSH 断线后，回到 Debian 宿主运行：

```bash
tmux attach -t omarchy-install
# 也可在另一个终端查看日志：
tail -f ~/.local/state/omarchy-alarm/install.log
```

重跑安装命令会连接已有会话；安装结束后可在该会话中重跑命令更新。
没有交互终端时安装在后台继续。虚拟机关机/重启会停止安装，开机后需重跑命令。
以 root/sudo 启动时，请按屏幕提示使用 `sudo tmux attach` 和对应日志路径。
若 sudo 要求密码，请在会话中完成提示后再离开；无人值守安装需要免密 sudo。
`--dry-run` 不安装或进入 tmux。

### 国内网络安装

以下命令使用 Gitee 源码和国内软件包镜像；请核对安装器打印的版本和源码 SHA。Gitee 由维护者单独同步，版本可能落后于 GitHub。

```bash
curl -fsSL https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm/raw/main/install.sh | MIRROR=cn OMARCHY_ALARM_REPO=https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm OMARCHY_ALARM_REF=main bash -s -- --profile core
```

**Resume on Pad（失败后继续）**：在 Debian 宿主终端重新运行以下命令。安装器会复用现有 Arch 容器和校验通过的 rootfs 缓存，保留未完成下载的 `.part` 文件；先修复容器 DNS 再继续 pacman。使用相同的用户和 `--rootfs` 参数（如曾指定）。

```bash
curl -fsSL https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm/raw/main/install.sh | MIRROR=cn OMARCHY_ALARM_REPO=https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm OMARCHY_ALARM_REF=main bash -s -- --profile core
```

Pad 切换网络后若容器 DNS 再次失败，重跑相同安装命令可刷新宿主上游 DNS。

或先克隆再安装：

```bash
git clone --branch main --depth 1 https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm.git && cd omarchy-xiaomipad9pm
MIRROR=cn bash ./install.sh --profile core
```

也可使用 `--mirror cn`；`--mirror auto` 短探测 github.com 与 raw.githubusercontent.com
（两者都可达才选 `global`），并打印所选模式；`--dry-run` 不探测、按 `global` 预览。
默认 `global` 保持海外安装方式。国内模式使用阿里云/清华/中科大 Debian 源，
清华/中科大/北外/交大 ALARM rootfs 和 pacman 源；原有软件源会备份。
Omarchy v4.0.4 已随源码附带，取得本项目源码后无需另行从 GitHub 下载上游。
国内模式使用 Gitee 上固定版本、校验过的构建源码和发布物。未镜像的
额外 AUR 应用会明确跳过；Rime 保留可用的默认中文输入方案。
全球（非 CN）模式下，core 和 full 均安装 mise、Claude Code、Codex、pi、opencode、herdr、crush、
Cursor Agent、oh-my-pi（`omp`）、GitHub CLI（`gh`）及参考工具清单中的其余程序，
只安装程序，不导入配置、
密钥、令牌或登录信息。请在 Arch 桌面终端运行这些命令并自行登录。
**国内模式（`MIRROR=cn`）不安装 oh-my-pi（`omp`）和 Cursor Agent（`cursor-agent`），已有副本会保留。**
如需这两个程序，请在可访问全球网络时，不带 `MIRROR=cn` 重新运行上方 GitHub 一键安装命令
（若曾导出该变量，先运行 `unset MIRROR`；也可显式指定 `MIRROR=global`）。
可选工具失败不会中断桌面安装，重新运行安装命令可重试；结果见
`~/.local/state/omarchy-alarm/tool-programs.txt`。
安装器创建 `~/Work` 和标准用户目录，保留已有文件及目录偏好。
仅在 `~/.config/nvim` 不存在时安装 LazyVim 初始配置；已有 Neovim 配置保持原样。
`MIRROR=cn` 要放在管道右侧的 `bash` 前面，放在 curl 左侧无效。

`MIRROR=cn` 默认从 Gitee 拉取本项目源码并选择国内软件包源；`global` 默认从 GitHub 拉取。
也可设置 `OMARCHY_ALARM_REPO` 指向你自己信任的 Git 镜像。
引导器缺少 Git 时先通过 Debian apt 安装 `git` 和 CA 证书；克隆后再检出 `OMARCHY_ALARM_REF`，支持分支、标签和完整提交 SHA（SHA 先克隆 `main` 及完整历史再检出）。
Git 获取失败时请检查网络后重试。


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
- `--profile core` — Omarchy 桌面 + 中文输入 + mise 和 AI 工具程序
- `--profile full` — 完整安装：core + 额外的 aarch64 可用应用

## 安装配置文件

| 配置 | 说明 |
|------|------|
| `core` | Omarchy 桌面 + fcitx5/Rime 中文输入 + mise 和 AI 工具程序 |
| `full` | core + 额外应用（如 qalculate-gtk 等 aarch64 可用的工具） |

键盘默认：**Caps Lock = Super，右 Alt = Compose**；Shift 切换中英文。
更新时保留用户修改过的键盘配置。

## 切换会话

安装完成后，默认会话为 Debian 桌面。切换到 Arch 容器的 Hyprland：

```bash
hypr-switch arch
```

切回 Debian：

```bash
hypr-switch debian
```

切换命令保存下一次显示启动使用的模式。完全关闭 Linux Terminal 应用再重新打开，
使选择生效。`--now` 也只保存选择。当前 shell 找不到命令时运行：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 更新与继续安装

在 Debian 宿主重新运行同一安装命令，使用相同用户和 `--rootfs` 参数（如曾指定）。
安装器复用现有容器和缓存，更新配置，不会重启显示服务。

## 自检

在 Linux Terminal 的**文本标签页**或独立 SSH 中运行：

```bash
~/.local/bin/arch-selftest
```

命令会关闭图形桌面和应用，完成后恢复所选桌面，并打印本次自检的私有日志路径。
退出 0 表示输出 IPC 就绪且已清理，不保证画面正常。查看命令打印的日志；分享前检查其中的私人信息。

[故障排除 / Troubleshooting](docs/troubleshooting.md)

## 已知限制

- **没有 GPU 硬件虚拟化支持**: 当前 Android 16 Linux Terminal 不提供 GPU 硬件加速，图形界面由 CPU 软件绘制（Mesa llvmpipe）。
  已关闭动画、模糊、阴影等特效，日常使用（终端、浏览器、办公）性能流畅；3D 游戏、视频剪辑等重度图形任务不适合。
- **暂不支持声音输入输出**: 扬声器、耳机和麦克风在容器桌面里暂时都不可用。
- **无 systemd --user**: 容器内没有用户级 systemd。原本由 systemd 用户服务管理的进程改为 Hyprland 启动时直接拉起。
- **宿主总线服务名冲突**: 宿主可能已占用 `org.freedesktop.Notifications`、`org.kde.StatusNotifierWatcher` 等服务名，可能导致通知、托盘图标异常。
- **锁屏密码警告**: 如果用户密码处于锁定状态，锁屏后将无法解锁。请先设置密码再使用锁屏功能。
- **x86-only 应用跳过**: 1Password、Spotify、Signal、Steam 等仅提供 x86 版本的应用不会安装。

## 卸载

在独立的文本终端或 SSH 中操作；这会关闭图形桌面及应用。

```bash
# 停止并删除容器（桌面运行时注册的机器名是 arch-desktop）
systemctl --user stop weston.socket weston.service
sudo machinectl terminate arch-desktop 2>/dev/null || true
sudo rm -rf /var/lib/machines/arch

# 删除宿主启动器
rm ~/.local/bin/{arch-hyprland,archbox,archsh,hypr-switch,hypr-session,arch-output,arch-diag,arch-selftest,arch-machine-id,arch-log}

# 删除 systemd drop-in（如已安装）
rm ~/.config/systemd/user/weston.service.d/hyprland.conf
systemctl --user daemon-reload

# 不再需要诊断证据时，删除私有日志及会话状态
rm -rf ~/.local/state/omarchy-alarm
```

## 致谢

- [Arch Linux ARM](https://archlinuxarm.org/) — aarch64 发行版
- [Hyprland](https://hyprland.org/) — Wayland 合成器
- [fcitx5](https://fcitx5.org/) + [Rime](https://rime.im/) + 雾凇拼音 — 中文输入方案
- [Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max) — 本项目的测试设备，采用 Xiaomi XRING O3 最新旗舰 AI 处理器
- **安装配置**：使用 [Claude Code](https://claude.com/claude-code) agent + [Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5) 模型完成
- **GitHub 发布**：使用 [Orca](https://www.onorca.dev/) ADE（[GitHub](https://github.com/stablyai/orca)）协调多个 agent 并行完成——
  [Claude Code](https://claude.com/claude-code)、[Codex](https://github.com/openai/codex)、[Pi](https://pi.dev)、
  [MiMo Code](https://mimo.xiaomi.com/coder)，以及 [MiMo-V2.6-Pro-UltraSpeed](https://mimo.mi.com/models/en-US/mimo-v2.6-pro-ultraspeed) 模型

## English

**Omarchy v4.0.4 on Arch Linux ARM (aarch64), running in a systemd-nspawn container on the
Debian 13 VM of Android 16's Linux Terminal, and shown on its display through seatd.**

**Device**: [Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max), powered by Xiaomi's latest flagship AI processor, the XRING O3 (Android 16 Linux Terminal, Debian 13 aarch64).

### Requirements

- An aarch64 device with Android 16's Linux Terminal (tested on Xiaomi Pad 9 Pro Max)
- The Terminal's Debian 13 (trixie) aarch64 VM
- Allow ≥ 20 GB free disk space for the desktop, AI programs and package/download caches
- An internet connection

### From scratch on Xiaomi Pad 9 Pro Max

Menu names follow HyperOS (Android 16) and may differ slightly between versions.

1. **Enable developer options**: *Settings → My device → All specs*, tap *OS version* 7 times
   and confirm with your lock-screen password.
2. **Enable the Linux development environment**: *Settings → Additional settings → Developer options*,
   turn on *Linux development environment*. A *Terminal* app appears.
3. **Set up Debian**: open *Terminal*. The first launch downloads and installs the Debian 13 image
   (a few hundred MB, Wi-Fi recommended) and drops you into a shell.
4. **Grow the disk**: *Terminal menu → Settings → Resize disk*, set it to **≥ 24 GB**.
5. **Run the one-command installer** below. It prepares the Debian host, then downloads and configures
   the Arch Linux ARM container; expect several GB of downloads.
6. **Switch to the Omarchy desktop**: run `hypr-switch arch`, then tap the Terminal's *Display* button
   (monitor icon). To go back to Debian's session later: `hypr-switch debian`.

### One-command install

```bash
curl -fsSL https://raw.githubusercontent.com/rwanglq-ctrl/omarchy-xiaomipad9pm/main/install.sh | OMARCHY_ALARM_REF=main bash
```

The installer opens the `omarchy-install` tmux session. After terminal standby or an SSH disconnect,
return to the Debian host and run:

```bash
tmux attach -t omarchy-install
# Follow progress from another terminal:
tail -f ~/.local/state/omarchy-alarm/install.log
```

Rerunning the installer reconnects to the existing session; after completion, rerun the command
inside that session to update. Without an interactive terminal, installation continues in the background.
VM shutdown/reboot stops the install; rerun the command after booting.
For a root/sudo invocation, use the printed `sudo tmux attach` command and log path.
If sudo asks for a password, answer inside the session before leaving; unattended installation requires passwordless sudo.
`--dry-run` neither installs nor enters tmux.

Or clone and run it:

```bash
git clone https://github.com/rwanglq-ctrl/omarchy-xiaomipad9pm.git
cd omarchy-xiaomipad9pm
./install.sh [--dry-run] [--user NAME] [--profile core|full] [--yes]
```

- `core`: the Omarchy desktop, Chinese input (fcitx5 + Rime), mise and AI tool programs
- `full`: core plus extra apps that exist for aarch64

### China installation and resume

```bash
curl -fsSL https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm/raw/main/install.sh | MIRROR=cn OMARCHY_ALARM_REPO=https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm OMARCHY_ALARM_REF=main bash -s -- --profile core
```

Gitee is synchronized separately and may lag GitHub. Check the printed version and source SHA.
To resume or update, rerun the same installation command with the same user and rootfs path.
The installer reuses the existing container and cached downloads, and does not restart the display.
In global (non-CN) mode, both profiles install mise, Claude Code, Codex, pi, opencode, herdr, crush,
Cursor Agent, oh-my-pi (`omp`), GitHub CLI (`gh`), and the remaining reference
tool inventory as programs only. CN builds use pinned source assets from Gitee;
extra AUR applications without mirrored sources are reported as skipped.
**CN mode (`MIRROR=cn`) does not install oh-my-pi (`omp`) or Cursor Agent (`cursor-agent`); existing copies are preserved.**
To install them later, rerun the GitHub one-command installer above in global mode without
`MIRROR=cn` (run `unset MIRROR` first if exported, or explicitly set `MIRROR=global`).
No tool settings, credentials, keys, tokens, or sign-in sessions are installed.
CN program downloads use npmmirror and checksum-verified assets in the project’s
Gitee release. There is no GitHub proxy or GitHub fallback.
A failed optional tool is reported and does not stop desktop setup; rerun to retry.
The installer creates `~/Work` and the standard user directories while preserving
existing files and directory preferences. LazyVim is seeded only when
`~/.config/nvim` is absent; existing Neovim configuration is preserved.

Run tools in the Arch desktop terminal:

```bash
mise --version
claude --version
codex --version
pi --version
opencode --version
herdr --version
crush --version
gh --version
# Available after a global-mode install:
cursor-agent --version
omp --version
```

Commands are available from `~/.local/bin`; sign in separately with each tool.
Installation results are in `~/.local/state/omarchy-alarm/tool-programs.txt`.

Keyboard defaults: **Caps Lock = Super, Right Alt = Compose**; Shift toggles Chinese/English.
Updates preserve user-modified keyboard configuration.

### Switching desktops and selftest

```bash
export PATH="$HOME/.local/bin:$PATH"
hypr-switch arch
# To select Debian instead:
hypr-switch debian
```

Fully close and reopen Linux Terminal to apply your selection. `--now` also saves the selection for later.
From the Terminal text tab or independent SSH, run:

```bash
~/.local/bin/arch-selftest
```

This closes graphical applications, tests output readiness, restores the selected desktop,
and prints the exact private log path. Exit 0 confirms output IPC readiness and cleanup;
it does not verify visible frames. Inspect the log before sharing it.

### Uninstall

Follow the commands in [卸载](#卸载) from a text terminal or independent SSH.
They stop the graphical desktop, delete the Arch container and remove the host launchers.

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

### Acknowledgments

Built on [Omarchy](https://github.com/basecamp/omarchy) by Basecamp.
Thanks to the [Xiaomi Pad 9 Pro Max](https://www.mi.com/prod/xiaomi-pad-9-pro-max) with Xiaomi's latest flagship AI processor, the XRING O3, the device this project was built and tested on.
The installation and configuration were done with the [Claude Code](https://claude.com/claude-code) agent and
the [Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5) model. The GitHub release was built with the
[Orca](https://www.onorca.dev/) ADE ([GitHub](https://github.com/stablyai/orca)) coordinating
[Claude Code](https://claude.com/claude-code), [Codex](https://github.com/openai/codex), [Pi](https://pi.dev) and
[MiMo Code](https://mimo.xiaomi.com/coder) in parallel, together with the
[MiMo-V2.6-Pro-UltraSpeed](https://mimo.mi.com/models/en-US/mimo-v2.6-pro-ultraspeed) model.
