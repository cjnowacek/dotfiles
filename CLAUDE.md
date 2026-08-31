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
├── obsidian/.obsidian/   → <vault>/.obsidian   (each vault; both OSes)
├── unix/.unix_aliases    (sourced by both .bashrc and .zshrc)
├── bootstrap.sh          (full system setup script)
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
  symlinks (shell, nvim, hypr, waybar) and skips all installs.

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
- `setup_obsidian()` links `obsidian/.obsidian` into each vault. Defaults to `~/dev/zettelpara`
  and `~/dev/ai-chats`; override with `VAULTS="/path/a /path/b" ./bootstrap.sh`. Vaults that
  don't exist are skipped with a log line, so a stale path fails silently — keep this list and
  the `-Vaults` default in `bootstrap.ps1` in sync when a vault moves.

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
