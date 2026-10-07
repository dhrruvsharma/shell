-- The keybinds manager's reader (scripts/keybinds.py runs it).
--
-- Runs the Hyprland Lua config with a stand-in `hl` that records every
-- hl.bind() instead of registering it, then prints the binds as JSON: the
-- key string as evaluated, the dispatcher (its hl.dsp path and arguments),
-- the options, the submap, and the file and line the call came from. Loops
-- and helper functions run as they would in Hyprland, so the binds they make
-- come out resolved too.
--
-- Nothing is carried out: hl.exec_cmd, event callbacks and timers do
-- nothing, os/io calls that change anything are stubbed out, and C modules
-- can't be loaded. Dispatcher names are checked against Hyprland's own API
-- stubs, so a misspelt one fails here rather than at the next reload.
--
-- usage: lua keybinds-probe.lua <config dir> [main file] [api stubs]

local dir = assert(arg[1], "usage: keybinds-probe.lua <config dir> [main file] [api stubs]")
local main = arg[2] or (dir .. "/hyprland.lua")
local stubsPath = arg[3] or "/usr/share/hypr/stubs/hl.meta.lua"

local stdout = io.stdout
local realOpen = io.open
local getinfo = debug.getinfo

-- ── JSON ────────────────────────────────────────────────────────────────────

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local encode

