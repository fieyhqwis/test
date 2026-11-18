--=====================================================================
--  RAT 4080 — INTO THE HIVE · GUN CHEAT
--  Client-side only: recoil, spread, magazine. Nothing visible to others.
--=====================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  HIVE GUNS",
    Footer = "recoil · spread · mag",
    Icon = "crosshair",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigDir = "RAT4080/Hive",
    ConfigPath = "RAT4080/Hive/guns.json",
}

local S = {
    NoRecoil = true,
    NoSpread = true,
    Infinite = true,   -- forces every magazine to InfiniteSize
    InfiniteSize = 9999,
    Magazine = 0,      -- extra slider, applies on top when Infinite is off
}

local Library, Window, Toggles, Options
local Signals = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Signals[#Signals + 1] = c
    return c
end

do
    local prev = getgenv().__rat4080Hive
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Hive = nil
end

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

pcall(function()
    Library:SetFont(Enum.Font.GothamMedium)
    Library:SetDPIScale(100)
end)

local Tabs = {
    Guns = Window:AddTab("Guns", "crosshair"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function notify(text, icon)
    Library:Notify({ Title = CFG.HubName, Description = text, Icon = icon or "info", Time = 3 })
end

--=========================================================
--  CONFIG FILE (sliders only, toggles always start on)
--=========================================================
local saveQueued = false

local function saveConfig()
    if type(writefile) ~= "function" or saveQueued then return end
    saveQueued = true
    task.delay(0.8, function()
        saveQueued = false
        pcall(function()
            if makefolder and not isfolder(CFG.ConfigDir) then makefolder(CFG.ConfigDir) end
            writefile(CFG.ConfigPath, HttpService:JSONEncode({ Magazine = S.Magazine }))
        end)
    end)
end

local function loadConfig()
    if type(readfile) ~= "function" then return nil end
    local ok, raw = pcall(readfile, CFG.ConfigPath)
    if not ok or type(raw) ~= "string" or raw == "" then return nil end
    local ok2, res = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(res) == "table" then return res end
    return nil
end

--=========================================================
--  GUN CONFIG PATCH
--=========================================================
local originals = {}

local function getGuns()
    local ok, mod = pcall(function() return require(ReplicatedStorage.Shared.Combat.Guns) end)
    if not ok or type(mod) ~= "table" or type(mod.Types) ~= "table" then return nil end
    local n = 0
    for _ in pairs(mod.Types) do n = n + 1 end
    if n == 0 then return nil end
    return mod
end

local function keyOf(def)
    return def.Name or tostring(def)
end

local function snapshot(def)
    local key = keyOf(def)
    if originals[key] then return originals[key] end
    local copy = {
        Spread = def.Spread,
        Magazine = def.Magazine,
        Recoil = def.Recoil and {
            Back = def.Recoil.Back,
            Jitter = def.Recoil.Jitter,
        },
        Kick = def.Kick and {
            Up = def.Kick.Up,
            Side = def.Kick.Side,
            Back = def.Kick.Back,
        },
        Bloom = def.Bloom and {
            PerShot = def.Bloom.PerShot,
            Max = def.Bloom.Max,
        },
        AimRef = def.Aim,
        AimSpread = def.Aim and def.Aim.Spread,
        Pattern = {},
    }
    if def.Recoil and type(def.Recoil.Pattern) == "table" then
        for i, step in ipairs(def.Recoil.Pattern) do
            copy.Pattern[i] = { step[1], step[2] }
        end
    end
    originals[key] = copy
    return copy
end

local patched = 0

local function applyAll()
    local mod = getGuns()
    if not mod then return 0 end
    local n = 0
    for _, def in pairs(mod.Types) do
        if type(def) == "table" then
            snapshot(def)

            if S.NoSpread then
                def.Spread = 0
                if def.Aim then def.Aim.Spread = 0 end
                if def.Bloom then
                    def.Bloom.PerShot = 0
                    def.Bloom.Max = 0
                end
            end

            if S.NoRecoil then
                if def.Recoil then
                    def.Recoil.Back = 0
                    def.Recoil.Jitter = { Up = 0, Side = 0 }
                    if type(def.Recoil.Pattern) == "table" then
                        for _, step in ipairs(def.Recoil.Pattern) do
                            step[1] = 0
                            step[2] = 0
                        end
                    end
                end
                if def.Kick then
                    def.Kick.Up = 0
                    def.Kick.Side = 0
                    def.Kick.Back = 0
                end
            end

            local magTarget = 0
            if S.Infinite then
                magTarget = S.InfiniteSize
            elseif S.Magazine > 0 then
                magTarget = S.Magazine
            end

            if magTarget > 0 and type(def.Magazine) == "number" and def.Magazine > 0 then
                def.Magazine = magTarget
            end

            n = n + 1
        end
    end
    patched = n
    return n
end

local function restoreAll()
    local mod = getGuns()
    if not mod then return end
    for _, def in pairs(mod.Types) do
        if type(def) == "table" then
            local orig = originals[keyOf(def)]
            if orig then
                def.Spread = orig.Spread
                def.Magazine = orig.Magazine
                if orig.AimRef then orig.AimRef.Spread = orig.AimSpread end
                if def.Bloom and orig.Bloom then
                    def.Bloom.PerShot = orig.Bloom.PerShot
                    def.Bloom.Max = orig.Bloom.Max
                end
                if def.Recoil and orig.Recoil then
                    def.Recoil.Back = orig.Recoil.Back
                    def.Recoil.Jitter = orig.Recoil.Jitter
                    if type(def.Recoil.Pattern) == "table" then
                        for i, step in ipairs(def.Recoil.Pattern) do
                            local old = orig.Pattern[i]
                            if old then
                                step[1] = old[1]
                                step[2] = old[2]
                            end
                        end
                    end
                end
                if def.Kick and orig.Kick then
                    def.Kick.Up = orig.Kick.Up
                    def.Kick.Side = orig.Kick.Side
                    def.Kick.Back = orig.Kick.Back
                end
            end
        end
    end
    patched = 0
end

local function refresh()
    if not (S.NoSpread or S.NoRecoil or S.Magazine > 0 or S.Infinite) then
        restoreAll()
        return 0
    end
    return applyAll()
end

--=========================================================
--  LIVE AMMO (the game keeps the current mag outside the config)
--=========================================================
local controllerLoader = nil

local function gunController()
    if not controllerLoader then
        local ok, loader = pcall(function()
            return require(LP.PlayerScripts.Client.Framework.ControllerLoader)
        end)
        if ok then controllerLoader = loader end
    end
    local map = controllerLoader and controllerLoader._map
    return map and map.GunController or nil
end

local function topUpAmmo()
    if not S.Infinite then return end
    local gun = gunController()
    if not gun or not gun._name then return end
    local mags = gun._mags
    local entry = mags and mags[gun._name]
    if type(entry) ~= "table" or type(entry.Ammo) ~= "number" then return end

    local target = S.InfiniteSize
    if tonumber(entry.Ammo) ~= target then
        entry.Ammo = target
    end
    entry.ReloadUntil = nil
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Guns:AddGroupbox({ Side = "Left", Name = "Weapon", IconName = "crosshair" })

box:AddToggle("NoRecoil", {
    Text = "No recoil",
    Default = true,
    Tooltip = "Zeroes the camera kick and the spray pattern. Client side, invisible to others.",
    Callback = function(v)
        S.NoRecoil = v
        refresh()
        notify("No recoil " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.NoRecoil then
    pcall(function()
        Toggles.NoRecoil:AddKeyPicker("RecoilBind", { Text = "No recoil bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddToggle("NoSpread", {
    Text = "No spread",
    Default = true,
    Tooltip = "Kills base spread, aim spread and bloom.",
    Callback = function(v)
        S.NoSpread = v
        refresh()
        notify("No spread " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.NoSpread then
    pcall(function()
        Toggles.NoSpread:AddKeyPicker("SpreadBind", { Text = "No spread bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddToggle("Infinite", {
    Text = "Infinite ammo",
    Default = true,
    Tooltip = "Rewrites every magazine to a huge size. Works on weapons added after the script loaded too.",
    Callback = function(v)
        S.Infinite = v
        refresh()
        notify("Infinite ammo " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Infinite then
    pcall(function()
        Toggles.Infinite:AddKeyPicker("AmmoBind", { Text = "Infinite ammo bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("InfiniteSize", {
    Text = "Infinite mag size",
    Default = S.InfiniteSize,
    Min = 100,
    Max = 9999,
    Rounding = 0,
    Callback = function(v) S.InfiniteSize = v; refresh() end,
})

box:AddSlider("Magazine", {
    Text = "Magazine size",
    Default = S.Magazine,
    Min = 0,
    Max = 300,
    Rounding = 0,
    Tooltip = "0 keeps the real magazine. Keep it modest, a 9999 mag is obvious in the kill feed.",
    Callback = function(v)
        S.Magazine = v
        refresh()
        saveConfig()
    end,
})

box:AddButton({
    Text = "Re-apply",
    Icon = "rotate-ccw",
    Func = function()
        local n = refresh()
        notify("Patched " .. tostring(n) .. " weapon types", "check")
    end,
})

box:AddDivider("Status")

local status = box:AddLabel("patched 0")

task.spawn(function()
    task.wait(2)
    while getgenv().__rat4080Hive do
        task.wait(1.5)
        pcall(function()
            -- keep re-applying: new weapon types can show up mid session
            if S.NoRecoil or S.NoSpread or S.Infinite or S.Magazine > 0 then
                refresh()
            end
            local mag = S.Infinite and S.InfiniteSize or (S.Magazine > 0 and S.Magazine or nil)
            status:SetText(string.format("patched %d types  ·  recoil %s  ·  spread %s  ·  mag %s",
                patched,
                S.NoRecoil and "off" or "on",
                S.NoSpread and "off" or "on",
                mag and tostring(mag) or "real"))
        end)
    end
end)

-- ammo lives in the gun controller, not in the config, so top it up often
task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Hive do
        pcall(topUpAmmo)
        task.wait(0.2)
    end
end)

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddToggle("CustomCursor", { Text = "Fallback cursor", Default = true, Callback = function() end })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

do
    local saved = loadConfig()
    if saved and type(saved.Magazine) == "number" then
        S.Magazine = math.clamp(saved.Magazine, 0, 300)
        pcall(function() Options.Magazine:SetValue(S.Magazine) end)
    end
end

-- Obsidian can fire toggle callbacks with false while building the window.
-- Force the real defaults here, then patch.
S.NoRecoil = true
S.NoSpread = true
S.Infinite = true
pcall(function() Toggles.NoRecoil:SetValue(true) end)
pcall(function() Toggles.NoSpread:SetValue(true) end)
pcall(function() Toggles.Infinite:SetValue(true) end)
S.NoRecoil = true
S.NoSpread = true
S.Infinite = true

refresh()

getgenv().__rat4080Hive = {
    State = S,
    Library = Library,
    Signals = Signals,
    Apply = refresh,
    Restore = restoreAll,
    Count = function() return patched end,
    TopUpAmmo = topUpAmmo,
}

Library:OnUnload(function()
    restoreAll()
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Hive = nil
end)

notify(string.format("Hive guns ready · %d types · %s", patched, CFG.MenuKey), "check")

return { Library = Library, Window = Window, State = S }
