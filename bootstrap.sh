#!/usr/bin/env bash

set -euo pipefail

# Configuration
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Host role: picks which hosts/<role>/ configs get linked for hypr and waybar.
# Auto-detected by battery presence; override with DOTFILES_HOST=desktop|laptop.
detect_host_role() {
  if [[ -n "${DOTFILES_HOST:-}" ]]; then
    HOST_ROLE="$DOTFILES_HOST"
  elif compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    HOST_ROLE="laptop"
  else
    HOST_ROLE="desktop"
  fi
}

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

    # An aborted pacman leaves a stale lock that fails every later run.
    # Only remove it when no pacman is actually running.
    if [[ -f /var/lib/pacman/db.lck ]] && ! pgrep -x pacman >/dev/null; then
      log "Removing stale pacman lock (no pacman running)"
      sudo rm -f /var/lib/pacman/db.lck
    fi

    # On a machine that hasn't updated in months the old keyring rejects
    # current package signatures ("marginal trust"), so refresh it first.
    sudo pacman -Sy --noconfirm archlinux-keyring
    sudo pacman -Su --noconfirm

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
        pandoc \
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
        pandoc \
        zsh
    fi

    # Everything the hypr/waybar configs exec or bind. The configs land on
    # every Linux machine, so a missing tool here is a silently dead keybind
    # or autostart (this is how the laptop ran without dunst, cliphist, and
    # the waybar Nerd Font icons for months).
    if [[ "$IS_WSL" != true ]] && command -v Hyprland &>/dev/null; then
      log "Installing Hyprland session tools"
      sudo pacman -S --needed --noconfirm \
        waybar hypridle hyprlock hyprpaper hyprsunset \
        dunst cliphist wl-clipboard wofi \
        grim slurp swappy playerctl brightnessctl \
        pavucontrol kitty yazi btop \
        ttf-jetbrains-mono-nerd
    fi

    # Install yay AUR helper
    if ! command -v yay &>/dev/null; then
      log "Installing yay (AUR helper)"
      local yay_tmp="/tmp/yay-build"
      rm -rf "$yay_tmp"
      git clone https://aur.archlinux.org/yay.git "$yay_tmp"
      (cd "$yay_tmp" && makepkg -si --noconfirm)
      rm -rf "$yay_tmp"
      log "yay installed"
    else
      log "yay already installed"
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
        pandoc \
        zsh \
        libasound2t64 \
        libnotify4 \
        libnss3 \
        xdg-utils \
        libsecret-1-0
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
        pandoc \
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
        pandoc \
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
        pandoc \
        zsh
    fi
    ;;
  brew)
    if ! command -v brew &>/dev/null; then
      log "Installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    log "Using Homebrew"
    brew install git curl wget ripgrep fd fzf eza pandoc zsh
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
  log_step "Installing Neovim"

  if command -v nvim &>/dev/null; then
    log "Neovim already installed: $(nvim --version | head -n1)"
    return 0
  fi

  case "$PKG_MANAGER" in
  pacman)
    sudo pacman -S --needed --noconfirm neovim
    ;;
  brew)
    brew install neovim
    ;;
  *)
    # AppImage fallback for Debian/Fedora/WSL
    local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"
    log "Downloading Neovim AppImage..."
    sudo curl -fLLo /usr/local/bin/nvim "$url" || {
      log_error "Failed to download Neovim AppImage"
      return 1
    }
    sudo chmod +x /usr/local/bin/nvim

    if ! file /usr/local/bin/nvim | grep -qi 'ELF'; then
      log_error "Downloaded Neovim is not a valid executable"
      head -c 200 /usr/local/bin/nvim; echo
      sudo rm -f /usr/local/bin/nvim
      return 1
    fi
    ;;
  esac

  log "Neovim installed: $(nvim --version | head -n1)"
}


