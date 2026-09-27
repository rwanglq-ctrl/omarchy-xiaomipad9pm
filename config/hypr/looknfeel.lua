





hl.config({
  decoration = {
    shadow = { enabled = false },
    blur = { enabled = false },
  },
  animations = {
    enabled = false,
  },
})

o.window({ tag = "default-opacity" }, { opacity = "1 1" })

hl.config({
  render = { cm_enabled = false },
  misc = { render_unfocused_fps = 5 },
})

hl.config({
  debug = {
    fifo_pending_workaround = true,
  },
})

hl.config({
  decoration = {
    rounding = 0,
    dim_inactive = false,
  },
})
