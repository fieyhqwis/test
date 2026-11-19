--=====================================================================
--  RAT 4080 — THE RIVER · FAST TOOLS
--  Spams Tool:Activate() so hand / paddle swing as fast as allowed.
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  FAST TOOLS",
    Footer = "hand · paddle",
    Icon = "hand",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Auto = false,
    Rate = 8,
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

local nextAt = 0
local swings = 0

connect(RunService.Heartbeat, function()
    if not S.Auto then return end
    local tool = heldTool()
    if not tool then return end

    local now = os.clock()
    local rate = math.clamp(tonumber(S.Rate) or 8, 1, 20)
    if now < nextAt then return end
    nextAt = now + (1 / rate)

    pcall(function() tool:Activate() end)
    swings = swings + 1
end)

local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Fast tools", IconName = "hand" })

box:AddToggle("Auto", {
    Text = "Fast hand / paddle",
    Default = false,
    Tooltip = "Calls Tool:Activate() at the chosen rate while a tool is equipped.",
    Callback = function(v)
        S.Auto = v
        notify("Fast tools " .. (v and "ON" or "OFF"), v and "check" or "x")
    end,
})

if Toggles.Auto then
    pcall(function()
        Toggles.Auto:AddKeyPicker("AutoBind", { Text = "Fast tools bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Rate", {
    Text = "Swings per second",
    Default = S.Rate,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Tooltip = "8-10 looks human. 20 is obviously robotic.",
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
            status:SetText(string.format("%s · %s · %d swings",
                S.Auto and "spamming" or "idle",
                tool and tool.Name or "no tool",
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
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    getgenv().__rat4080RiverTools = nil
end)

notify("Fast tools ready · " .. CFG.MenuKey, "check")

return { Library = Library, Window = Window, State = S }
