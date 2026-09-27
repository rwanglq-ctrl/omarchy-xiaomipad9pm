#!/usr/bin/env bash
# host/install.sh — Debian 13 aarch64 host side of omarchy-alarm-nspawn.
#
# Prepares the Debian host (Android 16 "Linux Terminal" VM) to run an Arch Linux ARM
# systemd-nspawn container whose Hyprland is shown on the host display through seatd:
#   1. apt dependencies (systemd-container, seatd, curl, bsdtar, sudo, ...)
#   2. seatd enabled, user added to its group
#   3. /dev/udmabuf (llvmpipe needs it for dmabuf export / explicit sync)
#   4. official ArchLinuxARM-aarch64-latest rootfs downloaded, verified, extracted
#   5. inside the rootfs: pacman keyring, same-UID/GID user with sudo, locales, base-devel
#   6. launchers arch-hyprland archbox archsh hypr-switch hypr-session in ~/.local/bin
#   7. (unless --no-display-hook) the weston.service drop-in that runs hypr-session
# The display keeps starting Debian's desktop until the user runs `hypr-switch arch`.
#
# Re-running is safe: finished steps are detected and skipped, an existing Arch rootfs is
# reused, and anything else in --rootfs is only moved aside when --yes is given.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ALARM_URL=${OMARCHY_ALARM_TARBALL_URL:-http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz}
# Fingerprint of the "Arch Linux ARM Build System" key that signs the rootfs tarballs
# (published on archlinuxarm.org), written in the usual groups of four.
ALARM_KEY="68B3 537F 39A3 13B3 E574  D067 7719 3F15 2BDB E6A6"
ALARM_KEY=${ALARM_KEY// /}
ALARM_KEYSERVER=${OMARCHY_ALARM_KEYSERVER:-hkps://keyserver.ubuntu.com}
CACHE_DIR=${OMARCHY_ALARM_CACHE:-/var/cache/omarchy-alarm-nspawn}
DEFAULT_HOME_BINDS="Downloads Pictures Videos Work"
LAUNCHERS=(arch-hyprland archbox archsh hypr-switch hypr-session)
APT_PACKAGES=(systemd-container seatd curl ca-certificates libarchive-tools sudo)
MACHINE=arch-desktop

DRY_RUN=0
YES=0
DISPLAY_HOOK=1
HOME_BINDS=1
RENDER_DIR=""
TARGET_USER=""
ROOTFS=/var/lib/machines/arch

usage() {
  cat <<'EOF'
Usage: host/install.sh [--dry-run] [--user NAME] [--rootfs DIR] [--no-display-hook]
                       [--no-home-binds] [--yes] [--render-only DIR]

  --dry-run          print every action; change nothing (no root or network needed)
  --user NAME        host user to mirror into the container (default: $SUDO_USER or $USER)
  --rootfs DIR       container root filesystem (default: /var/lib/machines/arch)
  --no-display-hook  do not install the weston.service drop-in (launchers only)
  --no-home-binds    do not share ~/Downloads ~/Pictures ~/Videos ~/Work with the container
  --yes              allow moving aside a non-Arch directory that is in the way of --rootfs
  --render-only DIR  only write the rendered launchers/drop-in into DIR and exit (no root)

Environment:
  OMARCHY_ALARM_TARBALL_URL  rootfs tarball URL (a mirror; .md5 and .sig must sit next to it)
  OMARCHY_ALARM_HOME_BINDS   space-separated home folders to share (default: Downloads Pictures Videos Work)
  OMARCHY_ALARM_CACHE        download cache (default: /var/cache/omarchy-alarm-nspawn)
EOF
}

log()  { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# run CMD...: print the command, and execute it unless --dry-run.
run() {
  printf '  +'; printf ' %q' "$@"; printf '\n'
  if (( DRY_RUN )); then return 0; fi
  "$@"
}

ORIG_ARGS=("$@")
while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) YES=1 ;;
    --no-display-hook) DISPLAY_HOOK=0 ;;
    --no-home-binds) HOME_BINDS=0 ;;
    --user) [[ $# -ge 2 ]] || die "--user needs a value"; TARGET_USER=$2; shift ;;
    --user=*) TARGET_USER=${1#*=} ;;
    --rootfs) [[ $# -ge 2 ]] || die "--rootfs needs a value"; ROOTFS=$2; shift ;;
    --rootfs=*) ROOTFS=${1#*=} ;;
    --render-only) [[ $# -ge 2 ]] || die "--render-only needs a directory"; RENDER_DIR=$2; shift ;;
    --render-only=*) RENDER_DIR=${1#*=} ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

[[ $ROOTFS == /* ]] || die "--rootfs must be an absolute path: $ROOTFS"
ROOTFS=${ROOTFS%/}
[[ -n $ROOTFS && $ROOTFS != / ]] || die "--rootfs must not be /"
# The rootfs path ends up inside single-quoted shell strings in the launchers.
[[ $ROOTFS =~ ^[A-Za-z0-9/._-]+$ ]] || die "--rootfs may only contain letters, digits and / . _ -: $ROOTFS"

# --- target user ----------------------------------------------------------------------
if [[ -z $TARGET_USER ]]; then
  if [[ $EUID -eq 0 ]]; then
    TARGET_USER=${SUDO_USER:-}
    [[ -n $TARGET_USER && $TARGET_USER != root ]] || die "running as root: pass --user NAME (the desktop user, not root)"
  else
    TARGET_USER=$(id -un)
  fi
fi
[[ $TARGET_USER =~ ^[a-z_][a-z0-9_-]*$ ]] || die "invalid user name: $TARGET_USER"
[[ $TARGET_USER != root ]] || die "--user must be a normal desktop user, not root"
[[ $TARGET_USER != alarm ]] || die "--user alarm clashes with the rootfs' default account; use your host user"

if pw=$(getent passwd "$TARGET_USER"); then
  IFS=: read -r _ _ T_UID T_GID _ T_HOME _ <<<"$pw"
  T_GROUP=$(getent group "$T_GID" | cut -d: -f1 || true)
  [[ -n $T_GROUP ]] || T_GROUP=$TARGET_USER
elif (( DRY_RUN )) || [[ -n $RENDER_DIR ]]; then
  # Plan/preview for a user that does not exist here: borrow the invoking user's IDs.
  T_UID=$(id -u); T_GID=$(id -g); T_HOME=/home/$TARGET_USER; T_GROUP=$TARGET_USER
  warn "user '$TARGET_USER' does not exist on this host; showing the plan with UID/GID $T_UID/$T_GID and HOME $T_HOME"
else
  die "user '$TARGET_USER' does not exist on this host"
fi
[[ $T_UID -ne 0 ]] || die "user '$TARGET_USER' has UID 0"
[[ $T_HOME =~ ^/[A-Za-z0-9/._-]*$ ]] || die "unsupported characters in home directory: $T_HOME"
C_HOME=/home/$TARGET_USER   # the user's home inside the container

if (( HOME_BINDS )); then
  HOME_BIND_DIRS=${OMARCHY_ALARM_HOME_BINDS:-$DEFAULT_HOME_BINDS}
else
  HOME_BIND_DIRS=""
fi
for d in $HOME_BIND_DIRS; do
  [[ $d =~ ^[A-Za-z0-9._-]+$ && $d != . && $d != .. ]] || die "invalid home bind folder: $d"
done

# --- templates -------------------------------------------------------------------------
# render SRC DST: fill in the @PLACEHOLDERS@ of a host/ template.
render() {
  sed -e "s|@ROOTFS@|$ROOTFS|g" \
      -e "s|@USER@|$TARGET_USER|g" \
      -e "s|@UID@|$T_UID|g" \
      -e "s|@HOME@|$T_HOME|g" \
      -e "s|@CHOME@|$C_HOME|g" \
      -e "s|@HOME_BIND_DIRS@|$HOME_BIND_DIRS|g" \
      -e "s|@PLACEHOLDERS@|placeholders|g" \
      "$1" >"$2"
  if grep -q '@[A-Z_]*@' "$2"; then
    die "unfilled placeholder in $2: $(grep -o '@[A-Z_]*@' "$2" | sort -u | tr '\n' ' ')"
  fi
}

render_all() {
  local out=$1 name
  mkdir -p "$out/bin" "$out/systemd/weston.service.d"
  for name in "${LAUNCHERS[@]}"; do
    render "$SCRIPT_DIR/bin/$name" "$out/bin/$name"
    chmod 755 "$out/bin/$name"
  done
  render "$SCRIPT_DIR/systemd/weston.service.d/hyprland.conf" "$out/systemd/weston.service.d/hyprland.conf"
}

if [[ -n $RENDER_DIR ]]; then
  render_all "$RENDER_DIR"
  log "rendered launchers for user $TARGET_USER (UID $T_UID) into $RENDER_DIR"
  find "$RENDER_DIR" -type f | sort | sed 's/^/    /'
  exit 0
fi

# --- privileges ------------------------------------------------------------------------
if (( ! DRY_RUN )) && [[ $EUID -ne 0 ]]; then
  command -v sudo >/dev/null || die "must run as root (sudo is not installed)"
  log "re-running with sudo"
  exec sudo bash "${BASH_SOURCE[0]}" "${ORIG_ARGS[@]}" --user "$TARGET_USER"
fi

(( DRY_RUN )) && log "DRY RUN — nothing will be changed"
log "host user: $TARGET_USER (UID $T_UID, GID $T_GID/$T_GROUP, HOME $T_HOME)"
log "rootfs:    $ROOTFS"
note "home binds: ${HOME_BIND_DIRS:-(none)}; display hook: $( (( DISPLAY_HOOK )) && echo yes || echo no)"

# --- 0. host check ---------------------------------------------------------------------
# shellcheck disable=SC1091
os_id=$(. /etc/os-release 2>/dev/null && echo "${ID:-}")
# shellcheck disable=SC1091
os_ver=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")
if [[ $os_id != debian || $(uname -m) != aarch64 ]]; then
  if (( DRY_RUN )); then
    warn "this host is ${os_id:-unknown} ${os_ver} $(uname -m), not Debian aarch64 — the plan below is for a Debian 13 aarch64 host"
  else
    die "host/install.sh is for Debian 13 aarch64 (this is ${os_id:-unknown} ${os_ver} $(uname -m))"
  fi
elif [[ $os_ver != 13 ]]; then
  warn "tested on Debian 13 only (this is Debian ${os_ver:-unknown})"
fi

# --- 1. apt dependencies ---------------------------------------------------------------
log "1/7 apt packages: ${APT_PACKAGES[*]}"
missing=()
for p in "${APT_PACKAGES[@]}"; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' || missing+=("$p")
done
if (( ${#missing[@]} )); then
  run env DEBIAN_FRONTEND=noninteractive apt-get update
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
else
  note "all installed"
fi

# --- 2. seatd --------------------------------------------------------------------------
# seatd hands the container's Hyprland the DRM and input devices over /run/seatd.sock.
# Only members of the group given with `seatd -g` (Debian: video) may connect.
log "2/7 seatd"
seat_group=$(systemctl cat seatd.service 2>/dev/null | sed -n 's/^ExecStart=.*-g[[:space:]]*\([^[:space:]]*\).*/\1/p' | tail -n1 || true)
seat_group=${seat_group:-video}
run systemctl enable --now seatd.service
if id -nG "$TARGET_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$seat_group"; then
  note "$TARGET_USER is already in group $seat_group"
else
  run usermod -aG "$seat_group" "$TARGET_USER"
  note "log out and back in (or restart the VM) for the new group to apply"
fi

# --- 3. udmabuf ------------------------------------------------------------------------
# llvmpipe exports dmabufs through /dev/udmabuf; without it Hyprland loses explicit sync
# and the screen shows torn/fragmented frames.
log "3/7 /dev/udmabuf"
if [[ -e /dev/udmabuf ]]; then
  note "present"
else
  if (( DRY_RUN )); then
    run modprobe udmabuf
  elif ! modprobe udmabuf 2>/dev/null; then
    warn "could not load the udmabuf module; Hyprland in the container will show torn frames"
  fi
  if (( DRY_RUN )) || modinfo udmabuf >/dev/null 2>&1; then
    printf '  + echo udmabuf > /etc/modules-load.d/omarchy-udmabuf.conf\n'
    (( DRY_RUN )) || echo udmabuf >/etc/modules-load.d/omarchy-udmabuf.conf
  fi
  (( DRY_RUN )) || [[ -e /dev/udmabuf ]] || warn "/dev/udmabuf is still missing; arch-hyprland binds it and will fail until it exists"
fi

# --- 4. rootfs -------------------------------------------------------------------------
log "4/7 Arch Linux ARM rootfs"
rootfs_state=missing
if [[ -e $ROOTFS/etc/arch-release ]] || grep -qs '^ID=archarm' "$ROOTFS/etc/os-release"; then
  rootfs_state=arch
elif [[ -d $ROOTFS && -n $(ls -A "$ROOTFS" 2>/dev/null) ]]; then
  rootfs_state=other
elif (( DRY_RUN )) && [[ -e ${ROOTFS%/*} && ! -r ${ROOTFS%/*} ]]; then
  rootfs_state=unknown
fi

fetch_rootfs() {
  local tarball=$CACHE_DIR/${ALARM_URL##*/}
  run mkdir -p "$CACHE_DIR"
  run curl -fL --retry 3 -o "$tarball.md5" "$ALARM_URL.md5"
  if (( DRY_RUN )); then
    run curl -fL --retry 3 -C - -o "$tarball" "$ALARM_URL"
    printf '  + (verify md5 of %s)\n' "$tarball"
  else
    local want
    want=$(awk '{print $1; exit}' "$tarball.md5")
    [[ $want =~ ^[0-9a-f]{32}$ ]] || die "bad checksum file from $ALARM_URL.md5"
    if [[ -f $tarball ]] && [[ $(md5sum "$tarball" | awk '{print $1}') == "$want" ]]; then
      note "cached download is current: $tarball"
    else
      rm -f "$tarball"
      run curl -fL --retry 3 -o "$tarball" "$ALARM_URL"
      [[ $(md5sum "$tarball" | awk '{print $1}') == "$want" ]] || die "md5 mismatch for $tarball (delete it and retry)"
      note "md5 OK"
    fi
  fi
  verify_gpg "$tarball"
  TARBALL=$tarball
}

# Signature check with the ALARM build key in a throwaway keyring. A bad signature is fatal;
# no gpg or no keyserver only warns (the md5 above still guards against corrupt downloads).
verify_gpg() {
  local tarball=$1 gh status
  if ! command -v gpg >/dev/null; then
    warn "gpg not installed; skipping the signature check (md5 only)"
    return 0
  fi
  if (( DRY_RUN )); then
    run curl -fL --retry 3 -o "$tarball.sig" "$ALARM_URL.sig"
    printf '  + gpg --recv-keys %s && gpg --verify %q %q\n' "$ALARM_KEY" "$tarball.sig" "$tarball"
    return 0
  fi
  if ! curl -fsL --retry 3 -o "$tarball.sig" "$ALARM_URL.sig"; then
    warn "could not download $ALARM_URL.sig; skipping the signature check"
    return 0
  fi
  gh=$(mktemp -d)
  if ! gpg --homedir "$gh" --batch --quiet --keyserver "$ALARM_KEYSERVER" --recv-keys "$ALARM_KEY" >/dev/null 2>&1; then
    warn "could not fetch the Arch Linux ARM signing key from $ALARM_KEYSERVER; skipping the signature check"
    rm -rf "$gh"; return 0
  fi
  status=$(gpg --homedir "$gh" --batch --status-fd 1 --verify "$tarball.sig" "$tarball" 2>/dev/null || true)
  rm -rf "$gh"
  if grep -q "^\[GNUPG:\] VALIDSIG $ALARM_KEY" <<<"$status"; then
    note "GPG signature OK ($ALARM_KEY)"
  elif grep -q '^\[GNUPG:\] BADSIG' <<<"$status"; then
    die "BAD GPG signature on $tarball — do not use it (delete it and retry)"
  else
    warn "GPG signature could not be verified against $ALARM_KEY"
  fi
}

case $rootfs_state in
  arch)
    note "existing Arch rootfs found — reusing it (not re-extracting)" ;;
  other)
    if (( ! YES )); then
      die "$ROOTFS exists, is not empty and is not an Arch Linux ARM rootfs; move it away or re-run with --yes to have it renamed"
    fi
    backup="$ROOTFS.old-$(date +%Y%m%d-%H%M%S)"
    note "--yes: moving the existing $ROOTFS to $backup"
    run mv "$ROOTFS" "$backup"
    rootfs_state=missing ;;
  unknown)
    note "(cannot inspect $ROOTFS without root; showing a fresh install)" ;;
esac
if [[ $rootfs_state != arch ]]; then
  TARBALL=""
  fetch_rootfs
  run mkdir -p "$ROOTFS"
  run chmod 755 "$ROOTFS"
  run bsdtar -xpf "${TARBALL:-$CACHE_DIR/${ALARM_URL##*/}}" -C "$ROOTFS"
fi

# --- 5. inside the container -----------------------------------------------------------
log "5/7 configure the container (keyring, user, sudo, locale, base-devel)"
if machinectl show "$MACHINE" >/dev/null 2>&1; then
  warn "the $MACHINE container is running (Arch desktop active); configuring the rootfs alongside it"
fi

# Host device groups the container user needs by GID: the seatd socket group, and the
# groups owning /dev/dri/card* and /dev/dri/renderD*. The container has its own group
# table, so each host GID is matched to the container group with that GID, or a new
# "host<name>" group is created for it.
host_groups=()
for g in "$seat_group" video render input; do
  gid=$(getent group "$g" | cut -d: -f3 || true)
  [[ -n $gid ]] && host_groups+=("$g:$gid")
done
mapfile -t host_groups < <(printf '%s\n' "${host_groups[@]}" | awk -F: 'NF && !seen[$2]++')

# Runs inside the rootfs as root. Arguments: user uid gid group-name host-groups...
# shellcheck disable=SC2016  # expanded inside the container, not here
CONTAINER_SETUP='
set -euo pipefail
user=$1 uid=$2 gid=$3 gname=$4; shift 4
say() { printf "    [container] %s\n" "$*"; }

# pacman keyring: generate a local master key once, then trust the ALARM packagers.
if [[ ! -s /etc/pacman.d/gnupg/trustdb.gpg ]]; then
  say "initialising pacman keyring"
  pacman-key --init
fi
pacman-key --populate archlinuxarm >/dev/null

# The host runs the kernel; the rootfs kernel/firmware are dead weight and their
# mkinitcpio hooks cannot run in a container.
if pacman -Q linux-aarch64 >/dev/null 2>&1; then
  say "removing the unused kernel package"
  pacman -Rns --noconfirm linux-aarch64 || true
fi

say "pacman -Syu base-devel git sudo"
pacman -Syu --noconfirm --needed base-devel git sudo

# Locales: English UI, Chinese available for apps and input.
changed=0
for l in "en_US.UTF-8 UTF-8" "zh_CN.UTF-8 UTF-8"; do
  if ! grep -qx "$l" /etc/locale.gen; then
    sed -i "s/^#[[:space:]]*${l}[[:space:]]*\$/${l}/" /etc/locale.gen
    grep -qx "$l" /etc/locale.gen || echo "$l" >>/etc/locale.gen
    changed=1
  fi
done
if (( changed )) || ! locale -a 2>/dev/null | grep -qi "^zh_CN.utf8$"; then
  say "generating locales"
  locale-gen
fi
[[ -f /etc/locale.conf ]] || echo "LANG=en_US.UTF-8" >/etc/locale.conf

# The rootfs ships a default "alarm" user (UID/GID 1000 in the official tarball). If it
# occupies the host UID or GID, remove it so files in shared folders map 1:1.
if getent passwd alarm >/dev/null; then
  a_uid=$(id -u alarm); a_gid=$(id -g alarm)
  if [[ $a_uid == "$uid" || $a_gid == "$gid" ]]; then
    say "removing the default alarm user (UID $a_uid collides)"
    userdel -r alarm 2>/dev/null || userdel alarm
    getent group alarm >/dev/null && groupdel alarm || true
  fi
fi

# Primary group with the host GID.
if g=$(getent group "$gid"); then
  gname=${g%%:*}
elif getent group "$gname" >/dev/null; then
  gname=$user
  getent group "$gname" >/dev/null && { echo "group $gname exists with another GID" >&2; exit 1; }
  groupadd -g "$gid" "$gname"
else
  groupadd -g "$gid" "$gname"
fi

# Supplementary groups: wheel (sudo), seat, video, audio, input.
groups=(wheel seat video audio input)
for g in "${groups[@]}"; do getent group "$g" >/dev/null || groupadd -r "$g"; done
# Host device groups, matched by GID (see host/install.sh).
for hg in "$@"; do
  hname=${hg%%:*} hgid=${hg##*:}
  if g=$(getent group "$hgid"); then
    [[ $hgid == "$gid" ]] || groups+=("${g%%:*}")
  else
    getent group "host$hname" >/dev/null || groupadd -g "$hgid" "host$hname"
    groups+=("host$hname")
  fi
done
glist=$(IFS=,; echo "${groups[*]}")

if existing=$(getent passwd "$user"); then
  e_uid=$(cut -d: -f3 <<<"$existing")
  [[ $e_uid == "$uid" ]] || { echo "user $user exists in the container with UID $e_uid, host has $uid" >&2; exit 1; }
  usermod -g "$gid" -aG "$glist" "$user"
  say "user $user present; groups updated"
else
  if other=$(getent passwd "$uid"); then
    echo "UID $uid is taken in the container by ${other%%:*}" >&2; exit 1
  fi
  useradd -m -u "$uid" -g "$gid" -G "$glist" -s /bin/bash "$user"
  say "created user $user (UID $uid, GID $gid)"
fi
# No passwords: the launchers enter the container as the user directly. Root stays locked;
# set a password for the user (`passwd` inside the container) before relying on the lock screen.
passwd -l root >/dev/null

# sudo: members of wheel may run anything without a password. The installer and the
# Omarchy scripts call sudo non-interactively (pacman, makepkg -si, yay) and the user has
# no password yet. Tighten this (drop NOPASSWD) once you have set one.
cat >/etc/sudoers.d/10-wheel-nopasswd <<EOS
# omarchy-alarm-nspawn: passwordless sudo for wheel (see host/install.sh)
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
EOS
chmod 440 /etc/sudoers.d/10-wheel-nopasswd
visudo -cqf /etc/sudoers.d/10-wheel-nopasswd
'

nspawn_setup=(env SYSTEMD_NSPAWN_LOCK=0 systemd-nspawn -q -D "$ROOTFS" --register=no
  --resolv-conf=copy-host --console=pipe
  /bin/bash -c "$CONTAINER_SETUP" container-setup
  "$TARGET_USER" "$T_UID" "$T_GID" "$T_GROUP" "${host_groups[@]}")
if (( DRY_RUN )); then
  printf '  + SYSTEMD_NSPAWN_LOCK=0 systemd-nspawn -q -D %q --register=no --resolv-conf=copy-host --console=pipe \\\n' "$ROOTFS"
  printf '      /bin/bash -c <setup script> %q %q %q %q %s\n' "$TARGET_USER" "$T_UID" "$T_GID" "$T_GROUP" "${host_groups[*]}"
  note "setup script: pacman-key --init/--populate archlinuxarm; drop linux-aarch64;"
  note "  pacman -Syu base-devel git sudo; locales en_US.UTF-8 + zh_CN.UTF-8;"
  note "  remove 'alarm' if it holds UID/GID $T_UID/$T_GID; user $TARGET_USER $T_UID:$T_GID in"
  note "  wheel,seat,video,audio,input + host device groups (${host_groups[*]:-none});"
  note "  lock root; /etc/sudoers.d/10-wheel-nopasswd (%wheel NOPASSWD)"
else
  "${nspawn_setup[@]}" </dev/null
fi

# --- 6. launchers ----------------------------------------------------------------------
# install_user_file SRC DST MODE: install as the target user; keep a copy of a file that
# was not written by us (no omarchy-alarm-nspawn marker) before replacing it.
install_user_file() {
  local src=$1 dst=$2 mode=$3
  if [[ -f $dst ]] && cmp -s "$src" "$dst"; then
    note "unchanged: $dst"; return 0
  fi
  if [[ -f $dst ]] && ! grep -q 'omarchy-alarm-nspawn' "$dst"; then
    run cp -p "$dst" "$dst.orig-$(date +%Y%m%d-%H%M%S)"
  fi
  run install -D -m "$mode" -o "$T_UID" -g "$T_GID" "$src" "$dst"
}

ensure_user_dir() {
  local dir=$1
  [[ -d $dir ]] && return 0
  run install -d -o "$T_UID" -g "$T_GID" "$dir"
}

RENDERED=$(mktemp -d)
trap 'rm -rf "$RENDERED"' EXIT
render_all "$RENDERED"

log "6/7 launchers → $T_HOME/.local/bin"
ensure_user_dir "$T_HOME/.local"
ensure_user_dir "$T_HOME/.local/bin"
for name in "${LAUNCHERS[@]}"; do
  install_user_file "$RENDERED/bin/$name" "$T_HOME/.local/bin/$name" 755
done
(( DRY_RUN )) && note "preview the rendered files with: host/install.sh --render-only DIR --user $TARGET_USER --rootfs $ROOTFS"

# --- 7. display hook -------------------------------------------------------------------
log "7/7 weston.service drop-in"
if (( ! DISPLAY_HOOK )); then
  note "skipped (--no-display-hook); start the Arch desktop by hand with arch-hyprland"
else
  if ! systemctl cat --global weston.service >/dev/null 2>&1 && [[ ! -e /etc/systemd/user/weston.service && ! -e /usr/lib/systemd/user/weston.service ]]; then
    warn "no weston.service user unit on this host (not an Android Linux Terminal?); installing the drop-in anyway"
  fi
  dropdir=$T_HOME/.config/systemd/user/weston.service.d
  for d in "$T_HOME/.config" "$T_HOME/.config/systemd" "$T_HOME/.config/systemd/user" "$dropdir"; do
    ensure_user_dir "$d"
  done
  install_user_file "$RENDERED/systemd/weston.service.d/hyprland.conf" "$dropdir/hyprland.conf" 644
  if [[ -S /run/user/$T_UID/bus ]]; then
    run runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR="/run/user/$T_UID" systemctl --user daemon-reload
  else
    note "user manager not running; the drop-in applies at next login"
  fi
fi

# The launchers and the drop-in's ExecStopPost call sudo without a terminal.
if (( ! DRY_RUN )) && ! sudo -l -U "$TARGET_USER" 2>/dev/null | grep -q 'NOPASSWD'; then
  warn "$TARGET_USER has no passwordless sudo on this host; hypr-session/arch-hyprland need it (sudo -n) to start the container from weston.service"
fi

log "host side done"
note "enter the container:      archbox        (shell in the running desktop: archsh)"
note "use the Arch desktop:     hypr-switch arch --now   (back: hypr-switch debian --now)"
