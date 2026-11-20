--=====================================================================
--  RAT 4080 — CARS OVERBOARD
--  Client-owned car physics: speed control + teleport.
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  CARS OVERBOARD",
    Footer = "car control",
    Icon = "car",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigFolder = "RAT4080/CarsOverboard",
    ConfigFile = "RAT4080/CarsOverboard/config.json",
}

local S = {
    SpeedOn = false,
    Speed = 180,
    TpDistance = 60,
    KeepY = true,
    NitroOn = false,
    NitroPower = 150,
}

local Library, Window, Toggles, Options

local function saveConfig()
    pcall(function()
        if not isfolder(CFG.ConfigFolder) then makefolder(CFG.ConfigFolder) end
        writefile(CFG.ConfigFile, game:GetService("HttpService"):JSONEncode({
            Speed = S.Speed,
            TpDistance = S.TpDistance,
            KeepY = S.KeepY,
            NitroPower = S.NitroPower,
        }))
    end)
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
    S.Speed = tonumber(data.Speed) or S.Speed
    S.TpDistance = tonumber(data.TpDistance) or S.TpDistance
    S.KeepY = data.KeepY ~= false
    S.NitroPower = tonumber(data.NitroPower) or S.NitroPower
end

do
    local prev = getgenv().__rat4080Cars
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
    getgenv().__rat4080Cars = nil
end

loadConfig()

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
    Drive = Window:AddTab("Drive", "car"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function getCar()
    local cars = workspace:FindFirstChild("Cars")
    if not cars then return nil end
    local model = cars:FindFirstChild("Car_" .. tostring(LP.UserId))
    if not model then return nil end
    local root = model.PrimaryPart
    if not root then
        root = model:FindFirstChildWhichIsA("BasePart")
    end
    return model, root
end

local stats = { speedNow = 0 }

local inputMod
for _, v in ipairs(LP.PlayerScripts:GetDescendants()) do
    if v:IsA("ModuleScript") and v.Name == "InputState" then
        inputMod = v
        break
    end
end

local inputHooked = false
if inputMod then
    local ok, mod = pcall(require, inputMod)
    if ok and type(mod) == "table" and type(mod.read) == "function" then
        local oldRead = mod.read
        mod.read = function(...)
            local state = oldRead(...)
            if S.NitroOn and type(state) == "table" then
                state.nitro = true
            end
            return state
        end
        inputHooked = true
    end
end

local conn = RunService.Heartbeat:Connect(function()
    if not S.SpeedOn then return end
    local model, root = getCar()
    if not root then return end

    local target = tonumber(S.Speed) or 180
    local look = root.CFrame.LookVector
    local vel = root.AssemblyLinearVelocity
    local y = S.KeepY and vel.Y or 0
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(look.X * target, y, look.Z * target)
    end)
    stats.speedNow = root.AssemblyLinearVelocity.Magnitude
end)

local nitroConn = RunService.Heartbeat:Connect(function()
    if not S.NitroOn then return end
    local model, root = getCar()
    if not root then return end
    local scale = (tonumber(S.NitroPower) or 150) / 100
    if scale <= 1.01 then return end
    local look = root.CFrame.LookVector
    local vel = root.AssemblyLinearVelocity
    local fwd = vel:Dot(look)
    if fwd > 1 then
        local lateral = vel - look * fwd
        pcall(function()
            root.AssemblyLinearVelocity = look * fwd * scale + lateral
        end)
    end
end)

local function teleportForward(distance)
    local model, root = getCar()
    if not root then return false end
    local dist = distance or tonumber(S.TpDistance) or 60
    pcall(function()
        root.CFrame = root.CFrame + root.CFrame.LookVector * dist
    end)
    return true
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Drive:AddGroupbox({ Side = "Left", Name = "Speed", IconName = "gauge" })

