# Changelog

## 0.2.12 — 2026-10-19

- Port the ARM container lock-screen IME fix as `patches/0007`: add
  `omarchy-lock-ime` and call it from the Quickshell lock service, turning
  fcitx5 off when the session lock engages and restoring the previous input
  state after unlock. Rime pinyin preedit no longer swallows lock-screen
  password input. The helper is a no-op when `fcitx5-remote` is missing.
- Keep the pinned upstream Omarchy v4.0.4 base and all v0.2.11 behaviour
  (tmux-protected install, CN mirrors, keyboard defaults, both profiles).

## 0.2.11 — 2026-10-15

- Run Debian one-click installation inside the named `omarchy-install` tmux
  session before cloning or long host/container work. Install missing tmux
  with noninteractive apt, using temporary signed mainland sources in CN mode.
  Terminal standby or SSH disconnection no longer kills the installer process;
  VM shutdown/reboot still requires rerunning it.
- Reconnect to an existing session, switch clients from another tmux session,
  and continue inline when already inside the installation session. Carry
  tmux context through sudo to avoid nesting. Piped bootstrap and its checkout
  cleanup now belong to the protected process. Preserve install arguments and
  settings when an older tmux server is already running.
- Append stdout/stderr to `~/.local/state/omarchy-alarm/install.log`, retain
  the completion status and a shell, and print Chinese/English reattach and
  log-follow instructions. Dry runs and render-only previews never enter tmux.
- Preserve v0.2.10 keyboard defaults and safe input.lua upgrades, CN omissions
  of omp/cursor-agent, Gitee assets, and both installation profiles.
- Add install-session regressions and keep bootstrap/stdin regression coverage.
  Validation: `tests/run.sh --full` passed 12/12 checks in 1377 seconds (exit 0),
  including fresh ARM64 installation and second-run idempotence. Real Debian
  Pad tmux 3.5a verifies auto-attach, reconnect, session reuse, sudo continuity
  and continued work after the initiating SSH connection ends. See [v0.2.11 validation](docs/v0.2.11-validation.md) for release evidence.
- Model roles: Codex **gpt-6-astra**, effort **high**, implementation lead;
  pi **xiaomi/mimo-v2.6-pro-ultraspeed**, real pre-change bootstrap/session
  analysis and patch review; Claude Code **claude-opus-5-5**, independent
  final-diff review with `--permission-mode bypassPermissions`. Logs:
  `~/work/v0211-run/mimo-logs/v0211-analysis.log`, `v0211-review.log`, and
  `v0211-claude-review.log`. Analysis findings on checkout lifetime, sudo
  environment loss, stdin safety, exact session matching and dry-run purity
  are addressed. Both follow-up reviews found no code blockers; zero-argument
  and PTY attach errors, stale server settings and early logging were fixed.

## 0.2.10 — 2026-10-15

- Default to `kb_options = "caps:super,compose:ralt"`: Caps Lock acts as Super,
  Right Alt as Compose. Caps cannot serve both roles. Keep
  `shift:both_capslock_cancel` excluded so fcitx5 receives Shift to switch IME.
- Upgrade only byte-identical known defaults, including the released v0.2.9
  `compose:caps` file even when its recorded baseline is missing. Preserve
  user edits and symlinks; write the new default to
  `~/.local/state/omarchy-alarm/input.lua.dist` for manual merging.
  Recognize the current default after baseline loss as well.
- Clarify in both README languages that `MIRROR=cn` skips omp (oh-my-pi) and
  cursor-agent; rerun the installer globally without `MIRROR=cn` to add them.
  Document Caps Lock / Right Alt defaults and retain one troubleshooting link.
- Add the frozen v0.2.9 fixture and regressions for upgrades without a baseline,
  modified defaults, symlinks and `.dist` contents; retain the Shift-option ban.
- Validation: `tests/run.sh --full` passed all 12 checks (1491 seconds, exit 0),
  including fresh ARM64 installation and second-run idempotence. Test Pad CN
  reinstall preserved the hand-applied input file and wrote the correct `.dist`;
  native temporary HOME verified v0.2.9 and upstream upgrades. After an explicit
  live backup and option-only edit, Hyprland had no config errors and real
  Wayland left/right Shift toggled English → Chinese → English.
  See [v0.2.10 validation](docs/v0.2.10-validation.md).
