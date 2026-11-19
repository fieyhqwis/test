--=====================================================================
--  RAT 4080 — THE RIVER · FAST SWING
--  Speeds up tool animations (hand / paddle) and can spam Activate().
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  FAST SWING",
    Footer = "hand · paddle",
    Icon = "hand",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Auto = false,
    Speed = 2.0,
    Spam = true,
    Rate = 10,
}

local Library, Window, Toggles, Options
local Signals = {}

local function connect(sig, fn)
    local c = sig:Connect(fn)
    Signals[#Signals + 1] = c
    return c
end

do
    local prev = getgenv().__rat4080RiverTools
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080RiverTools = nil
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
    Main = Window:AddTab("Tools", "hand"),
    Settings = Window:AddTab("Settings", "settings"),
}

local function notify(text, icon)
    Library:Notify({ Title = CFG.HubName, Description = text, Icon = icon or "info", Time = 3 })
end

local function heldTool()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

local function animator()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum:FindFirstChildOfClass("Animator") or nil
end

local nextActivate = 0
local swings = 0
local spedTracks = 0

local LOCO = { idle = true, walk = true, run = true, sprint = true, jump = true, fall = true, swim = true, climb = true, sit = true, toolnone = true }

connect(RunService.Heartbeat, function()
    if not S.Auto then return end

    local holding = false
    pcall(function()
        holding = game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end)

    local anim = animator()
    if anim then
        spedTracks = 0
        local speed = math.clamp(tonumber(S.Speed) or 1, 1, 5)
        local target = holding and speed or 1
        local ok, tracks = pcall(function() return anim:GetPlayingAnimationTracks() end)
        if ok and type(tracks) == "table" then
            for _, track in ipairs(tracks) do
                if track and track.Length and track.Length > 0.05 then
                    local name = ""
                    pcall(function() name = track.Animation and track.Animation.Name or "" end)
                    local lower = name:lower()
                    local isLoco = false
                    for key in pairs(LOCO) do
                        if lower:find(key) then isLoco = true break end
                    end
                    if not isLoco and math.abs(track.Speed - target) > 0.05 then
                        pcall(function() track:AdjustSpeed(target) end)
                    end
                    if not isLoco and target > 1 then spedTracks = spedTracks + 1 end
                end
            end
        end
    end

    if S.Spam and holding then
        local tool = heldTool()
        if tool then
            local now = os.clock()
            local rate = math.clamp(tonumber(S.Rate) or 10, 1, 20)
            if now >= nextActivate then
                nextActivate = now + (1 / rate)
                pcall(function() tool:Activate() end)
                swings = swings + 1
            end
        end
    end
end)

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Fast swing", IconName = "hand" })

box:AddToggle("Auto", {
    Text = "Fast hand / paddle",
    Default = false,
    Tooltip = "Speeds up tool animations and re-triggers the tool while LMB is held.",
    Callback = function(v)
        S.Auto = v
        notify("Fast swing " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Auto then
    pcall(function()
        Toggles.Auto:AddKeyPicker("AutoBind", { Text = "Fast swing bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Speed", {
    Text = "Animation speed x",
    Default = S.Speed,
    Min = 1,
    Max = 5,
    Rounding = 1,
    Tooltip = "2 = twice as fast stroke cycle. Above 3 looks unnatural.",
    Callback = function(v) S.Speed = v end,
})

box:AddToggle("Spam", {
    Text = "Re-trigger tool",
    Default = true,
    Tooltip = "Calls Tool:Activate() on a timer so held actions fire more often.",
    Callback = function(v) S.Spam = v end,
})

box:AddSlider("Rate", {
    Text = "Triggers per second",
    Default = S.Rate,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(v) S.Rate = v end,
})

box:AddDivider("Status")

local status = box:AddLabel("idle")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080RiverTools do
        pcall(function()
            local tool = heldTool()
            status:SetText(string.format("%s · %s · tracks %d · swings %d",
                S.Auto and "on" or "idle",
                tool and tool.Name or "no tool",
                spedTracks,
                swings))
        end)
        task.wait(0.35)
    end
end)

getgenv().__rat4080RiverTools = {
    State = S,
    Library = Library,
    Signals = Signals,
}

Library:OnUnload(function()
    S.Auto = false
    local anim = animator()
    if anim then
        pcall(function()
            for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
                pcall(function() track:AdjustSpeed(1) end)
            end
        end)
    end
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080RiverTools = nil
end)

notify("Fast swing ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
