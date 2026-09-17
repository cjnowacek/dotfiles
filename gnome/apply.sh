#!/usr/bin/env bash
# Skin GNOME the way the Hyprland hosts look: Flexoki palette, JetBrainsMono
# Nerd Font, Papirus-Dark icons, the hypr wallpaper/lockscreen, and a
# GNOME Terminal profile with kitty's colours. Used on the Rocky (Maya) VM,
# where Hyprland is not packaged and GNOME 40 is what Autodesk targets.
#
# Everything here is user-level (gsettings/dconf, ~/.local) — no sudo.
# Idempotent: safe to re-run. Called by bootstrap.sh setup_gnome; run by
# hand as ~/.dotfiles/gnome/apply.sh to re-apply after a GNOME reset.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
ASSETS="$DOTFILES_DIR/hypr/.config/hypr/assets"
UI_FONT="JetBrainsMono Nerd Font 10"
# VTE (GNOME Terminal) needs the *Mono* variant or icons render 2 cells wide;
# kitty is fine with the plain one, which is what kitty.conf uses.
MONO_FONT="JetBrainsMono Nerd Font Mono 11"

log() { echo "==> $*"; }

if ! command -v gsettings &>/dev/null; then
  echo "gsettings not found — not a GNOME session, nothing to do" >&2
  exit 0
fi

# --- Papirus-Dark icons: EPEL/Arch package if present, else user install ---
if ! find /usr/share/icons "$HOME/.local/share/icons" -maxdepth 1 -name Papirus-Dark 2>/dev/null | grep -q .; then
  log "Installing Papirus icons into ~/.local/share/icons"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/papirus.tar.gz" \
    https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/archive/refs/heads/master.tar.gz
  tar -xzf "$tmp/papirus.tar.gz" -C "$tmp"
  mkdir -p "$HOME/.local/share/icons"
  # Papirus-Dark inherits from Papirus, so both are needed.
  cp -r "$tmp"/papirus-icon-theme-master/Papirus "$tmp"/papirus-icon-theme-master/Papirus-Dark \
    "$HOME/.local/share/icons/"
  rm -rf "$tmp"
  command -v gtk-update-icon-cache &>/dev/null && \
    gtk-update-icon-cache -q "$HOME/.local/share/icons/Papirus" "$HOME/.local/share/icons/Papirus-Dark" || true
fi

# --- GTK theme, icons, fonts, window buttons ---------------------------------
log "Applying interface settings"
I=org.gnome.desktop.interface
# Flexoki = gtk/.local/share/themes/Flexoki (imports GTK's built-in Adwaita
# dark). Rocky's Adwaita-dark package only ships gtk-2.0, so naming that
# theme silently falls back to light Adwaita — hence our own theme dir.
gsettings set $I gtk-theme 'Flexoki'
gsettings set $I icon-theme 'Papirus-Dark'
gsettings set $I cursor-theme 'Adwaita'
gsettings set $I font-name "$UI_FONT"
gsettings set $I document-font-name "$UI_FONT"
gsettings set $I monospace-font-name "$MONO_FONT"
gsettings set $I font-antialiasing 'rgba'
gsettings set $I font-hinting 'slight'
# GNOME 42+ only; harmless no-op on 40.
gsettings set $I color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences titlebar-font "JetBrainsMono Nerd Font Bold 10"
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# --- Wallpaper / lock screen from the shared hypr assets ---------------------
log "Setting wallpaper and lock screen"
gsettings set org.gnome.desktop.background picture-uri "file://$ASSETS/wallpaper.jpg"
gsettings set org.gnome.desktop.background picture-uri-dark "file://$ASSETS/wallpaper.jpg" 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.screensaver picture-uri "file://$ASSETS/lockscreen.png"
gsettings set org.gnome.desktop.screensaver picture-options 'zoom'

# Rocky/Fedora stamp their logo on the wallpaper; the desktop-icons
# extension litters it with Home/Trash.
if command -v gnome-extensions &>/dev/null; then
  gnome-extensions disable background-logo@fedorahosted.org 2>/dev/null || true
fi
gsettings set org.gnome.shell.extensions.desktop-icons show-home false 2>/dev/null || true
gsettings set org.gnome.shell.extensions.desktop-icons show-trash false 2>/dev/null || true

# --- kitty as the default terminal --------------------------------------------
# Same bind as hyprland.conf ($mainMod Return -> kitty), plus Ctrl+Alt+T.
# NOTE: GLib on EL9 launches Terminal=true .desktop files with a hardcoded
# list (gnome-terminal, xterm, ...) and ignores this key; that is why
# applications/ ships a yazi.desktop override running `kitty -e yazi`.
log "Making kitty the default terminal"
gsettings set org.gnome.desktop.default-applications.terminal exec 'kitty'
gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
K=org.gnome.settings-daemon.plugins.media-keys
B=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
gsettings set $K custom-keybindings "['$B/kitty-super/', '$B/kitty-ctrlalt/']"
gsettings set "$K.custom-keybinding:$B/kitty-super/" name 'kitty'
gsettings set "$K.custom-keybinding:$B/kitty-super/" command 'kitty'
gsettings set "$K.custom-keybinding:$B/kitty-super/" binding '<Super>Return'
gsettings set "$K.custom-keybinding:$B/kitty-ctrlalt/" name 'kitty (ctrl+alt+t)'
gsettings set "$K.custom-keybinding:$B/kitty-ctrlalt/" command 'kitty'
gsettings set "$K.custom-keybinding:$B/kitty-ctrlalt/" binding '<Primary><Alt>t'
# Dash: kitty first, GNOME Terminal out.
gsettings set org.gnome.shell favorite-apps \
  "['kitty.desktop', 'firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Software.desktop']"

