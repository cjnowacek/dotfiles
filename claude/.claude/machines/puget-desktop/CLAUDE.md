# Machine notes (Arch, Hyprland, RTX 3080, nvidia-open)

## "The machine locked up" is usually a failed suspend, not the app

The NVIDIA driver runs with `NVreg_PreserveVideoMemoryAllocations=1`, so at
suspend it copies all used VRAM into an unnamed temp file under
`NVreg_TemporaryFilePath` (set in `/etc/modprobe.d/nvidia-power.conf`). If that
filesystem cannot hold the VRAM in use, the suspend fails silently, the GPU
stays active, and on wake the driver dies in the nvidia-drm modeset: black
screen, hard power-off. Recurred many times June–September 2026 while the
path was `/var/tmp` on a 36 GB root at 99% full and the Unreal editor held
several GB of VRAM.

Diagnose from the previous boot, not the app's logs:

```
journalctl -b -1 | grep -E 'NVRM|fbsr|memmgrRestore|nv_flip'
df -h /
```

`NV_ERR_NO_MEMORY ... fbsr_gm107.c` at the suspend timestamp is the signature.

Fix applied 2026-09-09: path moved to `/home/.nvidia-vram-tmp` (ext4, large
volume), pacman cache trimmed with `paccache -rk1`, `mkinitcpio -P` because the
nvidia modules are baked into the initramfs (`MODULES=` in mkinitcpio.conf and
the modconf hook copies modprobe.d in). If it recurs: check free space on that
path first, then whether the modprobe change survived a driver update.

Root disk being full also silently drops coredumps (`systemd-coredump: No
space left on device`), so a crash with no core is another hint.

## Left monitor (DP-1) black, flickering or "power cycling": run `dp-relink`

The left Dell S2725QS on DP-1 sometimes wedges after the panels have been off
or asleep: black ~99% of the time with millisecond flashes of picture, while
the GPU still reports DP-1 connected with a valid EDID and logs no hotplug.
The main link is stuck but HPD never dropped, so the NVIDIA driver never
retrains by itself. First seen after the 2026-09-10 power outage; this variant
2026-09-18.

Fix, before any diagnosis:

```
dp-relink            # default DP-1; `dp-relink HDMI-A-1` for the other panel
```

- Script: `~/.dotfiles/hypr/.config/hypr/scripts/dp-relink.sh`
  (= `~/.config/hypr/scripts/dp-relink.sh`, symlinked to `~/.local/bin/dp-relink`)
- Keybind: `SUPER+SHIFT+M`, defined in
  `~/.dotfiles/hypr/.config/hypr/hosts/desktop/host.lua`. Works with the
  screen black; sends a notification when done.
- What it does: sets the output to 1920x1080@60 for 3 s to force a fresh DP
  link training, then `hyprctl reload` restores the 4K mode from host.lua.

Variant 2026-10-18, right monitor (HDMI-A-1): nothing black, "the game is
lagging". The panel had fallen to 3840x2160@29.97 after a connector rescan:
aquamarine logged `crtc 205 failed restore` / `failed to commit: Invalid
argument` for every 4K mode above 30 Hz and silently took 29.97. Check with
`hyprctl monitors -j` (refreshRate). The EDID was still fine (600 MHz TMDS,
FRL); the NVIDIA driver's idea of the link was stale. No host-side reset
cleared it: not the 1080p bounce, not `disabled = true` + reload. The latter
is actively misleading: Hyprland then reports 60 Hz while
`/sys/class/drm/card1-HDMI-A-1/enabled` says `disabled` and the panel is
black. What fixed it: the monitor's own power button (real HPD drop), then
`hl.monitor(... mode = '3840x2160@60' ...)` committed cleanly. dp-relink now
checks the kernel state and, if 60 is refused, parks the panel at 29.97 and
says to power-cycle. Moonlight is separately capped at fps=30 in its own
settings; that is deliberate, not this bug.

If the picture holds at 1080p but dies again at 4K, the cable or GPU port is
marginal (host.lua already suspects a pre-DP1.4 cable): swap the cable or
move to another DP port. Drop history lives in the user journal:
`journalctl -b --user | grep 'hyprsunset.*Found new output'`. Events where
both outputs vanish at once are just the monitors being switched off/on.

## Subagents: triage every request, dispatch without asking

