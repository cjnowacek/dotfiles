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
├── hypr/.config/hypr/    → ~/.config/hypr
├── waybar/.config/waybar/ → ~/.config/waybar
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

## Key details

- `DOTFILES_DIR` in `bootstrap.sh` must stay as `$HOME/.dotfiles`
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
