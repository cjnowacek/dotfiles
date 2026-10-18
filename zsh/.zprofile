# Login-shell setup. Auto-start Hyprland on TTY1 — both machines log in on a
# plain TTY, no display manager. `exec` replaces the shell, so logging out of
# Hyprland lands back on the login prompt. Other TTYs stay plain shells for
# rescue work.
# The desktop runs Hyprland under uwsm (systemd-managed session: portals,
# hypridle suspend, per-app cgroups on NVIDIA); prefer it wherever installed.
# `hyprland.desktop` (not the bare `hyprland` binary): the entry's Exec is
# /usr/bin/start-hyprland, the watchdog wrapper 0.56+ wants — launching the
# binary directly puts a "started without start-hyprland" warning on screen
# at every login. uwsm still names the session "hyprland" from the entry ID.
if [[ -z "$WAYLAND_DISPLAY" && "$XDG_VTNR" == 1 ]]; then
  if command -v uwsm >/dev/null; then
    exec uwsm start hyprland.desktop
  elif command -v start-hyprland >/dev/null; then
    exec start-hyprland
  elif command -v Hyprland >/dev/null; then
    exec Hyprland
  fi
fi
