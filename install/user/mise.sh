# Build the lazy shims for Omarchy's default tools and the account dispatchers,
# both declared by /etc/mise/conf.d, without resolving versions over the network.
# ARM 容器移植：mise 只有 x86 的 mise-bin，ALARM 和 AUR 都没有可编译的包，跳过。
if ! command -v mise >/dev/null 2>&1; then echo "跳过 $(basename "${BASH_SOURCE[0]}")：没有 mise"; return 0 2>/dev/null || exit 0; fi
MISE_OFFLINE=true mise reshim --system
MISE_OFFLINE=true mise reshim
