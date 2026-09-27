#!/usr/bin/env bash
set -euo pipefail
mode=${1:---quick}
[[ $mode == --quick || $mode == --full ]]
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CACHE="$HOME/.cache/omarchy-alarm-tests"
mkdir -p "$CACHE"
export TMPDIR="$CACHE"
url=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
curl -fL --retry 3 "$url" -o "$CACHE/rootfs.tar.gz"
curl -fsSL --retry 3 "$url.md5" -o "$CACHE/rootfs.md5"
expected=$(awk '{print $1}' "$CACHE/rootfs.md5")
[[ $expected =~ ^[a-fA-F0-9]{32}$ ]]
[[ $(md5sum "$CACHE/rootfs.tar.gz" | awk '{print $1}') == "$expected" ]]
docker import "$CACHE/rootfs.tar.gz" omarchy-alarm-test:local >/dev/null
args=(--rm --volume "$ROOT:/src:ro" --workdir /src)
# The full suite needs nested namespaces/mounts. Quick receives no privilege.
if [[ $mode == --full ]]; then args+=(--privileged); fi
docker run "${args[@]}" omarchy-alarm-test:local /bin/bash -euc '
  # pacman 7 downloads as the sandboxed "alpm" user under Landlock, which the runner'"'"'s
  # unprivileged Docker refuses. Disable it only in this throwaway CI container.
  grep -q "^DisableSandbox" /etc/pacman.conf || sed -i "/^\[options\]/a DisableSandbox" /etc/pacman.conf
  pacman-key --init
  pacman-key --populate archlinuxarm
  pacman -Syu --noconfirm --needed git curl python lua sudo ripgrep jq which diffutils findutils util-linux bubblewrap systemd
  useradd -m -s /bin/bash tester
  printf "tester ALL=(ALL) NOPASSWD: ALL\n" > /etc/sudoers.d/tester
  chmod 440 /etc/sudoers.d/tester
  test_home=$(getent passwd tester | cut -d: -f6)
  cache="$test_home/.cache/omarchy-alarm-tests"
  install -d -o tester -g tester "$cache"
  curl -fL --retry 3 https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.aarch64.tar.xz -o "$cache/shellcheck.tar.xz"
  tar -xJf "$cache/shellcheck.tar.xz" -C "$cache"
  runuser -u tester -- env HOME="$test_home" bash /src/tests/run.sh "$1"
' bash "$mode"
