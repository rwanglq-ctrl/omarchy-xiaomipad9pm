#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CACHE="$HOME/.cache/omarchy-alarm-tests"
mkdir -p "$CACHE"
export TMPDIR="$CACHE"
CACHE=$(realpath "$CACHE")
[[ $# -eq 0 || ( $# -eq 1 && $1 == --probe-only ) ]] || { echo 'Usage: tests/full.sh [--probe-only]' >&2; exit 2; }
[[ $(uname -m) == aarch64 ]] || { echo 'Full tests require native aarch64'; exit 1; }
sudo -n true || { echo 'Full tests need noninteractive sudo'; exit 1; }
archive="$CACHE/ArchLinuxARM-aarch64-latest.tar.gz"
url=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
if [[ ! -f $archive ]]; then
  curl -fL --retry 2 --connect-timeout 20 "$url" -o "$archive.part"
  mv "$archive.part" "$archive"
fi
# The official endpoint uses HTTP; this checks transfer integrity, not authenticity.
curl -fsSL --retry 2 --connect-timeout 20 "$url.md5" -o "$archive.md5"
expected=$(awk '{print $1}' "$archive.md5")
[[ $expected =~ ^[a-fA-F0-9]{32}$ ]]
[[ $(md5sum "$archive" | awk '{print $1}') == "$expected" ]] || { echo 'Rootfs checksum mismatch; remove stale cached archive and retry'; exit 1; }
rootfs=$(mktemp -d "$CACHE/rootfs.XXXXXX")
cleanup() {
  # Never delete anything except this invocation's freshly allocated cache child.
  if [[ -n ${rootfs:-} && $rootfs == "$CACHE"/rootfs.* && $(dirname "$rootfs") == "$CACHE" && ! -L $rootfs ]]; then
    sudo -n rm -rf --one-file-system -- "$rootfs"
  else echo 'Refusing unsafe rootfs cleanup' >&2; return 1; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sudo -n tar --numeric-owner --exclude='./dev/*' --exclude='dev/*' -xpf "$archive" -C "$rootfs"
# The downloader drops privileges; mktemp creates mode 700, unlike a normal /.
sudo -n chown 0:0 "$rootfs"
sudo -n chmod 755 "$rootfs"
sudo -n mkdir -p "$rootfs/dev" "$rootfs/proc" "$rootfs/sys" "$rootfs/src"
sudo -n rm -f "$rootfs/etc/resolv.conf"
sudo -n cp -L /etc/resolv.conf "$rootfs/etc/resolv.conf"
# All bind mounts live in a private mount namespace and vanish when it exits.
cat > "$CACHE/unshare-run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
rootfs=$1
shift
mount --make-rprivate /
# pacman CheckSpace needs the chroot root to be a mount point in mountinfo.
mount --bind "$rootfs" "$rootfs"
mount -t proc proc "$rootfs/proc"
mount --rbind /dev "$rootfs/dev"
mount --make-rslave "$rootfs/dev"
mount --rbind /sys "$rootfs/sys"
mount --make-rslave "$rootfs/sys"
mount -o remount,bind,ro "$rootfs/sys"
exec chroot "$rootfs" "$@"
SH
method=''
probing=true
inside() {
  local -a limit=()
  if $probing; then limit=(timeout --kill-after=5 30); fi
  case "$method" in
    nspawn) "${limit[@]}" sudo -n systemd-nspawn --quiet --register=no --as-pid2 -D "$rootfs" "$@" ;;
    unshare) "${limit[@]}" sudo -n unshare --mount --pid --fork bash "$CACHE/unshare-run.sh" "$rootfs" "$@" ;;
    bwrap) "${limit[@]}" sudo -n bwrap --die-with-parent --unshare-pid --bind "$rootfs" / --proc /proc --dev /dev --ro-bind /sys /sys -- "$@" ;;
    *) return 1 ;;
  esac
}
for candidate in nspawn unshare bwrap; do
  method=$candidate
  echo "Probing $method"
  set +e
  inside /usr/bin/pacman -Q > "$CACHE/probe-$candidate.log" 2>&1
  rc=$?
  set -e
  if ((rc == 0)); then break; fi
  cat "$CACHE/probe-$candidate.log"
  method=''
done
probing=false
[[ -n $method ]] || { echo 'FAIL: no supported isolation method'; exit 1; }
printf 'PASS isolation=%s: pacman -Q succeeded in fresh ALARM rootfs\n' "$method"
printf '%s\n' "$method" > "$CACHE/isolation-method"
if [[ ${1:-} == --probe-only ]]; then exit 0; fi
# Copy only repository files, never metadata or any host home directory.
tar -C "$ROOT" --exclude=.git -cf - . | sudo -n tar -xf - -C "$rootfs/src"
inside /bin/bash -euc '
  pacman-key --init
  pacman-key --populate archlinuxarm
  pacman -Syu --noconfirm --needed sudo git
  id testuser >/dev/null 2>&1 || useradd -m -s /bin/bash testuser
  printf "testuser ALL=(ALL) NOPASSWD: ALL\n" > /etc/sudoers.d/omarchy-test
  chmod 440 /etc/sudoers.d/omarchy-test
  bash /src/container/install.sh --profile core --no-aur --user testuser
'
inside /bin/bash /src/tests/integration-assert.sh
inside /bin/bash /src/tests/integration-snapshot.sh > "$CACHE/before.snapshot"
inside /bin/bash /src/container/install.sh --profile core --no-aur --user testuser
inside /bin/bash /src/tests/integration-snapshot.sh > "$CACHE/after.snapshot"
diff -u "$CACHE/before.snapshot" "$CACHE/after.snapshot"
inside /bin/bash /src/tests/integration-assert.sh
echo 'PASS integration and second-run idempotence'