# Setup shell configurations
setup_shell() {
  log_step "Setting up shell configurations"

  create_symlink "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"
  create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  create_symlink "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"

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

# Setup Hyprland configuration
setup_hyprland() {
  log_step "Setting up Hyprland configuration"

  mkdir -p "$HOME/.config"

  if [[ -L "$HOME/.config/hypr" ]]; then
    rm "$HOME/.config/hypr"
  elif [[ -d "$HOME/.config/hypr" ]]; then
    backup_file "$HOME/.config/hypr"
  fi

  ln -sf "$DOTFILES_DIR/hypr/.config/hypr" "$HOME/.config/hypr"

  # Per-host configs: relative symlinks inside the repo dir (gitignored)
  local hypr_dir="$DOTFILES_DIR/hypr/.config/hypr"
  local f
  for f in host.conf hypridle.conf hyprlock.conf hyprpaper.conf; do
    ln -sfn "hosts/$HOST_ROLE/$f" "$hypr_dir/$f"
  done
  log "Hyprland configuration linked (host role: $HOST_ROLE)"
}

# Setup Waybar configuration (status bar for Hyprland)
setup_waybar() {
  log_step "Setting up Waybar configuration"

  create_symlink "$DOTFILES_DIR/waybar/.config/waybar" "$HOME/.config/waybar"

  # Per-host configs: relative symlinks inside the repo dir (gitignored)
  local waybar_dir="$DOTFILES_DIR/waybar/.config/waybar"
  local f
  for f in config.jsonc style.css; do
    ln -sfn "hosts/$HOST_ROLE/$f" "$waybar_dir/$f"
  done
  log "Waybar configuration linked (host role: $HOST_ROLE)"
}

# Setup Obsidian configuration
setup_obsidian() {
  log_step "Setting up Obsidian configuration"

  # Link .obsidian config into each vault that exists. Windows counterpart is
  # the -Vaults param in bootstrap.ps1; keep the two lists in sync.
  # Override: VAULTS="/path/one /path/two" ./bootstrap.sh
  local obsidian_src="$DOTFILES_DIR/obsidian/.obsidian"
  local vaults
  if [[ -n "${VAULTS:-}" ]]; then
    read -ra vaults <<< "$VAULTS"
  else
    vaults=("$HOME/dev/zettelpara" "$HOME/dev/ai-chats")
  fi

  for vault in "${vaults[@]}"; do
    if [[ -d "$vault" ]]; then
      local target="$vault/.obsidian"
      if [[ -L "$target" ]]; then
        rm "$target"
      elif [[ -d "$target" ]]; then
        backup_file "$target"
      fi
      ln -sf "$obsidian_src" "$target"
      log "Obsidian config linked: $target"
    else
      log "Skipped (no such vault): $vault"
    fi
  done

  log "Obsidian plugins will need to be installed from community browser on first launch"
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
install_zk() {
  log_step "Installing zk"

  # If zk already exists, report version and skip
  if command -v zk >/dev/null 2>&1; then
    log "zk already installed: $(zk --version)"
    return 0
  fi

  case "$PKG_MANAGER" in
  pacman)
    sudo pacman -S --needed --noconfirm zk
    ;;
  apt)
    sudo apt update
    sudo apt install -y golang-go make git
    rm -rf /tmp/zk-build
    git clone https://github.com/zk-org/zk.git /tmp/zk-build
    (cd /tmp/zk-build && make build)
    sudo install -m 0755 /tmp/zk-build/zk /usr/local/bin/zk
    rm -rf /tmp/zk-build
    ;;
  dnf)
    sudo dnf install -y golang make git
    rm -rf /tmp/zk-build
    git clone https://github.com/zk-org/zk.git /tmp/zk-build
    (cd /tmp/zk-build && make build)
    sudo install -m 0755 /tmp/zk-build/zk /usr/local/bin/zk
    rm -rf /tmp/zk-build
    ;;
  brew)
    brew install zk
    ;;
  esac

  zk --version || {
    log_error "zk installation failed"
    return 1
  }

  log "zk installed successfully"
}