- Model roles: Codex **gpt-6-astra**, effort **high**, implementation lead;
  pi **xiaomi/mimo-v2.6-pro-ultraspeed**, pre-change code-path/upgrade analysis
  and patch review; Claude Code **claude-opus-5-5**, independent final-diff
  review with `--permission-mode bypassPermissions`. Logs:
  `~/work/v0210-run/mimo-logs/v0210-analysis.log`, `v0210-review.log`, and
  `v0210-claude-review.log`. Analysis findings on lost baselines, `.dist`
  assertions and obsolete keyboard wording are addressed. Both code reviews
  found no release blockers; final evidence and documentation were reviewed.

## 0.2.9 — 2026-10-15

- Both core and full install mise plus the reference Pad’s Claude Code, Codex,
  pi, opencode, herdr, crush and gh versions as programs.
  oh-my-pi and Cursor Agent remain global-only: CN explicitly reports their quota skips
  and the exact later-install command, preserving any existing copy.
  README retains its generic inventory by request; its omp/cursor version
  examples are unavailable on a fresh CN install until installed globally.
  Node/npm move into core; herdr uses its available aarch64 prebuilt release.
- Register verified program prefixes with mise link and provide commands in
  ~/.local/bin, without writing mise/AI config, credentials, keys or tokens.
  Preserve existing commands with backups and existing AI settings unchanged.
  An append-only upstream patch disables mise provisioning in both modes and
  skips skill links and pi theme seeding during installer finalization.
- CN uses Gitee for this repo, npmmirror for npm artifacts, operator-owned Gitee
  release assets for pinned release binaries. Enforce download
  and redirect host allowlists and verify pinned SHA256/SHA512; no GitHub
  fallback. All pi dependencies are pinned and verified before offline npm
  installation with lifecycle scripts disabled. Global programs use upstream sources; desktop source snapshots use Gitee in both modes.
- Optional program failures produce per-tool status and never stop desktop
  installation. Cached downloads are reverified; repeated installs reuse
  completed prefixes. Resume verified large downloads on slow links and avoid
  fetching optional npm binaries for incompatible platforms. Split oversized
  Gitee assets into verified parts, then verify the reconstructed original.
  Track the full
  reference inventory in docs/packages.md.
- Extend regressions for forbidden CN hosts/redirects, corrupt downloads,
  traversal, protected user files, optional failures and offline npm; fresh
  full integration checks the programs-only boundary. README remains an
  installation/usage guide with its single troubleshooting link.
- Extend the program inventory to every active gold Pad mise tool, including
  pi 1.2.0 from @earendil-works/pi-coding-agent (earendil-works/pi).
- Create Work and standard XDG directories without overwriting user files or
  directory preferences. Add available ALARM desktop packages and the full
  JetBrains Nerd font fallback; build Yaru from a verified source bundle when
  the repository package is unavailable.
- Add verified Gitee source bundles for yay and requested AUR desktop tools,
  and an absent-only LazyVim starter with pinned local plugins and automatic
  network updates disabled. tree-sitter-cli uses its ALARM repository package.
- Fix source-bundle makepkg verification by removing obsolete empty architecture
  arrays while retaining verified top-level SHA256 inputs. Generate Yaru GTK
  color prerequisites and package only icons/cursors. Repeat named optional
  failures in the final installer summary, including failed helper processes.
- Ship generic Pad input/display/llvmpipe defaults, isolated session environment,
  fcitx5 + pinned public rime-ice, SC fonts/OCR, portal and lock-IME helpers,
  window rules, qalculate and herdr bindings. Preserve existing IME preferences.
  Remote access/VNC/upgrades stay manual opt-ins; document unvalidated Hyprland
  damage-clip builds as a known item. README unchanged by these tweaks.
- Fix lock-IME reset using the compositor lock probe (0.56 has no lock IPC
  event); launch the desktop with a private D-Bus session for portals/fcitx5.
  Preserve existing rime-ice-git packages on global upgrades.
