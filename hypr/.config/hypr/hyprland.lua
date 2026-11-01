-- Shared Hyprland config for all machines (Lua; Hyprland >= 0.56, which
-- warns at startup that the .conf format goes away in 0.57). Anything
-- hardware-specific (monitors, GPU env, wallpaper daemon, laptop keys) lives
-- in hosts/<role>/host.lua; bootstrap.sh links the right one to
-- ~/.config/hypr/host.lua, which is loaded at the end of this file.
--
-- hyprland.conf next to this file is a frozen fallback for a machine still on
-- Hyprland < 0.56; 0.56+ ignores it whenever hyprland.lua exists.
--
-- Checks (see CLAUDE.md in the repo):
--   Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
--   hyprctl binds | grep -c "^bind"      -- ~71 on the desktop
-- A Lua runtime error aborts the rest of the file, and a file that registers
-- no binds trips Hyprland's emergency mode (SUPER+Q only) — so the bind count
-- matters more than "config ok".

local HOME    = os.getenv("HOME")
local SCRIPTS = HOME .. "/.config/hypr/scripts"
-- exec-once wrapper: under uwsm every autostart app becomes its own unit.
local START   = SCRIPTS .. "/hypr-start.sh"


-----------------------------
---- ENVIRONMENT VARIABLES ----
-----------------------------

-- Wayland / toolkit hints
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "wofi --show drun"


-------------------
---- AUTOSTART ----
-------------------

-- "hyprland.start" fires once per compositor start, like exec-once did.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(START .. " waybar")
    -- Wallpaper daemon (hyprpaper on both hosts) is started from host.lua
    hl.exec_cmd(START .. " dunst")
    hl.exec_cmd(START .. " hypridle")
    -- hyprsunset.service (the packaged unit) is disabled on purpose: both
    -- running at once makes the second one die with "A CTM manager is
    -- already running" and the unit ends in start-limit-hit.
    hl.exec_cmd(START .. " hyprsunset")
    hl.exec_cmd(START .. " wl-paste --type text --watch cliphist store")
    hl.exec_cmd(START .. " wl-paste --type image --watch cliphist store")
end)


---------------------
---- PERMISSIONS ----
---------------------

hl.permission({ binary = "/usr/(bin|local/bin)/grim",                        type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,

        -- Flexoki, as in Cairn and waybar: the blue accent into teal, dark grey when unfocused.
        col = {
            active_border   = { colors = { "rgba(66a0c8ee)", "rgba(5abdacee)" }, angle = 45 },
            inactive_border = "rgba(403e3caa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 8,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 8,
            render_power = 2,
            color        = "rgba(11111bee)",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            new_optimizations = true,
            vibrancy          = 0.2,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    debug = {
        vfr = true,
    },
})

hl.curve("snappy",    { type = "bezier", points = { { 0.05, 0.9 }, { 0.1,  1.0   } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0   }, { 0.66, -0.56 } } })
hl.curve("smoothIn",  { type = "bezier", points = { { 0.25, 1   }, { 0.5,  1     } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4,  bezier = "snappy",    style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4,  bezier = "smoothOut", style = "popin 80%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4,  bezier = "smoothIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4,  bezier = "snappy",    style = "slide" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
-- No `loop` style here on purpose. A looping borderangle re-renders the
-- gradient forever, which pins the compositor at full frame rate on both 4K
-- outputs and defeats `debug.vfr` above — it can never go idle. Without loop
-- the gradient still sweeps on focus change, then settles.
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "smoothIn" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Core
hl.bind(mainMod .. " + Return",    hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + ALT + E",   hl.dsp.exec_cmd("kitty -e yazi"))  -- terminal file browser (Dolphin is on SUPER+E since 2026-10-30)
hl.bind(mainMod .. " + Space",     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))

-- Lock
-- NOTE: moved off SUPER+L so that key can complete the vim h/j/k/l focus set below.
-- Lock is also available from the power menu (SUPER+SHIFT+P).
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))

-- Scratchpad (drawer-style special workspace)
hl.bind(mainMod .. " + grave",          hl.dsp.workspace.toggle_special("web"))
hl.bind(mainMod .. " + SHIFT + grave",  hl.dsp.window.move({ workspace = "special:web" }))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal, { workspace = "special:web" }))

-- Screenshots
hl.bind("Print",                   hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("grim " .. HOME .. "/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"))
-- Globals (not locals) so they can be inspected:
--   hyprctl repl 'return RegionShot:is_enabled(), MoonlightSnip:is_enabled()'
RegionShot = hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))

