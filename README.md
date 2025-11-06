# Dotfiles

Personal configuration files for my development environment.

## Quick Start

### Clone the Repository

```bash
mkdir -p ~/git
cd ~/git
git clone <your-repo-url> dotfiles
cd dotfiles
```

### Run Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:

- ✅ Install system dependencies (git, curl, ripgrep, fzf, etc.)
- ✅ Install Rust toolchain
- ✅ Install Neovim (latest stable)
- ✅ Install Node.js (for markdown preview)
- ✅ Install Oh My Zsh
- ✅ Create symlinks for all configuration files
- ✅ Install Neovim plugins automatically
- ✅ Set up Python environment with pipx
- ✅ Change default shell to zsh

### Post-Installation

1. Restart your terminal or source your shell config:

   ```bash
   source ~/.zshrc
   ```

2. Open Neovim to finalize plugin setup:
   ```bash
   nvim
   ```

## Manual Installation

If you prefer to install components individually:

### Shell Configuration

```bash
ln -sf ~/git/dotfiles/bash/.bashrc ~/.bashrc
ln -sf ~/git/dotfiles/zsh/.zshrc ~/.zshrc
mkdir -p ~/dotfiles/unix
ln -sf ~/git/dotfiles/unix/.unix_aliases ~/dotfiles/unix/.unix_aliases
```

### Neovim Configuration

```bash
ln -sf ~/git/dotfiles/nvim/.config/nvim ~/.config/nvim
```

### Install Neovim Plugins

Open Neovim and run:

```vim
:Lazy sync
```

## What's Included

### Shell (Bash/Zsh)

- Custom aliases for common tasks
- Git shortcuts
- Neovim as default editor
- Rust and Python path configurations

### Neovim (LazyVim)

- **Plugin Manager:** lazy.nvim
- **LSP Support:** Python, Lua, Markdown, Bash, Terraform, Go, YAML, JSON, Docker, Ansible
- **Formatting:** Prettier, Black, Stylua
- **Features:**
  - Telescope for fuzzy finding
  - Neo-tree file explorer
  - Harpoon for quick file navigation
  - Git integration (Gitsigns, LazyGit)
  - Markdown preview and enhanced editing
  - Database UI (vim-dadbod)
  - LaTeX support (vimtex)

### Key Aliases

#### Terminal

- `ll` - Detailed list view
- `lt` - List by time
- `c` - Clear terminal
- `gs` - Git status

#### Neovim

- `v`, `n`, `vim` - Launch Neovim

#### Python

- `p` - Python3 shortcut

#### Navigation

- `zk` - Zettelkasten notes
- `wh` - Windows home (WSL)
- `website` - Web root
- `resume` - Resume directory

## Customization

### Add Your Own Aliases

Edit `unix/.unix_aliases`:

```bash
nvim ~/git/dotfiles/unix/.unix_aliases
```

### Customize Neovim

Add or modify plugins in:

```
nvim/.config/nvim/lua/plugins/
```

### Configure Shell

- Bash: `bash/.bashrc`
- Zsh: `zsh/.zshrc`

## Neovim Key Bindings

### Leader Key

- `<Space>` - Leader key
- `\` - Local leader key

### File Navigation

- `<Space>ff` - Find files
- `<Space>fg` - Live grep
- `<Space>fb` - Find buffers
- `<Space>fr` - Recent files
- `<Space>e` - Toggle file explorer

### LSP

- `gd` - Go to definition
- `gr` - Find references
- `K` - Hover documentation
- `<Space>ca` - Code actions
- `<Space>rn` - Rename symbol

### Git

- `<Space>gg` - Open LazyGit
- `<Space>gb` - Git blame line
- `]h` / `[h` - Next/prev git hunk

### Markdown

- `<Space>mp` - Markdown preview
- Auto-list continuation
- Auto-formatting on save

## Directory Structure

```
dotfiles/
├── bash/
│   └── .bashrc
├── nvim/
│   └── .config/
│       └── nvim/
│           ├── init.lua
│           ├── lua/
│           │   ├── config/
│           │   └── plugins/
│           └── after/
├── unix/
│   └── .unix_aliases
├── zsh/
│   └── .zshrc
├── setup.sh
└── README.md
```

## Troubleshooting

### Neovim Plugins Not Loading

```bash
nvim --headless "+Lazy! sync" +qa
```

### Shell Config Not Sourcing

Make sure the symlinks are correct:

```bash
ls -la ~/ | grep -E 'bashrc|zshrc'
```

### LSP Not Working

Install Mason packages manually:

```vim
:Mason
```

### Permissions Error

Make sure the setup script is executable:

```bash
chmod +x ~/git/dotfiles/setup.sh
```

## Backup

The setup script automatically backs up existing configuration files to:

```
~/.dotfiles-backup-<timestamp>/
```

## Dependencies

### Required

- Git
- Curl/Wget
- Build tools (gcc, make)

### Optional but Recommended

- Ripgrep (better grep)
- fd (better find)
- fzf (fuzzy finder)
- xclip (clipboard support on Linux)
- Node.js (for markdown preview)

## Updates

To update your dotfiles:

```bash
cd ~/git/dotfiles
git pull
./setup.sh  # Re-run if needed
```

To update Neovim plugins:

```vim
:Lazy sync
```

## License

Apache License 2.0 (see nvim/.config/nvim/LICENSE)

## Contributing

This is a personal dotfiles repository, but feel free to fork and adapt to your needs!