# --- Hyprland keybinds, as far as Mutter can express them --------------------
# Mirrors the bind = $mainMod ... block in hypr/.config/hypr/hyprland.conf.
# Not portable: togglefloating, pseudo, togglesplit, directional focus,
# step resize, special workspaces, cliphist (no clipboard manager on GNOME).
log "Applying Hyprland-style keybinds"
WM=org.gnome.desktop.wm.keybindings
SH=org.gnome.shell.keybindings
MK=org.gnome.settings-daemon.plugins.media-keys

# 10 static workspaces on Super+N / Super+Shift+N (0 = 10). GNOME Shell owns
# Super+1..9 for dash launching by default, so release those first.
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 10
for n in 1 2 3 4 5 6 7 8 9; do
  gsettings set $SH switch-to-application-$n "[]"
  gsettings set $WM switch-to-workspace-$n "['<Super>$n']"
  gsettings set $WM move-to-workspace-$n "['<Super><Shift>$n']"
done
gsettings set $WM switch-to-workspace-10 "['<Super>0']"
gsettings set $WM move-to-workspace-10 "['<Super><Shift>0']"

gsettings set $WM close "['<Super>q']"                       # killactive
gsettings set $WM toggle-fullscreen "['<Super>f']"           # fullscreen
gsettings set $WM minimize "[]"                              # was Super+h
gsettings set $WM cycle-windows "['<Super>l']"               # ~ movefocus r
gsettings set $WM cycle-windows-backward "['<Super>h']"      # ~ movefocus l
# movewindow across outputs (Hyprland does this at a monitor edge)
gsettings set $WM move-to-monitor-left  "['<Super><Shift>h', '<Super><Shift>Left']"
gsettings set $WM move-to-monitor-right "['<Super><Shift>l', '<Super><Shift>Right']"
gsettings set $WM move-to-monitor-up    "['<Super><Shift>k', '<Super><Shift>Up']"
gsettings set $WM move-to-monitor-down  "['<Super><Shift>j', '<Super><Shift>Down']"

gsettings set $SH toggle-application-view "['<Super>d']"     # wofi drun
gsettings set $SH toggle-message-tray "['<Super>m']"         # free Super+v
gsettings set $MK screensaver "['<Super><Control>l']"        # hyprlock
gsettings set $MK logout "['<Super><Shift>e']"               # exit
gsettings set $MK screenshot-clip "['Print']"                # grim | wl-copy
gsettings set $MK screenshot "['<Super>Print']"              # grim -> ~/Pictures
gsettings set $MK area-screenshot-clip "['<Super><Shift>s']" # slurp | swappy
gsettings set $MK area-screenshot "['<Shift>Print']"

# Super+drag moves, Super+right-drag resizes (bindm lines).
gsettings set org.gnome.desktop.wm.preferences mouse-button-modifier '<Super>'
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true

# exec binds -> custom keybindings (kitty ones are set above).
fm='nautilus'; command -v yazi &>/dev/null && fm='kitty -e yazi'
gsettings set $K custom-keybindings \
  "['$B/kitty-super/', '$B/kitty-ctrlalt/', '$B/filemanager/', '$B/powermenu/']"
gsettings set "$K.custom-keybinding:$B/filemanager/" name 'file manager'
gsettings set "$K.custom-keybinding:$B/filemanager/" command "$fm"
gsettings set "$K.custom-keybinding:$B/filemanager/" binding '<Super>e'
gsettings set "$K.custom-keybinding:$B/powermenu/" name 'power menu'
gsettings set "$K.custom-keybinding:$B/powermenu/" command 'gnome-session-quit --power-off'
gsettings set "$K.custom-keybinding:$B/powermenu/" binding '<Super><Shift>p'

# --- GNOME Terminal: kitty.conf's Flexoki palette on the default profile -----
# Kept themed for anything that still spawns it (see GLib note above).
if gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.Terminal.ProfilesList$'; then
  log "Applying Flexoki to the default GNOME Terminal profile"
  P=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
  G="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$P/"
  gsettings set "$G" visible-name 'Flexoki'
  gsettings set "$G" use-theme-colors false
  gsettings set "$G" use-system-font false
  gsettings set "$G" font "$MONO_FONT"
  gsettings set "$G" foreground-color '#CECDC3'
  gsettings set "$G" background-color '#100F0F'
  gsettings set "$G" bold-color-same-as-fg true
  gsettings set "$G" cursor-colors-set true
  gsettings set "$G" cursor-background-color '#CECDC3'
  gsettings set "$G" cursor-foreground-color '#100F0F'
  gsettings set "$G" highlight-colors-set true
  gsettings set "$G" highlight-background-color '#403E3C'
  gsettings set "$G" highlight-foreground-color '#CECDC3'
  gsettings set "$G" cursor-shape 'ibeam'
  gsettings set "$G" cursor-blink-mode 'off'
  gsettings set "$G" scrollback-lines 10000
  # color0-7, color8-15 from kitty.conf
  gsettings set "$G" palette "['#100F0F', '#AF3029', '#66800B', '#AD8301', '#205EA6', '#A02F6F', '#24837B', '#878580', '#6F6E69', '#D14D41', '#879A39', '#D0A215', '#4385BE', '#CE5D97', '#3AA99F', '#CECDC3']"
fi

log "GNOME skinned. Fonts installed this session only show up in terminals opened after every terminal window is closed (gnome-terminal-server caches fontconfig)."
