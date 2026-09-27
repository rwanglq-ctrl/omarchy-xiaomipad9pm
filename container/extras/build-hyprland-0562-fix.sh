#!/usr/bin/env bash
# Optional llvmpipe damage-clip backport, never invoked by the main installer.
# Drop this override when the distro Hyprland contains the upstream fix (expected
# in >= 0.57): select /usr/bin/Hyprland again and remove only this dedicated prefix.
set -euo pipefail
prefix=${HYPRLAND_FIX_PREFIX:-/opt/hyprland-0.56.2-fix}
source_dir=${HYPRLAND_FIX_SOURCE:-$HOME/.cache/omarchy-alarm/hyprland-0.56.2}
jobs=${JOBS:-$(nproc)}
if [[ ${1:-} == --dry-run ]]; then
  echo "Clone Hyprland v0.56.2 into $source_dir, apply damage clip fix, build with $jobs jobs, install into $prefix"
  exit 0
fi
[[ $# == 0 ]] || { echo 'Usage: build-hyprland-0562-fix.sh [--dry-run]' >&2; exit 2; }
[[ $prefix == /* && $prefix != / && $prefix != /usr && $prefix != /usr/local ]] || {
  echo 'Choose a dedicated absolute installation prefix.' >&2; exit 2;
}
[[ $jobs =~ ^[1-9][0-9]*$ ]] || { echo 'JOBS must be a positive integer.' >&2; exit 2; }
mkdir -p "$(dirname "$source_dir")" "$HOME/.cache/tmp"
export TMPDIR="$HOME/.cache/tmp"
if [[ ! -d $source_dir ]]; then
  git clone --depth 1 --recursive --shallow-submodules --branch v0.56.2 \
    https://github.com/hyprwm/Hyprland.git "$source_dir"
fi
cd "$source_dir"
[[ $(git describe --tags --exact-match HEAD) == v0.56.2 ]] || {
  echo 'Source must be exactly Hyprland v0.56.2; no automatic checkout or reset.' >&2; exit 1;
}
python3 - <<'PY'
from pathlib import Path
p = Path('src/render/OpenGL.cpp')
s = p.read_text()
anchor = '''                damageClip.intersect(data.clipRegion);
        }

        if (!damageClip.empty()) {'''
fix = '''                damageClip.intersect(data.clipRegion);
        }

        // Backport: avoid repainting the entire wallpaper for partial damage.
        damageClip.intersect(*data.damage);

        if (!damageClip.empty()) {'''
if fix not in s:
    if s.count(anchor) != 1:
        raise SystemExit('Unexpected source context; refusing to patch')
    p.write_text(s.replace(anchor, fix))
PY
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$prefix" -DNO_TESTS=ON -DBUILD_TESTING=OFF -DNO_HYPRPM=ON
nice cmake --build build --parallel "$jobs"
sudo cmake --install build
printf 'Installed optional compositor into %s. Select it explicitly in your host launcher.\n' "$prefix"