- Fix installer input defaults to `compose:caps` so fcitx5 receives Shift;
  preserve edited/symlinked input.lua and update only unchanged defaults.
  Deploy Rime schemas explicitly, upgrading only the exact installer fallback
  to rime_ice first plus luna_pinyin_simp; report deploy failures in the final
  summary. Add fresh/repeat/custom/symlink/failure regression coverage.
- Mirror ghui's verified ARM64 package to Gitee because npmmirror returns 404.
  Support reviewed per-asset/per-part Gitee base URLs with repository-scoped
  redirects; preserve whole-file and split-part checksums.
- Validation: final `tests/run.sh --full` passed all 12 checks, including fresh
  ARM64 installation and second-run idempotence. Real Pad CN core reinstall
  passed all 22 included tool provenance/version checks, package/tweak checks,
  native Rime migrations and live Shift toggle; 169 protected paths unchanged.
  Evidence: [v0.2.9 validation](docs/v0.2.9-validation.md).
- Mandatory process/provenance: Codex **gpt-6-astra** implementation; pi
  **xiaomi/mimo-v2.6-pro-ultraspeed** design and patch review in
  `/tmp/mimo-logs/v029-design.log` and `v029-patch-review.log`; independent
  Claude Code **claude-opus-5-5** review (`claude -p --model claude-opus-5-5
  --permission-mode bypassPermissions`) in `v029-claude-review.log`. Final IME follow-up and test-closure reviews also passed; all findings
  resolved before release. Raw local review logs are not bundled.

## 0.2.8 — 2026-10-15

- Root cause, confirmed on the failing Pad itself: the staged
  `/opt/debian-mesa/lib/libLLVM.so.19.1` had been truncated to exactly 104 MiB
  (the host file is about 117.5 MiB).
  - Loading it raised SIGBUS while Aquamarine created the GBM allocator.
  - SIGBUS leaves no crash report, and the end of the buffered hyprland.log was
    lost.
  - start-hyprland printed `Couldn't waitpid … No child processes` and
    "exit cleanly".
  - Pad A/B with one change per run: baseline failed; Arch Mesa only passed;
    repairing only that file passed.
- Staging is now durable and self-repairing:
  - every library and JSON file is fsynced;
  - the stage is verified before it is published;
  - a damaged cache is replaced by a new generation through an atomic symlink
    switch, and the damaged copy is removed only afterwards;
  - temporaries left by a killed install are cleaned up.
  - v0.2.7 refused the damaged cache on every reinstall.
- Each launch verifies the staged Mesa with `arch-mesa-check --verify`
  (libraries and EGL vendor file, about 0.3 s). If the copy is damaged or cannot
  be verified, the launch logs `stage=debian-mesa-damaged` or `-unverified` and
  uses Arch Mesa.
- `arch-diag` now begins with `hyprland-signal-death` and the Mesa integrity
  result.
- Bootstrap: a failing inner installer no longer prints
  `tmp: unbound variable`, hides its status or leaks its checkout.
- Verified on the Pad by installing the release tree over the damaged state:
  - the installer repaired the cache;
  - `arch-selftest` reached `output-ready`;
  - the real `weston.service` path reached `output-ready`;
  - a grim capture shows the wallpaper and bar;
  - DRM debugfs shows Hyprland's framebuffer on an active CRTC.
  See [validation](docs/v0.2.8-validation.md).
- Provenance:
  - Claude Code **claude-opus-5-5** (lead): Pad evidence, root cause, A/B, fix
    and Pad verification.
  - pi **xiaomi/mimo-v2.6-pro-ultraspeed**: signal analysis in
    `/tmp/mimo-logs/v028-mimo-signal-analysis.log`, patch review in
    `v028-mimo-patch-review.log` (5 findings plus 2 minor, all fixed).
  - Codex **gpt-6-astra**: independent review in `v028-codex-review.log`
    (2 P2 findings, fixed) and `v028-codex-review-2.log`.
  - Raw local logs are not bundled.

## 0.2.7 — 2026-10-14

