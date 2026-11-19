--=====================================================================
--  RAT 4080 — INTO THE HIVE
--  no recoil · no spread · magazine · fire rate · headshot rewrite
--=====================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  HIVE",
    Footer = "recoil · spread · mag · rate",
    Icon = "crosshair",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigDir = "RAT4080/Hive",
    ConfigPath = "RAT4080/Hive/guns.json",
}

local S = {
    NoRecoil = true,
    NoSpread = true,
    Magazine = 0,      -- 0 = leave the real magazine alone
    Rapid = true,
    RapidMult = 1.3,
    Headshot = true,
    NoHeat = true,
    InfAmmo = true,
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
--  CONFIG (sliders only)
--=========================================================
local saveQueued = false

local function saveConfig()
    if type(writefile) ~= "function" or saveQueued then return end
    saveQueued = true
    task.delay(0.8, function()
        saveQueued = false
        pcall(function()
            if makefolder and not isfolder(CFG.ConfigDir) then makefolder(CFG.ConfigDir) end
            writefile(CFG.ConfigPath, HttpService:JSONEncode({
                Magazine = S.Magazine, RapidMult = S.RapidMult,
            }))
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
--  MODULES
--=========================================================
local combatFolder = nil
local function combat()
    if not combatFolder then
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        combatFolder = shared and shared:FindFirstChild("Combat")
    end
    return combatFolder
end

local function getGuns()
    local C = combat()
    if not C then return nil end
    local ok, mod = pcall(function() return require(C.Guns) end)
    if ok and type(mod) == "table" and type(mod.Types) == "table" then return mod end
    return nil
end

local loaderModule = nil
local function controllerLoader()
    if not loaderModule then
        local ok, loader = pcall(function()
            return require(LP.PlayerScripts.Client.Framework.ControllerLoader)
        end)
        if ok then loaderModule = loader end
    end
    return loaderModule
end

local function gunController()
    local loader = controllerLoader()
    local map = loader and loader._map
    return map and map.GunController or nil
end

--=========================================================
--  WEAPON PATCH
--=========================================================
local base = getgenv().__rat4080HiveBase
if type(base) ~= "table" then
    base = {}
    getgenv().__rat4080HiveBase = base
end

local function stateFor(name, def)
    local st = base[name]
    if not st then
        st = {
            rate = def.Rate,
            mag = def.Magazine,
            heat = def.Heat and def.Heat.PerShot,
            overheat = def.Heat and def.Heat.OverheatSeconds,
        }
        base[name] = st
    end
    return st
end

local function modDef(def, name)
    if type(def) ~= "table" or type(name) ~= "string" then return false end
    local st = stateFor(name, def)

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

    if S.Magazine > 0 and type(st.mag) == "number" and st.mag > 0 then
        def.Magazine = S.Magazine
    end

    if S.NoHeat and def.Heat then
        def.Heat.PerShot = 0
        def.Heat.OverheatSeconds = 0
    end

    if type(st.rate) == "number" then
        local rate = S.Rapid and (st.rate * S.RapidMult) or st.rate
        if rate >= 0.2 and rate <= 500 then
            def.Rate = rate
        end
    end

    return true
end

local patched = 0

local function applyAll()
    local n = 0
    local Guns = getGuns()
    if Guns then
        for name, def in pairs(Guns.Types) do
            if modDef(def, name) then n = n + 1 end
        end
    end

    local gun = gunController()
    if gun and gun._def and gun._name then
        modDef(gun._def, gun._name)

        local entry = gun._mags and gun._mags[gun._name]
        if type(entry) == "table" then
            if S.NoHeat then
                entry.Heat = 0
                entry.OverheatUntil = nil
            end
            if S.InfAmmo and type(entry.Ammo) == "number" then
                local target = tonumber(gun._def.Magazine) or 0
                if target > 0 and entry.Ammo < target then
                    entry.Ammo = target
                end
            end
        end
    end

    if n > 0 then patched = n end
    return n
end

local function restoreAll()
    local Guns = getGuns()
    if Guns then
        for name, def in pairs(Guns.Types) do
            local st = base[name]
            if st and type(def) == "table" then
                if type(st.rate) == "number" then def.Rate = st.rate end
                if type(st.mag) == "number" then def.Magazine = st.mag end
            end
        end
    end
    local gun = gunController()
    if gun and gun._def and gun._name then
        local st = base[gun._name]
        if st then
            if type(st.rate) == "number" then gun._def.Rate = st.rate end
            if type(st.mag) == "number" then gun._def.Magazine = st.mag end
        end
    end
end

--=========================================================
--  HEADSHOT REWRITE (real hit packet, head flag forced)
--=========================================================
local sendHitsOriginal = nil
local headHooked = false

local function installHeadshot()
    local gun = gunController()
    if not gun or type(gun._sendHits) ~= "function" then return false end
    if headHooked then return true end

    sendHitsOriginal = gun._sendHits
    gun._sendHits = function(self, t)
        if S.Headshot then
            local hits = self._hits
            if type(hits) == "table" then
                for i = 1, #hits do
                    local entry = hits[i]
                    if type(entry) == "table" and type(entry[1]) == "number" then
                        entry[2] = true
                        entry[3] = 0
                        entry[4] = 0
                        entry[5] = false
                    end
                end
            end
        end
        return sendHitsOriginal(self, t)
    end
    headHooked = true
    return true
end

local function uninstallHeadshot()
    local gun = gunController()
    if gun and sendHitsOriginal then
        gun._sendHits = sendHitsOriginal
    end
    sendHitsOriginal = nil
    headHooked = false
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Guns:AddGroupbox({ Side = "Left", Name = "Weapon", IconName = "crosshair" })

box:AddToggle("NoRecoil", {
    Text = "No recoil",
    Default = true,
    Tooltip = "Zeroes the camera kick and the spray pattern.",
    Callback = function(v)
        S.NoRecoil = v
        applyAll()
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
        applyAll()
        notify("No spread " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.NoSpread then
    pcall(function()
        Toggles.NoSpread:AddKeyPicker("SpreadBind", { Text = "No spread bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Magazine", {
    Text = "Magazine size",
    Default = S.Magazine,
    Min = 0,
    Max = 300,
    Rounding = 0,
    Tooltip = "0 keeps the real magazine.",
    Callback = function(v)
        S.Magazine = v
        applyAll()
        saveConfig()
    end,
})

box:AddToggle("Rapid", {
    Text = "Faster fire",
    Default = true,
    Tooltip = "Small multiplier on the fire rate.",
    Callback = function(v)
        S.Rapid = v
        applyAll()
        notify("Faster fire " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Rapid then
    pcall(function()
        Toggles.Rapid:AddKeyPicker("RapidBind", { Text = "Faster fire bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("RapidMult", {
    Text = "Fire rate x",
    Default = S.RapidMult,
    Min = 1.05,
    Max = 2.5,
    Rounding = 2,
    Tooltip = "1.3 = +30%. Above 1.6 the server starts eating shots.",
    Callback = function(v) S.RapidMult = v; applyAll(); saveConfig() end,
})

box:AddDivider("Heat / ammo")

box:AddToggle("NoHeat", {
    Text = "No weapon heat",
    Default = true,
    Tooltip = "Minigun and any heat weapon never builds heat or overheats.",
    Callback = function(v)
        S.NoHeat = v
        applyAll()
        notify("No heat " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.NoHeat then
    pcall(function()
        Toggles.NoHeat:AddKeyPicker("HeatBind", { Text = "No heat bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddToggle("InfAmmo", {
    Text = "Infinite ammo (held weapon)",
    Default = true,
    Tooltip = "Keeps the held weapon magazine full while you shoot.",
    Callback = function(v)
        S.InfAmmo = v
        notify("Infinite ammo " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.InfAmmo then
    pcall(function()
        Toggles.InfAmmo:AddKeyPicker("AmmoBind", { Text = "Infinite ammo bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddDivider("Headshot")

box:AddToggle("Headshot", {
    Text = "All hits = headshot",
    Default = true,
    Tooltip = "Rewrites the head flag inside your real hit packet before it is sent.",
    Callback = function(v)
        S.Headshot = v
        if v then installHeadshot() else uninstallHeadshot() end
        notify("Headshot rewrite " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Headshot then
    pcall(function()
        Toggles.Headshot:AddKeyPicker("HeadBind", { Text = "Headshot bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddButton({
    Text = "Re-apply",
    Icon = "rotate-ccw",
    Func = function()
        local n = applyAll()
        installHeadshot()
        notify("Patched " .. tostring(n) .. " weapons", "check")
    end,
})

box:AddDivider("Status")

local status = box:AddLabel("patched 0")

task.spawn(function()
    task.wait(2)
    while getgenv().__rat4080Hive do
        pcall(function()
            applyAll()
            if S.Headshot and not headHooked then installHeadshot() end
            status:SetText(string.format("weapons %d  ·  mag %s  ·  rate x%.2f  ·  head %s",
                patched,
                S.Magazine > 0 and tostring(S.Magazine) or "real",
                S.Rapid and S.RapidMult or 1,
                S.Headshot and "forced" or "normal"))
        end)
        task.wait(1)
    end
end)

-- heat and ammo need a faster tick than the config refresh
task.spawn(function()
    task.wait(2)
    while getgenv().__rat4080Hive do
        pcall(function()
            local gun = gunController()
            local entry = gun and gun._name and gun._mags and gun._mags[gun._name]
            if type(entry) == "table" then
                if S.NoHeat then
                    entry.Heat = 0
                    entry.OverheatUntil = nil
                end
                if S.InfAmmo and type(entry.Ammo) == "number" then
                    local target = tonumber(gun._def and gun._def.Magazine) or 0
                    if target > 0 and entry.Ammo < target then
                        entry.Ammo = target
                    end
                end
            end
        end)
        task.wait(0.1)
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
    if saved then
        if type(saved.Magazine) == "number" then
            S.Magazine = math.clamp(saved.Magazine, 0, 300)
            pcall(function() Options.Magazine:SetValue(S.Magazine) end)
        end
        if type(saved.RapidMult) == "number" then
            S.RapidMult = math.clamp(saved.RapidMult, 1.05, 2.5)
            pcall(function() Options.RapidMult:SetValue(S.RapidMult) end)
        end
    end
end

-- Obsidian fires toggle callbacks with false while building the window
S.NoRecoil = true
S.NoSpread = true
S.Rapid = true
S.Headshot = true
pcall(function() Toggles.NoRecoil:SetValue(true) end)
pcall(function() Toggles.NoSpread:SetValue(true) end)
pcall(function() Toggles.Rapid:SetValue(true) end)
pcall(function() Toggles.Headshot:SetValue(true) end)
S.NoRecoil = true
S.NoSpread = true
S.Rapid = true
S.Headshot = true

applyAll()
installHeadshot()

getgenv().__rat4080Hive = {
    State = S,
    Library = Library,
    Signals = Signals,
    Apply = applyAll,
    Restore = restoreAll,
    Count = function() return patched end,
    InstallHeadshot = installHeadshot,
}

Library:OnUnload(function()
    restoreAll()
    uninstallHeadshot()
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Hive = nil
end)

notify(string.format("Hive ready · %d weapons · %s", patched, CFG.MenuKey), "check")

return { Library = Library, Window = Window, State = S }
