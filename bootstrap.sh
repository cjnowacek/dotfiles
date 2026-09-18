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

# Machine name: picks which claude/.claude/machines/<name>/ notes get linked.
# Deliberately finer than HOST_ROLE: those notes describe one physical computer
# (its GPU, disks, monitors), and the Rocky VM also detects as "desktop".
# DOTFILES_MACHINE wins, then the untracked ~/.config/dotfiles/machine, then the
# hostname — which is last because the Arch installs never set one and all
# report "archlinux".
MACHINE_FILE="$HOME/.config/dotfiles/machine"
detect_machine() {
  if [[ -n "${DOTFILES_MACHINE:-}" ]]; then
    MACHINE="$DOTFILES_MACHINE"
  elif [[ -s "$MACHINE_FILE" ]]; then
    MACHINE=$(tr -d '[:space:]' <"$MACHINE_FILE")
  else
    MACHINE=$(uname -n)
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

# Detect OS and package manager, then load the matching backend.
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
    if command -v pacman &>/dev/null; then
      PKG_MANAGER="pacman"
      log "Detected Arch Linux"
    elif command -v apt-get &>/dev/null; then
      PKG_MANAGER="apt"
      log "Detected Debian/Ubuntu"
    elif command -v dnf &>/dev/null; then
      PKG_MANAGER="dnf"
      log "Detected Fedora/RHEL family"
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

  load_pkg_backend
}

# Everything that differs per package manager lives in bootstrap.d/<manager>.sh.
# Each backend defines exactly these functions; the generic install_* steps
# below call them. To support a new distro: add a detection branch in
# check_os and a bootstrap.d/<manager>.sh that defines all of them.
PKG_INTERFACE=(
  pkg_install_base      # refresh repos, install git/curl/build tools/ripgrep/fd/fzf/eza/pandoc/zsh
  pkg_install_neovim    # a LazyVim-capable nvim (package or install_neovim_appimage)
  pkg_install_nodejs    # node + npm
  pkg_install_zk        # zk (package or build_zk_from_source)
  pkg_install_pipx      # pipx on PATH
  pkg_install_obsidian  # Obsidian desktop, or a log line saying it's manual
)

load_pkg_backend() {
  local backend="$DOTFILES_DIR/bootstrap.d/$PKG_MANAGER.sh"
  if [[ ! -r "$backend" ]]; then
    log_error "No package manager backend at $backend"
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$backend"

  local fn
  for fn in "${PKG_INTERFACE[@]}"; do
    if ! declare -F "$fn" >/dev/null; then
      log_error "$backend does not define $fn"
      exit 1
    fi
  done
  log "Package manager backend: $PKG_MANAGER"
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
  pkg_install_base
  log "Dependencies installed"
}

# Shared helpers for backends whose repos lack a usable package.

# Upstream Neovim AppImage into /usr/local/bin (needs libfuse2 and `file`).
install_neovim_appimage() {
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
}

# Build zk from source (caller installs go, make, git first).
build_zk_from_source() {
  rm -rf /tmp/zk-build
  git clone https://github.com/zk-org/zk.git /tmp/zk-build
  (cd /tmp/zk-build && make build)
  sudo install -m 0755 /tmp/zk-build/zk /usr/local/bin/zk
  rm -rf /tmp/zk-build
}

# eza is aliased in unix/.unix_aliases but is missing from EPEL 9, so on
# distros where the package manager could not provide it, drop the upstream
# static binary into /usr/local/bin.
install_eza() {
  if command -v eza &>/dev/null; then
    return 0
  fi
  log_step "Installing eza from GitHub release"

  local arch
  arch=$(uname -m)
  if [[ "$arch" != "x86_64" ]]; then
    log_error "No eza release fallback for $arch — install it manually"
    return 0
  fi

  local url="https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL "$url" | tar -xz -C "$tmp"; then
    sudo install -m 0755 "$tmp/eza" /usr/local/bin/eza
    log "eza installed: $(eza --version | head -n1)"
  else
    log_error "Failed to download eza — the z alias will be broken until it is installed"
  fi
  rm -rf "$tmp"
}

