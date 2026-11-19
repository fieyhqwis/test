--=====================================================================
--  RAT 4080 — RAGDOLL BEASTS · INPUT SPAM
--  Re-sends the input snapshot with attack flags forced on.
--=====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  BEASTS",
    Footer = "input spam",
    Icon = "paw-print",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Spam = false,
    Rate = 30,
    ForceAttack = true,
}

local Library, Window, Toggles, Options

do
    local prev = getgenv().__rat4080Beasts
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Beasts = nil
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

local Tabs = {
    Main = Window:AddTab("Input", "paw-print"),
    Settings = Window:AddTab("Settings", "settings"),
}

--=========================================================
--  CAPTURE + RESEND
--=========================================================
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InputShapsnot")
local lastArgs = nil
local sent = 0
local installed = false
local oldNamecall = nil

local function install()
    if installed then return true end
    if type(hookmetamethod) ~= "function" then return false end

    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if typeof(self) == "Instance" and self == remote then
            lastArgs = table.pack(...)
        end
        return oldNamecall(self, ...)
    end)

    installed = true
    return true
end

local nextAt = 0

RunService.Heartbeat:Connect(function()
    if not S.Spam then return end
    if not lastArgs then return end

    local now = os.clock()
    local rate = math.clamp(tonumber(S.Rate) or 30, 1, 90)
    if now < nextAt then return end
    nextAt = now + (1 / rate)

    local a1 = lastArgs[1]
    local a2 = lastArgs[2]
    local a3 = lastArgs[3]
    local a4 = lastArgs[4]

    if S.ForceAttack then
        a3 = true
        a4 = true
    end

    pcall(function()
        remote:FireServer(a1, a2, a3, a4)
    end)
    sent = sent + 1
end)

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Input", IconName = "paw-print" })

box:AddToggle("Spam", {
    Text = "Attack spam",
    Default = false,
    Tooltip = "Repeats your own input snapshot with attack flags forced on.",
    Callback = function(v)
        S.Spam = v
        if v then install() end
        Library:Notify({ Title = CFG.HubName, Description = "Spam " .. (v and "ON" or "OFF"), Icon = v and "check" or "x", Time = 2 })
    end,
})

if Toggles.Spam then
    pcall(function()
        Toggles.Spam:AddKeyPicker("SpamBind", { Text = "Spam bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddSlider("Rate", {
    Text = "Inputs per second",
    Default = S.Rate,
    Min = 1,
    Max = 90,
    Rounding = 0,
    Callback = function(v) S.Rate = v end,
})

box:AddToggle("ForceAttack", {
    Text = "Force attack flags",
    Default = true,
    Callback = function(v) S.ForceAttack = v end,
})

box:AddDivider("Status")

local status = box:AddLabel("waiting for input")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Beasts do
        pcall(function()
            status:SetText(string.format("%s · %d/s · sent %d · %s",
                S.Spam and "spamming" or "idle",
                S.Rate,
                sent,
                lastArgs and "have snapshot" or "no snapshot yet"))
        end)
        task.wait(0.35)
    end
end)

getgenv().__rat4080Beasts = {
    State = S,
    Library = Library,
    Remote = remote,
    Sent = function() return sent end,
}

Library:OnUnload(function()
    S.Spam = false
    if installed and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
    end
    getgenv().__rat4080Beasts = nil
end)

Library:Notify({ Title = CFG.HubName, Description = "Beasts spam ready · " .. CFG.MenuKey, Icon = "check", Time = 3 })

return { Library = Library, Window = Window, State = S }
