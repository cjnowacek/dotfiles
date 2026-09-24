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
  `~/.dotfiles/hypr/.config/hypr/hosts/desktop/host.conf`. Works with the
  screen black; sends a notification when done.
- What it does: sets the output to 1920x1080@60 for 3 s to force a fresh DP
  link training, then `hyprctl reload` restores the 4K mode from host.conf.

If the picture holds at 1080p but dies again at 4K, the cable or GPU port is
marginal (host.conf already suspects a pre-DP1.4 cable): swap the cable or
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
