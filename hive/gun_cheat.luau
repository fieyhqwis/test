--=====================================================================
--  RAT 4080 — INTO THE HIVE · GUN CHEAT
--  Patches the weapon def the client actually fires with.
--=====================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  HIVE GUNS",
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
    Magazine = 0,       -- 0 = leave the real magazine alone
    Rapid = true,
    RapidMult = 1.3,
    Grenades = false,
    Turret = false,
    Ultimate = false,
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
--  CONFIG FILE
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
local function gunController()
    if not loaderModule then
        local ok, loader = pcall(function()
            return require(LP.PlayerScripts.Client.Framework.ControllerLoader)
        end)
        if ok then loaderModule = loader end
    end
    local map = loaderModule and loaderModule._map
    return map and map.GunController or nil
end

--=========================================================
--  WEAPON PATCH
--=========================================================
-- base[name] keeps the untouched values, written* keeps what we last wrote,
-- so an augments/level rewrite is picked up without stacking multipliers.
local base = getgenv().__rat4080HiveBase
if type(base) ~= "table" then
    base = {}
    getgenv().__rat4080HiveBase = base
end

local function stateFor(name, def)
    local st = base[name]
    if not st then
        st = { rate = def.Rate, mag = def.Magazine }
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

    if type(st.rate) == "number" then
        local rate = st.rate
        if S.Rapid then
            rate = rate * S.RapidMult
        end
        -- never write something absurd, that is how a gun stops shooting
        if rate >= 0.2 and rate <= 500 then
            def.Rate = rate
        end
    end

    st.writtenRate = def.Rate
    st.writtenMag = def.Magazine
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

    -- the controller keeps its own copy of the def, that is what actually fires
    local gun = gunController()
    if gun and gun._def and gun._name then
        modDef(gun._def, gun._name)
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
--  ABILITIES
--=========================================================
local abilityOriginals = {}

local function patchAbilities()
    local C = combat()
    if not C then return end

    local okTh, Th = pcall(function() return require(C.Throwables) end)
    if okTh and type(Th) == "table" and type(Th.Types) == "table" then
        for key, def in pairs(Th.Types) do
            if type(def) == "table" then
                local saved = abilityOriginals["TH_" .. tostring(key)]
                if not saved then
                    saved = { Charges = def.Charges, Recharge = def.Recharge }
                    abilityOriginals["TH_" .. tostring(key)] = saved
                end
                if S.Grenades then
                    if type(def.Charges) == "number" then def.Charges = 99 end
                    if type(def.Recharge) == "number" then def.Recharge = 0 end
                else
                    def.Charges = saved.Charges
                    def.Recharge = saved.Recharge
                end
            end
        end
    end

    local okTu, Tu = pcall(function() return require(C.Turrets) end)
    if okTu and type(Tu) == "table" then
        if abilityOriginals.turretRecharge == nil then
            abilityOriginals.turretRecharge = Tu.Recharge
        end
        Tu.Recharge = S.Turret and 0 or abilityOriginals.turretRecharge
    end

    local okCl, Cl = pcall(function() return require(C.Classes) end)
    if okCl and type(Cl) == "table" and type(Cl.Ultimate) == "table" then
        if abilityOriginals.ultPerSecond == nil then
            abilityOriginals.ultPerSecond = Cl.Ultimate.PerSecond
        end
        Cl.Ultimate.PerSecond = S.Ultimate and 500 or abilityOriginals.ultPerSecond

        if not abilityOriginals.ultOf and type(Cl.UltimateOf) == "function" then
            abilityOriginals.ultOf = Cl.UltimateOf
            Cl.UltimateOf = function(player, now)
                if S.Ultimate then return Cl.Ultimate.Full, 0 end
                return abilityOriginals.ultOf(player, now)
            end
        end
    end
end

local function refresh()
    local n = applyAll()
    patchAbilities()
    return n
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Guns:AddGroupbox({ Side = "Left", Name = "Weapon", IconName = "crosshair" })

box:AddToggle("NoRecoil", {
    Text = "No recoil",
    Default = true,
    Tooltip = "Zeroes the camera kick and the spray pattern. Client side.",
    Callback = function(v)
        S.NoRecoil = v
        refresh()
        notify("No recoil " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

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

box:AddSlider("Magazine", {
    Text = "Magazine size",
    Default = S.Magazine,
    Min = 0,
    Max = 300,
    Rounding = 0,
    Tooltip = "0 keeps the real magazine. Bigger mag, not infinite ammo.",    Callback = function(v)
        S.Magazine = v
        refresh()
        saveConfig()
    end,
})

box:AddToggle("Rapid", {
    Text = "Faster fire",
    Default = true,
    Tooltip = "Speeds up shooting and the charge build on charge weapons.",
    Callback = function(v)
        S.Rapid = v
        refresh()
        notify("Faster fire " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

box:AddSlider("RapidMult", {
    Text = "Fire rate x",
    Default = S.RapidMult,
    Min = 1.05,
    Max = 2.5,
    Rounding = 2,
    Tooltip = "1.3 = +30%. Applies to both tap shots and charge speed.",
    Callback = function(v) S.RapidMult = v; refresh(); saveConfig() end,
})

box:AddButton({
    Text = "Re-apply",
    Icon = "rotate-ccw",
    Func = function()
        local n = refresh()
        notify("Patched " .. tostring(n) .. " weapons", "check")
    end,
})

box:AddDivider("Abilities")

box:AddToggle("Grenades", {
    Text = "Grenades: 99 charges",
    Default = false,
    Tooltip = "Charges 99 and recharge 0 on every throwable.",
    Callback = function(v) S.Grenades = v; refresh(); notify("Grenades " .. (v and "ON" or "OFF"), "check") end,
})

box:AddToggle("Turret", {
    Text = "Turret no cooldown",
    Default = false,
    Tooltip = "Sets the turret recharge to 0.",
    Callback = function(v) S.Turret = v; refresh(); notify("Turret cd " .. (v and "off" or "normal"), "check") end,
})

box:AddToggle("Ultimate", {
    Text = "Ultimate always full",
    Default = false,
    Tooltip = "Forces the ultimate charge to Full on the client.",
    Callback = function(v) S.Ultimate = v; refresh(); notify("Ultimate " .. (v and "full" or "normal"), "check") end,
})

box:AddDivider("Status")

local status = box:AddLabel("patched 0")

task.spawn(function()
    task.wait(2)
    while getgenv().__rat4080Hive do
        pcall(function()
            refresh()
            status:SetText(string.format("weapons %d  ·  mag %s  ·  rate x%.2f  ·  grenade %s",
                patched,
                S.Magazine > 0 and tostring(S.Magazine) or "real",
                S.Rapid and S.RapidMult or 1,
                S.Grenades and "99" or "normal"))
        end)
        task.wait(0.5)
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
pcall(function() Toggles.NoRecoil:SetValue(true) end)
pcall(function() Toggles.NoSpread:SetValue(true) end)
pcall(function() Toggles.Rapid:SetValue(true) end)
S.NoRecoil = true
S.NoSpread = true
S.Rapid = true

refresh()

getgenv().__rat4080Hive = {
    State = S,
    Library = Library,
    Signals = Signals,
    Apply = refresh,
    Restore = restoreAll,
    Count = function() return patched end,
}

Library:OnUnload(function()
    restoreAll()
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Hive = nil
end)

notify(string.format("Hive guns ready · %d weapons · %s", patched, CFG.MenuKey), "check")

return { Library = Library, Window = Window, State = S }
