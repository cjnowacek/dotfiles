# Login-shell setup. Auto-start Hyprland on TTY1 — both machines log in on a
# plain TTY, no display manager. `exec` replaces the shell, so logging out of
# Hyprland lands back on the login prompt. Other TTYs stay plain shells for
# rescue work.
if [[ -z "$WAYLAND_DISPLAY" && "$XDG_VTNR" == 1 ]] && command -v Hyprland >/dev/null; then
  exec Hyprland
fi
