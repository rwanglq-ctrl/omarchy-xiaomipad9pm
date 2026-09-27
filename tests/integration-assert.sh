#!/usr/bin/env bash
set -euo pipefail
home=$(getent passwd testuser | cut -d: -f6)
checkout="$home/.local/share/omarchy"
[[ $(readlink /usr/share/omarchy) == "$checkout" ]]
for binary in Hyprland quickshell fcitx5 foot; do command -v "$binary"; done
[[ -f $home/.config/hypr/hyprland.lua ]]
base=$(cat /src/patches/BASE)
[[ $(runuser -u testuser -- git -C "$checkout" branch --show-current) == arm-port ]]
for patch in /src/patches/*.patch; do
  patch_id=$(git patch-id --stable < "$patch" | awk '{print $1}')
  runuser -u testuser -- git -C "$checkout" log -p "$base..HEAD" | git patch-id --stable | awk '{print $1}' | grep -Fx "$patch_id"
done
[[ -z $(runuser -u testuser -- git -C "$checkout" status --porcelain) ]]
install -d -o testuser -g testuser -m700 /run/omarchy-test
runuser -u testuser -- env -i HOME="$home" USER=testuser PATH=/usr/local/bin:/usr/bin XDG_RUNTIME_DIR=/run/omarchy-test Hyprland --verify-config -c "$home/.config/hypr/hyprland.lua"
