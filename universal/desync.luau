--=====================================================================
--  RAT 4080 — DESYNC / GHOST
--  Freezes your character replication for a chosen window: the server
--  keeps the last position it received, other players see a statue,
--  you keep moving on your own client.
--  Requires an executor with native RakNet (Madium). Real works too,
--  but its RakNet hooks cost ~90% FPS while installed.
--=====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  GHOST",
    Footer = "desync",
    Icon = "ghost",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigFolder = "RAT4080/Desync",
    ConfigFile = "RAT4080/Desync/config.json",
}

local S = {
    Ghost = false,
    Burst = 3,
    BlockByte = 69,
    BlockAll = false,
    HideLocal = false,
}

local Library, Window, Toggles, Options

--=========================================================
--  CONFIG
--=========================================================
local function saveConfig()
    local ok = pcall(function()
        if not isfolder(CFG.ConfigFolder) then makefolder(CFG.ConfigFolder) end
        writefile(CFG.ConfigFile, game:GetService("HttpService"):JSONEncode({
            Burst = S.Burst,
            BlockByte = S.BlockByte,
            BlockAll = S.BlockAll,
            HideLocal = S.HideLocal,
        }))
    end)
    return ok
end

local function loadConfig()
    local ok, raw = pcall(function()
        if isfile(CFG.ConfigFile) then return readfile(CFG.ConfigFile) end
    end)
    if not ok or type(raw) ~= "string" then return end
    local decodedOk, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not decodedOk or type(data) ~= "table" then return end
    S.Burst = tonumber(data.Burst) or S.Burst
    S.BlockByte = tonumber(data.BlockByte) or S.BlockByte
    S.BlockAll = data.BlockAll == true
    S.HideLocal = data.HideLocal == true
end

