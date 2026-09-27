#!/usr/bin/env bash
# install.sh — one-click entry for omarchy-alarm-nspawn.
#
#   curl -fsSL https://raw.githubusercontent.com/rwanglq-ctrl/omarchy-xiaomipad9pm/main/install.sh | bash
#   ./install.sh [--dry-run] [--user NAME] [--profile core|full] [--yes]
#
# Debian 13 aarch64 (Android Linux Terminal host):
#   host/install.sh prepares the host and the Arch Linux ARM container, then this repo is
#   copied into the container (/opt/omarchy-alarm-nspawn) and container/install.sh runs
#   inside it as the user.
# Arch Linux ARM (already inside the container): container/install.sh only.
# Anything else: error, exit 2.
#
# Extra options passed through: --rootfs DIR, --no-display-hook, --no-home-binds (host),
# --no-aur (container). Environment: OMARCHY_ALARM_REPO / OMARCHY_ALARM_REF select what a
# piped (curl | bash) run clones.

set -euo pipefail

# Everything lives in functions called on the last line, so a piped script is read in full
# before anything runs (and nothing below can swallow the rest of it from stdin).

REPO_URL=${OMARCHY_ALARM_REPO:-https://github.com/rwanglq-ctrl/omarchy-xiaomipad9pm}
REPO_REF=${OMARCHY_ALARM_REF:-main}
CONTAINER_REPO=/opt/omarchy-alarm-nspawn

log()  { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit "${2:-1}"; }

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--user NAME] [--profile core|full] [--yes]
                  [--rootfs DIR] [--no-display-hook] [--no-home-binds] [--no-aur]

  --dry-run          print what would be done; change nothing
  --user NAME        desktop user (default: the invoking user)
  --profile P        core = Omarchy desktop + Chinese input; full = core + extra apps
  --yes              allow host/install.sh to move aside a non-Arch directory at --rootfs
  --rootfs DIR       container rootfs on a Debian host (default: /var/lib/machines/arch)
  --no-display-hook  Debian host: do not hook the Android Terminal display (weston.service)
  --no-home-binds    Debian host: do not share ~/Downloads ~/Pictures ~/Videos ~/Work
  --no-aur           container: skip yay and AUR packages
EOF
}

# q ARGS...: shell-quoted command line for display.
q() { printf ' %q' "$@"; }

# Locate the checkout this script belongs to, or clone one when run from a pipe.
find_repo() {
  local src=${BASH_SOURCE[0]:-} dir
  if [[ -n $src && -f $src ]]; then
    dir=$(cd "$(dirname "$src")" && pwd)
    if [[ -f $dir/host/install.sh && -d $dir/container ]]; then
      REPO_DIR=$dir
      return 0
    fi
  fi
  [[ -z ${OMARCHY_ALARM_BOOTSTRAPPED:-} ]] || die "bootstrapped checkout is incomplete (no host/install.sh)"
  bootstrap "$@"
}

bootstrap() {
  local tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-alarm-nspawn.XXXXXX")
  log "not running from a checkout; fetching $REPO_URL ($REPO_REF) into $tmp"
  if command -v git >/dev/null; then
    git clone --quiet --depth 1 --branch "$REPO_REF" "$REPO_URL" "$tmp/repo"
  elif command -v curl >/dev/null; then
    mkdir -p "$tmp/repo"
    curl -fsSL "$REPO_URL/archive/$REPO_REF.tar.gz" | tar -xz --strip-components=1 -C "$tmp/repo"
  else
    die "need git or curl to fetch $REPO_URL"
  fi
  [[ -f $tmp/repo/install.sh ]] || die "fetched repo has no install.sh"
  export OMARCHY_ALARM_BOOTSTRAPPED=1
  # Give the real run a terminal again (stdin was the piped script) when there is one.
  if { exec 3</dev/tty; } 2>/dev/null; then
    exec bash "$tmp/repo/install.sh" "$@" <&3 3<&-
  fi
  exec bash "$tmp/repo/install.sh" "$@" </dev/null
}

detect_os() {
  local rel=${OMARCHY_ALARM_OS_RELEASE:-/etc/os-release} id ver like
  local arch=${OMARCHY_ALARM_ARCH:-$(uname -m)}
  [[ -r $rel ]] || die "cannot read $rel to detect the OS" 2
  # shellcheck disable=SC1090
  id=$(. "$rel" && echo "${ID:-}")
  # shellcheck disable=SC1090
  ver=$(. "$rel" && echo "${VERSION_ID:-}")
  # shellcheck disable=SC1090
  like=$(. "$rel" && echo "${ID_LIKE:-}")
  if [[ $id == debian && $arch == aarch64 ]]; then
    [[ $ver == 13 ]] || die "Debian $ver is not supported; this needs Debian 13 (trixie) aarch64" 2
    OS=debian
  elif [[ $arch == aarch64 && ( $id == archarm || $id == arch || $like == arch ) ]]; then
    OS=archarm
  else
    die "unsupported system: ${id:-unknown} ${ver} on $arch. Supported: Debian 13 aarch64 (host) or Arch Linux ARM aarch64 (container)" 2
  fi
}

