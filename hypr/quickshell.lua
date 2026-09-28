-- Quickshell integration, loaded from hyprland.lua via require("quickshell").
-- Holds only what the shell needs: keybinds, blur, animations and scale.
-- ~/.config/quickshell/scripts/gen-ipc-commands.py reads the binds here to
-- label the notes drawer's "IPC Toggle" entries with their keys.

---------------
---- SCALE ----
---------------

-- Panels are sized for scale 1. This catch-all rule only applies to monitors
-- without a rule of their own.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})


----------------------------
---- BLUR AND ANIMATIONS ----
----------------------------

hl.config({
    decoration = {
        blur = {
            enabled           = true,
            size              = 12,
            passes            = 4,
            ignore_opacity    = true,
            new_optimizations = true,
            vibrancy          = 0.4,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1.0} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("bounceCurve",    { type = "bezier", points = { {0.6, 1.5},   {0.8, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "bounceCurve" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.5,  bezier = "bounceCurve", style = "slide 10%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 4.5,  bezier = "linear",      style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 0.5,  bezier = "bounceCurve",  style = "slidefadevert" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4.5,  bezier = "bounceCurve",  style = "slidefadevert" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4.5,  bezier = "bounceCurve",  style = "slidefadevert" })


------------------
---- KEYBINDS ----
------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd("qs ipc call launcherWindow toggle"))
hl.bind(mainMod .. " + A",         hl.dsp.exec_cmd("qs ipc call avatarPicker toggle"))
hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("qs ipc call powerMenu toggle"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("qs ipc call notepad toggle"))
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd("qs ipc call cavaWidget edit"))
hl.bind(mainMod .. " + space",     hl.dsp.exec_cmd("qs ipc call pet toggle"))
hl.bind("ALT + TAB",               hl.dsp.exec_cmd("qs ipc call expose toggle"))
hl.bind("ALT + SHIFT + N",         hl.dsp.exec_cmd("qs ipc call networkPanel changeVisible"))
hl.bind("ALT + SHIFT + C",         hl.dsp.exec_cmd("qs ipc call controlCenter changeVisible"))
hl.bind("ALT + H",                 hl.dsp.exec_cmd("quickshell -p ~/.config/quickshell/Lock.qml"))
hl.bind("ALT + SHIFT + H",         hl.dsp.exec_cmd("qs ipc call lockscreen toggle"))
hl.bind("ALT + SHIFT + W",         hl.dsp.exec_cmd("qs ipc call widgets toggle"))
