# shellcheck shell=bash
# pacman backend (Arch Linux). Sourced by bootstrap.sh after check_os picks
# it; implements the pkg_* interface listed in bootstrap.sh load_pkg_backend.
# Uses log/log_error, IS_WSL, and the shared helpers from bootstrap.sh.

pkg_install_base() {
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

  local -a pkgs=(git curl wget base-devel ripgrep fd fzf eza pandoc zsh)
  # WSL doesn't need xclip (uses Windows clipboard)
  [[ "$IS_WSL" != true ]] && pkgs+=(xclip)
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"

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
      pavucontrol kitty yazi btop rclone fuse3 \
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
}

pkg_install_neovim() {
  sudo pacman -S --needed --noconfirm neovim
}

pkg_install_nodejs() {
  sudo pacman -S --needed --noconfirm nodejs npm
}

pkg_install_zk() {
  sudo pacman -S --needed --noconfirm zk
}

pkg_install_pipx() {
  sudo pacman -S --needed --noconfirm python-pipx
}

pkg_install_obsidian() {
  # Obsidian moved from the AUR into the official extra repo.
  sudo pacman -S --needed --noconfirm obsidian
}