main() {
  local dry=0 yes=0 user="" profile="" rootfs=/var/lib/machines/arch
  local host_extra=() container_extra=()
  local all_args=("$@")
  while (( $# )); do
    case "$1" in
      --dry-run) dry=1 ;;
      --yes|-y) yes=1 ;;
      --user) [[ $# -ge 2 ]] || die "--user needs a value"; user=$2; shift ;;
      --user=*) user=${1#*=} ;;
      --profile) [[ $# -ge 2 ]] || die "--profile needs a value"; profile=$2; shift ;;
      --profile=*) profile=${1#*=} ;;
      --rootfs) [[ $# -ge 2 ]] || die "--rootfs needs a value"; rootfs=$2; shift ;;
      --rootfs=*) rootfs=${1#*=} ;;
      --no-display-hook|--no-home-binds) host_extra+=("$1") ;;
      --no-aur) container_extra+=("$1") ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "unknown option: $1" 2 ;;
    esac
    shift
  done
  if [[ -n $profile && $profile != core && $profile != full ]]; then
    die "--profile must be core or full" 2
  fi
  [[ -n $profile ]] && container_extra=(--profile "$profile" "${container_extra[@]}")

  REPO_DIR=""
  find_repo "${all_args[@]}"
  detect_os
  (( dry )) && log "DRY RUN — nothing will be changed"
  log "repo: $REPO_DIR"
  log "system: $OS"

  if [[ $OS == archarm ]]; then
    run_container_local "$dry" "$user" "${container_extra[@]}"
  else
    run_debian "$dry" "$yes" "$user" "$rootfs" "${#host_extra[@]}" "${host_extra[@]}" "${container_extra[@]}"
  fi
}

# Already inside Arch Linux ARM: container/install.sh only.
run_container_local() {
  local dry=$1 user=$2; shift 2
  local cmd=(bash "$REPO_DIR/container/install.sh")
  (( dry )) && cmd+=(--dry-run)
  [[ -n $user ]] && cmd+=(--user "$user")
  cmd+=("$@")
  log "container plan: Omarchy on Arch Linux ARM"
  printf '  +%s\n' "$(q "${cmd[@]}")"
  if [[ ! -f $REPO_DIR/container/install.sh ]]; then
    if (( dry )); then
      warn "container/install.sh is not in this checkout yet; nothing more to show"
      return 0
    fi
    die "container/install.sh is missing from $REPO_DIR"
  fi
  "${cmd[@]}"
}

# Debian host: host side first, then the container side inside the new rootfs.
run_debian() {
  local dry=$1 yes=$2 user=$3 rootfs=$4 nhost=$5; shift 5
  local host_extra=("${@:1:$nhost}") container_extra=("${@:$((nhost + 1))}")
  if [[ -z $user ]]; then
    if [[ $EUID -eq 0 ]]; then
      user=${SUDO_USER:-}
      [[ -n $user && $user != root ]] || die "running as root: pass --user NAME (your desktop user)"
    else
      user=$(id -un)
    fi
  fi
  local sudo=()
  [[ $EUID -eq 0 ]] || sudo=(sudo)

  local host_cmd=(bash "$REPO_DIR/host/install.sh" --user "$user" --rootfs "$rootfs" "${host_extra[@]}")
  (( yes )) && host_cmd+=(--yes)
  log "host side"
  if (( dry )); then
    "${host_cmd[@]}" --dry-run
  else
    "${sudo[@]}" "${host_cmd[@]}"
  fi

  local chome=/home/$user
  local nspawn=("${sudo[@]}" env SYSTEMD_NSPAWN_LOCK=0 systemd-nspawn -q -D "$rootfs" --register=no
    --resolv-conf=copy-host -u "$user" --chdir="$chome"
    --setenv=HOME="$chome" --setenv=LANG=en_US.UTF-8 --setenv=TERM="${TERM:-xterm-256color}")
  [[ -t 0 ]] || nspawn+=(--console=pipe)
  nspawn+=(bash "$CONTAINER_REPO/container/install.sh" "${container_extra[@]}")

  log "copy this repo into the container: $rootfs$CONTAINER_REPO"
  if (( dry )); then
    printf '  + rm -rf %q && mkdir -p %q\n' "$rootfs$CONTAINER_REPO" "$rootfs$CONTAINER_REPO"
    printf '  + tar -C %q --exclude=.git -cf - . | tar -C %q -xf -\n' "$REPO_DIR" "$rootfs$CONTAINER_REPO"
    log "container side (as $user inside the container)"
    printf '  +%s\n' "$(q "${nspawn[@]}")"
    note "(the container plan itself can be previewed inside Arch with: install.sh --dry-run)"
    return 0
  fi
  # Never let an empty variable turn this into rm -rf of a host directory.
  [[ -n "$rootfs" && "$rootfs" != / && "$CONTAINER_REPO" == /opt/?* ]] \
    || die "refusing to replace '$rootfs$CONTAINER_REPO'"
  "${sudo[@]}" rm -rf "$rootfs$CONTAINER_REPO"
  "${sudo[@]}" mkdir -p "$rootfs$CONTAINER_REPO"
  tar -C "$REPO_DIR" --exclude=.git -cf - . | "${sudo[@]}" tar -C "$rootfs$CONTAINER_REPO" --no-same-owner -xf -
  "${sudo[@]}" chmod -R a+rX "$rootfs$CONTAINER_REPO"

  log "container side (as $user inside the container)"
  "${nspawn[@]}"

  log "done"
  note "switch the display to the Arch desktop: hypr-switch arch --now"
  note "shell in the container: archbox (or archsh while the Arch desktop runs)"
}

main "$@"
