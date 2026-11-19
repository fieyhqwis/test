--=====================================================================
--  RAT 4080 — DRIVE ONLY UP · INFINITE NITRO
--=====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  DRIVE ONLY UP",
    Footer = "infinite nitro",
    Icon = "flame",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Nitro = true,
    Power = 1.3,
}

local Library, Window, Toggles, Options
local Signals = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Signals[#Signals + 1] = c
    return c
end

do
    local prev = getgenv().__rat4080Drive
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Drive = nil
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
    Main = Window:AddTab("Nitro", "flame"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function notify(text, icon)
    Library:Notify({ Title = CFG.HubName, Description = text, Icon = icon or "info", Time = 3 })
end

--=========================================================
--  CONTROLLER
--=========================================================
local knit = nil

local function carController()
    if not knit then
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        local mod = packages and packages:FindFirstChild("Knit")
        if not mod then return nil end
        local ok, K = pcall(function() return require(mod) end)
        if ok and type(K) == "table" then knit = K end
    end
    if not knit then return nil end

    local ok, ctrl = pcall(function() return knit.GetController("CarController") end)
    if ok and type(ctrl) == "table" then return ctrl end
    if type(knit.Controllers) == "table" then return knit.Controllers.CarController end
    return nil
end

local tankOf = nil
local applied = false
local nitroBase = nil

local function applyPower(car)
    local cfg = car._nitroCfg
    if type(cfg) ~= "table" then return end

    if not nitroBase then
        nitroBase = {
            Ground = tonumber(cfg.GroundThrust) or 0.45,
            Air = tonumber(cfg.AirThrust) or 1.3,
            Top = tonumber(cfg.TopSpeedAdd) or 20,
            AirMax = tonumber(cfg.AirThrustMax) or 110,
        }
    end

    local p = math.clamp(tonumber(S.Power) or 1, 1, 3)
    cfg.GroundThrust = nitroBase.Ground * p
    cfg.AirThrust = nitroBase.Air * p
    cfg.TopSpeedAdd = nitroBase.Top * p
    cfg.AirThrustMax = nitroBase.AirMax * p
end

local function nitroTick()
    local car = carController()
    if not car then
        applied = false
        return
    end
    if not tankOf or tankOf <= 0 then
        tankOf = tonumber(car._nitroCfgTank) or 1
    end

    if not S.Nitro then
        if nitroBase then
            local cfg = car._nitroCfg
            if type(cfg) == "table" then
                cfg.GroundThrust = nitroBase.Ground
                cfg.AirThrust = nitroBase.Air
                cfg.TopSpeedAdd = nitroBase.Top
                cfg.AirThrustMax = nitroBase.AirMax
            end
        end
        return
    end

    applyPower(car)

    if tonumber(car.nitro) ~= tankOf then
        car.nitro = tankOf
    end
    applied = true
end
--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Nitro", IconName = "flame" })

box:AddToggle("Nitro", {
    Text = "Infinite nitro",
    Default = true,
    Tooltip = "Pins the car nitro tank at full so boost never runs out.",
    Callback = function(v)
        S.Nitro = v
        notify("Infinite nitro " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Nitro then
    pcall(function()
        Toggles.Nitro:AddKeyPicker("NitroBind", { Text = "Nitro bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Power", {
    Text = "Nitro power x",
    Default = S.Power,
    Min = 1,
    Max = 3,
    Rounding = 1,
    Tooltip = "Multiplies nitro thrust. 1.3 is noticeable, 2+ is violent.",
    Callback = function(v) S.Power = v end,
})

box:AddDivider("Status")

local status = box:AddLabel("waiting for car")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddToggle("CustomCursor", { Text = "Fallback cursor", Default = true, Callback = function() end })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

--=========================================================
--  LOOP
--=========================================================
task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Drive do
        pcall(nitroTick)
        pcall(function()
            local car = carController()
            if car then
                status:SetText(string.format("nitro %.2f / %.2f  ·  %s",
                    tonumber(car.nitro) or 0,
                    tankOf or 0,
                    applied and "pinned" or "idle"))
            else
                status:SetText("waiting for car")
            end
        end)
        task.wait(0.1)
    end
end)

S.Nitro = true
pcall(function() Toggles.Nitro:SetValue(true) end)
S.Nitro = true

getgenv().__rat4080Drive = {
    State = S,
    Library = Library,
    Signals = Signals,
    Car = carController,
}

Library:OnUnload(function()
    S.Nitro = false
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Drive = nil
end)

notify("Drive Only Up ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
