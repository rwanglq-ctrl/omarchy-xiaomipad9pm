
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")


require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

require("default.hypr.toggles")


hl.env("OMARCHY_OCR_LANGS", "chi_sim+eng")

hl.env("TMUX_TMPDIR", os.getenv("HOME") .. "/.local/state")

o.window({ tag = "floating-window", class = "^org.omarchy.btop$" }, { size = { 1200, 800 } })
o.window("org.omarchy.about", { size = { 1200, 800 } })
