# Dotfiles (~/.dotfiles)

Personal dotfiles repo. Lives at `~/.dotfiles` with symlinks into `$HOME`.

## Clone Location

- **Windows:** `C:\dev\dotfiles` (CJ's repos live in `C:\dev`)
- **Linux:** `~/.dotfiles` — the exception to the usual `~/dev` convention, because `bootstrap.sh`'s `DOTFILES_DIR` requires `$HOME/.dotfiles`

## Structure

```
dotfiles/
├── bash/.bashrc          → ~/.bashrc
├── zsh/.zshrc            → ~/.zshrc
├── nvim/.config/nvim/    → ~/.config/nvim
├── hypr/.config/hypr/    → ~/.config/hypr
├── unix/.unix_aliases    (sourced by both .bashrc and .zshrc)
├── bootstrap.sh          (full system setup script)
├── bootstrap.ps1         (Windows setup — nvim + PowerShell profile)
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
- `bootstrap.sh` also installs system deps, oh-my-zsh, rust, node, neovim, zk, and configures MCP chat-logger
- Shell aliases live in `unix/.unix_aliases`, not in the rc files directly

## Windows (cross-platform) half

The repo is checked out on **both** OSes: WSL/Linux at `~/.dotfiles`, and a Windows
clone (e.g. `C:\dev\dotfiles`) for the Windows-native pieces. Same repo/history —
`git pull` on each side.

- `bootstrap.ps1` — Windows setup; run from the Windows clone (`pwsh -File bootstrap.ps1`).
  Junctions `nvim/.config/nvim` → `%LOCALAPPDATA%\nvim`, and writes a `$PROFILE` stub that
  dot-sources `powershell/Microsoft.PowerShell_profile.ps1`.
- `powershell/Microsoft.PowerShell_profile.ps1` — Windows equivalent of `unix/.unix_aliases`;
  keep the two in rough sync when adding aliases.
- **No admin / Developer Mode required.** Directory junctions and the profile stub both work
  for a plain user, entirely under the Windows user home (`%LOCALAPPDATA%`, `%USERPROFILE%`),
  and edits flow through on `git pull`. Good for locked-down work machines.
- Only **nvim** and the **aliases** are shared. `hypr/`, `bootstrap.sh`, and the oh-my-zsh
  setup are Linux-only, no Windows counterpart.
