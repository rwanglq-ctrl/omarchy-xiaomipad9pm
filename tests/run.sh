#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CACHE="$HOME/.cache/omarchy-alarm-tests"
mkdir -p "$CACHE"
export TMPDIR="$CACHE"
missing() {
  echo "Missing target/tool: $*"
  if [[ ${ALARM_TEST_ALLOW_MISSING:-0} == 1 ]]; then exit 77; fi
  exit 1
}
need() { [[ -e $ROOT/$1 ]] || missing "$1"; }
scripts() {
  find "$ROOT" -path "$ROOT/.git" -prune -o -type f \( -name '*.sh' -o -path "$ROOT/host/bin/*" -o -path "$ROOT/container/bin/*" \) -print0
}
names() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$@" | sort -u; }
check_syntax() {
  local f
  while IFS= read -r -d '' f; do bash -n "$f"; done < <(scripts)
}
check_shellcheck() {
  local checker f bad=0
  checker=$(command -v shellcheck || true)
  if [[ -z $checker && -x $CACHE/shellcheck-v0.11.0/shellcheck ]]; then checker="$CACHE/shellcheck-v0.11.0/shellcheck"; fi
  if [[ -z $checker ]]; then echo 'Optional ShellCheck unavailable (see tests/README.md)'; exit 78; fi
  while IFS= read -r -d '' f; do "$checker" -S warning -s bash "$f" || bad=1; done < <(scripts)
  return "$bad"
}
check_privacy() { need tools/privacy-scan.sh; bash "$ROOT/tools/privacy-scan.sh" "$ROOT"; }
check_privacy_selftest() { need tools/privacy-selftest.sh; bash "$ROOT/tools/privacy-selftest.sh"; }
check_patches() {
  need patches/BASE
  local base p
  base=$(tr -d '\n' < "$ROOT/patches/BASE")
  if [[ ! -d $CACHE/upstream/.git ]]; then
    work=$(mktemp -d "$CACHE/clone.XXXXXX")
    trap 'rm -rf -- "$work"' EXIT
    timeout 40 git clone --quiet --depth 1 --branch v4.0.4 https://github.com/basecamp/omarchy.git "$work"
    mv "$work" "$CACHE/upstream"
    trap - EXIT
  fi
  [[ $(git -C "$CACHE/upstream" rev-parse HEAD) == "$base" ]]
  work=$(mktemp -d "$CACHE/patches.XXXXXX")
  trap 'rm -rf -- "$work"' EXIT
  git -C "$CACHE/upstream" archive HEAD | tar -x -C "$work"
  git -C "$work" init --quiet
  local -a patches=("$ROOT"/patches/*.patch)
  [[ -f ${patches[0]} ]] || missing 'patches/*.patch'
  for p in "${patches[@]}"; do
    git -C "$work" apply --check "$p"
    git -C "$work" apply "$p"
  done
}
check_repo_packages() {
  need packages/repo-core.txt; need packages/repo-full.txt
  command -v pacman >/dev/null || missing pacman
  local -a pkgs
  mapfile -t pkgs < <(names "$ROOT"/packages/repo-*.txt)
  ((${#pkgs[@]} > 0))
  pacman -Si "${pkgs[@]}" >/dev/null
}
check_aur_packages() {
  need packages/aur-core.txt; need packages/aur-full.txt
  command -v python3 >/dev/null || missing python3
  python3 - "$ROOT" <<'PY'
import glob,json,sys,urllib.parse,urllib.request
names=set()
for path in glob.glob(sys.argv[1]+'/packages/aur-*.txt'):
    for line in open(path):
        name=line.split('#')[0].strip()
        if name: names.add(name)
assert names, 'AUR manifests are empty'
items=sorted(names)
for start in range(0,len(items),100):
    batch=items[start:start+100]
    query=urllib.parse.urlencode([('v','5'),('type','info')]+[('arg[]',x) for x in batch])
    with urllib.request.urlopen('https://aur.archlinux.org/rpc/?'+query,timeout=20) as response:
        result=json.load(response)
    assert result.get('type')=='multiinfo',result
    absent=set(batch)-{x['Name'] for x in result['results']}
    assert not absent, 'Missing AUR packages: '+', '.join(sorted(absent))
print('All AUR names exist')
PY
}
check_dry_runs() {
  need install.sh; need container/install.sh; need host/install.sh
  local forbidden
  work=$(mktemp -d "$CACHE/dry-run.XXXXXX")
  export TMPDIR="$work"
  trap 'rm -rf -- "$work"' EXIT
  printf 'ID=debian\nVERSION_ID=13\n' > "$work/debian"
  printf 'ID=archarm\nID_LIKE=arch\n' > "$work/arch"
  # Build the forbidden account string without embedding owner data in the repo.
  forbidden=$(printf '\144\162\157\151\144')
  for os in arch debian; do
    HOME="$work" OMARCHY_ALARM_OS_RELEASE="$work/$os" OMARCHY_ALARM_ARCH=aarch64 bash "$ROOT/install.sh" --dry-run --user testuser > "$work/root-$os.log" 2>&1
  done
  HOME="$work" bash "$ROOT/container/install.sh" --dry-run --profile core > "$work/core.log" 2>&1
  HOME="$work" bash "$ROOT/container/install.sh" --dry-run --profile full > "$work/full.log" 2>&1
  HOME="$work" OMARCHY_ALARM_OS_RELEASE="$work/debian" OMARCHY_ALARM_ARCH=aarch64 bash "$ROOT/host/install.sh" --dry-run --user testuser --rootfs /tmp/x > "$work/host.log" 2>&1
  python3 - "$ROOT" "$work" <<'PYCODE'
import glob,sys
for path in glob.glob(sys.argv[2]+'/*.log'):
    text=open(path).read().replace(sys.argv[1],'<repo>').replace(sys.argv[2],'<test-cache>')
    open(path,'w').write(text)
PYCODE
  if grep -Fw "$forbidden" "$work"/*.log; then echo 'Dry-run exposes owner account'; exit 1; fi
  HOME="$work" bash "$ROOT/host/install.sh" --render-only "$work/rendered" --user testuser --rootfs /tmp/x >/dev/null
  local f
  for f in "$work"/rendered/bin/*; do bash -n "$f"; done
}
check_lua() {
  need config/hypr/hyprland.lua
  local f
  if command -v luac >/dev/null; then
    while IFS= read -r -d '' f; do luac -p "$f"; done < <(find "$ROOT/config" -name '*.lua' -print0)
  elif command -v Hyprland >/dev/null && [[ -d $CACHE/upstream/config ]]; then
    work=$(mktemp -d "$CACHE/lua.XXXXXX")
    trap 'rm -rf -- "$work"' EXIT
    mkdir -p "$work/.config" "$work/runtime"
    chmod 700 "$work/runtime"
    cp -a "$CACHE/upstream/config/." "$work/.config/"
    cp -a "$ROOT/config/." "$work/.config/"
    env -i HOME="$work" PATH="$PATH" XDG_RUNTIME_DIR="$work/runtime" OMARCHY_PATH="$CACHE/upstream" Hyprland --verify-config -c "$work/.config/hypr/hyprland.lua"
  else missing 'luac (or Hyprland plus cached upstream)'; fi
}
check_hygiene() {
  local f target bad=0
  while IFS= read -r -d '' f; do
    if [[ -L $f ]]; then
      target=$(realpath -m -- "$f")
      case "$target" in "$ROOT"/*) ;; *) echo "External symlink: ${f#"$ROOT/"}"; bad=1 ;; esac
    elif [[ -f $f ]]; then
      if (( $(stat -c %s "$f") > 1000000 )); then echo "Oversize: ${f#"$ROOT/"}"; bad=1; fi
      case "$f" in *.bak*) echo "Backup: ${f#"$ROOT/"}"; bad=1 ;; esac
    fi
  done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -print0)
  return "$bad"
}
if [[ ${1:-} == --check ]]; then
  case "${2:-}" in syntax|shellcheck|privacy|privacy_selftest|patches|repo_packages|aur_packages|dry_runs|lua|hygiene) "check_$2" ;; *) exit 2 ;; esac
  exit 0
fi
mode=${1:---quick}
[[ $# -le 1 && ( $mode == --quick || $mode == --full ) ]] || { echo 'Usage: tests/run.sh [--quick|--full]' >&2; exit 2; }
start=$SECONDS
failed=0
rows=()
for check in syntax shellcheck privacy privacy_selftest patches repo_packages aur_packages dry_runs lua hygiene; do
  echo "=== $check ==="
  remaining=$((115 - (SECONDS - start)))
  status=FAIL
  if ((remaining > 0)); then
    set +e
    timeout --kill-after=1 "$remaining" bash "$0" --check "$check"
    rc=$?
    set -e
    case "$rc" in
      0) status=PASS ;;
      78) status=SKIP ;;
      77) status=SKIP; failed=1 ;;
      *) failed=1 ;;
    esac
  else echo 'Quick suite time budget exhausted'; failed=1; fi
  rows+=("$status $check")
done
if [[ $mode == --full ]]; then
  set +e
  bash "$ROOT/tests/full.sh"
  rc=$?
  set -e
  if ((rc == 0)); then rows+=('PASS integration'); else rows+=('FAIL integration'); failed=1; fi
fi
printf '\n%-6s %s\n' RESULT CHECK
for row in "${rows[@]}"; do read -r status check <<< "$row"; printf '%-6s %s\n' "$status" "$check"; done
printf 'Elapsed: %ss; exit: %s\n' "$((SECONDS - start))" "$failed"
exit "$failed"
