#!/usr/bin/env bash
# Cycle wallpapers from $WALLPAPER_DIR using swww/awww.
#
#   wallpaper-cycle.sh         -> start the daemon (if needed) and loop forever,
#                                 switching to a random wallpaper every $INTERVAL
#   wallpaper-cycle.sh once    -> switch to one random wallpaper and exit
#                                 (handy for a keybind)
#
# The swww project was renamed swww -> awww; this handles either binary name.
set -uo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wallpaper}"
INTERVAL="${WALLPAPER_INTERVAL:-900}"   # seconds between switches (default 15 min)
LAST_FILE="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-cycle.last"

bin()    { command -v swww        || command -v awww        ; }
daemon() { command -v swww-daemon || command -v awww-daemon ; }

BIN="$(bin)" || { echo "swww/awww not installed (try: sudo pacman -S awww)" >&2; exit 1; }

ensure_daemon() {
  "$BIN" query >/dev/null 2>&1 && return 0
  local d; d="$(daemon || true)"
  if [ -n "$d" ]; then "$d" >/dev/null 2>&1 & else "${BIN}-daemon" >/dev/null 2>&1 & fi
  # wait up to ~3s for the socket to come up
  for _ in 1 2 3 4 5 6; do "$BIN" query >/dev/null 2>&1 && return 0; sleep 0.5; done
  return 1
}

pick_and_set() {
  local imgs=() last="" pick
  mapfile -t imgs < <(find "$WALLPAPER_DIR" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
       -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) | sort)
  ((${#imgs[@]})) || { echo "no images in $WALLPAPER_DIR" >&2; return 1; }

  [ -r "$LAST_FILE" ] && last="$(cat "$LAST_FILE")"
  pick="${imgs[RANDOM % ${#imgs[@]}]}"
  # avoid repeating the same image back-to-back when more than one exists
  if [ "${#imgs[@]}" -gt 1 ]; then
    while [ "$pick" = "$last" ]; do pick="${imgs[RANDOM % ${#imgs[@]}]}"; done
  fi

  "$BIN" img "$pick" \
    --transition-type any --transition-fps 60 --transition-duration 1.5 \
    && printf '%s' "$pick" > "$LAST_FILE"
}

ensure_daemon || { echo "could not start swww/awww daemon" >&2; exit 1; }

if [ "${1:-}" = "once" ]; then
  pick_and_set
  exit $?
fi

while :; do
  pick_and_set || true
  sleep "$INTERVAL"
done
