-- Laptop (ThinkPad T480, Intel graphics, eDP-1 1080p) — loaded at the end of
-- hyprland.lua, which passes { mainMod, start, scripts }.
local ctx = ...

----------------
---- MONITORS --
----------------

hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
-- Anything hotplugged (dock, HDMI) just extends to the right at native res.
hl.monitor({ output = "",      mode = "preferred", position = "auto", scale = 1 })


-----------------
---- WALLPAPER --
-----------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
end)


-----------------------
---- LAPTOP HARDWARE --
-----------------------

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
