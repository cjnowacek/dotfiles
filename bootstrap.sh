#!/usr/bin/env bash

set -euo pipefail

# Configuration
DOTFILES_DIR="$HOME/projects/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Helper functions
log() {
  echo ":: $1"
}

log_error() {
  echo "ERROR: $1" >&2
}

log_step() {
  echo ""
  echo "===> $1"
}

# Check if running on supported OS
check_os() {
  log_step "Checking operating system"

  # Check for WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
    log "Detected WSL (Windows Subsystem for Linux)"
  else
    IS_WSL=false
  fi

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"

    # Detect package manager
    if command -v pacman &>/dev/null; then
      PKG_MANAGER="pacman"
      log "Detected Arch Linux"
    elif command -v apt-get &>/dev/null; then
      PKG_MANAGER="apt"
      log "Detected Debian/Ubuntu"
    elif command -v dnf &>/dev/null; then
      PKG_MANAGER="dnf"
      log "Detected Fedora/RHEL"
    else
      log_error "Unsupported package manager"
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PKG_MANAGER="brew"
    log "Detected macOS"
  else
    log_error "Unsupported operating system: $OSTYPE"
    exit 1
  fi
}

# Backup existing files
backup_file() {
  local file=$1
  if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    log "Backing up: $file"
    cp -r "$file" "$BACKUP_DIR/"
    rm -rf "$file"
  elif [[ -L "$file" ]]; then
    rm "$file"
  fi
}

# Create symlink
create_symlink() {
  local source=$1
  local target=$2

  if [[ -e "$source" ]]; then
    backup_file "$target"
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    log "Linked: $target"
  else
    log "Warning: source not found: $source"
  fi
}

# Install system dependencies
install_dependencies() {
  log_step "Installing system dependencies"

  case "$PKG_MANAGER" in
  pacman)
    log "Using pacman"
    sudo pacman -Syu --noconfirm

    if [[ "$IS_WSL" == true ]]; then
      # WSL doesn't need xclip (uses Windows clipboard)
      sudo pacman -S --needed --noconfirm \
        git \
        curl \
        wget \
        base-devel \
        ripgrep \
        fd \
        fzf \
        eza \
        zsh
    else
      sudo pacman -S --needed --noconfirm \
        git \
        curl \
        wget \
        base-devel \
        xclip \
        ripgrep \
        fd \
        fzf \
        eza \
        zsh
    fi
    ;;
  apt)
    log "Using apt"
    sudo apt-get update

    if [[ "$IS_WSL" == true ]]; then
      # WSL doesn't need xclip
      sudo apt-get install -y \
        git \
        curl \
        wget \
        build-essential \
        ripgrep \
        fd-find \
        fzf \
        eza \
        zsh
    else
      sudo apt-get install -y \
        git \
        curl \
        wget \
        build-essential \
        xclip \
        ripgrep \
        fd-find \
        fzf \
        eza \
        zsh
    fi

    # Ubuntu/Debian: fd is packaged as "fd-find" and the binary is usually "fdfind"
    if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
      log "Creating fd symlink (fdfind -> fd)"
      sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi
    ;;
  dnf)
    log "Using dnf"

    if [[ "$IS_WSL" == true ]]; then
      sudo dnf install -y \
        git \
        curl \
        wget \
        @development-tools \
        ripgrep \
        fd-find \
        fzf \
        eza \
        zsh
    else
      sudo dnf install -y \
        git \
        curl \
        wget \
        @development-tools \
        xclip \
        ripgrep \
        fd-find \
        fzf \
        eza \
        zsh
    fi
    ;;
  brew)
    if ! command -v brew &>/dev/null; then
      log "Installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    log "Using Homebrew"
    brew install git curl wget ripgrep fd fzf eza zsh
    ;;
  esac

  log "Dependencies installed"
}

# Install Oh My Zsh
install_oh_my_zsh() {
  log_step "Installing Oh My Zsh"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log "Oh My Zsh installed"
  else
    log "Oh My Zsh already installed"
  fi
}

# Install Rust
install_rust() {
  log_step "Installing Rust"

  if ! command -v rustc &>/dev/null; then
    log "Installing Rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
    log "Rust installed"
  else
    log "Rust already installed"
  fi
}

# Install Neovim
install_neovim() {
  log_step "Installing Neovim (latest stable AppImage)"

  local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"

  log "Downloading Neovim AppImage..."
  sudo curl -fLLo /usr/local/bin/nvim "$url" || {
    log_error "Failed to download Neovim AppImage"
    return 1
  }

  sudo chmod +x /usr/local/bin/nvim

  # Sanity check: ensure we didn't install HTML
  if ! file /usr/local/bin/nvim | grep -qi 'ELF'; then
    log_error "Downloaded Neovim is not a valid executable"
    head -c 200 /usr/local/bin/nvim; echo
    sudo rm -f /usr/local/bin/nvim
    return 1
  fi

  log "Neovim installed: $(nvim --version | head -n1)"
}


# Setup shell configurations
setup_shell() {
  log_step "Setting up shell configurations"

  create_symlink "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"
  create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

  log "Shell configurations linked"
}