# JetBrainsMono Nerd Font: kitty, waybar, hyprlock, and the GNOME skin all
# use it. pacman ships it (ttf-jetbrains-mono-nerd); EPEL/apt do not, so
# drop the upstream release into ~/.local/share/fonts when fontconfig
# can't see it.
install_nerd_font() {
  log_step "Installing JetBrainsMono Nerd Font"
  if fc-list 2>/dev/null | grep -qi "jetbrainsmono nerd"; then
    log "JetBrainsMono Nerd Font already installed"
    return 0
  fi
  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerd" tmp
  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/jbm.tar.xz" \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz; then
    mkdir -p "$dir"
    tar -xJf "$tmp/jbm.tar.xz" -C "$dir"
    rm -f "$dir"/LICENSE* "$dir"/README*
    fc-cache -f >/dev/null 2>&1 || true
    log "JetBrainsMono Nerd Font installed to $dir (restart terminals to pick it up)"
  else
    log_error "Could not download JetBrainsMono Nerd Font"
  fi
  rm -rf "$tmp"
}

# Release-binary fallbacks for tools the package manager could not provide
# (yazi is in no EL9 repo; rclone is EPEL but needs root). Dropped into
# ~/.local/bin, which unix/.unix_aliases puts on PATH. pacman hosts get
# both from the repos and skip these.
install_yazi() {
  log_step "Installing yazi"
  if command -v yazi &>/dev/null; then
    log "yazi already installed"
    return 0
  fi
  [[ "$(uname -m)" == "x86_64" ]] || { log_error "No yazi release fallback for $(uname -m)"; return 0; }
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/yazi.zip" \
      https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip \
    && unzip -qo "$tmp/yazi.zip" -d "$tmp"; then
    mkdir -p "$HOME/.local/bin"
    cp "$tmp"/yazi-x86_64-unknown-linux-musl/{yazi,ya} "$HOME/.local/bin/"
    chmod 755 "$HOME/.local/bin/yazi" "$HOME/.local/bin/ya"
    log "yazi installed to ~/.local/bin"
  else
    log_error "Could not download yazi"
  fi
  rm -rf "$tmp"
}

install_rclone() {
  log_step "Installing rclone"
  if command -v rclone &>/dev/null; then
    log "rclone already installed"
    return 0
  fi
  [[ "$(uname -m)" == "x86_64" ]] || { log_error "No rclone release fallback for $(uname -m)"; return 0; }
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/rclone.zip" https://downloads.rclone.org/rclone-current-linux-amd64.zip \
    && unzip -qo "$tmp/rclone.zip" -d "$tmp"; then
    mkdir -p "$HOME/.local/bin"
    cp "$tmp"/rclone-*-linux-amd64/rclone "$HOME/.local/bin/rclone"
    chmod 755 "$HOME/.local/bin/rclone"
    log "rclone installed to ~/.local/bin"
  else
    log_error "Could not download rclone"
  fi
  rm -rf "$tmp"
}

install_btop() {
  log_step "Installing btop"
  if command -v btop &>/dev/null; then
    log "btop already installed"
    return 0
  fi
  [[ "$(uname -m)" == "x86_64" ]] || { log_error "No btop release fallback for $(uname -m)"; return 0; }
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL -o "$tmp/btop.tgz" \
      https://github.com/aristocratos/btop/releases/latest/download/btop-x86_64-unknown-linux-musl.tar.gz \
    && tar -xzf "$tmp/btop.tgz" -C "$tmp"; then
    mkdir -p "$HOME/.local/bin"
    cp "$tmp/btop/bin/btop" "$HOME/.local/bin/btop"
    chmod 755 "$HOME/.local/bin/btop"
    log "btop installed to ~/.local/bin"
  else
    log_error "Could not download btop"
  fi
  rm -rf "$tmp"
}

