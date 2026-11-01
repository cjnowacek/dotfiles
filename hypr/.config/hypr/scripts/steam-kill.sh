#!/usr/bin/env bash
# steam-kill — kill every process of a running Steam game, including the
# orphans that Steam's own Stop button leaves behind.
#
# Why this exists (2026-10-31, STAR WARS Galactic Racer): after an in-game
# crash the Sentry/crashpad handler pins the game, Steam's Stop does nothing,
# and killing the visible Proton tree (reaper → pressure-vessel → wine) still
# leaves the real game thread alive. It gets reparented to `systemd --user`
# with comm `GameThread` and an EMPTY command line, so `pgrep -f SWGR` never
# sees it, while it keeps playing audio and holding ~8 GB of VRAM.
#
# What does not lie is the environment: Steam stamps every process of a launch
# with SteamGameId / SteamAppId / STEAM_COMPAT_APP_ID, and Proton adds
# STEAM_COMPAT_DATA_PATH / WINEPREFIX pointing at compatdata/<appid>. Every
# descendant inherits them, reparenting or not. So: scan /proc/*/environ,
# SIGKILL everything that carries a game id, repeat until nothing is left
# (EOS overlay etc. respawn once), then verify with PipeWire and nvidia-smi.
#
# Usage:
#   steam-kill            kill every running Steam game
#   steam-kill 4078430    kill only that appid
#   steam-kill -n [id]    dry run: list what would die
#
# The Steam client itself (steam, steamwebhelper, steam.sh) is never touched.
# Keybind: SUPER+SHIFT+Q (hyprland.lua) — works with the game fullscreen/hung.

set -uo pipefail

dry=0
appid=""
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) dry=1 ;;
        -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
        *) appid="$arg" ;;
    esac
done

notify() {
    local urgency=$1; shift
    command -v notify-send >/dev/null && notify-send -u "$urgency" "steam-kill" "$*" || true
    echo "$*"
}

# Processes that belong to a Steam game launch, by environment. Prints "pid appid comm".
find_game_pids() {
    local d pid env id comm exe
    for d in /proc/[0-9]*; do
        pid=${d#/proc/}
        [[ $pid == "$$" || $pid == "$PPID" ]] && continue
        [[ -r $d/environ ]] || continue
        env=$( { tr '\0' '\n' < "$d/environ"; } 2>/dev/null ) || continue
        id=$(grep -m1 -E '^(SteamGameId|SteamAppId|STEAM_COMPAT_APP_ID)=' <<<"$env" | cut -d= -f2)
        if [[ -z $id ]]; then
            # Proton-only process without the Steam ids: take the appid from the prefix path.
            id=$(grep -m1 -oE '^(STEAM_COMPAT_DATA_PATH|WINEPREFIX)=.*/compatdata/[0-9]+' <<<"$env" | grep -oE '[0-9]+$')
        fi
        [[ -n $id ]] || continue
        [[ -n $appid && $id != "$appid" ]] && continue
        comm=$(<"$d/comm") 2>/dev/null || comm="?"
        exe=$(readlink "$d/exe" 2>/dev/null || true)
        # Never the Steam client itself.
        case "$exe$comm" in
            */ubuntu12_32/steam*|*steamwebhelper*|*steam.sh*|*steam-runtime-launcher-service*) continue ;;
        esac
        echo "$pid $id $comm"
    done
}

mapfile -t first < <(find_game_pids)
if (( ${#first[@]} == 0 )); then
    notify low "No Steam game processes found${appid:+ for appid $appid}."
    exit 0
fi

ids=$(printf '%s\n' "${first[@]}" | awk '{print $2}' | sort -u | paste -sd,)
if (( dry )); then
    echo "Would kill ${#first[@]} processes (appid $ids):"
    printf '  %s\n' "${first[@]}"
    exit 0
fi

total=0
for _ in 1 2 3 4 5 6; do
    mapfile -t victims < <(find_game_pids)
    (( ${#victims[@]} == 0 )) && break
    pids=$(printf '%s\n' "${victims[@]}" | awk '{print $1}')
    # shellcheck disable=SC2086
    kill -KILL $pids 2>/dev/null || true
    total=$(( total + ${#victims[@]} ))
    sleep 1
done

# Verify: anything still holding audio or the GPU under a wine/proton binary?
left=$(find_game_pids | wc -l)
audio=$(pactl list sink-inputs 2>/dev/null | grep -c 'application.process.binary = "wine' || true)
vram=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1); vram=${vram:-n/a}   # Intel laptop: no nvidia-smi

msg="Killed $total processes (appid $ids). Left: $left. Wine audio streams: $audio. VRAM used: ${vram} MiB."
if (( left > 0 || audio > 0 )); then
    notify critical "$msg  Something survived — run: steam-kill -n"
    exit 1
fi
notify normal "$msg"
