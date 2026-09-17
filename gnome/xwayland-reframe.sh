#!/usr/bin/env bash
# Kick mutter into re-managing XWayland windows.
#
# Symptom (GNOME 40 / mutter 40.9 on the Rocky VM, 2026-09-17): after Maya
# starts, clicks in its viewport land off from the cursor. Cause: Maya's main
# X11 window was never reparented into a mutter frame (it sat inside Maya's
# own Qt helper window), so mutter's pointer translation for the surface was
# off. Mapping and unmapping any other X11 window made mutter re-manage the
# stack; afterwards the window has a proper mutter parent and clicks line up.
# Maximising the window does the same thing.
#
# Usage: xwayland-reframe.sh    (needs xev from xorg-x11-utils)
if ! command -v xev >/dev/null; then
  echo "xev not found (dnf install xorg-x11-utils)" >&2
  exit 1
fi
timeout 1 xev -geometry 1x1+0+0 >/dev/null 2>&1
exit 0