- Keep README limited to installation and usage in Chinese and English; retain
  exactly one relative troubleshooting link, keep investigation history in
  CHANGELOG/docs and guard against narrative regressions.
- Correct the misleading registration-failed diagnosis: it meant the launcher
  exited before readiness without an observed Leader, not a machined rejection.
  Retain the raw exit status and registration observations; do not hide early exits.
- Record launch choices in every launch mode, plus attempt version/PID/script hashes.
  v0.2.6 had removed the renderer message globally, including normal sessions.
- Separate current stages, diagnostic snapshots and historical journals; list
  previous attempts by path and collect bounded persistent crash reports.
- Print the exact selftest evidence path after display restoration, even when
  restoration creates a newer normal-session log. Preserve stop/restore behavior.
- Regress delayed registration across multiple checks in all launch modes,
  Welcome followed by exits 0/1/7 between polls, renderer evidence, crash report
  mtimes and mixed historical evidence. CN/Gitee routing remains unchanged.
- Both photographed attempts exited in about one second. The launcher lifecycle
  and label defect are established; the physical Pad's inner compositor/watchdog
  exit reason remains unproven. See [evidence and limits](docs/v0.2.7-validation.md).
- Provenance: Codex **gpt-6-astra**; pi **xiaomi/mimo-v2.6-pro-ultraspeed**
  analysis/review in `/tmp/mimo-logs/v027-analysis.log`,
  `v027-analysis-addendum.log`, `v027-review.log`, `v027-review-final.log`,
  `v027-review-release.log`, `v027-review-readme.log`;
  Claude Code **claude-opus-5-5** review in
  `/tmp/mimo-logs/v027-claude-review.log`. Raw local logs are not bundled.

## 0.2.6 — 2026-10-14

- Make `arch-selftest` stop weston.socket before weston.service, wait for the
  session lock/seat, report live owners, clear dead PID metadata under flock,
  and restore both display units after success, failure or handled signals.
- Preserve systemd's activation socket across session logging and Weston
  fallback; close the session lock in the logger and container launcher.
- Probe in the container's explicit mount/PID namespace, root and working
  directory as the configured UID. Verify the command socket and live process,
  pass the instance signature explicitly, and fall back to socket/lock discovery
  when `hyprctl instances` fails. Record bounded probe progress.
- Capture runtime mount/permissions, sockets and real Hyprland logs inside the
  container before other diagnostics and teardown. Preserve host log retrieval
  when the container has already exited or namespace entry fails.
- Prevent direct DRM startup from connecting to the idle weston.socket as a
  parent Wayland compositor. A VM backtrace confirmed the startup roundtrip
  blocked before Hyprland created its command socket. Client environments use
  Hyprland's own socket after startup.
- Test the real gate and selftest with connected outputs flipping Virtual-2 to
  Virtual-1, discovery failures, activation races, stale/live locks, restoration
  and signals, including a watchdog restart gap and an abandoned event socket.
- Align with newly collected same-Pad gold evidence: stage Debian 13 Mesa/LLVM
  from apt-installed files with package/source versions and SHA256 provenance;
  preserve Arch packages and allow opt-out. Debian 13 arm64 is the supported
  host; the new dependency set does not support Debian 12. Use driver autodetection without
  forced AQ/LIBGL defaults. Clear parent Wayland variables and privately mask
  the idle host wayland-0 socket, preserving host fallback activation.
- Select the matching watchdog, libraries and probe client for an explicit
  custom prefix. Default remains distro Hyprland; the reference's custom 0.55
  dependency/build provenance is incomplete, so no unknown binaries are shipped.
  Physical Pad validation remains outstanding; arm64 VM startup/selftest pass
  with distro 0.56.2 plus Debian Mesa 25.0.7.