The rule for which work the main session keeps and which it sends to a
subagent is `~/dev/subagent-workflow-kit/templates/ROUTING.md`; a repo may
carry its own `.claude/ROUTING.md`, which wins. Short version: questions,
design, anything with a silent failure mode, the check, the gate, the look
and every commit stay with the main session; a pinned-down change with a
check goes to `implementer` (in `~/.claude/agents`, symlinked from the kit),
a sweep across files to `Explore`. Say in one line what was sent and to
whom; never wait for a veto. The user, 2026-09-24: "as you see fit for the
type of task it is. and then ill just staying in fable."

## Discord: official `discord` package, forced to XWayland

Fixed 2026-10-11. Two separate problems stacked:

- `discord_arch_electron` (AUR, system Electron) cannot show other people's
  streams: Discord's web app now needs `addDirectVideoOutputSink`, which only
  Discord's own bundled Electron provides. `renderer_js.log` says
  `Direct video streams are unavailable outside the native client`. Fix: the
  `discord` package from extra. Since 1.0.x it is a 2 MB bootstrapper that
  downloads the real client into `~/.config/discord/app-<ver>/` and keeps
  `~/.config/discord/Discord` pointing at the current one.
- The official build on native Wayland + NVIDIA kills its GPU process within
  seconds: `'--ozone-platform=wayland' is not compatible with Vulkan`, then
  `GPU process isn't usable. Goodbye.` Same thing in June 2026 on the AUR
  build. XWayland is stable (slightly soft at 1.5x scale).

What runs: `~/.config/hypr/scripts/discord-launch.sh` (prefers
`~/.config/discord/Discord`, falls back to `/usr/bin/discord`, always adds
`--ozone-platform=x11`), wired in by the dotfiles override
`applications/.local/share/applications/discord.desktop`.

Screen share with audio: Share Screen opens the Hyprland portal picker; the
next dialog has "Also share system audio" (captures the default sink via
pipewire-pulse). Needs xdg-desktop-portal-hyprland alive with a live PipeWire
connection. If the picker never appears, PipeWire was restarted under the
portals:

```
systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal
```

`~/.config/discord-flags.conf` is only read by the AUR launcher; the official
client ignores it.

## Steam / Proton games: `steam-kill`, and why X11 windows are now unscaled

- **Game hung, "won't close", audio still playing after Steam's Stop:**
  `steam-kill` (SUPER+SHIFT+Q). Steam's Stop does nothing once a crash handler
  pins the game, and the real game thread survives a kill of the visible Proton
  tree: reparented to `systemd --user`, comm `GameThread`, empty cmdline, still
  holding audio + ~8 GB VRAM. The script kills by environment (SteamGameId /
  SteamAppId / compatdata path), which every descendant inherits. `-n` = dry run.
  Script: `~/.config/hypr/scripts/steam-kill.sh`. The Steam client survives.
- **`xwayland.force_zero_scaling = true`** (hyprland.lua, 2026-10-31): X11
  windows get real 4K pixels instead of a 2560x1440 logical screen blurred up by
  the compositor. Apps that scale themselves must be told: Steam via
  `STEAM_FORCE_DESKTOPUI_SCALING=1.5` (hosts/desktop/host.lua; `env` only
  applies at Hyprland start, `systemctl --user set-environment` for the running
  session, and export it in any shell that launches Steam through `uwsm app`),
  Electron/Discord via `--force-device-scale-factor` (discord-launch.sh reads
  the focused monitor's scale). A new X11 app that comes up tiny needs the same.
- **Proton helpers that waste a core:** `PROTON_USE_XALIA=0` (accessibility
  helper, ~20%) and `WINEDLLOVERRIDES=EOSOVH-Win64-Shipping=d` (Epic EOS
  overlay = Chromium inside Wine, ~25% + its own GPU process) as per-game launch
  options. Proton appends user WINEDLLOVERRIDES to its own, it does not clobber.
- **Keep Proton + Steam Linux Runtime on the NVMe library**
  (`~/.local/share/Steam`). On `/mnt/sao` (SMR HDD, NTFS via ntfs-3g FUSE) a
  launch spends minutes reading 13k small files. Moving = move
  `appmanifest_<id>.acf` + `common/<dir>` with Steam closed; Steam rebuilds
  libraryfolders.vdf. Deleting from `/mnt/sao` leaves `.fuse_hidden*` files
  behind if anything had them open; they vanish on the next remount.
- Game-specific history (Galactic Racer): Claude memory `galactic-racer-steam`.
