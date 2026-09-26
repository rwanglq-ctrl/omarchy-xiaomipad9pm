local paths = require("default.hypr.paths")
local require_optional = require("default.hypr.require_optional")

-- GUM environment variables for styling purposes.
require_optional.module("omarchy.current.theme.gum_env")

-- Cursor size.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Force all apps to use Wayland.
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Allow better support for screen sharing (Google Meet, Discord, etc).
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Use XCompose file.
hl.env("XCOMPOSEFILE", paths.home .. "/.XCompose")

-- hyprctl setenv doesn't reach keybind dispatcher env; use hl.env.
hl.env("OMARCHY_PATH", paths.omarchy_path)

local bin_dir = paths.omarchy_path .. "/bin"
local kept = {}
for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
  if entry ~= bin_dir then table.insert(kept, entry) end
end
table.insert(kept, 1, bin_dir)
-- ARM 容器移植：原来经 uwsm 读 env-bootstrap 追加的用户目录
local local_bin = paths.home .. "/.local/bin"
local have_local = false
for _, e in ipairs(kept) do if e == local_bin then have_local = true end end
if not have_local then table.insert(kept, local_bin) end
hl.env("PATH", table.concat(kept, ":"))

-- ARM 容器移植：没有 uwsm / systemd --user，原本由 default/uwsm/default 和
-- default/environment.d/10-omarchy-fcitx.conf 提供的会话变量改在这里设置。
hl.env("TERMINAL", "xdg-terminal-exec")
hl.env("EDITOR", "omarchy-launch-editor --inline")
hl.env("INPUT_METHOD", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
-- D-Bus 会话总线属于宿主：gsettings 默认会经总线交给宿主的 dconf-service，
-- 写进宿主的配置。改用本地 keyfile（~/.config/glib-2.0/settings/keyfile）。
hl.env("GSETTINGS_BACKEND", "keyfile")

-- Hardware-specific environment.
require("default.hypr.nvidia")

hl.config({
  xwayland = {
    force_zero_scaling = true,
  },

  ecosystem = {
    no_update_news = true,
  },
})
