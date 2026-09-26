#!/bin/bash

# ARM 容器移植：容器里没有 systemd --user。
# 这些单元里需要的（fcitx5、omarchy-migrate-notify）已改到
# default/hypr/autostart.lua 用 Hyprland 启动；其余（蓝牙配对、睡眠锁、
# 内置屏恢复、崩溃监控）依赖 bluez / logind / journald，在容器里跳过。
exit 0
