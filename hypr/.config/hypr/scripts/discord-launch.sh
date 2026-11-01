#!/usr/bin/env bash
# Launch the official Discord client forced onto XWayland.
#
# Why (2026-10-11, machine notes "Discord" section):
#  - discord_arch_electron (system Electron) cannot show other people's streams:
#    the web app needs addDirectVideoOutputSink, which only Discord's own bundled
#    Electron provides ("Direct video streams are unavailable outside the native
#    client" in renderer_js.log). Use the `discord` package from extra instead.
#  - The official build on native Wayland + NVIDIA kills its GPU process within
#    seconds ("'--ozone-platform=wayland' is not compatible with Vulkan",
#    "GPU process isn't usable. Goodbye."). XWayland is stable; screen share with
#    "Also share system audio" works there via the PipeWire capturer.
#
# The extra `discord` package is a bootstrapper: it downloads the real client to
# ~/.config/discord/app-<ver>/ and keeps ~/.config/discord/Discord pointing at the
# current one. Prefer that symlink so this works even while /usr/bin/discord is
# still the AUR launcher.
set -euo pipefail

# Hyprland runs with xwayland.force_zero_scaling, so X11 windows get raw pixels
# and Electron must be told the monitor scale itself or it renders tiny.
scale=$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys
ms=json.load(sys.stdin); m=next((m for m in ms if m.get("focused")), ms[0] if ms else {})
print(m.get("scale", 1))' 2>/dev/null || echo 1)
set -- "--force-device-scale-factor=$scale" "$@"

official="${XDG_CONFIG_HOME:-$HOME/.config}/discord/Discord"
if [[ -x "$official" ]]; then
    exec "$official" --ozone-platform=x11 "$@"
fi
exec /usr/bin/discord --ozone-platform=x11 "$@"
