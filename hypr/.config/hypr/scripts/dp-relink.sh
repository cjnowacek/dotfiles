#!/usr/bin/env bash
# Force a DisplayPort link renegotiation on a monitor that has gone black.
#
# Symptom this fixes (left Dell S2725QS on DP-1, first seen 2026-09-18): panel
# is black ~99% of the time and flashes a picture for a few ms, while the GPU
# still reports the connector as connected with a valid EDID and logs no
# hotplug at all. The main link is wedged, but HPD never dropped, so the
# NVIDIA driver never retrains on its own.
#
# Fix: bounce the output through a low-bandwidth mode (forces a fresh link
# training), then `hyprctl reload` to put back whatever host.conf says.
# Restoring via reload rather than "the mode we saw before" means a run that
# got interrupted half way can't leave the panel stuck at 1080p.
#
# Usage: dp-relink.sh [OUTPUT]      (default DP-1)
# Bound to SUPER+SHIFT+M in hosts/desktop/host.conf; also on PATH as dp-relink.
set -euo pipefail

output=${1:-DP-1}

if ! hyprctl monitors all | grep -q "^Monitor $output "; then
    echo "dp-relink: no such output: $output" >&2
    exit 1
fi

hyprctl keyword monitor "$output, 1920x1080@60, auto, 1" >/dev/null
sleep 3
hyprctl reload >/dev/null
sleep 2

mode=$(hyprctl monitors | grep -A1 "^Monitor $output " | tail -n1 | awk '{print $1}')
msg="$output relinked, now ${mode:-unknown}"
echo "$msg"
command -v notify-send >/dev/null && notify-send "dp-relink" "$msg" || true
