# ARM 容器移植：mise 只有 x86 的 mise-bin，ALARM 和 AUR 都没有可编译的包，跳过。
if ! command -v mise >/dev/null 2>&1; then echo "跳过 $(basename "${BASH_SOURCE[0]}")：没有 mise"; return 0 2>/dev/null || exit 0; fi

# Setup default work directory (and tries)
mkdir -p "$HOME/Work"
mkdir -p "$HOME/Work/tries"
