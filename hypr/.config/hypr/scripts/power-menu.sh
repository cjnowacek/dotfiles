#!/usr/bin/env bash
# Power menu for Hyprland, rendered with wofi.
#
# Replaces the old `SUPER+SHIFT+P -> systemctl poweroff` bind, which fired
# instantly with no confirmation and sat one modifier away from SUPER+P (pseudo).
#
# Destructive actions (reboot / poweroff / exit) require a second confirm step;
# lock and suspend are harmless and fire immediately.
set -euo pipefail

menu() { wofi --dmenu --insensitive --width 300 --height 260 --prompt "$1"; }

confirm() {
    local what=$1 choice
    choice=$(printf 'No, cancel\nYes, %s' "$what" | menu "$what?") || exit 0
    [[ $choice == Yes* ]]
}

choice=$(printf '  Lock\n  Suspend\n  Reboot\n  Power off\n  Exit Hyprland' \
    | menu "Power") || exit 0

case "$choice" in
*Lock*)      hyprlock ;;
*Suspend*)   systemctl suspend ;;
*Reboot*)    confirm "Reboot"        && systemctl reboot ;;
*"Power off"*) confirm "Power off"   && systemctl poweroff ;;
*Exit*)      confirm "Exit Hyprland" && hyprctl dispatch exit ;;
esac
