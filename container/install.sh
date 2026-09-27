#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile=core
dry_run=false
no_aur=false
target_user=''
usage() {
  echo 'Usage: container/install.sh [--dry-run] [--profile core|full] [--no-aur] [--user NAME]'
  echo 'Optional full profile: OMARCHY_ALARM_INSTALL_MISE=1 installs mise using its official installer.'
}
while (($#)); do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --no-aur) no_aur=true; shift ;;
    --profile|--user)
      (($# >= 2)) || { usage >&2; exit 2; }
      case "$1" in --profile) profile=$2 ;; --user) target_user=$2 ;; esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ $profile == core || $profile == full ]] || { usage >&2; exit 2; }

step() {
  local function=$1 description=$2
  printf '\n==> %s: %s\n' "$function" "$description"
  if ! $dry_run; then "$function"; fi
}
as_root() { sudo -- "$@"; }
packages() {
  local kind=$1
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$ROOT/packages/$kind-core.txt"
  if [[ $profile == full ]]; then
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$ROOT/packages/$kind-full.txt"
  fi
}
validate_environment() {
  [[ $(uname -m) == aarch64 && -f /etc/arch-release ]] || {
    echo 'This installer requires Arch Linux ARM aarch64.' >&2; exit 2;
  }
  sudo -v
  mkdir -p "$HOME/.cache/tmp" "$HOME/.cache/makepkg" "$HOME/.local/bin" "$HOME/.local/state/omarchy-alarm"
  export TMPDIR="$HOME/.cache/tmp"
  export OMARCHY_PATH="$HOME/.local/share/omarchy"
  export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"
}
install_repo_packages() {
  local -a names
  mapfile -t names < <(packages repo)
  # A full upgrade avoids unsupported Arch partial upgrades.
  as_root pacman -Syu --needed --noconfirm "${names[@]}"
}
configure_build_directories() {
  mkdir -p "$HOME/.config/pacman" "$HOME/.cache/makepkg" "$HOME/.cache/tmp"
  local file="$HOME/.config/pacman/makepkg.conf"
  touch "$file"
  if ! grep -q '^# BEGIN omarchy-alarm build$' "$file"; then
    {
      printf '\n# BEGIN omarchy-alarm build\n'
      cat "$ROOT/config/pacman/makepkg.conf"
      printf '# END omarchy-alarm build\n'
    } >> "$file"
  fi
}
install_aur_packages() {
  if $no_aur; then echo 'AUR disabled; Rime uses the packaged default schema.'; return; fi
  local buildroot="$HOME/.cache/omarchy-alarm/aur" package
  mkdir -p "$buildroot"
  if ! command -v yay >/dev/null 2>&1; then
    if [[ ! -d $buildroot/yay ]]; then git clone https://aur.archlinux.org/yay.git "$buildroot/yay"; fi
    (cd "$buildroot/yay" && makepkg --syncdeps --install --needed --noconfirm)
  fi
  while IFS= read -r package; do
    [[ $package != yay ]] || continue
    if pacman -Q "$package" >/dev/null 2>&1; then continue; fi
    case "$package" in
      tensaku|omawrite)
        if [[ ! -d $buildroot/$package ]]; then git clone "https://aur.archlinux.org/$package.git" "$buildroot/$package"; fi
        (cd "$buildroot/$package" && makepkg --ignorearch --syncdeps --install --needed --noconfirm) ;;
      *) yay -S --needed --noconfirm "$package" ;;
    esac
  done < <(packages aur)
}
clone_and_patch_omarchy() {
  local expected actual patch_file patch_id applied_ids
  expected=$(tr -d '\n' < "$ROOT/patches/BASE")
  if [[ ! -e $OMARCHY_PATH ]]; then
    git clone --branch v4.0.4 --depth 1 https://github.com/basecamp/omarchy.git "$OMARCHY_PATH"
  fi
  actual=$(git -C "$OMARCHY_PATH" rev-parse 'v4.0.4^{commit}')
  [[ $actual == "$expected" ]] || {
    echo 'Existing Omarchy checkout does not have the pinned base.' >&2; exit 1;
  }
  git -C "$OMARCHY_PATH" merge-base --is-ancestor "$expected" HEAD || {
    echo 'Existing Omarchy checkout is not based on the pinned release.' >&2; exit 1;
  }
  [[ -z $(git -C "$OMARCHY_PATH" status --porcelain) ]] || {
    echo 'Existing Omarchy checkout has local changes; preserve it before installing.' >&2; exit 1;
  }
  if git -C "$OMARCHY_PATH" show-ref --verify --quiet refs/heads/arm-port; then
    [[ $(git -C "$OMARCHY_PATH" branch --show-current) == arm-port ]] || {
      echo 'Existing arm-port branch is not checked out; refusing to switch user work.' >&2; exit 1;
    }
  else
    [[ $(git -C "$OMARCHY_PATH" rev-parse HEAD) == "$expected" ]] || {
      echo 'Refusing to create arm-port on an unrelated user commit.' >&2; exit 1;
    }
    git -C "$OMARCHY_PATH" switch -c arm-port
  fi
  for patch_file in "$ROOT"/patches/*.patch; do
    [[ -f $patch_file ]] || { echo 'No ARM patches found.' >&2; exit 1; }
    patch_id=$(git patch-id --stable < "$patch_file" | awk '{print $1}')
    applied_ids=$(git -C "$OMARCHY_PATH" log --pretty=format:%H -p "$expected..HEAD" | git patch-id --stable | awk '{print $1}')
    if ! grep -Fxq "$patch_id" <<< "$applied_ids"; then
      git -C "$OMARCHY_PATH" -c user.name=omarchy-alarm-nspawn -c user.email=noreply@example.com am "$patch_file"
    fi
  done
}

install_system_helpers() {
  if [[ -e /usr/share/omarchy && ! -L /usr/share/omarchy ]]; then
    echo '/usr/share/omarchy is a real directory; refusing to replace it.' >&2; exit 1
  fi
  as_root ln -sfnT "$OMARCHY_PATH" /usr/share/omarchy
  as_root install -Dm755 "$ROOT/container/bin/uwsm-app" /usr/local/bin/uwsm-app
}
seed_omarchy_config() {
  mkdir -p "$HOME/.config"
  # Seed missing defaults while retaining pre-existing user files.
  cp -a --update=none "$OMARCHY_PATH/config/." "$HOME/.config/"
}
install_config_overlay() {
  local file relative
  while IFS= read -r -d '' file; do
    relative=${file#"$ROOT/config/"}
    # This file is merged by configure_build_directories, not overwritten.
    [[ $relative != pacman/makepkg.conf ]] || continue
    install -Dm644 "$file" "$HOME/.config/$relative"
  done < <(find "$ROOT/config" -type f -print0)
  install -Dm755 "$ROOT/container/bin/fcitx5-autostart" "$HOME/.local/bin/fcitx5-autostart"
  install -Dm755 "$ROOT/container/bin/host-run" "$HOME/.local/bin/host-run"
}
configure_bashrc() {
  local rc="$HOME/.bashrc"
  touch "$rc"
  if ! grep -q '^# BEGIN omarchy-alarm shell$' "$rc"; then
    cat >> "$rc" <<'BASHRC'

# BEGIN omarchy-alarm shell
# Based on Omarchy default/bashrc, preserving the existing user file.
export OMARCHY_PATH="$HOME/.local/share/omarchy"
[[ -r "$OMARCHY_PATH/default/bash/env-bootstrap" ]] && source "$OMARCHY_PATH/default/bash/env-bootstrap"
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"
if [[ $- == *i* ]]; then
  source "$OMARCHY_PATH/default/bash/rc"
fi
# END omarchy-alarm shell
BASHRC
  fi
}
provision_user_headless() {
  # No graphical session or host dconf access; no copied identity or mise secrets.
  env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    OMARCHY_SETUP_CONTEXT=provision-owner OMARCHY_THEME_HEADLESS=1 \
    OMARCHY_USER_NAME='' OMARCHY_USER_EMAIL='' GSETTINGS_BACKEND=keyfile \
    "$OMARCHY_PATH/bin/omarchy-provision-user"
}
configure_input_and_fonts() {
  local rime="$HOME/.local/share/fcitx5/rime"
  mkdir -p "$rime" "$HOME/.config/glib-2.0/settings"
  install -m644 "$ROOT/container/config-share/fcitx5/rime/default.custom.yaml" "$rime/default.custom.yaml"
  if ! pacman -Q rime-ice-git >/dev/null 2>&1; then
    # --no-aur keeps working Chinese input with the stock librime schema.
    sed -i '/__include:/d; /schema: rime_ice/d' "$rime/default.custom.yaml"
  fi
  fc-cache -f
  # fcitx5 deploys these configuration files when the actual desktop starts.
}
configure_stay_awake() {
  mkdir -p "$HOME/.local/state/omarchy/indicators"
  touch "$HOME/.local/state/omarchy/indicators/stay-awake"
  local status
  status=$(as_root passwd -S "$(id -un)" | awk '{print $2}')
  if [[ $status == L || $status == LK || $status == NP ]]; then
    echo 'WARNING: Password is locked or unset. Do not lock the desktop; set a password before enabling idle locking.'
  fi
  echo 'Stay-awake is ON. After setting a password, use omarchy toggle idle to enable idle locking.'
  OMARCHY_INSTALL_USER=$(id -un) "$OMARCHY_PATH/bin/omarchy-apply-lock"
}
install_optional_mise() {
  if [[ $profile != full || ${OMARCHY_ALARM_INSTALL_MISE:-0} != 1 ]]; then
    echo 'Optional mise skipped (enable with full profile and OMARCHY_ALARM_INSTALL_MISE=1).'; return
  fi
  if [[ ! -x $HOME/.local/bin/mise ]]; then
    local installer="$HOME/.cache/omarchy-alarm/mise-installer.sh"
    curl --fail --show-error --location https://mise.run -o "$installer"
    MISE_INSTALL_PATH="$HOME/.local/bin/mise" bash "$installer"
  fi
}

if ! $dry_run; then
  if (( EUID == 0 )); then
    [[ -n $target_user && $target_user != root ]] || { echo 'Root must supply --user NAME.' >&2; exit 2; }
    args=(--profile "$profile")
    if $no_aur; then args+=(--no-aur); fi
    exec runuser -u "$target_user" -- env HOME="$(getent passwd "$target_user" | cut -d: -f6)" \
      OMARCHY_ALARM_INSTALL_MISE="${OMARCHY_ALARM_INSTALL_MISE:-0}" bash "$ROOT/container/install.sh" "${args[@]}"
  fi
  [[ -z $target_user || $target_user == "$(id -un)" ]] || { echo '--user must match the current user.' >&2; exit 2; }
  mkdir -p "$HOME/.cache/omarchy-alarm"
  exec > >(tee -a "$HOME/.cache/omarchy-alarm/install.log") 2>&1
fi
printf 'Omarchy ARM profile=%s dry-run=%s no-aur=%s\n' "$profile" "$dry_run" "$no_aur"
step validate_environment 'Check Arch Linux ARM, sudo access, and user build paths'
step install_repo_packages 'Install repository packages (core plus selected full extras)'
step configure_build_directories 'Set makepkg BUILDDIR and TMPDIR beneath HOME/.cache'
step install_aur_packages 'Bootstrap yay; install AUR packages; tensaku/omawrite use --ignorearch (unless --no-aur)'
step clone_and_patch_omarchy 'Clone upstream v4.0.4, verify patches/BASE, apply ARM patches once'
step install_system_helpers 'Link /usr/share/omarchy and install /usr/local/bin/uwsm-app'
step seed_omarchy_config 'Seed missing upstream configuration defaults'
step install_config_overlay 'Install reviewed config allowlist and fcitx5-autostart/host-run helpers'
step configure_bashrc 'Append marked Omarchy default bash configuration and bin PATH'
step provision_user_headless 'Run omarchy-provision-user headless; seed Tokyo Night theme'
step configure_input_and_fonts 'Install configuration-only Rime presets, local keyfile backend, CJK fonts'
step configure_stay_awake 'Default stay-awake ON, configure lock PAM, warn for locked passwords'
step install_optional_mise 'Optionally install mise from its official installer in full profile'
echo 'Container setup complete. Start the desktop using the host launcher.'
