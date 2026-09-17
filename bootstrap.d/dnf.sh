# shellcheck shell=bash
# dnf backend (Fedora and the RHEL family: Rocky, Alma, CentOS, RHEL).
# Sourced by bootstrap.sh after check_os picks it; implements the pkg_*
# interface listed in bootstrap.sh load_pkg_backend. Uses log/log_error,
# IS_WSL, and the shared helpers from bootstrap.sh.

# Rocky/Alma/CentOS/RHEL keep only slow-moving packages in base; the dev
# tools (ripgrep, fd, fzf, pandoc) come from EPEL. Fedora ships them
# directly and has no EPEL.
dnf_is_el() {
  local os_id="" os_like=""
  if [[ -r /etc/os-release ]]; then
    os_id=$(. /etc/os-release && echo "${ID:-}")
    os_like=$(. /etc/os-release && echo "${ID_LIKE:-}")
  fi
  [[ "$os_id" =~ ^(rocky|almalinux|centos|rhel)$ || "$os_like" == *rhel* ]]
}

pkg_install_base() {
  log "Using dnf"

  if dnf_is_el; then
    log "Enterprise Linux detected — enabling EPEL and CRB repos"
    sudo dnf install -y epel-release
    # CRB (CodeReady Builder) holds build deps that EPEL packages pull in.
    # Rocky/Alma ship a `crb` helper; fall back to config-manager on others.
    if command -v crb &>/dev/null; then
      sudo crb enable
    else
      sudo dnf install -y dnf-plugins-core
      sudo dnf config-manager --set-enabled crb || sudo dnf config-manager --set-enabled powertools || true
    fi
  fi

  # "Development Tools" is the group name on both Fedora and EL; the
  # @development-tools id only exists on Fedora.
  # strict=0 turns an unavailable package into a warning instead of
  # aborting the whole transaction (eza is not in EPEL 9 — install_eza in
  # bootstrap.sh picks it up afterwards).
  # file: install_neovim_appimage validates the download with it.
  # fuse-libs: the Neovim AppImage needs libfuse2 to run.
  local -a pkgs=(
    git curl wget file "@Development Tools"
    ripgrep fd-find fzf eza pandoc zsh fuse-libs unzip
    rclone btop
  )
  # GNOME skin (gnome/apply.sh): Papirus is in EPEL, Tweaks + user-theme in
  # AppStream. gnome/apply.sh falls back to a ~/.local Papirus if these fail.
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && \
    pkgs+=(papirus-icon-theme gnome-tweaks gnome-shell-extension-user-theme)
  # WSL doesn't need xclip (uses Windows clipboard)
  [[ "$IS_WSL" != true ]] && pkgs+=(xclip)
  sudo dnf install -y --setopt=strict=0 "${pkgs[@]}"
}

pkg_install_neovim() {
  # EPEL's neovim is too old for LazyVim; use the upstream AppImage.
  install_neovim_appimage
}

pkg_install_nodejs() {
  sudo dnf install -y nodejs npm
}

pkg_install_zk() {
  sudo dnf install -y golang make git
  build_zk_from_source
}

pkg_install_pipx() {
  sudo dnf install -y python3-pip
  python3 -m pip install --user pipx
  python3 -m pipx ensurepath
}

pkg_install_obsidian() {
  log "No automated Obsidian install for dnf — grab the AppImage from obsidian.md"
}
