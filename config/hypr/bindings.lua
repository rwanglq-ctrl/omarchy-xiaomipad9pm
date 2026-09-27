-- ARM replacements for unavailable Omarchy packages.
hl.unbind("SUPER + CTRL + Q")
hl.unbind("XF86Calculator")
o.bind("SUPER + CTRL + Q", "Calculator", "qalculate-gtk")
o.bind("XF86Calculator", "Calculator", "qalculate-gtk")
hl.unbind("SUPER + CTRL + RETURN")
o.bind("SUPER + CTRL + RETURN", "Tmux", { omarchy = "terminal-tmux" })