-- Moonlight: the streamed Windows host wants Win+Shift+S for Snipping Tool, but
-- that is SUPER+SHIFT+S here and Hyprland eats it for the local region shot.
-- While Moonlight has focus the local bind is disabled so the chord passes
-- straight through to the stream, and ALT+SHIFT+S is enabled as a second route
-- that injects the same chord. Outside Moonlight both revert: the region shot
-- is back and ALT+SHIFT+S is not intercepted at all.
local MOONLIGHT_CLASS = "com.moonlight_stream.Moonlight"
MoonlightSnip = hl.bind("ALT + SHIFT + S",
    hl.dsp.send_shortcut({ mods = "SUPER SHIFT", key = "S", window = "class:" .. MOONLIGHT_CLASS }),
    { desc = "Moonlight: send Win+Shift+S (Snipping Tool) to the host" })
MoonlightSnip:set_enabled(false)
local function syncMoonlightBinds()
    local win = hl.get_active_window()
    local inMoonlight = win ~= nil and win.class == MOONLIGHT_CLASS
    RegionShot:set_enabled(not inMoonlight)
    MoonlightSnip:set_enabled(inMoonlight)
end
hl.on("window.active", syncMoonlightBinds)
syncMoonlightBinds()  -- also right after (re)load, when no focus event fires

-- Clipboard history
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- Move focus (arrows and vim keys)
local DIRS = { left = "left", right = "right", up = "up", down = "down",
               h = "left",    l = "right",     k = "up", j = "down" }
for key, dir in pairs(DIRS) do
    hl.bind(mainMod .. " + " .. key,            hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key,    hl.dsp.window.move({ direction = dir }))
end

-- Resize windows
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }))

-- Switch workspaces / move window to workspace (key 0 = workspace 10)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys (bindel = locked + repeating, bindl = locked)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Power
-- Was `systemctl poweroff` directly — instant, unconfirmed, and one modifier away
-- from SUPER+P (pseudo). Now opens a menu; reboot/poweroff/exit ask to confirm.
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(SCRIPTS .. "/power-menu.sh"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name   = "float-dialogs",
    match  = { title = "^(Open|Save|File|Folder|Choose|Select).*$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-pavucontrol",
    match  = { class = "^(pavucontrol)$" },
    float  = true,
    size   = "800 500",
    center = true,
})

hl.window_rule({
    name   = "float-portal-gtk",
    match  = { class = "^(xdg-desktop-portal-gtk)$" },
    float  = true,
    size   = "900 600",
    center = true,
})

-- Cairn (the zk-engine app) is relaunched constantly while developing it, and
-- every launch was landing on whatever workspace was in front. Pin it to 4 —
-- a HDMI-A-1 workspace — so a rebuild never covers the work that prompted it.
-- float = false is the tile rule; dwindle is the global layout anyway, so
-- this only matters if a future rule tries to float it.
hl.window_rule({
    name  = "cairn-workspace-4",
    -- Native Wayland reports `cairn`; under XWayland (QT_QPA_PLATFORM=xcb,
    -- which is how it gets driven by xdotool) the same app reports `Cairn`.
    match     = { class = "^([Cc]airn)$" },
    workspace = 4,
    float     = false,
})

-- Cairn as a Chrome app window (applications/cairn.desktop runs
-- `google-chrome-stable --app=https://notes.cjnowacek.com`). Chrome names
-- the window chrome-<host>__-<Profile>; the profile part varies per machine,
-- so match the prefix. Tiled like any app, and not pinned to a workspace:
-- unlike the Qt build above it is used, not relaunched, so it belongs
-- wherever it was opened.
hl.window_rule({
    name  = "cairn-web",
    -- Installed in Chrome (2026-10-19) the class is chrome-<app id>-<Profile>;
    -- the plain --app= window keeps the host-named class. Both are Cairn.
    match = { class = "^chrome-(notes\\.cjnowacek\\.com__|ekamnaoljcinngmggjdmagnkcmgnfckp)-" },
    float = false,
})


----------------------
---- HOST OVERLAY ----
----------------------

-- Symlink created by bootstrap.sh -> hosts/<desktop|laptop>/host.lua.
-- loadfile (not require) so `hyprctl reload` re-runs it: require would cache
-- the module and a reload would then come back without the host's monitors
-- and binds.
local configDir = debug.getinfo(1, "S").source:match("^@(.*)/") or (HOME .. "/.config/hypr")
local host = assert(loadfile(configDir .. "/host.lua"))
host({ mainMod = mainMod, start = START, scripts = SCRIPTS })
