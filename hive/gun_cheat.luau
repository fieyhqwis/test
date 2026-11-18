--=====================================================================
--  RAT 4080 — INTO THE HIVE · GUN CHEAT
--  Patches the weapon def the client actually fires with.
--=====================================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
    WeakAim = false,
    AimStrength = 0.35,
    Grenades = false,
    Turret = false,
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
    local map = controllerLoader() and loaderModule._map
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

    local okTu, Tu = pcall(function() return require(C.Turrets) end)
    if okTu and type(Tu) == "table" then
        if abilityOriginals.turretRecharge == nil then
            abilityOriginals.turretRecharge = Tu.Recharge
        end
        Tu.Recharge = S.Turret and 0 or abilityOriginals.turretRecharge
    end
end

local aimAssistOriginals = nil

local function patchAimAssist()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local cfgFolder = shared and shared:FindFirstChild("Config")
    local mod = cfgFolder and cfgFolder:FindFirstChild("AimAssist")
    if not mod then return end
    local ok, cfg = pcall(function() return require(mod) end)
    if not ok or type(cfg) ~= "table" then return end

    if not aimAssistOriginals then
        aimAssistOriginals = {
            Range = cfg.Range,
            Cone = cfg.Cone and { Aim = cfg.Cone.Aim, Hip = cfg.Cone.Hip },
            Pull = cfg.Pull and { Aim = cfg.Pull.Aim, Hip = cfg.Pull.Hip },
            Follow = cfg.Follow and { Hip = cfg.Follow.Hip, Aim = cfg.Follow.Aim },
            Firing = cfg.Firing and { Aim = cfg.Firing.Aim, Hip = cfg.Firing.Hip },
            Slowdown = cfg.Slowdown and { Aim = cfg.Slowdown.Aim, Hip = cfg.Slowdown.Hip },
        }
    end

    local o = aimAssistOriginals
    if not S.WeakAim then
        cfg.Range = o.Range
        if cfg.Cone and o.Cone then cfg.Cone.Aim, cfg.Cone.Hip = o.Cone.Aim, o.Cone.Hip end
        if cfg.Pull and o.Pull then cfg.Pull.Aim, cfg.Pull.Hip = o.Pull.Aim, o.Pull.Hip end
        if cfg.Follow and o.Follow then cfg.Follow.Aim, cfg.Follow.Hip = o.Follow.Aim, o.Follow.Hip end
        if cfg.Firing and o.Firing then cfg.Firing.Aim, cfg.Firing.Hip = o.Firing.Aim, o.Firing.Hip end
        if cfg.Slowdown and o.Slowdown then cfg.Slowdown.Aim, cfg.Slowdown.Hip = o.Slowdown.Aim, o.Slowdown.Hip end
        return
    end

    cfg.Range = 400
    if cfg.Cone then cfg.Cone.Aim, cfg.Cone.Hip = 45, 45 end
    if cfg.Pull then cfg.Pull.Aim, cfg.Pull.Hip = 1, 1 end
    if cfg.Follow then cfg.Follow.Aim, cfg.Follow.Hip = 1, 1 end
    if cfg.Firing then cfg.Firing.Aim, cfg.Firing.Hip = 80, 80 end
    if cfg.Slowdown then cfg.Slowdown.Aim, cfg.Slowdown.Hip = 0, 0 end
end

local function refresh()
    local n = applyAll()
    patchAbilities()
    patchAimAssist()
    return n
end

--=========================================================
--  WEAK SPOT AIM
--=========================================================
local aimOriginals = {}

local function bugController()
    local loader = controllerLoader()
    local map = loader and loader._map
    return map and map.BugController or nil
end

local function partWeakSpot(model)
    if not model or typeof(model) ~= "Instance" then return nil end
    for _, name in ipairs({ "Head", "Weak", "WeakPoint", "Core", "Eye", "Yolk", "Glow" }) do
        local p = model:FindFirstChild(name, true)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

local function bugModels()
    local list = {}
    local ctrl = bugController()

    local bugs = ctrl and ctrl._bugs
    if type(bugs) == "table" then
        for _, entry in pairs(bugs) do
            if type(entry) == "table" then
                local cand = entry.Rig or entry.Model or entry.Part or entry.Root or entry.Body
                if typeof(cand) == "Instance" then list[#list + 1] = cand end
            elseif typeof(entry) == "Instance" then
                list[#list + 1] = entry
            end
        end
    end

    -- nests are the weak core targets when no swarm is up
    local nests = workspace:FindFirstChild("Nests")
    if nests then
        for _, nest in ipairs(nests:GetChildren()) do
            list[#list + 1] = nest
        end
    end

    return list
end

local aimEnabled = false

RunService:BindToRenderStep("RAT4080WeakAim", Enum.RenderPriority.Camera.Value + 8, function()
    if not aimEnabled then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local models = bugModels()
    if #models == 0 then return end

    local camPos = cam.CFrame.Position
    local viewport = cam.ViewportSize
    local center = viewport * 0.5
    local bestPart, bestScore = nil, math.huge

    for _, model in ipairs(models) do
        local part = partWeakSpot(model)
        if part then
            local sp, on = cam:WorldToViewportPoint(part.Position)
            if on and sp.Z > 0 then
                local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                local worldDist = (part.Position - camPos).Magnitude
                if screenDist < 180 and worldDist < 400 then
                    local score = screenDist + worldDist * 0.1
                    if score < bestScore then
                        bestScore, bestPart = score, part
                    end
                end
            end
        end
    end

    if not bestPart then return end

    local current = cam.CFrame.LookVector
    local want = (bestPart.Position - camPos).Unit
    local alpha = math.clamp(S.AimStrength, 0.05, 1)
    local blended = current:Lerp(want, alpha)
    if blended.Magnitude < 0.01 then return end
    cam.CFrame = CFrame.lookAt(camPos, camPos + blended.Unit)
end)

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

box:AddDivider("Aim")

box:AddToggle("WeakAim", {
    Text = "Aim at weak spot",
    Default = false,
    Tooltip = "Smoothly pulls the crosshair onto the weak part (head / core) of the nearest target on screen.",
    Callback = function(v)
        S.WeakAim = v
        aimEnabled = v
        refresh()
        notify("Weak spot aim " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

box:AddSlider("AimStrength", {
    Text = "Aim strength",
    Default = S.AimStrength,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Tooltip = "0.2 = мягкая подтяжка, 0.5 = заметная, 1 = резкий снап. Ниже 0.4 камера не дёргается.",
    Callback = function(v) S.AimStrength = v end,
})

if Toggles.WeakAim then
    pcall(function()
        Toggles.WeakAim:AddKeyPicker("WeakBind", { Text = "Weak spot bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddDivider("Abilities")

box:AddToggle("Turret", {
    Text = "Turret no cooldown",
    Default = false,
    Tooltip = "Sets the turret recharge to 0.",
    Callback = function(v) S.Turret = v; refresh(); notify("Turret cd " .. (v and "off" or "normal"), "check") end,
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
    pcall(function() RunService:UnbindFromRenderStep("RAT4080WeakAim") end)
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Hive = nil
end)

notify(string.format("Hive guns ready · %d weapons · %s", patched, CFG.MenuKey), "check")

return { Library = Library, Window = Window, State = S }
