--=====================================================================
--  RAT 4080 — RAGDOLL SWORD BATTLES · MOUSE SENSITIVITY
--=====================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  SWORD BATTLES",
    Footer = "mouse sensitivity",
    Icon = "mouse-pointer-2",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigDir = "RAT4080/SwordBattles",
    ConfigPath = "RAT4080/SwordBattles/config.json",
}

local S = {
    Sens = 1.6,
    Cursor = true,
    Reach = false,
    ReachAdd = 1.5,
}

local Library, Window, Toggles, Options
local Signals = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Signals[#Signals + 1] = c
    return c
end

do
    local prev = getgenv().__rat4080Sword
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Sword = nil
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
    Main = Window:AddTab("Mouse", "mouse-pointer-2"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function notify(text, icon)
    Library:Notify({ Title = CFG.HubName, Description = text, Icon = icon or "info", Time = 3 })
end

--=========================================================
--  CONFIG
--=========================================================
local saveQueued = false

local function saveConfig()
    if type(writefile) ~= "function" or saveQueued then return end
    saveQueued = true
    task.delay(0.8, function()
        saveQueued = false
        pcall(function()
            if makefolder and not isfolder(CFG.ConfigDir) then makefolder(CFG.ConfigDir) end
            writefile(CFG.ConfigPath, HttpService:JSONEncode({ Sens = S.Sens }))
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
--  SENSITIVITY
--=========================================================
local originalSens = UserInputService.MouseDeltaSensitivity

local function applySens()
    local target = math.clamp(tonumber(S.Sens) or 1, 0.2, 5)
    if math.abs(UserInputService.MouseDeltaSensitivity - target) > 0.001 then
        pcall(function() UserInputService.MouseDeltaSensitivity = target end)
    end
end

local function restoreSens()
    pcall(function() UserInputService.MouseDeltaSensitivity = originalSens or 1 end)
end

--=========================================================
--  REACH
--=========================================================
local swordBase = nil

local function swordConfig()
    local rs = game:GetService("ReplicatedStorage")
    local folder = rs:FindFirstChild("SwordCombat")
    local mod = folder and folder:FindFirstChild("Config")
    if not mod then return nil end
    local ok, C = pcall(function() return require(mod) end)
    if ok and type(C) == "table" then return C end
    return nil
end

local function applyReach()
    local C = swordConfig()
    if not C or type(C.Sword) ~= "table" then return end

    if not swordBase then
        swordBase = {
            blade = tonumber(C.Sword.BladeLength) or 3.3,
            tip = tonumber(C.Sword.TipLength) or 0.42,
            arm = C.Control and tonumber(C.Control.ArmReach) or 2.6,
        }
    end

    if S.Reach then
        local add = math.clamp(tonumber(S.ReachAdd) or 0, 0, 6)
        C.Sword.BladeLength = swordBase.blade + add
        C.Sword.TipLength = swordBase.tip + add * 0.25
        if C.Control then C.Control.ArmReach = swordBase.arm + add * 0.5 end
    else
        C.Sword.BladeLength = swordBase.blade
        C.Sword.TipLength = swordBase.tip
        if C.Control then C.Control.ArmReach = swordBase.arm end
    end
end

local function restoreReach()
    local C = swordConfig()
    if not (C and swordBase and type(C.Sword) == "table") then return end
    C.Sword.BladeLength = swordBase.blade
    C.Sword.TipLength = swordBase.tip
    if C.Control then C.Control.ArmReach = swordBase.arm end
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Mouse", IconName = "mouse-pointer-2" })

box:AddSlider("Sens", {
    Text = "Mouse sensitivity",
    Default = S.Sens,
    Min = 0.2,
    Max = 5,
    Rounding = 2,
    Tooltip = "Multiplies the game camera sensitivity. 1 = game default.",
    Callback = function(v)
        S.Sens = v
        applySens()
        saveConfig()
    end,
})

box:AddButton({
    Text = "Reset to game default (1.0)",
    Icon = "rotate-ccw",
    Func = function()
        S.Sens = 1
        pcall(function() Options.Sens:SetValue(1) end)
        S.Sens = 1
        applySens()
        notify("Sensitivity reset", "check")
    end,
})

box:AddDivider("Reach")

box:AddToggle("Reach", {
    Text = "Reach (sword length)",
    Default = false,
    Tooltip = "Adds studs to the hit sweep. Small values only, the server may compare distance.",
    Callback = function(v)
        S.Reach = v
        applyReach()
        notify("Reach " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Reach then
    pcall(function()
        Toggles.Reach:AddKeyPicker("ReachBind", { Text = "Reach bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("ReachAdd", {
    Text = "Reach +",
    Default = S.ReachAdd,
    Min = 0.5,
    Max = 6,
    Rounding = 1,
    Suffix = " studs",
    Tooltip = "1-2 studs looks natural. 4+ is obvious in the kill feed.",
    Callback = function(v) S.ReachAdd = v; applyReach() end,
})

box:AddDivider("Status")

local status = box:AddLabel("sensitivity 1.00")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddToggle("Cursor", { Text = "Force cursor while menu open", Default = true, Callback = function(v) S.Cursor = v end })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

--=========================================================
--  CURSOR + LOOP
--=========================================================
local drawCursor = nil

connect(RunService.Heartbeat, function()
    if S.Cursor and Window.MainFrame.Visible then
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
    elseif drawCursor then
        drawCursor.dot.Visible = false
        drawCursor.h1.Visible = false
        drawCursor.h2.Visible = false
    end
end)

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Sword do
        pcall(applySens)
        pcall(applyReach)
        pcall(function()
            status:SetText(string.format("sensitivity %.2f  ·  game default %.2f",
                UserInputService.MouseDeltaSensitivity,
                originalSens or 1))
        end)
        task.wait(0.35)
    end
end)

do
    local saved = loadConfig()
    if saved and type(saved.Sens) == "number" then
        S.Sens = math.clamp(saved.Sens, 0.2, 5)
        pcall(function() Options.Sens:SetValue(S.Sens) end)
    end
end

S.Cursor = true
pcall(function() Toggles.Cursor:SetValue(true) end)
S.Cursor = true

applySens()

getgenv().__rat4080Sword = {
    State = S,
    Library = Library,
    Signals = Signals,
}

Library:OnUnload(function()
    restoreSens()
    restoreReach()
    if drawCursor then
        pcall(function()
            drawCursor.dot:Remove()
            drawCursor.h1:Remove()
            drawCursor.h2:Remove()
        end)
    end
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Sword = nil
end)

notify("Sensitivity ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