# Install Claude Code CLI (native binary; the nvim plugin shells out to it)
install_claude_code() {
  log_step "Installing Claude Code"

  if command -v claude >/dev/null 2>&1; then
    log "claude already installed: $(claude --version)"
    return 0
  fi

  curl -fsSL https://claude.ai/install.sh | bash

  # The installer drops the binary in ~/.local/bin, which may not be on PATH yet
  export PATH="$HOME/.local/bin:$PATH"

  claude --version || {
    log_error "Claude Code installation failed"
    return 1
  }

  log "Claude Code installed successfully"
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

  mkdir -p "$HOME/dev"

  if [ ! -d "$HOME/dev/bash/.git" ]; then
    git clone git@github.com:cjnowacek/bash.git "$HOME/dev/bash"
  else
    git -C "$HOME/dev/bash" pull --rebase
  fi
}

# Check we can reach a repo (e.g. private repos need SSH access)
can_access_repo() {
  git ls-remote "$1" &>/dev/null
}

# Setup MCP chat-logger server
setup_mcp_chat_logger() {
  log_step "Setting up MCP chat-logger"

  local repo_dir="$HOME/dev/mcp-chat-logger"

  # Clone or pull
  if [ ! -d "$repo_dir/.git" ]; then
    if ! can_access_repo git@github.com:cjnowacek/mcp-chat-logger.git; then
      log "Warning: no access to MCP-Chat-Logger (private repo) — skipping"
      return
    fi
    git clone git@github.com:cjnowacek/mcp-chat-logger.git "$repo_dir"
  else
    git -C "$repo_dir" stash
    git -C "$repo_dir" pull --rebase
    git -C "$repo_dir" stash pop 2>/dev/null || true
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
      vault_path="$HOME/dev/ai-chats"
    fi
  else
    vault_path="$HOME/dev/ai-chats"
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
  mkdir -p "$HOME/dev"
  mkdir -p "$HOME/.local/bin"

  log "Directories created"
}

# Setup zettelpara vault (optional)
setup_zettelpara_vault() {
  log_step "Zettelpara vault"

  local repo_dir="$HOME/dev/zettelpara"

  read -rp ":: Clone zettelpara repo? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    log "Skipping zettelpara"
    return
  fi

  # Clone or pull
  if [ ! -d "$repo_dir/.git" ]; then
    if ! can_access_repo git@github.com:cjnowacek/zettelpara.git; then
      log "Warning: no access to zettelpara (private repo) — skipping"
      return
    fi
    git clone git@github.com:cjnowacek/zettelpara.git "$repo_dir"
  else
    git -C "$repo_dir" pull --rebase || log "Warning: could not pull zettelpara (dirty worktree?)"
    log "zettelpara already cloned"
  fi

  log "zettelpara setup complete"
}

# Setup AI-Chats project (optional)
setup_ai_chats() {
  log_step "AI Chats project"

  local repo_dir="$HOME/dev/ai-chats"

  read -rp ":: Clone AI-Chats repo? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    log "Skipping AI-Chats"
    return
  fi

  # Clone or pull
  if [ ! -d "$repo_dir/.git" ]; then
    if ! can_access_repo git@github.com:cjnowacek/ai-chats.git; then
      log "Warning: no access to AI-Chats (private repo) — skipping"
      return
    fi
    git clone git@github.com:cjnowacek/ai-chats.git "$repo_dir"
  else
    git -C "$repo_dir" pull --rebase || log "Warning: could not pull AI-Chats (dirty worktree?)"
    log "AI-Chats already cloned"
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
      "args": ["$HOME/dev/mcp-chat-logger/dist/index.js"],
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

  log "AI-Chats setup complete"
}

