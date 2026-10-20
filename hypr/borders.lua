-- SVG window frames from borders-plus-plus-svg, loaded from hyprland.lua via require("borders").
--
-- `style` is the name of any svg in ~/borders-plus-plus-svg/rice/frames: drop one in and put its name here.
-- Matugen colour tokens in it, like {{colors.primary.default.hex}}, are filled in from colors.lua each time
-- Hyprland loads its config, which matugen makes it do on every wallpaper change. Its settings come from
-- data- attributes on its <svg> tag (see the README), or the defaults below.
--
-- Made by rice/frames/generate.py, each with a frame for every rounding the desktop themes use:
--   halo       a soft glow lifting off the window, quiet enough for anything
--   tomoe      sharingan rings with a tomoe turning at every corner
--   sakura     cherry blossoms tucked into the corners
--   neon       two glowing tubes, broken at the corners like a sign
--   hud        ruler ticks, corner brackets and little status marks
--   torii      the window stands under a torii gate
--   starlight  a dotted constellation line with stars in the corners
--   jewel      an art-deco band with beads and a jewel at each corner
local style = "golden-frame"

-- for svgs that don't set them: border thickness on screen, corner size inside the svg (0 for a third of its
-- smaller side), corner size on screen (0 for the border thickness) and whether edges "stretch" or "repeat"
local defaults = { border_size = 14, slice = 0, corner = 0, edges = "stretch" }

local home   = os.getenv("HOME")
local frames = home .. "/borders-plus-plus-svg/rice/frames"
local out    = home .. "/.config/hypr/borders" -- where svgs with colour tokens are written once filled in

-- loads once, later reloads leave the already loaded plugin alone
hl.plugin.load(home .. "/borders-plus-plus-svg/borders-plus-plus-svg.so")

-- The config runs once more after the plugin loads. Until then (or for good, if it can't load, say after a
-- Hyprland update before it's rebuilt) its options would be unknown keys and fill the screen with errors.
local function loaded()
    for _, plugin in ipairs(hl.get_loaded_plugins()) do
        if plugin.name == "borders-plus-plus-svg" then
            return true
        end
    end
    return false
end

if not loaded() then
    return
end

local function read(path)
    local fh = io.open(path, "rb")
    if not fh then
        return nil
    end
    local text = fh:read("a")
    fh:close()
    return text
end

-- Hyprland runs the config a few times in a row while the plugin loads, so remember what was said in the last
-- few seconds (across those runs) rather than saying it three times
local function notify(text)
    local stamp  = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/borders-lua-notified"
    local now    = os.time()
    local recent = {}
    for time, said in (read(stamp) or ""):gmatch("(%d+) ([^\n]*)\n") do
        if now - tonumber(time) < 10 then
            if said == text then
                return
            end
            recent[#recent + 1] = time .. " " .. said .. "\n"
        end
    end
    local fh = io.open(stamp, "wb")
    if fh then
        fh:write(table.concat(recent) .. now .. " " .. text .. "\n")
        fh:close()
    end
    hl.notification.create({ text = "borders.lua: " .. text, duration = 8000, icon = "error" })
end

-- data-name="value" from the svg's own <svg> tag
local function attribute(svg, name)
    local tag = svg:match("<svg[^>]*>") or ""
    local pattern = "%s" .. name:gsub("%-", "%%-") .. "%s*=%s*"
    return tag:match(pattern .. '"([^"]*)"') or tag:match(pattern .. "'([^']*)'")
end

local function whole(value, fallback)
    local n = tonumber(value)
    return n and math.floor(n + 0.5) or fallback
end

-- fills {{colors.<role>.default.hex}} (or .hex_stripped) with the wallpaper's colours from colors.lua
local function colour(svg)
    local colors  = dofile(home .. "/.config/hypr/colors.lua")
    local unknown = {}
    local filled  = svg:gsub("{{%s*colors%.([%w_]+)%.([%w_]+)%.([%w_]+)%s*}}", function(role, mode, format)
        local value = colors[role]
        local rgb   = type(value) == "string" and (value:match("^#(%x%x%x%x%x%x)") or value:match("%((%x%x%x%x%x%x)"))
        if not rgb or mode == "light" or (format ~= "hex" and format ~= "hex_stripped") then
            unknown[#unknown + 1] = role .. "." .. mode .. "." .. format
            return nil -- leaves the token as it was
        end
        return format == "hex" and "#" .. rgb or rgb
    end)
    return filled, unknown
end

-- writes `text` to `path` unless it's there already, swapping the new file in so it's never seen half written
local function write(path, text)
    if read(path) == text then
        return
    end
    local fh = io.open(path .. ".tmp", "wb")
    if not fh then
        os.execute("mkdir -p '" .. out .. "'")
        fh = assert(io.open(path .. ".tmp", "wb"))
    end
    fh:write(text)
    fh:close()
    assert(os.rename(path .. ".tmp", path))
end

local function frame()
    local source = frames .. "/" .. style .. ".svg"
    local svg    = read(source)
    if not svg then
        error("there's no frame called " .. style .. " (" .. source .. ")", 0)
    end

    local path = source
    if svg:find("{{", 1, true) then
        local filled, unknown = colour(svg)
        if #unknown > 0 then
            notify(style .. ".svg uses colours colors.lua doesn't have: " .. table.concat(unknown, ", "))
        end
        path = out .. "/" .. style .. ".svg"
        write(path, filled)
    end

    local edges = attribute(svg, "data-edges") or defaults.edges
    if edges ~= "stretch" and edges ~= "repeat" then
        notify(style .. '.svg: data-edges should be "stretch" or "repeat", not "' .. edges .. '"')
        edges = defaults.edges
    end

    return {
        border_size_1 = whole(attribute(svg, "data-border-size"), defaults.border_size),
        svg_1         = path,
        svg_slice_1   = whole(attribute(svg, "data-slice"), defaults.slice),
        svg_corner_1  = whole(attribute(svg, "data-corner"), defaults.corner),
        svg_edges_1   = edges,
    }
end

local ok, settings = pcall(frame)
if not ok then
    -- never take the rest of hyprland.lua down with it: say what's wrong and draw nothing
    notify(tostring(settings))
    settings = { add_borders = 0 }
end

settings.add_borders    = settings.add_borders or 1
settings.inactive_alpha = 0.45 -- dims the frame on windows without focus

hl.config({ plugin = { borders_plus_plus_svg = settings } })
