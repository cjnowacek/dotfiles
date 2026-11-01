-- Desktop (dual Dell S2725QS on NVIDIA) — loaded at the end of hyprland.lua,
-- which passes { mainMod, start, scripts }.
local ctx = ...

----------------
---- MONITORS --
----------------

-- Both panels are Dell S2725QS — 4K 120Hz hardware, but both run at 60 here.
--
-- HDMI-A-1: EDID DOES advertise 3840x2160@120 (aquamarine logs it as "Mode 1"),
--   but requesting it — via config or `hyprctl eval` — is silently ignored:
--   Hyprland logs no modeset attempt at all and stays at 60. Tried @120,
--   @120.00 and @119.88. Suspect the nvidia DRM atomic path won't do HDMI 2.1
--   FRL+DSC, which 4K120 needs for bandwidth. Recheck after driver bumps
--   (currently 610.43.03).
-- DP-1: only advertises 4K@60 at all — its 120Hz modes top out at 2560x1440,
--   so the DP link isn't negotiating DSC. Most likely a pre-DP1.4 cable.
--
-- Do NOT use `highrr` on either: it would drop them to 1440p to chase refresh.
local SCALE = 1.5
hl.monitor({ output = "DP-1",     mode = "3840x2160@60", position = "0x0",    scale = SCALE })
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "2560x0", scale = SCALE })

-- xwayland.force_zero_scaling (hyprland.lua) hands X11 apps raw 4K pixels, so
-- the Steam client (XWayland) must scale its own UI to match SCALE. The laptop
-- host runs at scale 1 and needs nothing. `env` only applies at Hyprland start;
-- for the running session it was also pushed with `systemctl --user set-environment`.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", tostring(SCALE))

-- DP-1 sometimes wedges after the panels have been off/asleep: black with
-- millisecond flashes, while the GPU still reports it connected (no HPD drop,
-- so the driver never retrains). This bounces it through 1080p to force a new
-- link training, then reloads. Details in the script header.
hl.bind(ctx.mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(ctx.scripts .. "/dp-relink.sh"))

for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = (i <= 2) and "DP-1" or "HDMI-A-1" })
end


--------------
---- NVIDIA --
--------------

hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

hl.config({
    cursor = {
        no_hardware_cursors = true,
    },

    -- Flat acceleration for the desktop mouse; a touchpad wants accel, so
    -- this stays out of the shared config.
    input = {
        accel_profile = "flat",
    },
})


-----------------
---- WALLPAPER --
-----------------

-- Static wallpaper via hyprpaper (same image as the laptop, from assets/).
-- The swww/awww cycler is retired; scripts/wallpaper-cycle.sh stays in the
-- repo if it ever comes back.
hl.on("hyprland.start", function()
    hl.exec_cmd(ctx.start .. " hyprpaper")
end)
