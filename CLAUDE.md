# Dotfiles (~/.dotfiles)

Personal dotfiles repo. Lives at `~/.dotfiles` with symlinks into `$HOME`.

## Clone Location

- **Windows:** `C:\dev\dotfiles` (CJ's repos live in `C:\dev`)
- **Linux:** `~/.dotfiles`, the exception to the usual `~/dev` convention, because `bootstrap.sh`'s `DOTFILES_DIR` requires `$HOME/.dotfiles`

## Structure

```
dotfiles/
├── bash/.bashrc          → ~/.bashrc
├── zsh/.zshrc            → ~/.zshrc
├── nvim/.config/nvim/    → ~/.config/nvim
├── hypr/.config/hypr/    → ~/.config/hypr      (shared + hosts/, see below)
├── waybar/.config/waybar/ → ~/.config/waybar   (hosts/ only, see below)
├── wofi/.config/wofi/    → ~/.config/wofi
├── kitty/.config/kitty/  → ~/.config/kitty
├── dunst/.config/dunst/  → ~/.config/dunst
├── gtk/.config/gtk-{3,4}.0/*  → ~/.config/gtk-{3,4}.0/  (linked per file; bookmarks stays real)
├── gtk/.local/share/themes/Flexoki/ → ~/.local/share/themes/Flexoki  (GTK3 theme, GNOME host)
├── gnome/apply.sh        (gsettings skin for the GNOME host; run by setup_gnome)
├── applications/.local/share/applications/*.desktop → ~/.local/share/applications/  (linked per file)
├── obsidian/.obsidian/   → <vault>/.obsidian   (each vault; both OSes)
├── unix/.unix_aliases    (sourced by both .bashrc and .zshrc)
├── bootstrap.sh          (full system setup script; OS-agnostic steps + dispatch)
├── bootstrap.d/<pm>.sh   (one file per package manager: pacman, apt, dnf, brew)
├── bootstrap.ps1         (Windows setup: nvim + PowerShell profile + Obsidian)
├── powershell/Microsoft.PowerShell_profile.ps1   (Windows alias equivalent)
└── emacs/                (unused)
```

## Symlink convention

Each subdirectory mirrors the target path from `$HOME`. The bootstrap script (`bootstrap.sh`) creates symlinks via `ln -sf`. When adding a new config:

1. Place it under a subdirectory matching the tool name
2. Add a `create_symlink` call in `bootstrap.sh`

## Per-host configs (desktop vs laptop)

Two Linux machines share the repo: a **desktop** (dual Dell 4K on NVIDIA) and a
**laptop** (ThinkPad T480, Intel, eDP-1). Machine-specific config lives in
`hosts/<role>/` directories:

Everything that can be shared IS shared in one tracked file; a host file holds
only what hardware dictates. Per-host files are down to three:

- `hypr/.config/hypr/hyprland.conf` (shared) sources `~/.config/hypr/host.conf`
  as its last line → `hosts/<role>/host.conf`: monitors, GPU env, wallpaper
  daemon autostart, laptop brightness keys.
- `hosts/<role>/hypridle.conf`: genuinely different — the desktop's NVIDIA/DP
  combo segfaults Hyprland on dpms-off, so it suspends instead; the laptop
  stages lock → screen-off (+ brightness restore) → suspend.
- `waybar/.config/waybar/config.jsonc` (shared) has
  `"include": "$HOME/.config/waybar/host.jsonc"` → `hosts/<role>/host.jsonc`:
  ONLY `modules-right` (battery vs dropbox-only) and `hyprland/workspaces`
  (desktop pins them to outputs). Keys in the main file win over the include,
  so never define those two keys in config.jsonc. Module definitions stay in
  the shared file even when one host doesn't list them — unlisted is inert.
  `style.css` is fully shared (CSS for absent modules is inert).
- `hyprlock.conf` and `hyprpaper.conf` are shared tracked files (identical
  needs on both machines; hyprpaper's empty `monitor =` covers any output).
- `bootstrap.sh` detects the role by battery presence (`/sys/class/power_supply/BAT*`
  → laptop), overridable with `DOTFILES_HOST=desktop|laptop`, and creates
  **gitignored relative symlinks inside the repo** (e.g.
  `hypr/.config/hypr/host.conf → hosts/laptop/host.conf`). After a pull that
  changes the hosts layout, run `./bootstrap.sh links` — it redoes only the
  symlinks (shell, nvim, hypr, waybar, wofi, kitty, dunst) and skips all installs.

**Pulling the 2026-08-30 shared-file consolidation over the older hosts/
layout:** the pull creates tracked `waybar/config.jsonc`, `waybar/style.css`,
`hypr/hyprlock.conf`, `hypr/hyprpaper.conf` where the old layout left
untracked per-host symlinks — if git refuses the pull over those four paths,
delete the symlinks and pull again, then run `./bootstrap.sh links` (it also
cleans any stale ones and links `host.jsonc`).

## First pull on the desktop after the hosts/ restructure (2026-08-30)

The split moved the desktop's `hypridle.conf`, `hyprlock.conf`, `hyprpaper.conf`,
and waybar `config.jsonc`/`style.css` into `hosts/desktop/`, so the pull deletes
the old top-level files. **Run `./bootstrap.sh links` immediately after pulling**
to recreate them as symlinks — until then hyprlock/hypridle have no config, so
don't reboot, log out, or lock in between. Then verify before ending the session:
`hyprctl reload && hyprctl configerrors` must be clean and
`hyprctl binds | grep -c "^bind"` should be ~71 — check the bind *count*, not
just parse errors. Commit 56f2cfc in history shipped a config that parsed clean
with zero binds (the laptop needed boot-media recovery); the fix is 130606a.
Two more gotchas:

- `links` also symlinks `~/.zprofile` (auto-`exec Hyprland` on TTY1 login). If
  the desktop had its own `~/.zprofile`, it's backed up to
  `~/.dotfiles-backup-<timestamp>/` — check it for lines worth merging.
- Hyprland 0.56+ with an empty/missing config dir silently autogenerates a
  **Lua** config (`hyprland.lua`) instead of erroring, and that session ignores
  `hyprland.conf` until a full relogin — `hyprctl systeminfo | grep configProvider`
  should say `hyprlang`, not `lua`. `hyprctl reload` cannot switch providers.
- **Pause Hyprland's auto-reload before any git operation that rewrites
  `hyprland.conf`** (pull, rebase, checkout, stash):
  `hyprctl keyword misc:disable_autoreload true`, then `hyprctl reload` once
  the tree is settled (the reload also turns auto-reload back on). Git deletes
  and recreates a file it rewrites; a running Hyprland that notices the moment
  it is missing writes its "This config is a STUB!" file over it, and the
  rebase then stops on that as a local change. Seen 2026-09-16 on the desktop:
  restore with `git checkout -- hypr/.config/hypr/hyprland.conf`.

## Key details

- `DOTFILES_DIR` in `bootstrap.sh` must stay as `$HOME/.dotfiles`
- After `git pull` on either machine, if `hosts/` or symlink layout changed, run
  `./bootstrap.sh links` to refresh the per-host symlinks
- `.bashrc` and `.zshrc` both source `$HOME/.dotfiles/unix/.unix_aliases`
- Neovim config uses LazyVim (lazy.nvim plugin manager)
- `bootstrap.sh` also installs system deps, oh-my-zsh, rust, node, neovim, zk, Claude Code, and configures MCP chat-logger; the repos it clones (bash, mcp-chat-logger, zettelpara, ai-chats) go into `~/dev/`, matching the Windows `C:\dev` convention
- Claude Code is installed natively on both OSes (`install.sh` / `install.ps1`, not npm) and the
  `coder/claudecode.nvim` plugin (`nvim/.config/nvim/lua/plugins/claudecode.lua`) shells out to
  the `claude` binary on PATH. Keybinds are under `<leader>a`; the terminal comes from
  snacks.nvim, which LazyVim already ships. Run it from the nvim terminal split or PowerShell,
  not raw Git Bash (no TTY, so the interactive CLI errors with "Raw mode is not supported")
- Shell aliases live in `unix/.unix_aliases`, not in the rc files directly
- `setup_github_backup()` installs a daily user timer running `~/dev/bash/github-backup.sh`
  (from the bash tools repo): every GitHub repo mirrored to `~/backups/github/mirrors`, a
  dated `git bundle` per repo under `bundles/`, last 7 days kept, bundles rclone-synced
  straight to `dropbox:99-system/github-backups` (not via the FUSE mount). Needs
  `github-cli` + `gh auth login` once per machine; `systemctl --user start github-backup` runs it now
- `applications/` holds `.desktop` overrides, linked **per file** into `~/.local/share/applications/`
  (that dir also has untracked Steam/Chrome entries). `yazi.desktop` exists because the stock entry
  has `Terminal=true` and wofi's terminal autodetection silently fails on it, so selecting Yazi in
  drun did nothing; the override runs `kitty -e yazi` with `Terminal=false`. `wofi/config` also
  sets `term=kitty` for any other terminal apps.
- `setup_obsidian()` links `obsidian/.obsidian` into each vault. Defaults to `~/dev/zettelpara`
  and `~/dev/ai-chats`; override with `VAULTS="/path/a /path/b" ./bootstrap.sh`. Vaults that
  don't exist are skipped with a log line, so a stale path fails silently — keep this list and
  the `-Vaults` default in `bootstrap.ps1` in sync when a vault moves.

## Package manager backends (`bootstrap.d/`)

`bootstrap.sh` holds only the OS-agnostic flow (symlinks, curl-installed tools,
repos, systemd units, doctor). Everything that depends on the package manager
lives in `bootstrap.d/<manager>.sh`, which `check_os` sources after detecting
pacman, apt, dnf, or brew. Each backend must define the six functions in the
`PKG_INTERFACE` array in `bootstrap.sh` (`pkg_install_base`, `_neovim`,
`_nodejs`, `_zk`, `_pipx`, `_obsidian`); `load_pkg_backend` exits with the
missing name if one is absent. Backends may call the shared helpers
`install_neovim_appimage` and `build_zk_from_source` from `bootstrap.sh`, and
read `IS_WSL`. To add a distro: one detection branch in `check_os`, one new
file in `bootstrap.d/`. Windows stays separate in `bootstrap.ps1` because
PowerShell cannot share bash code.

## Rocky / RHEL-family (dnf) half

The `rocky-maya` libvirt VM (Rocky 9, GNOME) runs the same `bootstrap.sh`
via `bootstrap.d/dnf.sh`. Its `dnf_is_el` reads `/etc/os-release`; on
Rocky/Alma/CentOS/RHEL it installs `epel-release` and enables CRB before the
package list (ripgrep, fd-find, fzf, pandoc live in EPEL, not base). The dnf
install runs with `--setopt=strict=0` so a package missing from that distro's
repos is a warning, not an abort. eza is not in EPEL 9, so `install_eza`
drops the upstream x86_64 release binary into `/usr/local/bin` whenever the
package manager did not provide it. Neovim comes from the AppImage
(`fuse-libs` is in the dnf list for it). The Hyprland/waybar/wofi/dunst
symlinks are still created under GNOME and simply sit unused. Clone over
HTTPS in the VM (repo is public; no SSH key needed for read-only).

Hyprland is not packaged for EL9 (no base/EPEL/RPM Fusion build; GNOME 40 +
old Mesa), and Maya targets GNOME anyway, so the VM keeps GNOME and gets
**skinned to match** instead (2026-09-17):

- `gtk/.local/share/themes/Flexoki/gtk-3.0/gtk.css` imports GTK's built-in
  `Adwaita/gtk-contained-dark.css` and overrides the colours with the
  kitty/waybar Flexoki palette (`#1c1b1a` chrome, `#100f0f` views, `#cecdc3`
  text, `#66a0c8` accent). It is its own named theme because Rocky's
  `Adwaita-dark` package ships only `gtk-2.0/`, so `gtk-theme=Adwaita-dark`
  silently falls back to light Adwaita. `gtk/.config/gtk-4.0/gtk.css` does the
  same with libadwaita's `@define-color` names.
- `gnome/apply.sh` (user-level, idempotent, called by `setup_gnome` only when
  `XDG_CURRENT_DESKTOP` contains GNOME): sets gtk-theme Flexoki, Papirus-Dark
  icons (EPEL package, else a `~/.local/share/icons` install), JetBrainsMono
  Nerd Font for UI/mono, the hypr `assets/wallpaper.jpg` + `lockscreen.png`,
  disables the Rocky background logo, and writes kitty.conf's palette into
  the default GNOME Terminal profile.
- The top bar is themed too: `gtk/.local/share/themes/Flexoki/gnome-shell/
  gnome-shell.css` imports the stock shell CSS and recolours panel, popups,
  overview and OSD. It loads through the user-theme extension, which
  `apply.sh` installs per-user from extensions.gnome.org (the RPM needs root)
  and selects with `dconf write .../user-theme/name`. GNOME Shell only scans
  the user extension dir at login, so a first install needs a relogin, or
  the shell's own D-Bus `InstallRemoteExtension` call to load it live.
- kitty is the default terminal there too: `apply.sh` sets
  `default-applications.terminal`, binds Super+Return (same as hyprland.conf)
  and Ctrl+Alt+T to kitty, and puts kitty first in the dash favourites.
  GLib on EL9 ignores that key for `Terminal=true` launchers (hardcoded
  gnome-terminal/xterm list), hence the `applications/yazi.desktop` override.
- `apply.sh` also replays the hyprland.conf binds Mutter can express: 10
  static workspaces on Super+N / Super+Shift+N, Super+Q close, Super+F
  fullscreen, Super+D app grid, Super+E file manager (yazi in kitty if
  installed, else nautilus), Super+Ctrl+L lock, Super+Shift+E logout,
  Super+Shift+P power dialog, Print / Super+Print / Super+Shift+S
  screenshots, Super+drag move and Super+right-drag resize, Super+h/l cycle
  windows, Super+Shift+hjkl/arrows move to monitor. Not mappable: floating
  toggle, pseudo/split, directional focus, step resize, special workspaces,
  cliphist. Super+1..9 dash launching and Super+h minimize are cleared.
- Dropbox on the VM is the same on-demand `rclone-dropbox.service` as the
  Hyprland hosts. `applications/dropbox-mount.desktop` (Papirus `dropbox`
  icon, an Unmount action) stands in for the waybar module. rclone comes from
  EPEL (`sudo dnf install rclone`); the `dropbox:` remote token is copied from
  the desktop's `~/.config/rclone/rclone.conf` or made with `rclone config`.
- Obsidian on dnf hosts: `pkg_install_obsidian` (dnf.sh) calls
  `install_obsidian_appimage`, which puts the newest release *with an x86_64
  AppImage* at `~/.local/bin/obsidian` (mobile-only tags have no assets).
  `applications/obsidian.desktop` launches it with `--ozone-platform-hint=auto`
  (native Wayland); Papirus supplies the icon. `setup_obsidian` links the
  vault configs as on every host.
- `install_yazi` / `install_rclone` / `install_btop` (bootstrap.sh) drop the upstream x86_64
  release binaries into `~/.local/bin` when the package manager left them
  out (yazi is in no EL9 repo; rclone is EPEL but the VM had no sudo). The
  rclone unit's `ExecStart` is resolved from `command -v rclone` for that
  reason. `gnome/apply.sh` binds Super+E to `kitty -e yazi` once yazi exists.
- `install_nerd_font` (bootstrap.sh) downloads the Nerd Font release into
  `~/.local/share/fonts` when no package provided it (EPEL has none).
- **VTE gotchas:** GNOME Terminal must use the `... Nerd Font Mono` variant
  (the non-Mono one renders icons two cells wide); and `gnome-terminal-server`
  caches fontconfig at start, so a font installed while a terminal is open
  shows as a proportional fallback with huge letter spacing until *every*
  terminal window is closed and reopened. kitty is unaffected.
- `./bootstrap.sh doctor` under GNOME checks only kitty/yazi/btop/nvim/zsh
  and that gtk-theme is Flexoki; the hypr tool list is skipped there.

## Windows (cross-platform) half

The repo is checked out on **both** OSes: WSL/Linux at `~/.dotfiles`, and a Windows
clone (e.g. `C:\dev\dotfiles`) for the Windows-native pieces. Same repo/history;
`git pull` on each side.

- `bootstrap.ps1`: Windows setup; run from the Windows clone (`pwsh -File bootstrap.ps1`).
  Junctions `nvim/.config/nvim` → `%LOCALAPPDATA%\nvim`, writes a `$PROFILE` stub that
  dot-sources `powershell/Microsoft.PowerShell_profile.ps1`, junctions
  `obsidian/.obsidian` into each vault (Windows counterpart of `setup_obsidian()` in
  `bootstrap.sh`; vault list defaults to `C:\dev\zettelpara` and `C:\dev\ai-chats`,
  override with `-Vaults`, missing vaults are skipped), and clones/updates repos into
  `C:\dev` over SSH (bash, mcp-chat-logger always; zettelpara, ai-chats behind y/N prompts),
  mirroring `bootstrap.sh`'s repo setup.
- `bootstrap.ps1` also winget-installs the native tools the config assumes (neovim, git,
  ripgrep, fd, eza, zig, Claude Code) via `Install-Pkg`, which skips anything already on PATH
  and warns instead of aborting on failure. Rough counterpart of `install_dependencies()` +
  `install_neovim()` in `bootstrap.sh`. The WinLibs gcc entry is there only because
  nvim-treesitter compiles parsers: its `main` branch probes for `cc`/`gcc` specifically, so
  zig does not satisfy the check even though it compiles C. WinLibs needs no Visual Studio.
- **Keep `bootstrap.ps1` ASCII-only.** It has no BOM, so Windows PowerShell 5.1 decodes it as
  ANSI; a non-ASCII character such as an em dash decodes to a curly quote, which the parser
  treats as a string delimiter, and the whole script fails to parse.
- `powershell/Microsoft.PowerShell_profile.ps1`: Windows equivalent of `unix/.unix_aliases`;
  keep the two in rough sync when adding aliases.
- **No admin / Developer Mode required.** Directory junctions and the profile stub both work
  for a plain user, entirely under the Windows user home (`%LOCALAPPDATA%`, `%USERPROFILE%`),
  and edits flow through on `git pull`. Good for locked-down work machines.
- **nvim**, the **aliases**, and the **Obsidian config** are shared. `hypr/`, `bootstrap.sh`,
  `waybar/`, and the oh-my-zsh setup are Linux-only, no Windows counterpart.
- Obsidian plugin code (`plugins/*/main.js`, `manifest.json`, `themes/`) is gitignored by
  `obsidian/.obsidian/.gitignore`; only settings and `community-plugins.json` are tracked, so
  plugins reinstall from the community browser on first launch. Same on both OSes.
