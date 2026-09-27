# Package verification

Checked 2026-09-27 on Arch Linux ARM aarch64 using the configured pacman sync databases (read-only `pacman -Si`, no database refresh).

- Repository: 149/149 found (112 core, 37 additional full).
- AUR RPC: 12/12 found (4 core, 8 additional full), via https://aur.archlinux.org/rpc/v5/info.
- No missing names; existence does not guarantee a future build succeeds.
- `tensaku` and `omawrite` require source builds with `makepkg --ignorearch`.
- Derived from v4.0.4 `install/omarchy-base.packages`, the port notes, and explicit/foreign reference snapshots; snapshots deleted after verification.
- `omarchy-other.packages` is excluded because it provisions boot, kernels, firmware and host hardware.
- `vi` is unavailable in the reference sync database; `ex-vi-compat` is used instead.
- The core AUR manifest includes yay, which the installer bootstraps first.