# Final setup steps
final_steps() {
  log_step "Final steps"

  if [[ -d "$BACKUP_DIR" ]]; then
    log "Backup saved to: $BACKUP_DIR"
  fi

  # Prompt to install Obsidian
  echo ""
  read -rp ":: Install Obsidian? (requires sudo) [y/N] " install_obsidian
  if [[ "$install_obsidian" =~ ^[Yy]$ ]]; then
    case "$PKG_MANAGER" in
    pacman)
      # Obsidian moved from the AUR into the official extra repo.
      sudo pacman -S --needed --noconfirm obsidian
      ;;
    apt)
      local obsidian_deb="/tmp/obsidian.deb"
      if [[ ! -f "$obsidian_deb" ]]; then
        log "Downloading latest Obsidian .deb..."
        local obsidian_url
        obsidian_url=$(curl -sL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
          | grep -oP '"browser_download_url":\s*"\K[^"]*\.deb' | head -1)
        curl -L -o "$obsidian_deb" "$obsidian_url"
      fi
      log "Installing Obsidian dependencies and package..."
      sudo apt-get install -y libasound2t64 libnotify4 libnss3 xdg-utils libsecret-1-0 libxss1
      sudo dpkg -i "$obsidian_deb"
      ;;
    brew)
      brew install --cask obsidian
      ;;
    *)
      log "No automated Obsidian install for this package manager — install manually"
      ;;
    esac
    log "Obsidian installed"
  else
    log "Skipping Obsidian"
  fi

  echo ""
  log "Setup complete!"
  log "Next steps:"
  log "  1. Log out and log back in (or reboot) for shell change to take effect"
  log "  2. After logging back in, open Neovim to install plugins: nvim"
  log "  3. Check SSH agent status: systemctl --user status ssh-agent"
}

