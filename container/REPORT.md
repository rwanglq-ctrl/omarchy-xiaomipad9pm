# Container delivery report

Implemented the core/full manifests, reviewed configuration allowlist, three
runtime helpers, configuration-only Rime share overlay, 13-step container
installer and optional Hyprland 0.56.2 damage-clip backport. No live configuration,
host state, package installation, git commit or push was performed.

## Package verification

- `pacman -Si`: **149/149** repository names found on Arch Linux ARM aarch64:
  **112 core**, **37 additional full**.
- AUR v5 info RPC: **12/12** names found: **4 core**, **8 additional full**.
- No missing manifest entries. `vi` was replaced by available `ex-vi-compat`.
- Private explicit/foreign snapshots were deleted after derivation and validation.
- Details and verification date are in `packages/VERIFICATION.md`.
- Package-name existence was checked; real AUR builds were intentionally not run.

## Validation

- `bash -n` passed separately for the installer, each runtime helper and optional
  build script. ShellCheck was not installed on the reference machine.
- `bash container/install.sh --dry-run --profile full` returned 0 and listed all
  13 named steps. Four argument combinations passed with an isolated, nonexistent
  HOME and did not create it. Invalid/missing arguments returned 2.
- The uwsm compatibility helper preserved command arguments including spaces and
  rejected a missing option argument.
- Both exported ARM patches applied in order to pristine v4.0.4 source files
  extracted into a disposable repository under the owned container directory.
- The required config scan for owner identifiers, absolute home paths, at signs
  and Rime database references returned no matches.
- Every copied configuration file was reviewed. Private application shortcuts
  were removed; the generic host-run helper has no application-specific launch.
- Full real installation, graphical startup and AUR builds remain integration
  checks for a disposable target, because this task forbids changing the live host.

## Integration details

The Rime share overlay is under `container/config-share/`, within container
ownership. The optional mise switch is `OMARCHY_ALARM_INSTALL_MISE=1` together
with the full profile. The main installer never runs the optional compositor
build. The repository scanner initially reported the ordinary upstream foot
and kitty include paths, plus a Rime config path, as base64 false positives;
the scan was stopped after these findings and they were reported to its owner.