# Setup Neovim configuration
setup_neovim() {
  log_step "Setting up Neovim configuration"

  mkdir -p "$HOME/.config"

  if [[ -L "$HOME/.config/nvim" ]]; then
    rm "$HOME/.config/nvim"
  elif [[ -d "$HOME/.config/nvim" ]]; then
    backup_file "$HOME/.config/nvim"
  fi

  ln -sf "$DOTFILES_DIR/nvim/.config/nvim" "$HOME/.config/nvim"
  log "Neovim configuration linked"

  # Note: Plugins will auto-install on first Neovim launch
  log "Neovim plugins will install on first launch (open nvim to trigger)"
}

# Install Node.js (for markdown-preview)
install_nodejs() {
  log_step "Installing Node.js"

  if ! command -v node &>/dev/null; then
    log "Installing Node.js"

    case "$PKG_MANAGER" in
    pacman)
      sudo pacman -S --needed --noconfirm nodejs npm
      ;;
    apt)
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
      ;;
    dnf)
      sudo dnf install -y nodejs npm
      ;;
    brew)
      brew install node
      ;;
    esac

    log "Node.js installed"
  else
    log "Node.js already installed"
  fi
}

# Install zk (Zettelkasten CLI tool)
install_zk_from_source() {
  log "Installing zk from source"

  # Ensure deps
  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y golang-go make git
  else
    log_error "Unsupported package manager for zk install"
    return 1
  fi

  # If zk already exists, report version and skip rebuild
  if command -v zk >/dev/null 2>&1; then
    log "zk already installed: $(zk --version)"
    return 0
  fi

  # Build
  rm -rf /tmp/zk-build
  git clone https://github.com/zk-org/zk.git /tmp/zk-build
  (
    cd /tmp/zk-build || exit 1
    make build
  )

  # Install
  sudo install -m 0755 /tmp/zk-build/zk /usr/local/bin/zk

  # Verify
  zk --version || {
    log_error "zk installation failed"
    return 1
  }

  log "zk installed successfully"
}

# Setup Python environment
setup_python() {
  log_step "Setting up Python environment"

  if command -v python3 &>/dev/null; then
    log "Installing pipx"

    case "$PKG_MANAGER" in
    pacman)
      sudo pacman -S --needed --noconfirm python-pipx
      ;;
    apt)
      sudo apt-get install -y pipx
      pipx ensurepath
      ;;
    dnf)
      sudo dnf install -y python3-pip
      python3 -m pip install --user pipx
      python3 -m pipx ensurepath
      ;;
    brew)
      brew install pipx
      pipx ensurepath
      ;;
    esac

    log "Python environment configured"
  else
    log "Warning: Python3 not found"
  fi
}

# Get or pull bash scripts repository
setup_bash_tools() {
  log_step "Setting up bash tools repo"

  command -v git >/dev/null || {
    log_error "git is required but not installed"
    exit 1
  }

  mkdir -p "$HOME/git"

  if [ ! -d "$HOME/git/bash/.git" ]; then
    git clone https://github.com/cjnowacek/bash.git "$HOME/git/bash"
  else
    git -C "$HOME/git/bash" pull --rebase
  fi
}

# Setup MCP chat-logger server
setup_mcp_chat_logger() {
  log_step "Setting up MCP chat-logger"

  local repo_dir="$HOME/projects/mcp-chat-logger"

  # Clone or pull
  if [ ! -d "$repo_dir/.git" ]; then
    git clone git@github.com:cjnowacek/mcp-chat-logger.git "$repo_dir"
  else
    git -C "$repo_dir" pull --rebase
  fi

  # Install and build
  (cd "$repo_dir" && npm install && npm run build)

  # Determine vault path
  local vault_path
  if [[ "$IS_WSL" == true ]]; then
    local win_user
    win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r') || true
    if [[ -n "$win_user" && -d "/mnt/c/Users/$win_user/Documents/kb" ]]; then
      vault_path="/mnt/c/Users/$win_user/Documents/kb"
    else
      vault_path="$HOME/projects/knowledge-base"
    fi
  else
    vault_path="$HOME/projects/knowledge-base"
  fi

  # Configure Claude MCP server in ~/.claude.json
  local node_path
  node_path="$(command -v node)"
  local server_script="$repo_dir/dist/index.js"
  local claude_config="$HOME/.claude.json"

  node -e "
    const fs = require('fs');
    const configPath = process.argv[1];
    const nodePath = process.argv[2];
    const script = process.argv[3];
    const vault = process.argv[4];
    let config = {};
    try { config = JSON.parse(fs.readFileSync(configPath, 'utf-8')); } catch {}
    if (!config.mcpServers) config.mcpServers = {};
    config.mcpServers['chat-logger'] = {
      type: 'stdio',
      command: nodePath,
      args: [script],
      env: { VAULT_PATH: vault }
    };
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n', 'utf-8');
  " "$claude_config" "$node_path" "$server_script" "$vault_path"

  log "MCP chat-logger configured (vault: $vault_path)"
}

