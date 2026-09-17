# shellcheck shell=bash
# apt backend (Debian/Ubuntu). Sourced by bootstrap.sh after check_os picks
# it; implements the pkg_* interface listed in bootstrap.sh load_pkg_backend.
# Uses log/log_error, IS_WSL, and the shared helpers from bootstrap.sh.

pkg_install_base() {
  log "Using apt"
  sudo apt-get update

  local -a pkgs=(git curl wget build-essential ripgrep fd-find fzf eza pandoc zsh)
  if [[ "$IS_WSL" == true ]]; then
    # WSL doesn't need xclip (uses Windows clipboard); these are the Obsidian
    # runtime libs, pulled in up front on WSL.
    pkgs+=(libasound2t64 libnotify4 libnss3 xdg-utils libsecret-1-0)
  else
    pkgs+=(xclip)
  fi
  sudo apt-get install -y "${pkgs[@]}"

  # Ubuntu/Debian: fd is packaged as "fd-find" and the binary is usually "fdfind"
  if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
    log "Creating fd symlink (fdfind -> fd)"
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi
}

pkg_install_neovim() {
  # Debian's packaged neovim lags far behind what LazyVim needs.
  install_neovim_appimage
}

pkg_install_nodejs() {
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
}

pkg_install_zk() {
  sudo apt-get install -y golang-go make git
  build_zk_from_source
}

pkg_install_pipx() {
  sudo apt-get install -y pipx
  pipx ensurepath
}

pkg_install_obsidian() {
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
}
