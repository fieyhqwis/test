--=====================================================================
--  RAT 4080 — FLY (bind)
--  PlatformStand hover, WASD + Space/Ctrl, velocity driven.
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  FLY",
    Footer = "bind · WASD · Space/Ctrl",
    Icon = "plane",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigDir = "RAT4080/Fly",
    ConfigPath = "RAT4080/Fly/config.json",
}

local S = {
    Fly = false,
    Speed = 60,
    Hover = true,
    Cursor = true,
    NoAbilityCd = false,
}

local Library, Window, Toggles, Options
local Signals = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Signals[#Signals + 1] = c
    return c
end

do
    local prev = getgenv().__rat4080Fly
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Fly = nil
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
    Main = Window:AddTab("Fly", "plane"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function notify(text, icon)
    Library:Notify({ Title = CFG.HubName, Description = text, Icon = icon or "info", Time = 3 })
end

local function parts()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return nil end
    return char, hum, root
end

local flyActive = false

local function axis()
    local move = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move + Vector3.new(0, -1, 0) end
    return move
end

local function startFly()
    local _, hum = parts()
    if not hum then return false end
    flyActive = true
    pcall(function()
        hum.PlatformStand = true
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end)
    return true
end

local function stopFly()
    local _, hum = parts()
    flyActive = false
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

connect(RunService.Heartbeat, function()
    if not S.Fly then
        if flyActive then stopFly() end
        return
    end

    local _, hum, root = parts()
    if not hum or not root then return end

    if not flyActive then
        if not startFly() then return end
    end

    -- the character re-enables physics on state changes, keep it pinned
    if hum.PlatformStand ~= true then
        pcall(function()
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local move = axis()
    local speed = math.clamp(tonumber(S.Speed) or 60, 10, 400)

    local vel = Vector3.zero
    if move.Magnitude > 0 then
        vel = cam.CFrame:VectorToWorldSpace(move.Unit).Unit * speed
    elseif S.Hover then
        vel = Vector3.new(0, 0, 0)
    end

    pcall(function()
        root.AssemblyLinearVelocity = vel
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end)

--=========================================================
--  ABILITIES (cooldown)
--=========================================================
local abilityBase = nil

local function abilityList()
    local rs = game:GetService("ReplicatedStorage")
    local folder = rs:FindFirstChild("SwordCombat")
    local mod = folder and folder:FindFirstChild("Abilities")
    if not mod then return nil end
    local ok, A = pcall(function() return require(mod) end)
    if ok and type(A) == "table" and type(A.List) == "table" then return A.List end
    return nil
end

local function applyAbilities()
    local list = abilityList()
    if not list then return end

    if not abilityBase then
        abilityBase = {}
        for i, entry in pairs(list) do
            if type(entry) == "table" and type(entry.cooldown) == "number" then
                abilityBase[i] = entry.cooldown
            end
        end
    end

    for i, entry in pairs(list) do
        if type(entry) == "table" and type(abilityBase[i]) == "number" then
            entry.cooldown = S.NoAbilityCd and 0 or abilityBase[i]
        end
    end
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Fly", IconName = "plane" })

box:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Tooltip = "WASD to move, Space up, Ctrl down. Bind toggles it.",
    Callback = function(v)
        S.Fly = v
        if v then startFly() else stopFly() end
        notify("Fly " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Fly then
    pcall(function()
        Toggles.Fly:AddKeyPicker("FlyBind", { Text = "Fly bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Speed", {
    Text = "Fly speed",
    Default = S.Speed,
    Min = 10,
    Max = 400,
    Rounding = 0,
    Callback = function(v) S.Speed = v end,
})

box:AddToggle("Hover", {
    Text = "Hover (stay in place)",
    Default = true,
    Tooltip = "When no keys are held the character hangs still instead of falling.",
    Callback = function(v) S.Hover = v end,
})

box:AddDivider("Abilities")

box:AddToggle("NoAbilityCd", {
    Text = "Abilities no cooldown",
    Default = false,
    Tooltip = "Zeroes the client cooldown of every ability (bandage, sand, hook...).",
    Callback = function(v)
        S.NoAbilityCd = v
        applyAbilities()
        notify("Ability cooldown " .. (v and "0" or "normal"), v and "check" or "x")
    end,
})

if Toggles.NoAbilityCd then
    pcall(function()
        Toggles.NoAbilityCd:AddKeyPicker("AbilityBind", { Text = "Ability cd bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddDivider("Status")

local status = box:AddLabel("idle")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddToggle("Cursor", { Text = "Force cursor while menu open", Default = true, Callback = function(v) S.Cursor = v end })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

local cursorDraw = nil

connect(RunService.Heartbeat, function()
    if S.Cursor and Window.MainFrame.Visible then
        if UserInputService.MouseIconEnabled ~= true then
            pcall(function() UserInputService.MouseIconEnabled = true end)
        end
        if not cursorDraw then
            local ok1, l1 = pcall(function() return Drawing.new("Line") end)
            local ok2, l2 = pcall(function() return Drawing.new("Line") end)
            if ok1 and ok2 then
                l1.Thickness = 1
                l1.Color = Color3.fromRGB(120, 255, 160)
                l2.Thickness = 1
                l2.Color = Color3.fromRGB(120, 255, 160)
                cursorDraw = { v = l1, h = l2 }
            end
        end
        if cursorDraw then
            local p = UserInputService:GetMouseLocation()
            cursorDraw.h.From = Vector2.new(p.X - 9, p.Y)
            cursorDraw.h.To = Vector2.new(p.X + 9, p.Y)
            cursorDraw.h.Visible = true
            cursorDraw.v.From = Vector2.new(p.X, p.Y - 9)
            cursorDraw.v.To = Vector2.new(p.X, p.Y + 9)
            cursorDraw.v.Visible = true
        end
    elseif cursorDraw then
        cursorDraw.v.Visible = false
        cursorDraw.h.Visible = false
    end
end)

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Fly do
        pcall(function()
            local _, _, root = parts()
            status:SetText(string.format("%s · speed %d · y %.0f",
                flyActive and "flying" or "idle",
                S.Speed,
                root and root.Position.Y or 0))
        end)
        pcall(applyAbilities)
        task.wait(0.35)
    end
end)

S.Hover = true
S.Cursor = true
S.Fly = false
pcall(function() Toggles.Hover:SetValue(true) end)
pcall(function() Toggles.Cursor:SetValue(true) end)
pcall(function() Toggles.Fly:SetValue(false) end)
S.Hover = true
S.Cursor = true
S.Fly = false

getgenv().__rat4080Fly = {
    State = S,
    Library = Library,
    Signals = Signals,
    Start = startFly,
    Stop = stopFly,
}

Library:OnUnload(function()
    S.Fly = false
    stopFly()
    if cursorDraw then
        pcall(function() cursorDraw.v:Remove() cursorDraw.h:Remove() end)
    end
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080Fly = nil
end)

notify("Fly ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