# Obsidian AppImage into ~/.local/bin for hosts with no package (dnf backend
# calls this from pkg_install_obsidian). Picks the newest release that ships
# an x86_64 AppImage: obsidian-releases tags mobile-only releases too, whose
# asset list is empty. Needs fuse-libs (in the dnf base list).
install_obsidian_appimage() {
  if command -v obsidian &>/dev/null; then
    log "Obsidian already installed"
    return 0
  fi
  [[ "$(uname -m)" == "x86_64" ]] || { log_error "No Obsidian AppImage fallback for $(uname -m)"; return 0; }
  local url
  url=$(curl -fsSL "https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=10" \
    | grep -oE '"browser_download_url": *"[^"]*/Obsidian-[0-9.]+\.AppImage"' \
    | head -1 | grep -oE 'https://[^"]+')
  if [[ -n "$url" ]] && curl -fsSL -o "$HOME/.local/bin/obsidian" "$url"; then
    chmod 755 "$HOME/.local/bin/obsidian"
    log "Obsidian AppImage installed to ~/.local/bin/obsidian ($(basename "$url"))"
  else
    log_error "Could not download the Obsidian AppImage"
  fi
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

  pkg_install_neovim

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

  # Per-host configs: relative symlinks inside the repo dir (gitignored).
  # hyprlock.conf and hyprpaper.conf are shared tracked files now — drop the
  # symlinks left behind by the pre-2026-08-30 layout so they don't shadow.
  local hypr_dir="$DOTFILES_DIR/hypr/.config/hypr"
  local f
  for f in hyprlock.conf hyprpaper.conf; do
    [[ -L "$hypr_dir/$f" ]] && rm "$hypr_dir/$f"
  done
  for f in host.conf hypridle.conf; do
    ln -sfn "hosts/$HOST_ROLE/$f" "$hypr_dir/$f"
  done
  log "Hyprland configuration linked (host role: $HOST_ROLE)"
}

# Setup Waybar configuration (status bar for Hyprland)
setup_waybar() {
  log_step "Setting up Waybar configuration"

  create_symlink "$DOTFILES_DIR/waybar/.config/waybar" "$HOME/.config/waybar"

  # Per-host config: one relative symlink inside the repo dir (gitignored).
  # config.jsonc and style.css are shared tracked files now — drop the
  # symlinks left behind by the pre-2026-08-30 layout so they don't shadow.
  local waybar_dir="$DOTFILES_DIR/waybar/.config/waybar"
  local f
  for f in config.jsonc style.css; do
    [[ -L "$waybar_dir/$f" ]] && rm "$waybar_dir/$f"
  done
  ln -sfn "hosts/$HOST_ROLE/host.jsonc" "$waybar_dir/host.jsonc"
  log "Waybar configuration linked (host role: $HOST_ROLE)"
}