--=========================================================
--  CLEANUP
--=========================================================
do
    local prev = getgenv().__rat4080Ghost
    if prev then
        pcall(function() if prev.restore then prev.restore() end end)
        pcall(function() if prev.Library and prev.Library.Unload then prev.Library:Unload() end end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Ghost = nil
end

loadConfig()

local rn = rawget(getfenv(), "raknet") or raknet or RakNet

--=========================================================
--  LIBRARY
--=========================================================
do
    local ok, res = pcall(function() return loadstring(game:HttpGet(CFG.Repo .. "Library.lua"))() end)
    if ok then Library = res end
end

if not Library then
    warn("[4080] Obsidian failed to load")
    return
end

Toggles, Options = Library.Toggles, Library.Options

Window = Library:CreateWindow({
    Title = CFG.WindowTitle,
    Footer = CFG.Footer,
    Icon = CFG.Icon,
    NotifySide = "Right",
    Center = true,
    AutoShow = true,
    CornerRadius = 10,
    Animations = { ToggleWindow = true, TabSwitch = true, Groupbox = true, KeyPicker = true },
})

local Tabs = {
    Main = Window:AddTab("Ghost", "ghost"),
    Settings = Window:AddTab("Settings", "settings"),
}

--=========================================================
--  GHOST CORE
--=========================================================
local stats = { blocked = 0, passed = 0, lastPrefix = "--" }
local ghostUntil = 0
local hooked = false
local hookFn = nil

local function charParts()
    local ch = LP.Character
    if not ch then return {} end
    local out = {}
    for _, v in ipairs(ch:GetDescendants()) do
        if v:IsA("BasePart") then out[#out + 1] = v end
    end
    return out
end

local function applyHide(on)
    for _, part in ipairs(charParts()) do
        pcall(function()
            part.LocalTransparencyModifier = on and 1 or 0
        end)
    end
end

local function isGhostActive()
    if S.Ghost then return true end
    return os.clock() < ghostUntil
end

local function onPacket(packet)
    local idOk, id = pcall(function() return packet.PacketId end)
    if not idOk or id ~= 195 then
        stats.passed += 1
        return
    end

    local ok, raw = pcall(function() return packet.AsString end)
    if not ok or type(raw) ~= "string" or #raw < 2 then
        stats.passed += 1
        return
    end

    if not isGhostActive() then
        stats.passed += 1
        return
    end

    local first, second = raw:byte(1), raw:byte(2)
    stats.lastPrefix = string.format("%02X %02X", first, second)

    local hit = false
    if S.BlockAll then
        hit = true
    elseif first == 0xC3 and second == S.BlockByte then
        hit = true
    end

    if hit then
        stats.blocked += 1
        pcall(function() packet:Block() end)
    else
        stats.passed += 1
    end
end

local function installHook()
    if hooked then return true end
    if not rn or type(rn.add_send_hook) ~= "function" then return false end
    hookFn = onPacket
    local ok = pcall(function() rn.add_send_hook(hookFn) end)
    hooked = ok
    return ok
end

local function removeHook()
    if not hooked or not hookFn then return end
    pcall(function() rn.remove_send_hook(hookFn) end)
    hooked = false
    hookFn = nil
end

local function setGhost(on)
    S.Ghost = on
    if on then
        if not installHook() then
            S.Ghost = false
            Library:Notify({ Title = CFG.HubName, Description = "RakNet is not available", Icon = "x", Time = 3 })
            return false
        end
        applyHide(S.HideLocal)
    else
        ghostUntil = 0
        applyHide(false)
    end
    return true
end

local function burst(seconds)
    if not installHook() then
        Library:Notify({ Title = CFG.HubName, Description = "RakNet is not available", Icon = "x", Time = 3 })
        return false
    end
    ghostUntil = os.clock() + seconds
    applyHide(S.HideLocal)
    return true
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Desync", IconName = "ghost" })

box:AddToggle("Ghost", {
    Text = "Ghost mode",
    Default = false,
    Tooltip = "Stops sending your position to the server. Others see a statue.",
    Callback = function(v)
        if v and not setGhost(true) then
            pcall(function() Toggles.Ghost:SetValue(false) end)
            return
        end
        S.Ghost = v
        if not v then setGhost(false) end
    end,
})

if Toggles.Ghost then
    pcall(function()
        Toggles.Ghost:AddKeyPicker("GhostBind", { Text = "Ghost bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddButton({
    Text = "Burst",
    Icon = "zap",
    Func = function()
        if burst(S.Burst) then
            Library:Notify({ Title = CFG.HubName, Description = string.format("Ghost for %ds", S.Burst), Icon = "zap", Time = 2 })
        end
    end,
})

box:AddSlider("Burst", {
    Text = "Burst seconds",
    Default = S.Burst,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(v)
        S.Burst = v
        saveConfig()
    end,
})

box:AddSlider("BlockByte", {
    Text = "Replication byte",
    Default = S.BlockByte,
    Min = 0,
    Max = 255,
    Rounding = 0,
    Tooltip = "Second byte of the C3 packet that carries position. 69 = 0x45.",
    Callback = function(v)
        S.BlockByte = v
        saveConfig()
    end,
})

box:AddToggle("BlockAll", {
    Text = "Block all player packets",
    Default = S.BlockAll,
    Tooltip = "Also blocks remotes. Use only if the byte filter misses.",
    Callback = function(v)
        S.BlockAll = v
        saveConfig()
        if v then
            Library:Notify({ Title = CFG.HubName, Description = "Remotes will be blocked too", Icon = "alert-triangle", Time = 3 })
        end
    end,
})

box:AddToggle("HideLocal", {
    Text = "Hide my model locally",
    Default = S.HideLocal,
    Tooltip = "Cosmetic: your character becomes invisible on your own screen.",
    Callback = function(v)
        S.HideLocal = v
        applyHide(v and isGhostActive())
        saveConfig()
    end,
})

box:AddDivider("Status")

local status = box:AddLabel("idle")
local prefixLabel = box:AddLabel("last packet: --")
local counters = box:AddLabel("blocked 0 · passed 0")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

--=========================================================
--  LOOP
--=========================================================
task.spawn(function()
    while getgenv().__rat4080Ghost do
        local active = isGhostActive()
        if not active and hooked and not S.Ghost then
            removeHook()
        end
        pcall(function()
            status:SetText(string.format("%s · burst %ds · byte %d",
                active and "GHOST" or "live",
                S.Burst,
                S.BlockByte))
            prefixLabel:SetText("last packet: " .. stats.lastPrefix)
            counters:SetText(string.format("blocked %d · passed %d", stats.blocked, stats.passed))
        end)
        task.wait(0.25)
    end
end)

task.spawn(function()
    while getgenv().__rat4080Ghost do
        if S.HideLocal and isGhostActive() then
            applyHide(true)
        end
        task.wait(0.5)
    end
end)

getgenv().__rat4080Ghost = {
    State = S,
    Library = Library,
    Stats = stats,
    SetGhost = setGhost,
    Burst = burst,
    restore = function()
        S.Ghost = false
        ghostUntil = 0
        removeHook()
        applyHide(false)
    end,
}

Library:OnUnload(function()
    getgenv().__rat4080Ghost = nil
    S.Ghost = false
    ghostUntil = 0
    removeHook()
    applyHide(false)
end)

Library:Notify({
    Title = CFG.HubName,
    Description = "Ghost ready · " .. CFG.MenuKey,
    Icon = "ghost",
    Time = 3,
})

return { Library = Library, Window = Window, State = S }
