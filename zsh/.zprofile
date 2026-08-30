# Login-shell setup. Auto-start Hyprland on TTY1 — both machines log in on a
# plain TTY, no display manager. `exec` replaces the shell, so logging out of
# Hyprland lands back on the login prompt. Other TTYs stay plain shells for
# rescue work.
# The desktop runs Hyprland under uwsm (systemd-managed session: portals,
# hypridle suspend, per-app cgroups on NVIDIA); prefer it wherever installed.
if [[ -z "$WAYLAND_DISPLAY" && "$XDG_VTNR" == 1 ]]; then
  if command -v uwsm >/dev/null; then
    exec uwsm start hyprland
  elif command -v Hyprland >/dev/null; then
    exec Hyprland
  fi
fi
