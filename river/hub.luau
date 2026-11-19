--=====================================================================
--  RAT 4080 — THE RIVER · FLY + SPEED
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  THE RIVER",
    Footer = "fly · speed",
    Icon = "waves",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Fly = false,
    FlySpeed = 80,
    Hover = true,
    Speed = false,
    WalkSpeed = 40,
}

local Library, Window, Toggles, Options
local Signals = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Signals[#Signals + 1] = c
    return c
end

do
    local prev = getgenv().__rat4080River
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080River = nil
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
    Main = Window:AddTab("Main", "waves"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function notify(text, icon)
    Library:Notify({ Title = CFG.HubName, Description = text, Icon = icon or "info", Time = 3 })
end

local function humanoid()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid") or nil
end

local function root()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end

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

local speedBase = nil
local flyActive = false

local function startFly()
    local hum = humanoid()
    if not hum then return false end
    flyActive = true
    pcall(function()
        hum.PlatformStand = true
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end)
    return true
end

local function stopFly()
    local hum = humanoid()
    flyActive = false
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

connect(RunService.Heartbeat, function()
    local hum = humanoid()
    local r = root()
    if not (hum and r) then return end

    if S.Speed then
        if not speedBase then speedBase = hum.WalkSpeed end
        if math.abs(hum.WalkSpeed - S.WalkSpeed) > 0.1 then hum.WalkSpeed = S.WalkSpeed end
    elseif speedBase then
        hum.WalkSpeed = speedBase
        speedBase = nil
    end

    if not S.Fly then
        if flyActive then stopFly() end
        return
    end

    if not flyActive then
        if not startFly() then return end
    end

    if hum.PlatformStand ~= true then
        pcall(function()
            hum.PlatformStand = true
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local move = axis()
    local speed = math.clamp(tonumber(S.FlySpeed) or 80, 10, 400)
    local vel = Vector3.zero

    if move.Magnitude > 0 then
        vel = cam.CFrame:VectorToWorldSpace(move.Unit).Unit * speed
    elseif S.Hover then
        vel = Vector3.new(0, 4, 0)
    end

    pcall(function()
        r.AssemblyLinearVelocity = vel
        r.AssemblyAngularVelocity = Vector3.zero
    end)
end)

local flyBox = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Fly", IconName = "plane" })

flyBox:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Tooltip = "WASD to move, Space up, Ctrl down.",
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

flyBox:AddSlider("FlySpeed", {
    Text = "Fly speed",
    Default = S.FlySpeed,
    Min = 10,
    Max = 400,
    Rounding = 0,
    Callback = function(v) S.FlySpeed = v end,
})

flyBox:AddToggle("Hover", {
    Text = "Hover in place",
    Default = true,
    Callback = function(v) S.Hover = v end,
})

local moveBox = Tabs.Main:AddGroupbox({ Side = "Right", Name = "Movement", IconName = "wind" })

moveBox:AddToggle("Speed", {
    Text = "Speed boost",
    Default = false,
    Callback = function(v)
        S.Speed = v
        notify("Speed " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Speed then
    pcall(function()
        Toggles.Speed:AddKeyPicker("SpeedBind", { Text = "Speed bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

moveBox:AddSlider("WalkSpeed", {
    Text = "Walk speed",
    Default = S.WalkSpeed,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(v) S.WalkSpeed = v end,
})

moveBox:AddDivider("Status")

local status = moveBox:AddLabel("idle")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080River do
        pcall(function()
            local r = root()
            status:SetText(string.format("%s · fly %d · walk %s · y %.0f",
                flyActive and "flying" or "idle",
                S.FlySpeed,
                S.Speed and tostring(S.WalkSpeed) or "default",
                r and r.Position.Y or 0))
        end)
        task.wait(0.35)
    end
end)

getgenv().__rat4080River = {
    State = S,
    Library = Library,
    Signals = Signals,
}

Library:OnUnload(function()
    S.Fly = false
    S.Speed = false
    stopFly()
    local hum = humanoid()
    if hum and speedBase then
        pcall(function() hum.WalkSpeed = speedBase end)
    end
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080River = nil
end)

notify("The River ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
