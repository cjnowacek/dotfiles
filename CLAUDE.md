# Dotfiles (~/.dotfiles)

Personal dotfiles repo. Lives at `~/.dotfiles` with symlinks into `$HOME`.

## Structure

```
dotfiles/
├── bash/.bashrc          → ~/.bashrc
├── zsh/.zshrc            → ~/.zshrc
├── nvim/.config/nvim/    → ~/.config/nvim
├── unix/.unix_aliases    (sourced by both .bashrc and .zshrc)
├── bootstrap.sh          (full system setup script)
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
