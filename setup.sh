#!/usr/bin/env bash

set -e

# Configuration
DOTFILES_DIR="$HOME/git/dotfiles"
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
    sudo pacman -S --needed --noconfirm \
      git \
      curl \
      wget \
      base-devel \
      xclip \
      ripgrep \
      fd \
      fzf \
      zsh
    ;;
  apt)
    log "Using apt"
    sudo apt-get update
    sudo apt-get install -y \
      git \
      curl \
      wget \
      build-essential \
      xclip \
      ripgrep \
      fd-find \
      fzf \
      zsh
    ;;
  dnf)
    log "Using dnf"
    sudo dnf install -y \
      git \
      curl \
      wget \
      @development-tools \
      xclip \
      ripgrep \
      fd-find \
      fzf \
      zsh
    ;;
  brew)
    if ! command -v brew &>/dev/null; then
      log "Installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    log "Using Homebrew"
    brew install git curl wget ripgrep fd fzf zsh
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
    source "$HOME/.cargo/env"
    log "Rust installed"
  else
    log "Rust already installed"
  fi
}

# Install Neovim
install_neovim() {
  log_step "Installing Neovim"

  if ! command -v nvim &>/dev/null; then
    log "Installing Neovim"

    case "$PKG_MANAGER" in
    pacman)
      sudo pacman -S --needed --noconfirm neovim
      ;;
    apt)
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
      sudo rm -rf /opt/nvim
      sudo tar -C /opt -xzf nvim-linux64.tar.gz
      rm nvim-linux64.tar.gz
      sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
      ;;
    dnf)
      sudo dnf install -y neovim
      ;;
    brew)
      brew install neovim
      ;;
    esac

    log "Neovim installed"
  else
    log "Neovim already installed"
  fi
}

# Setup shell configurations
setup_shell() {
  log_step "Setting up shell configurations"

  create_symlink "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"
  create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

  mkdir -p "$HOME/dotfiles/unix"
  create_symlink "$DOTFILES_DIR/unix/.unix_aliases" "$HOME/dotfiles/unix/.unix_aliases"

  log "Shell configurations linked"
}

# Setup Neovim
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

  log "Installing Neovim plugins"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
  log "Neovim plugins installed"
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

# Setup Python environment
setup_python() {
  log_step "Setting up Python environment"

  if command -v python3 &>/dev/null; then
    log "Installing pipx"

    case "$PKG_MANAGER" in
    pacman)
      # On Arch, install pipx via pacman (PEP 668 compliance)
      sudo pacman -S --needed --noconfirm python-pipx
      ;;
    apt)
      sudo apt-get install -y python3-pip python3-venv
      python3 -m pip install --user pipx
      python3 -m pipx ensurepath
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

# Change default shell to zsh
change_shell() {
  log_step "Setting default shell"

  if [[ "$SHELL" != "$(which zsh)" ]]; then
    log "Changing default shell to zsh"
    chsh -s "$(which zsh)"
    log "Default shell changed (effective on next login)"
  else
    log "Default shell is already zsh"
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

# Final setup steps
final_steps() {
  log_step "Final steps"

  if [[ -d "$BACKUP_DIR" ]]; then
    log "Backup saved to: $BACKUP_DIR"
  fi

  echo ""
  log "Setup complete!"
  log "Next steps:"
  log "  1. Restart your terminal or run: source ~/.zshrc"
  log "  2. Open Neovim: nvim"
}

# Main installation flow
main() {
  echo "Dotfiles Setup Script"
  echo ""

  # Verify dotfiles directory exists
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_error "Dotfiles directory not found at: $DOTFILES_DIR"
    log "Please clone the repository first:"
    log "  mkdir -p ~/git"
    log "  git clone <your-repo-url> ~/git/dotfiles"
    exit 1
  fi

  cd "$DOTFILES_DIR"

  # Run setup steps
  check_os
  install_dependencies
  install_rust
  install_nodejs
  install_neovim
  install_oh_my_zsh
  create_directories
  setup_shell
  setup_neovim
  setup_python
  change_shell
  final_steps
}

# Run main function
main "$@"
