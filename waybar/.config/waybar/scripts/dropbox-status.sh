#!/usr/bin/env bash
# Waybar custom module: rclone Dropbox mount status
# Outputs JSON: {text, tooltip, class}
MNT="$HOME/Dropbox"
ICON_OK="Dropbox"        # font lacks Nerd Font glyphs; plain label is reliable
ICON_BAD="Dropbox down"

if mountpoint -q "$MNT" && systemctl --user is-active --quiet rclone-dropbox.service; then
    cache=$(du -sh "$HOME/.cache/rclone/vfs" 2>/dev/null | cut -f1)
    [ -z "$cache" ] && cache="0B"
    printf '{"text":"%s","tooltip":"Dropbox mounted (rclone on-demand)\\nCache: %s\\nLeft-click: open  •  Right-click: restart","class":"mounted"}\n' "$ICON_OK" "$cache"
else
    state=$(systemctl --user is-active rclone-dropbox.service 2>/dev/null)
    [ -z "$state" ] && state="unknown"
    printf '{"text":"%s","tooltip":"Dropbox NOT mounted (service: %s)\\nRight-click to restart","class":"unmounted"}\n' "$ICON_BAD" "$state"
fi
