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
# training), then `hyprctl reload` to put back whatever host.lua says.
# Restoring via reload rather than "the mode we saw before" means a run that
# got interrupted half way can't leave the panel stuck at 1080p.
#
# Under the Lua config (Hyprland 0.56+) `hyprctl keyword` is refused
# ("keyword can't work with non-legacy parsers. Use eval."), so the modeset
# goes through `hyprctl eval hl.monitor(...)`; the keyword path stays for a
# session still on the legacy hyprlang provider.
#
# Second failure mode (HDMI-A-1, 2026-10-18): after a connector rescan the
# NVIDIA driver rejects every 4K mode above 30 Hz with EINVAL ("crtc 205
# failed restore") and Hyprland silently falls back to 3840x2160@29.97 — the
# game looks laggy, nothing is black. Host-side resets (1080p bounce, even
# disabling and re-enabling the output) do NOT clear it: the driver keeps its
# stale, HDMI-1.4-class idea of the link until a real HPD drop. Worse, after
# a re-enable Hyprland *reports* 60 Hz while the kernel shows the CRTC off
# (black panel). So this script verifies against /sys/class/drm, and when the
# wanted mode is refused it parks the panel on a mode that actually commits
# and tells you to power-cycle the monitor, which is what fixed it.
#
# Usage: dp-relink.sh [OUTPUT]      (default DP-1)
# Bound to SUPER+SHIFT+M in hosts/desktop/host.lua; also on PATH as dp-relink.
set -euo pipefail

output=${1:-DP-1}

if ! hyprctl monitors all | grep -q "^Monitor $output "; then
    echo "dp-relink: no such output: $output" >&2
    exit 1
fi

if hyprctl systeminfo | grep -q '^configProvider: lua'; then
    hyprctl eval "hl.monitor({ output = '$output', mode = '1920x1080@60', position = 'auto', scale = 1 })" >/dev/null
else
    hyprctl keyword monitor "$output, 1920x1080@60, auto, 1" >/dev/null
fi
sleep 3
hyprctl reload >/dev/null
sleep 2

drm_dir=$(find /sys/class/drm -maxdepth 1 -name "card*-$output" 2>/dev/null | head -n1)
current_mode() {
    hyprctl monitors | grep -A1 "^Monitor $output " | tail -n1 | awk '{print $1}'
}
refresh_of() { echo "${1##*@}" | cut -d. -f1; }
# Hyprland reports the mode it *asked for*; only the kernel knows whether the
# CRTC is really scanning out.
really_on() {
    [ -n "$drm_dir" ] && [ "$(cat "$drm_dir/enabled")" = enabled ] \
        && [ "$(cat "$drm_dir/dpms")" = On ]
}

mode=$(current_mode)
stage="relinked"

if ! really_on || [ "$(refresh_of "$mode")" -lt 50 ] 2>/dev/null; then
    # The driver refused the configured mode. Fall back to the highest 4K
    # mode the stale link will take so the panel is not black.
    fallback="3840x2160@29.97"
    hyprctl eval "hl.monitor({ output = '$output', mode = '$fallback', position = 'auto', scale = 1.5 })" >/dev/null
    sleep 4
    mode=$(current_mode)
    if really_on; then
        msg="$output stuck at ${mode}: driver refuses 60 Hz. Power-cycle the monitor with its button, then run dp-relink $output again."
    else
        msg="$output has no picture even at ${fallback}. Power-cycle the monitor, then run dp-relink $output again."
    fi
    echo "$msg" >&2
    command -v notify-send >/dev/null && notify-send -u critical "dp-relink" "$msg" || true
    exit 2
fi

msg="$output $stage, now ${mode:-unknown}"
echo "$msg"
command -v notify-send >/dev/null && notify-send "dp-relink" "$msg" || true
