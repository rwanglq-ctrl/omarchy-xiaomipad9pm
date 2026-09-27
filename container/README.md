# Container installation

Run `bash container/install.sh --dry-run --profile full` to review the steps.
Real installation requires a sudo-capable regular user in Arch Linux ARM aarch64;
root must pass `--user NAME`. The default profile is `core`. `full` adds the
applications in the two `*-full.txt` manifests to the corresponding core lists.
`--no-aur` skips yay and all AUR builds, and selects the stock Rime schema instead
of the unavailable rime-ice preset. No real install was run during development.

The installer logs real runs to `~/.cache/omarchy-alarm/install.log`. Repository
installation includes a full system upgrade. AUR packages run their upstream
PKGBUILDs as the regular user; review them before installation. Source and build
caches live below `~/.cache`, including Rust temporary files. The two packages
`tensaku` and `omawrite` explicitly use `makepkg --ignorearch` because their AUR
metadata lists x86_64 despite their portable source builds.

An existing Omarchy checkout must be at the pinned commit in `patches/BASE`.
The installer never resets it or discards local edits. Applied patch checksums
are recorded under `~/.local/state/omarchy-alarm`. Repeat runs preserve seeded
upstream defaults, reapply the explicit `config/` overlay, and append the shell
and makepkg blocks only once. The config overlay intentionally replaces its
listed target files; review it before installing onto an existing account.

Upstream `omarchy-provision-user` runs in headless provisioning mode, with Tokyo
Night as the initial theme. Existing provisioned users keep their current theme.
The user's bashrc is retained with a marked block based on the upstream default.
The local GSettings keyfile backend avoids writing through the host dconf service.
`config-share/fcitx5/rime/default.custom.yaml` is the only Rime share overlay;
no learned dictionaries or personal application profiles are included.

Stay-awake defaults to ON on every installer run. A locked or missing password
prints a warning. Set a password before using `omarchy toggle idle` or manually
locking the session. Host services and hardware configuration are not provisioned
here; desktop launch remains the host launcher's job.

Optional mise installation uses the official https://mise.run installer only when
`OMARCHY_ALARM_INSTALL_MISE=1` and `--profile full` are both supplied. It runs after
Omarchy provisioning, so installing mise does not implicitly install the user's
AI tools, wrappers or secrets. On a later provisioning retry, upstream scripts
may detect an existing mise installation and perform their standard setup.

`extras/build-hyprland-0562-fix.sh` is an optional llvmpipe performance backport,
never invoked by the installer. It requires the development tools and libraries
for Hyprland (including CMake, Ninja, Python and a C++ toolchain). Set `JOBS`,
`HYPRLAND_FIX_SOURCE` or `HYPRLAND_FIX_PREFIX` to override its defaults; the prefix
must be a dedicated absolute directory. Select its compositor explicitly in the
host launcher. Once the distro compositor includes the damage-clip fix (expected
in Hyprland 0.57 or newer), use `/usr/bin/Hyprland` and remove the dedicated prefix.