- CN continues to clone Gitee; only origin is pushed by this release task.
- Provenance: Codex **gpt-6-astra** implementation and validation; pi
  **xiaomi/mimo-v2.6-pro-ultraspeed** analysis and review in
  `/tmp/mimo-logs/v026-analysis.log`, `/tmp/mimo-logs/v026-pad-analysis.log`,
  `/tmp/mimo-logs/v026-ipc-analysis.log`,
  `/tmp/mimo-logs/v026-reference-diff.log`, `/tmp/mimo-logs/v026-review.log`,
  `/tmp/mimo-logs/v026-review-followup.log`, `v026-gold-diff.log`,
  `v026-gold-review.log`, `v026-gold-final-review.log`; independent Claude **claude-opus-5-5** review
  in `/tmp/mimo-logs/v026-claude-review.log` and
  `/tmp/mimo-logs/v026-claude-followup.log` and `v026-claude-review-3.log`. Local raw logs are not bundled.


## 0.2.5 — 2026-10-14

- Initialize a stable container machine ID before nonboot nspawn startup. The
  empty ALARM identity caused a reproduced D-Bus/Quickshell crash loop.
- Qualify Omarchy shell color references to resolve the reproduced Qt 6.12
  `QtQuick.Color` collision, restoring the themed bar, menus and notifications.
- Persist each launch's stdout/stderr, stage timestamps, actual runtime logs,
  shell log and journals before cleanup. Add foreground `arch-selftest`, private
  reports, explicit missing-log markers and post-teardown log retrieval.
- Use Linux uptime for readiness/cleanup deadlines, independent of wall-clock
  corrections; validate machine-ID bytes before shell substitution.
- Bound owned-session cleanup and signal handling; refuse competing sessions
  and suppress Weston fallback when cleanup cannot prove the machine is gone.
  Check sudo, required bind sources, seat socket and launcher before nspawn.
- Install missing Git through Debian apt, clone then check out branches/tags/full
  SHAs, and remove archive fallback. Resolve auto mirrors before fetching; keep
  piped dry runs offline. Add host prerequisites and device-group mapping.
- Expand bootstrap, identity, display and lifecycle regressions, installed
  Qt/Quickshell checks and second-install identity comparisons. Document the
  real ARM VM reproduction and its Android/crosvm fidelity limits. The Pad's
  original automatic fallback remains undiagnosed; no verified Pad fix claimed.
- Address independent review: reject leading-newline identities and linked check
  paths, retry registry queries, honor stops during cleanup, bound session logs
  to 8 MiB/ten attempts, skip root device-group membership, and document recovery.
  Restore Gitee source clones for CN, including branch/tag/SHA regression tests;
  the operator synchronizes Gitee after each origin release. Passwordless sudo is required when enabling the display hook.
- Provenance: Codex **gpt-6-astra** implemented and verified this continuation.
  pi **xiaomi/mimo-v2.6-pro-ultraspeed** provided analysis, full-path audit,
  test plan, plan review, patch review and final review against the plan:
  `/tmp/mimo-logs/v025-analysis.log`, `/tmp/mimo-logs/v025-audit.log`,
  `/tmp/mimo-logs/v025-test-plan.log`, `/tmp/mimo-logs/v025-plan-review.log`,
  `/tmp/mimo-logs/v025-patch-review.log`, `/tmp/mimo-logs/v025-final-review.log`.
  The audit and plan-review logs include `v025-baseline-plan-addendum.log`.
  Claude Code **claude-opus-5-5** provided independent review:
  `/tmp/mimo-logs/v025-claude-review.log` and
  `/tmp/mimo-logs/v025-claude-review-2.log`. GLM was not used.
  Raw local logs are not bundled with the source release.

## 0.2.4 — 2026-10-14

- Remove the Virtual-1 assumption: catch-all preferred monitor rule, any usable
  non-fallback output satisfies startup, and arch-output autodetects connected
  card0 connectors without requiring kernel/Aquamarine names to match.
- Preserve pre-fallback monitors all, filtered Arch runtime log tails (even when
  IPC failed), and DRM status in private diagnostics. Keep software GL,
  AQ_NO_MODIFIERS and software cursors.
- Correct installation hints: select Arch, fully close/reopen Linux Terminal;
  retain the early shell PATH block and verify interactive/login shells.
- Fail safely when an existing desktop has an unreadable previous leader.
- Extend display regressions for connector changes and pre-cleanup diagnostics.
  Pad visible-frame verification remains outstanding.