local function isArray(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n > 0 and n == #t
end

encode = function(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(v)
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "null"
        end
        return math.type(v) == "integer" and string.format("%d", v) or string.format("%.14g", v)
    elseif t == "string" then
        return '"' .. (v:gsub('[%c"\\]', function(c)
            return escapes[c] or string.format("\\u%04x", c:byte())
        end)) .. '"'
    elseif t == "table" then
        if depth > 8 then
            return '"<nested too deep>"'
        end
        local mt = getmetatable(v)
        if mt and mt.__qsDescribe then
            return encode(mt.__qsDescribe(v), depth + 1)
        end
        local parts = {}
        if isArray(v) then
            for i = 1, #v do
                parts[i] = encode(v[i], depth + 1)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = encode(tostring(k)) .. ":" .. encode(v[k], depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "function" then
        return '{"__function":true}'
    end
    return encode(tostring(v))
end

-- ── Dispatcher names, from Hyprland's API stubs ─────────────────────────────

-- { [""] = { exec_cmd = "fn", window = "window", … }, window = { close = "fn", … } }
local function loadSpec(path)
    local f = realOpen(path, "r")
    if not f then
        return nil
    end
    local spec, cur = {}, nil
    for line in f:lines() do
        local cls = line:match("^%-%-%-@class HL%.Dsp(%a*)Namespace")
        if cls then
            cur = cls:lower()
            spec[cur] = spec[cur] or {}
        elseif cur and not line:match("^%-%-%-") then
            cur = nil
        elseif cur then
            local name, kind = line:match("^%-%-%-@field ([%w_]+) (%S+)")
            if name then
                local ns = kind:match("^HL%.Dsp(%a+)Namespace$")
                spec[cur][name] = ns and ns:lower() or "fn"
            end
        end
    end
    f:close()
    return spec[""] and spec or nil
end

local spec = loadSpec(stubsPath)

local Dispatcher = {}
Dispatcher.__tostring = function() return "HL.Dispatcher" end
Dispatcher.__qsDescribe = function(d)
    local args = {}
    for i = 1, d.n do
        args[i] = d.args[i] == nil and "<nil>" or d.args[i]
    end
    return { path = d.path, args = args }
end

-- hl.dsp and its namespaces. `kind` is "fn", a namespace's spec table, or
-- nil when there are no stubs (then any name goes).
local function dspNode(path, kind)
    return setmetatable({}, {
        __index = function(_, k)
            if type(k) ~= "string" then
                return nil
            end
            local full = path == "" and k or path .. "." .. k
            if spec then
                if type(kind) ~= "table" or kind[k] == nil then
                    error("hl.dsp." .. full .. " is not a dispatcher", 2)
                end
                local sub = kind[k]
                return dspNode(full, sub == "fn" and "fn" or spec[sub])
            end
            return dspNode(full, nil)
        end,
        __call = function(_, ...)
            if spec and kind ~= "fn" then
                error("hl.dsp." .. path .. " is a namespace, not a dispatcher", 2)
            end
            return setmetatable({ path = path, n = select("#", ...), args = { ... } }, Dispatcher)
        end,
    })
end

-- ── The stand-in hl ─────────────────────────────────────────────────────────

-- Callable, indexable, concatenable nothing, for every hl call whose result
-- the config might keep or chain (hl.get_active_monitor():…, rules, timers).
local Nothing
Nothing = setmetatable({}, {
    __call = function() return Nothing end,
    __index = function() return Nothing end,
    __concat = function(a, b) return (a == Nothing and "" or tostring(a)) .. (b == Nothing and "" or tostring(b)) end,
    __tostring = function() return "" end,
    __len = function() return 0 end,
})

local Keybind = {
    __index = {
        remove = function() end,
        unbind = function() end,
        set_enabled = function() end,
        is_enabled = function() return true end,
    },
}

local binds, unbinds, prints = {}, {}, {}
local submap = ""

-- The config frame an hl call came from: the nearest file under `dir`.
local function caller()
    for level = 3, 40 do
        local info = getinfo(level, "Sl")
        if not info then
            break
        end
        local src = info.source
        if src:sub(1, 1) == "@" and src:sub(2, #dir + 1) == dir then
            return src:sub(#dir + 3), info.currentline
        end
    end
    return "?", 0
end

local function describe(dsp)
    local mt = getmetatable(dsp)
    if mt == Dispatcher then
        return Dispatcher.__qsDescribe(dsp)
    elseif type(dsp) == "function" then
        return { path = "<function>", args = {} }
    elseif dsp == nil then
        return { path = "<nil>", args = {} }
    end
    return { path = "<" .. type(dsp) .. ">", args = {} }
end

hl = setmetatable({}, { __index = function() return Nothing end })
hl.dsp = dspNode("", spec and spec[""])

function hl.bind(keys, dsp, opts)
    local file, line = caller()
    binds[#binds + 1] = {
        keys = type(keys) == "string" and keys or tostring(keys),
        dsp = describe(dsp),
        opts = type(opts) == "table" and opts or nil,
        submap = submap,
        file = file,
        line = line,
    }
    return setmetatable({}, Keybind)
end

function hl.unbind(keys)
    local file, line = caller()
    unbinds[#unbinds + 1] = { keys = tostring(keys), file = file, line = line }
end

function hl.define_submap(name, a, b)
    local fn = type(a) == "function" and a or b
    local outer = submap
    submap = tostring(name)
    if type(fn) == "function" then
        fn()
    end
    submap = outer
end

function hl.get_current_submap()
    return submap
end

function hl.version()
    return "0.0.0"
end

-- ── A sandbox for the rest ──────────────────────────────────────────────────

local function capture(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    prints[#prints + 1] = table.concat(parts, "\t")
end

local function refuse()
    return nil, "not allowed while reading binds"
end

print = capture
io.write = capture
io.popen = refuse
io.open = function(path, mode)
    if mode and mode:find("[wa+]") then
        return refuse()
    end
    return realOpen(path, mode)
end
os.execute = refuse
os.remove = refuse
os.rename = refuse
os.tmpname = refuse
os.exit = function() error("os.exit called", 2) end
package.loadlib = refuse
package.cpath = ""
package.path = dir .. "/?.lua;" .. dir .. "/?/init.lua;" .. package.path

-- Hyprland has a watchdog for runaway configs; so does this.
debug.sethook(function() error("the config ran too long", 2) end, "", 50000000)

local chunk, loadErr = loadfile(main)
local ok, err = false, loadErr
if chunk then
    ok, err = xpcall(chunk, debug.traceback)
end

debug.sethook()

stdout:write(encode({
    ok = ok,
    error = ok and "" or tostring(err),
    binds = binds,
    unbinds = unbinds,
    prints = prints,
    strict = spec ~= nil,
}), "\n")