box:AddToggle("SpeedOn", {
    Text = "Speed control",
    Default = false,
    Tooltip = "Overrides your car speed every frame. Physics are client-side here.",
    Callback = function(v)
        S.SpeedOn = v
        if v then
            Library:Notify({ Title = CFG.HubName, Description = "Speed ON", Icon = "check", Time = 2 })
        end
    end,
})

if Toggles.SpeedOn then
    pcall(function()
        Toggles.SpeedOn:AddKeyPicker("SpeedBind", { Text = "Speed bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Speed", {
    Text = "Speed (studs/s)",
    Default = S.Speed,
    Min = 30,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        S.Speed = v
        saveConfig()
    end,
})

box:AddToggle("KeepY", {
    Text = "Keep vertical velocity",
    Default = S.KeepY,
    Tooltip = "Off = zero gravity while boosting.",
    Callback = function(v)
        S.KeepY = v
        saveConfig()
    end,
})

local nitroBox = Tabs.Drive:AddGroupbox({ Side = "Left", Name = "Nitro", IconName = "flame" })

nitroBox:AddToggle("NitroOn", {
    Text = "Infinite nitro",
    Default = false,
    Tooltip = "Forces the nitro input on every frame, so it never runs out.",
    Callback = function(v)
        S.NitroOn = v
        Library:Notify({ Title = CFG.HubName, Description = "Nitro " .. (v and "ON" or "OFF"), Icon = v and "flame" or "x", Time = 2 })
    end,
})

if Toggles.NitroOn then
    pcall(function()
        Toggles.NitroOn:AddKeyPicker("NitroBind", { Text = "Nitro bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

nitroBox:AddSlider("NitroPower", {
    Text = "Nitro power %",
    Default = S.NitroPower,
    Min = 100,
    Max = 300,
    Rounding = 0,
    Callback = function(v)
        S.NitroPower = v
        saveConfig()
    end,
})

nitroBox:AddLabel(inputHooked and "input hook: ready" or "input hook: missing")

local tp = Tabs.Drive:AddGroupbox({ Side = "Right", Name = "Teleport", IconName = "move" })

tp:AddSlider("TpDistance", {
    Text = "Teleport studs",
    Default = S.TpDistance,
    Min = 5,
    Max = 300,
    Rounding = 0,
    Callback = function(v)
        S.TpDistance = v
        saveConfig()
    end,
})

tp:AddButton({
    Text = "Teleport forward",
    Icon = "arrow-up",
    Func = function()
        if teleportForward() then
            Library:Notify({ Title = CFG.HubName, Description = "Teleported", Icon = "zap", Time = 2 })
        end
    end,
})

tp:AddDivider("Status")

local status = tp:AddLabel("idle")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

task.spawn(function()
    while getgenv().__rat4080Cars do
        pcall(function()
            local model, root = getCar()
            if root then
                status:SetText(string.format("%s · %d studs/s · now %.0f", S.SpeedOn and "boost" or "idle", S.Speed, root.AssemblyLinearVelocity.Magnitude))
            else
                status:SetText("no car")
            end
        end)
        task.wait(0.25)
    end
end)

getgenv().__rat4080Cars = {
    State = S,
    Library = Library,
    GetCar = getCar,
    Teleport = teleportForward,
    InputHooked = inputHooked,
    restore = function()
        S.SpeedOn = false
        S.NitroOn = false
        if conn then pcall(function() conn:Disconnect() end) end
        if nitroConn then pcall(function() nitroConn:Disconnect() end) end
        getgenv().__rat4080Cars = nil
    end,
}

Library:OnUnload(function()
    S.SpeedOn = false
    S.NitroOn = false
    if conn then pcall(function() conn:Disconnect() end) end
    if nitroConn then pcall(function() nitroConn:Disconnect() end) end
    getgenv().__rat4080Cars = nil
end)

Library:Notify({ Title = CFG.HubName, Description = "Car control ready · " .. CFG.MenuKey, Icon = "car", Time = 3 })

return { Library = Library, Window = Window, State = S }