- How this release was made: Codex (on rwolinux) implemented the code and
  tests and ran verification (full suite 12/12 PASS). pi with
  xiaomi/mimo-v2.6-pro-ultraspeed did analysis, design, review and final
  review (/tmp/mimo-logs/v024-{analysis,design,review,review-final}.log).
  GLM 5.3 was not used.

## 0.2.3 — 2026-10-13

- Set software llvmpipe and linear DRM buffer defaults before nspawn launch;
  retain atomic modesetting with an opt-in legacy diagnostic knob.
- Explicitly enable Virtual-1 in Lua and disable hardware cursors.
- Detect alive-but-no-output startup via bounded, namespace-local hyprctl IPC;
  reject a leftover container leader, save private diagnostics and stop the
  container before Weston recovery.
- Add read-only arch-diag and arch-output helpers; defer hypr-switch --now
  to protect the Android Terminal UI. Add host bashrc/profile local-bin PATH.
- Correct CN resume to pinned Gitee URLs and document safe update/recovery.
- Support full QEMU integration by disabling Landlock only in disposable test rootfs.
- Add behavioral display regressions and record upstream analysis and
  reproduction limits.

## 0.2.2 — 2026-10-13

- Repair container DNS before pacman: replace rootfs resolver symlinks, read host
  upstream DNS instead of loopback stubs, and verify mirror resolution in nspawn.
  CN retries with AliDNS and DNSPod; nspawn preserves the managed resolver.
- Isolate installer children from piped script stdin and send diagnostic logs
  to stderr as defensive protection against script/input mixups.
- Remove the unsupported `[aur]` sync repository in CN mode (with a backup),
  and install host `gnupg` in CN mode before rootfs signature verification.
- Extract fresh rootfs into staging and rename only after success, so interrupted
  extraction cannot be mistaken for an installed container.
- Retry a mirror once from scratch after a stale partial fails its checksum.
- Confirm existing Arch containers and checksum-valid cached rootfs downloads
  are reused on resume; add resolver, stdin, repository and resume regressions.
- Support arm64 CI under QEMU with an adjustable quick-suite budget, cached
  rootfs downloads and explicit Docker platform selection.

## 0.2.1 — 2026-10-13

- Publish the Gitee mirror https://gitee.com/zenbardofsuhe/omarchy-xiaomipad9pm; `MIRROR=cn` bootstrap now
  fetches from it by default, enabling a one-line install on mainland networks.

## 0.2.0 — 2026-10-13

- Add `MIRROR=cn|global|auto` and `--mirror`, with bounded probes, downloads,
  retries and mainland mirror fallback. Keep `global` as the default.
- Configure Debian apt and ALARM pacman before their first install; back up
  original source files and propagate the mode through sudo/nspawn/runuser.
- Vendor the exact Omarchy v4.0.4 Git checkout with checksums and its MIT license.
  CN installs skip AUR and optional mise, using repository fonts and stock Rime.
- Document every install fetch, reachability results, bootstrap limitations,
  and reproducible blocked-host simulation; add mirror policy tests.
- Bootstrap `ca-certificates` over plain-HTTP mainland mirrors when the CA
  bundle is missing or HTTPS probes fail, then switch sources back to HTTPS;
  the test container always bootstraps over HTTP first and bounds HTTPS apt
  fetches with `Acquire::https::Timeout`.
- Make downloads resumable (`curl -C -`, keep `.part` across retries and
  candidates, delete only on checksum mismatch) and give the rootfs a larger,
  overridable timeout (`NETWORK_ROOTFS_TIMEOUT`).
- Bootstrap fallback: a failing `git clone` now falls back to the archive
  download (both with 300s deadlines), and the archive URL is overridable via
  `OMARCHY_ALARM_ARCHIVE_URL`.
- Single `auto` mirror detection in `lib/network.sh`, probing both github.com
  and raw.githubusercontent.com and logging the chosen mode from every entry
  point; dry runs resolve `auto` to `global` without probing.
- Bound AUR git clones with 120s deadlines and git low-speed limits.
