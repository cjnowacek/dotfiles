# shellcheck shell=bash
# Homebrew backend (macOS). Sourced by bootstrap.sh after check_os picks it;
# implements the pkg_* interface listed in bootstrap.sh load_pkg_backend.
# Uses log/log_error, IS_WSL, and the shared helpers from bootstrap.sh.

pkg_install_base() {
  if ! command -v brew &>/dev/null; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  log "Using Homebrew"
  brew install git curl wget ripgrep fd fzf eza pandoc zsh
}

pkg_install_neovim() {
  brew install neovim
}

pkg_install_nodejs() {
  brew install node
}

pkg_install_zk() {
  brew install zk
}

pkg_install_pipx() {
  brew install pipx
  pipx ensurepath
}

pkg_install_obsidian() {
  brew install --cask obsidian
}
