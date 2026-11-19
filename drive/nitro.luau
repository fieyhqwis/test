--=====================================================================
--  RAT 4080 — DRIVE ONLY UP · INFINITE NITRO
--=====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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
    Cursor = true,
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

--=========================================================
--  NITRO
--=========================================================
local tankOf = nil
local base = nil
local configNitro = nil
local applied = false

local function abilityConfig()
    if configNitro then return configNitro end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local cfgFolder = shared and shared:FindFirstChild("Config")
    local mod = cfgFolder and cfgFolder:FindFirstChild("AbilityConfig")
    if not mod then return nil end
    local ok, A = pcall(function() return require(mod) end)
    if ok and type(A) == "table" and type(A.Nitro) == "table" then
        configNitro = A.Nitro
    end
    return configNitro
end

local function applyPower()
    local nitro = abilityConfig()
    if not nitro then return end

    if not base then
        base = {
            Ground = tonumber(nitro.GroundThrust) or 0.45,
            Air = tonumber(nitro.AirThrust) or 1.3,
            Top = tonumber(nitro.TopSpeedAdd) or 20,
            AirMax = tonumber(nitro.AirThrustMax) or 110,
            Engine = tonumber(nitro.EngineScale) or 1.45,
        }
    end

    local p = math.clamp(tonumber(S.Power) or 1, 1, 8)
    nitro.GroundThrust = base.Ground * p
    nitro.AirThrust = base.Air * p
    nitro.TopSpeedAdd = base.Top * p
    nitro.AirThrustMax = base.AirMax * p
    nitro.EngineScale = base.Engine * p
end

local function restorePower()
    local nitro = abilityConfig()
    if not (nitro and base) then return end
    nitro.GroundThrust = base.Ground
    nitro.AirThrust = base.Air
    nitro.TopSpeedAdd = base.Top
    nitro.AirThrustMax = base.AirMax
    nitro.EngineScale = base.Engine
end

local function nitroTick()
    if not S.Nitro then
        restorePower()
        applied = false
        return
    end

    applyPower()

    local car = carController()
    if not car then
        applied = false
        return
    end
    if not tankOf or tankOf <= 0 then
        tankOf = tonumber(car._nitroCfgTank) or 1
    end

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
    Max = 8,
    Rounding = 1,
    Tooltip = "Multiplies nitro thrust and top speed bonus. 1.5 is safe, 3+ is violent.",
    Callback = function(v) S.Power = v end,
})

box:AddDivider("Status")

local status = box:AddLabel("waiting for car")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddToggle("Cursor", { Text = "Force cursor while menu open", Default = true, Callback = function(v) S.Cursor = v end })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

--=========================================================
--  CURSOR
--=========================================================
local drawCursor = nil

connect(RunService.Heartbeat, function()
    if not (S.Cursor and Window.MainFrame.Visible) then
        if drawCursor then
            drawCursor.dot.Visible = false
            drawCursor.h1.Visible = false
            drawCursor.h2.Visible = false
        end
        return
    end

    if UserInputService.MouseIconEnabled ~= true then
        pcall(function() UserInputService.MouseIconEnabled = true end)
    end

    if not drawCursor then
        local okDot, dot = pcall(function() return Drawing.new("Circle") end)
        local okL, l1 = pcall(function() return Drawing.new("Line") end)
        local okL2, l2 = pcall(function() return Drawing.new("Line") end)
        if okDot and okL and okL2 then
            dot.Radius = 4
            dot.Thickness = 1
            dot.Filled = true
            dot.Color = Color3.fromRGB(120, 255, 160)
            dot.NumSides = 24
            l1.Thickness = 1
            l1.Color = Color3.fromRGB(120, 255, 160)
            l2.Thickness = 1
            l2.Color = Color3.fromRGB(120, 255, 160)
            drawCursor = { dot = dot, h1 = l1, h2 = l2 }
        end
    end

    if drawCursor then
        local p = UserInputService:GetMouseLocation()
        drawCursor.dot.Position = Vector2.new(p.X, p.Y)
        drawCursor.dot.Visible = true
        drawCursor.h1.From = Vector2.new(p.X - 9, p.Y)
        drawCursor.h1.To = Vector2.new(p.X - 5, p.Y)
        drawCursor.h1.Visible = true
        drawCursor.h2.From = Vector2.new(p.X + 5, p.Y)
        drawCursor.h2.To = Vector2.new(p.X + 9, p.Y)
        drawCursor.h2.Visible = true
    end
end)

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
S.Cursor = true
pcall(function() Toggles.Nitro:SetValue(true) end)
pcall(function() Toggles.Cursor:SetValue(true) end)
S.Nitro = true
S.Cursor = true

getgenv().__rat4080Drive = {
    State = S,
    Library = Library,
    Signals = Signals,
    Car = carController,
}

Library:OnUnload(function()
    S.Nitro = false
    restorePower()
    if drawCursor then
        pcall(function()
            drawCursor.dot:Remove()
            drawCursor.h1:Remove()
            drawCursor.h2:Remove()
        end)
    end
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Drive = nil
end)

notify("Drive Only Up ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