# Setup wofi (app launcher) and per-app .desktop overrides
setup_wofi() {
  log_step "Setting up wofi configuration"

  create_symlink "$DOTFILES_DIR/wofi/.config/wofi" "$HOME/.config/wofi"

  # Stock yazi.desktop has Terminal=true, and wofi's terminal autodetection
  # silently fails on it (selecting Yazi does nothing). The override runs
  # `kitty -e yazi` directly. Linked per file, not per dir: the target dir
  # also holds Steam/Chrome-generated entries that must stay untracked.
  local apps_src="$DOTFILES_DIR/applications/.local/share/applications"
  local apps_dst="$HOME/.local/share/applications"
  local f
  for f in "$apps_src"/*.desktop; do
    create_symlink "$f" "$apps_dst/$(basename "$f")"
  done
  command -v update-desktop-database >/dev/null && update-desktop-database "$apps_dst" 2>/dev/null
  rm -f "$HOME/.cache/wofi-drun"
  log "wofi configuration and desktop overrides linked"
}

# Setup kitty (the terminal Hyprland binds and wofi launches)
setup_kitty() {
  log_step "Setting up kitty configuration"
  create_symlink "$DOTFILES_DIR/kitty/.config/kitty" "$HOME/.config/kitty"
  log "kitty configuration linked"
}

# Setup dunst (notifications)
setup_dunst() {
  log_step "Setting up dunst configuration"
  create_symlink "$DOTFILES_DIR/dunst/.config/dunst" "$HOME/.config/dunst"
  command -v dunstctl >/dev/null && dunstctl reload 2>/dev/null
  log "dunst configuration linked"
}

# Setup Claude Code machine notes (~/.claude/CLAUDE.md, loaded into every
# session on that computer). Linked per file: ~/.claude itself holds
# credentials and session history and must stay a real, untracked directory.
# Because it is a symlink, notes Claude appends land in the repo as a diff.
setup_claude_notes() {
  log_step "Setting up Claude Code machine notes"
  local src="$DOTFILES_DIR/claude/.claude/machines/$MACHINE/CLAUDE.md"
  if [[ -f "$src" ]]; then
    create_symlink "$src" "$HOME/.claude/CLAUDE.md"
    log "Claude notes linked (machine: $MACHINE)"
  else
    log "No Claude notes for machine '$MACHINE' — ~/.claude/CLAUDE.md left alone."
    log "  To track this computer: echo <name> > $MACHINE_FILE, put the notes in"
    log "  claude/.claude/machines/<name>/CLAUDE.md, then ./bootstrap.sh links"
  fi
}

# Setup GTK theme (Flexoki) + gtk settings.ini. Linked per file so
# ~/.config/gtk-3.0/bookmarks (nautilus) stays a real file.
setup_gtk() {
  log_step "Setting up GTK configuration"
  local v f
  for v in gtk-3.0 gtk-4.0; do
    for f in "$DOTFILES_DIR/gtk/.config/$v"/*; do
      create_symlink "$f" "$HOME/.config/$v/$(basename "$f")"
    done
  done
  # Flexoki = built-in Adwaita dark + the kitty/waybar palette. Named theme
  # dir because Rocky's Adwaita-dark package has no gtk-3.0 half.
  create_symlink "$DOTFILES_DIR/gtk/.local/share/themes/Flexoki" "$HOME/.local/share/themes/Flexoki"
  log "GTK configuration linked"
}

# Skin GNOME (Rocky/Maya VM) like the Hyprland hosts. No-op elsewhere.
setup_gnome() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || return 0
  log_step "Applying GNOME settings (gnome/apply.sh)"
  DOTFILES_DIR="$DOTFILES_DIR" bash "$DOTFILES_DIR/gnome/apply.sh"
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

    pkg_install_nodejs
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

  pkg_install_zk

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

    pkg_install_pipx
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

# maya-mcp (cjnowacek/maya-mcp): MCP server that drives a running Maya via
# the repo's in-Maya bridge (maya_bridge.py, 127.0.0.1:7777). Same shape as
# chat-logger: repo in ~/dev, registered in ~/.claude.json. Server needs
# Python >= 3.11; on EL9 the only one is Maya's mayapy (3.13), so the venv is
# built from it. Skipped when Maya is absent.
setup_mcp_maya() {
  log_step "Setting up MCP maya"

  local maya_bin="/usr/autodesk/maya/bin"
  if [[ ! -x "$maya_bin/mayapy" ]]; then
    log "Skipping maya-mcp (no Maya at /usr/autodesk/maya)"
    return
  fi

  local repo_dir="$HOME/dev/maya-mcp"
  if [ ! -d "$repo_dir/.git" ]; then
    if ! can_access_repo git@github.com:cjnowacek/maya-mcp.git; then
      log "Warning: no access to maya-mcp repo — skipping"
      return
    fi
    git clone git@github.com:cjnowacek/maya-mcp.git "$repo_dir"
  else
    git -C "$repo_dir" pull --rebase --autostash
  fi

  # venv: python3 if >= 3.11, else mayapy.
  local py="$maya_bin/mayapy"
  if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
    py=python3
  fi
  [[ -x "$repo_dir/.venv/bin/python" ]] || "$py" -m venv "$repo_dir/.venv"
  "$repo_dir/.venv/bin/python" -m pip install --quiet --upgrade pip
  "$repo_dir/.venv/bin/python" -m pip install --quiet -e "$repo_dir"

  # Maya side: userSetup.py imports maya_bridge at startup (per-version dir).
  local ver_dir
  for ver_dir in "$HOME"/maya/20[0-9][0-9]; do
    [[ -d "$ver_dir" ]] || continue
    mkdir -p "$ver_dir/scripts"
    ln -sfn "$DOTFILES_DIR/maya/scripts/userSetup.py" "$ver_dir/scripts/userSetup.py"
    log "Maya $(basename "$ver_dir"): userSetup.py linked (starts the bridge)"
  done

  # Register with Claude Code (~/.claude.json, user scope).
  node -e "
    const fs = require('fs');
    const [configPath, cmd] = process.argv.slice(1);
    let config = {};
    try { config = JSON.parse(fs.readFileSync(configPath, 'utf-8')); } catch {}
    if (!config.mcpServers) config.mcpServers = {};
    config.mcpServers['maya'] = { type: 'stdio', command: cmd, args: [] };
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n', 'utf-8');
  " "$HOME/.claude.json" "$repo_dir/.venv/bin/maya-mcp"

  log "MCP maya configured ($repo_dir/.venv/bin/maya-mcp; bridge starts with Maya)"
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
    pkg_install_obsidian
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

# rclone Dropbox mount (the waybar dropbox module reads this service's state)
setup_rclone_dropbox() {
  log_step "Setting up rclone Dropbox mount service"

  if ! command -v rclone &>/dev/null; then
    log "Skipping rclone-dropbox (rclone not installed)"
    return
  fi

  # Resolve the binary: /usr/bin from pacman/EPEL, ~/.local/bin on a host
  # where it was dropped in without root (the Rocky VM).
  local rclone_bin
  rclone_bin=$(command -v rclone)
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/rclone-dropbox.service" << EOF
[Unit]
Description=rclone Dropbox mount (on-demand VFS)
After=network-online.target

[Service]
Type=notify
ExecStart=$rclone_bin mount dropbox: %h/Dropbox --vfs-cache-mode writes
ExecStop=/usr/bin/fusermount -u %h/Dropbox
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload

  # Never enabled at login — CJ wants the mount strictly on-demand: start it
  # by right-clicking the waybar dropbox module (or systemctl --user start
  # rclone-dropbox). Auth is a manual, per-machine step (`rclone config`, or
  # copy ~/.config/rclone/rclone.conf from a machine that has it; the token
  # is a secret and stays out of this repo).
  if rclone listremotes 2>/dev/null | grep -qx "dropbox:"; then
    mkdir -p "$HOME/Dropbox"
    log "rclone-dropbox service installed (on-demand; start from the waybar module)"
  else
    log "rclone remote 'dropbox:' not configured — service installed but unusable"
    log "  (run: rclone config   or copy ~/.config/rclone/rclone.conf from the desktop)"
  fi
}

# Daily GitHub backup: mirrors + bundles to ~/backups/github, bundles synced
# to Dropbox. The script lives in the bash tools repo (setup_bash_tools).
setup_github_backup() {
  log_step "Setting up GitHub backup timer"

  local script="$HOME/dev/bash/github-backup.sh"
  if [[ ! -x "$script" ]]; then
    log "Skipping github-backup (script not found at $script)"
    return
  fi

  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/github-backup.service" << 'EOF'
[Unit]
Description=Mirror GitHub repos locally and bundle them to Dropbox
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=%h/dev/bash/github-backup.sh
EOF
  cat > "$HOME/.config/systemd/user/github-backup.timer" << 'EOF'
[Unit]
Description=Daily GitHub backup

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now github-backup.timer 2>/dev/null || true

  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    log "github-backup timer enabled (daily; run now: systemctl --user start github-backup)"
  else
    log "github-backup timer enabled, but gh is not logged in — the run will fail until: gh auth login"
    command -v gh &>/dev/null || log "  (gh not installed: pacman -S github-cli)"
  fi
}

# Main installation flow
# Read-only health check: reports drift without changing anything.
doctor() {
  local ok=true

  log_step "Doctor: symlink health"
  local link target
  for link in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.zprofile" \
    "$HOME/.config/nvim" "$HOME/.config/hypr" "$HOME/.config/waybar" \
    "$HOME/.config/wofi" "$HOME/.config/kitty" "$HOME/.config/dunst" "$HOME/.local/share/applications/yazi.desktop" \
    "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/settings.ini" \
    "$HOME/.local/share/themes/Flexoki"; do
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

  log_step "Doctor: Claude machine notes (machine: $MACHINE)"
  local notes="$DOTFILES_DIR/claude/.claude/machines/$MACHINE/CLAUDE.md"
  if [[ ! -f "$notes" ]]; then
    log "No tracked notes for '$MACHINE' (name this computer in $MACHINE_FILE to track them)"
  elif [[ "$(readlink -f "$HOME/.claude/CLAUDE.md" 2>/dev/null)" != "$notes" ]]; then
    log "WRONG/MISSING  ~/.claude/CLAUDE.md should link to $notes (run: ./bootstrap.sh links)"
    ok=false
  else
    log "~/.claude/CLAUDE.md -> machines/$MACHINE"
  fi

  log_step "Doctor: per-host links (role: $HOST_ROLE)"
  local f
  for f in host.conf hypridle.conf; do
    if [[ "$(readlink "$DOTFILES_DIR/hypr/.config/hypr/$f" 2>/dev/null)" != "hosts/$HOST_ROLE/$f" ]]; then
      log "WRONG/MISSING  hypr/$f should link to hosts/$HOST_ROLE/$f (run: ./bootstrap.sh links)"
      ok=false
    fi
  done
  if [[ "$(readlink "$DOTFILES_DIR/waybar/.config/waybar/host.jsonc" 2>/dev/null)" != "hosts/$HOST_ROLE/host.jsonc" ]]; then
    log "WRONG/MISSING  waybar/host.jsonc should link to hosts/$HOST_ROLE/host.jsonc (run: ./bootstrap.sh links)"
    ok=false
  fi
  # Leftovers from the pre-2026-08-30 layout shadow the shared tracked files
  for f in hypr/.config/hypr/hyprlock.conf hypr/.config/hypr/hyprpaper.conf \
    waybar/.config/waybar/config.jsonc waybar/.config/waybar/style.css; do
    if [[ -L "$DOTFILES_DIR/$f" ]]; then
      log "STALE LINK  $f shadows the shared tracked file (run: ./bootstrap.sh links)"
      ok=false
    fi
  done

  log_step "Doctor: tools the configs invoke"
  local missing=()
  local cmd
  local doctor_tools=(waybar hypridle hyprlock dunst cliphist wofi grim slurp \
    swappy playerctl wl-copy kitty yazi btop nvim zsh)
  # GNOME host (Rocky): the hypr stack is unpackaged and unused there.
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    doctor_tools=(kitty yazi btop nvim zsh)
    if [[ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" != "'Flexoki'" ]]; then
      log "GNOME not skinned (gtk-theme != Flexoki): run gnome/apply.sh"
      ok=false
    fi
  fi
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
  detect_machine
  log "Machine: $MACHINE (override with DOTFILES_MACHINE=<name> or $MACHINE_FILE)"

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
    setup_wofi
    setup_kitty
    setup_dunst
    setup_gtk
    setup_claude_notes
    return
  fi

  # Run setup steps
  check_os
  install_dependencies
  install_eza
  install_nerd_font
  install_yazi
  install_rclone
  install_btop
  setup_bash_tools
  install_rust
  install_nodejs
  setup_mcp_chat_logger
  setup_mcp_maya
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
  setup_wofi
  setup_kitty
  setup_dunst
  setup_gtk
  setup_claude_notes
  setup_gnome
  setup_obsidian
  setup_python
  setup_ssh_agent
  setup_rclone_dropbox
  setup_github_backup
  change_shell
  final_steps
}

# Run main function
main "$@"
