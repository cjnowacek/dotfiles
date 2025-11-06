#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOTFILES_DIR="$HOME/git/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Helper functions
print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# Check if running on supported OS
check_os() {
  print_header "Checking Operating System"

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_success "Detected Linux"
    OS="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    print_success "Detected macOS"
    OS="macos"
  else
    print_error "Unsupported operating system: $OSTYPE"
    exit 1
  fi
}

# Backup existing files
backup_file() {
  local file=$1
  if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
    mkdir -p "$BACKUP_DIR"
    print_warning "Backing up existing file: $file"
    cp -r "$file" "$BACKUP_DIR/"
    rm -rf "$file"
  elif [[ -L "$file" ]]; then
    print_info "Removing existing symlink: $file"
    rm "$file"
  fi
}

# Create symlink
create_symlink() {
  local source=$1
  local target=$2

  if [[ -e "$source" ]]; then
    backup_file "$target"

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$target")"

    ln -sf "$source" "$target"
    print_success "Linked: $source -> $target"
  else
    print_warning "Source file not found: $source"
  fi
}

# Install system dependencies
install_dependencies() {
  print_header "Installing System Dependencies"

  if [[ "$OS" == "linux" ]]; then
    if command -v apt-get &>/dev/null; then
      print_info "Installing dependencies with apt..."
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
    elif command -v dnf &>/dev/null; then
      print_info "Installing dependencies with dnf..."
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
    else
      print_warning "Package manager not supported. Please install dependencies manually."
    fi
  elif [[ "$OS" == "macos" ]]; then
    if ! command -v brew &>/dev/null; then
      print_info "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    print_info "Installing dependencies with Homebrew..."
    brew install git curl wget ripgrep fd fzf zsh
  fi

  print_success "Dependencies installed"
}

# Install Oh My Zsh
install_oh_my_zsh() {
  print_header "Installing Oh My Zsh"

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    print_info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_success "Oh My Zsh installed"
  else
    print_info "Oh My Zsh already installed"
  fi
}

# Install Rust
install_rust() {
  print_header "Installing Rust"

  if ! command -v rustc &>/dev/null; then
    print_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    print_success "Rust installed"
  else
    print_info "Rust already installed"
  fi
}

# Install Neovim
install_neovim() {
  print_header "Installing Neovim"

  if ! command -v nvim &>/dev/null; then
    print_info "Installing Neovim..."

    if [[ "$OS" == "linux" ]]; then
      # Install latest stable Neovim
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
      sudo rm -rf /opt/nvim
      sudo tar -C /opt -xzf nvim-linux64.tar.gz
      rm nvim-linux64.tar.gz
      sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    elif [[ "$OS" == "macos" ]]; then
      brew install neovim
    fi

    print_success "Neovim installed"
  else
    print_info "Neovim already installed"
  fi
}

# Setup shell configurations
setup_shell() {
  print_header "Setting Up Shell Configurations"

  # Bash
  create_symlink "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"

  # Zsh
  create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

  # Unix aliases (shared)
  create_symlink "$DOTFILES_DIR/unix/.unix_aliases" "$HOME/dotfiles/unix/.unix_aliases"
  mkdir -p "$HOME/dotfiles/unix"

  print_success "Shell configurations linked"
}

# Setup Neovim
setup_neovim() {
  print_header "Setting Up Neovim Configuration"

  # Create Neovim config directory
  mkdir -p "$HOME/.config"

  # Link entire nvim config directory
  if [[ -L "$HOME/.config/nvim" ]]; then
    rm "$HOME/.config/nvim"
  elif [[ -d "$HOME/.config/nvim" ]]; then
    backup_file "$HOME/.config/nvim"
  fi

  ln -sf "$DOTFILES_DIR/nvim/.config/nvim" "$HOME/.config/nvim"
  print_success "Neovim configuration linked"

  # Install lazy.nvim and plugins
  print_info "Installing Neovim plugins..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
  print_success "Neovim plugins installed"
}

# Install Node.js (for markdown-preview)
install_nodejs() {
  print_header "Installing Node.js"

  if ! command -v node &>/dev/null; then
    print_info "Installing Node.js..."

    if [[ "$OS" == "linux" ]]; then
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif [[ "$OS" == "macos" ]]; then
      brew install node
    fi

    print_success "Node.js installed"
  else
    print_info "Node.js already installed"
  fi
}

# Setup Python environment
setup_python() {
  print_header "Setting Up Python Environment"

  if command -v python3 &>/dev/null; then
    print_info "Installing Python packages..."

    # Install pipx for better tool management
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath

    print_success "Python environment configured"
  else
    print_warning "Python3 not found. Please install Python3."
  fi
}

# Change default shell to zsh
change_shell() {
  print_header "Setting Default Shell"

  if [[ "$SHELL" != "$(which zsh)" ]]; then
    print_info "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
    print_success "Default shell changed to zsh (will take effect on next login)"
  else
    print_info "Default shell is already zsh"
  fi
}

# Create necessary directories
create_directories() {
  print_header "Creating Necessary Directories"

  mkdir -p "$HOME/bin"
  mkdir -p "$HOME/projects"
  mkdir -p "$HOME/.local/bin"

  print_success "Directories created"
}

# Final setup steps
final_steps() {
  print_header "Final Setup Steps"

  print_info "Sourcing shell configuration..."

  # Source the appropriate shell config
  if [[ -f "$HOME/.zshrc" ]]; then
    print_info "Please run: source ~/.zshrc"
  fi

  if [[ -f "$HOME/.bashrc" ]]; then
    print_info "Or run: source ~/.bashrc"
  fi

  if [[ -d "$BACKUP_DIR" ]]; then
    print_warning "Backup of old files saved to: $BACKUP_DIR"
  fi
}

# Main installation flow
main() {
  print_header "Dotfiles Setup Script"
  echo "This script will set up your development environment."
  echo ""

  # Verify dotfiles directory exists
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    print_error "Dotfiles directory not found at: $DOTFILES_DIR"
    print_info "Please clone the repository first:"
    print_info "  mkdir -p ~/git"
    print_info "  git clone <your-repo-url> ~/git/dotfiles"
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

  print_header "Setup Complete! 🎉"
  echo ""
  print_success "Your dotfiles have been installed successfully!"
  echo ""
  print_info "Next steps:"
  echo "  1. Restart your terminal or run: source ~/.zshrc"
  echo "  2. Open Neovim to complete plugin installation: nvim"
  echo "  3. Customize your configuration as needed"
  echo ""
}

# Run main function
main "$@"