# Setup SSH agent as systemd service
setup_ssh_agent() {
  log_step "Setting up SSH agent systemd service"
  
  # Only set up if SSH key exists
  if [[ ! -f "$HOME/.ssh/github_key" ]]; then
    log "Skipping ssh-agent setup (no github_key found)"
    return
  fi
  
  mkdir -p "$HOME/.config/systemd/user"
  
  cat > "$HOME/.config/systemd/user/ssh-agent.service" << 'EOF'
[Unit]
Description=SSH key agent
Documentation=man:ssh-agent(1)

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK
ExecStartPost=/usr/bin/ssh-add %h/.ssh/github_key

[Install]
WantedBy=default.target
EOF
  
  # Enable and start the service
  systemctl --user enable ssh-agent.service 2>/dev/null || true
  systemctl --user start ssh-agent.service 2>/dev/null || true
  
  log "SSH agent systemd service configured"
}

# Change default shell to zsh
change_shell() {
  log_step "Setting default shell"

  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    log "Changing default shell to zsh ($zsh_path)"
    if ! chsh -s "$zsh_path"; then
      log "Warning: could not change shell automatically (you may need: chsh -s $zsh_path)"
    fi
  else
    log "Default shell already zsh"
  fi

  # Remove Alacritty shell config if it exists (not needed on WSL)
  local file="$HOME/.config/alacritty/alacritty.toml"
  if [[ "$IS_WSL" == false ]] && [[ -f "$file" ]]; then
    log "Removing Alacritty shell config to use login shell"

    if grep -q "^\[.*shell\]" "$file" 2>/dev/null; then
      if [[ "$OS" == "linux" ]]; then
        sed -i '/^\[.*shell\]/d' "$file"
        sed -i '/^program = /d' "$file"
        sed -i '/^args = /d' "$file"
      elif [[ "$OS" == "macos" ]]; then
        sed -i '' '/^\[.*shell\]/d' "$file"
        sed -i '' '/^program = /d' "$file"
        sed -i '' '/^args = /d' "$file"
      fi
    fi
  fi
}

# Create necessary directories
create_directories() {
  log_step "Creating directories"

  mkdir -p "$HOME/bin"
  mkdir -p "$HOME/projects"
  mkdir -p "$HOME/.local/bin"

  log "Directories created"
}

# Setup ai-chats project (optional)
setup_ai_chats() {
  log_step "AI Chats project"

  local repo_dir="$HOME/projects/ai-chats"

  read -rp ":: Clone ai-chats repo? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    log "Skipping ai-chats"
    return
  fi

  # Clone or pull
  if [ ! -d "$repo_dir/.git" ]; then
    git clone git@github.com:cjnowacek/ai-chats.git "$repo_dir"
  else
    git -C "$repo_dir" pull --rebase || log "Warning: could not pull ai-chats (dirty worktree?)"
    log "ai-chats already cloned"
  fi

  # Set up Claude Code memory directory
  local encoded_path="${repo_dir//\//-}"
  local memory_dir="$HOME/.claude/projects/$encoded_path/memory"
  mkdir -p "$memory_dir"
  log "Claude Code memory dir: $memory_dir"

  # Write .mcp.json into the project if it doesn't exist
  local mcp_config="$repo_dir/.mcp.json"
  if [ ! -f "$mcp_config" ]; then
    local node_path
    node_path="$(command -v node)"
    cat > "$mcp_config" <<EOF
{
  "mcpServers": {
    "chat-logger": {
      "command": "$node_path",
      "args": ["$HOME/projects/mcp-chat-logger/dist/index.js"],
      "env": {
        "VAULT_PATH": "$repo_dir",
        "OUTPUT_DIR": "$repo_dir",
        "CLAUDE_DATA_DIR": "$HOME/.claude"
      }
    }
  }
}
EOF
    log "Wrote $mcp_config"
  else
    log ".mcp.json already exists, skipping"
  fi

  log "ai-chats setup complete"
}

# Final setup steps
final_steps() {
  log_step "Final steps"

  if [[ -d "$BACKUP_DIR" ]]; then
    log "Backup saved to: $BACKUP_DIR"
  fi

  echo ""
  log "Setup complete!"
  log "Next steps:"
  log "  1. Log out and log back in (or reboot) for shell change to take effect"
  log "  2. After logging back in, open Neovim to install plugins: nvim"
  log "  3. Check SSH agent status: systemctl --user status ssh-agent"
}

# Main installation flow
main() {
  echo "Dotfiles Setup Script"
  echo ""

  # Verify dotfiles directory exists
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_error "Dotfiles directory not found at: $DOTFILES_DIR"
    log "Please clone the repository first:"
    log "  mkdir -p $HOME/projects"
    log "  git clone <your-repo-url> $HOME/projects/dotfiles"
    exit 1
  fi

  cd "$DOTFILES_DIR"

  # Run setup steps
  check_os
  install_dependencies
  setup_bash_tools
  install_rust
  install_nodejs
  setup_mcp_chat_logger
  setup_ai_chats
  install_zk_from_source
  install_neovim
  install_oh_my_zsh
  create_directories
  setup_shell
  setup_neovim
  setup_python
  setup_ssh_agent
  change_shell
  final_steps
}

# Run main function
main "$@"