# Main installation flow
# Read-only health check: reports drift without changing anything.
doctor() {
  local ok=true

  log_step "Doctor: symlink health"
  local link target
  for link in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.zprofile" \
    "$HOME/.config/nvim" "$HOME/.config/hypr" "$HOME/.config/waybar"; do
    if [[ ! -e "$link" && ! -L "$link" ]]; then
      log "MISSING  $link (run: ./bootstrap.sh links)"
      ok=false
    elif [[ ! -L "$link" ]]; then
      log "NOT A LINK  $link is a real file/dir, not linked to the repo"
      ok=false
    elif [[ ! -e "$link" ]]; then
      log "DANGLING  $link -> $(readlink "$link") (target gone; run: ./bootstrap.sh links)"
      ok=false
    else
      target=$(readlink -f "$link")
      if [[ "$target" != "$DOTFILES_DIR"/* ]]; then
        log "FOREIGN  $link -> $target (outside $DOTFILES_DIR)"
        ok=false
      fi
    fi
  done

  # Any other dangling links lying around $HOME and ~/.config
  $ok && log "All linked into $DOTFILES_DIR"

  local dangling
  dangling=$(find "$HOME" -maxdepth 1 -xtype l 2>/dev/null
    find "$HOME/.config" -maxdepth 1 -xtype l 2>/dev/null)
  if [[ -n "$dangling" ]]; then
    log "Other dangling symlinks:"
    printf '     %s\n' $dangling
    ok=false
  fi

  log_step "Doctor: per-host links (role: $HOST_ROLE)"
  local f
  for f in host.conf hypridle.conf hyprlock.conf hyprpaper.conf; do
    if [[ "$(readlink "$DOTFILES_DIR/hypr/.config/hypr/$f" 2>/dev/null)" != "hosts/$HOST_ROLE/$f" ]]; then
      log "WRONG/MISSING  hypr/$f should link to hosts/$HOST_ROLE/$f (run: ./bootstrap.sh links)"
      ok=false
    fi
  done
  for f in config.jsonc style.css; do
    if [[ "$(readlink "$DOTFILES_DIR/waybar/.config/waybar/$f" 2>/dev/null)" != "hosts/$HOST_ROLE/$f" ]]; then
      log "WRONG/MISSING  waybar/$f should link to hosts/$HOST_ROLE/$f (run: ./bootstrap.sh links)"
      ok=false
    fi
  done

  log_step "Doctor: tools the configs invoke"
  local missing=()
  local cmd
  local doctor_tools=(waybar hypridle hyprlock dunst cliphist wofi grim slurp \
    swappy playerctl wl-copy kitty yazi btop nvim zsh)
  # brightnessctl is only bound in the laptop host.conf
  [[ "$HOST_ROLE" == "laptop" ]] && doctor_tools+=(brightnessctl)
  for cmd in "${doctor_tools[@]}"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if ((${#missing[@]})); then
    log "MISSING TOOLS: ${missing[*]}"
    ok=false
  else
    log "All present"
  fi

  if command -v fc-list &>/dev/null && ! fc-list 2>/dev/null | grep -i "jetbrainsmono nerd" >/dev/null; then
    log "MISSING FONT: JetBrainsMono Nerd Font (waybar/hyprlock icons will be tofu)"
    ok=false
  fi

  log_step "Doctor: system"
  if [[ -f /var/lib/pacman/db.lck ]] && ! pgrep -x pacman >/dev/null; then
    log "STALE pacman lock: sudo rm /var/lib/pacman/db.lck"
    ok=false
  fi
  if [[ -n "$(cd "$DOTFILES_DIR" && git status --porcelain 2>/dev/null)" ]]; then
    log "Repo has uncommitted changes (git status in $DOTFILES_DIR)"
  fi
  local behind
  behind=$(cd "$DOTFILES_DIR" && git rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
  [[ "$behind" -gt 0 ]] && log "Repo is $behind commit(s) behind origin — git pull, then ./bootstrap.sh links"

  echo ""
  if $ok; then log "Doctor: all clear"; else log "Doctor: issues found (see above)"; fi
}

main() {
  echo "Dotfiles Setup Script"
  echo ""

  # On WSL, symlink dotfiles dir from Windows filesystem if needed
  if [[ ! -d "$DOTFILES_DIR" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_DOTFILES="/mnt/c/Users/$(whoami)/.dotfiles"
    if [[ -d "$WIN_DOTFILES" ]]; then
      log "WSL detected — creating symlink to Windows dotfiles"
      mkdir -p "$(dirname "$DOTFILES_DIR")"
      ln -sf "$WIN_DOTFILES" "$DOTFILES_DIR"
    fi
  fi

  # Verify dotfiles directory exists
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_error "Dotfiles directory not found at: $DOTFILES_DIR"
    log "Please clone the repository first:"
    log "  git clone <your-repo-url> $HOME/.dotfiles"
    exit 1
  fi

  cd "$DOTFILES_DIR"

  detect_host_role
  log "Host role: $HOST_ROLE (override with DOTFILES_HOST=desktop|laptop)"

  # `./bootstrap.sh doctor` — read-only drift report, changes nothing.
  if [[ "${1:-}" == "doctor" ]]; then
    doctor
    return
  fi

  # `./bootstrap.sh links` — only (re)create symlinks, e.g. after a pull that
  # changed the hosts/ layout. Skips all installs.
  if [[ "${1:-}" == "links" ]]; then
    setup_shell
    setup_neovim
    setup_hyprland
    setup_waybar
    return
  fi

  # Run setup steps
  check_os
  install_dependencies
  setup_bash_tools
  install_rust
  install_nodejs
  setup_mcp_chat_logger
  setup_ai_chats
  setup_zettelpara_vault
  install_zk
  install_claude_code
  install_neovim
  install_oh_my_zsh
  create_directories
  setup_shell
  setup_neovim
  setup_hyprland
  setup_waybar
  setup_obsidian
  setup_python
  setup_ssh_agent
  change_shell
  final_steps
}

# Run main function
main "$@"
