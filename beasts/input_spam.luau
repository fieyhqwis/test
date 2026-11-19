--=====================================================================
--  RAT 4080 — RAGDOLL BEASTS · ANTI-RAGDOLL
--  Detects the beast being toppled and re-sends the recovery input.
--=====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  ANTI RAGDOLL",
    Footer = "recover input",
    Icon = "activity",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Auto = true,
    Rate = 30,
    Tilt = 0.55,
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
    Main = Window:AddTab("Recover", "activity"),
    Settings = Window:AddTab("Settings", "settings"),
}

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("InputShapsnot")

--=========================================================
--  CAPTURE + RECOVERY SPAM
--=========================================================
local lastArgs = nil
local installed = false
local oldNamecall = nil
local sent = 0
local toppled = false

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

local function beastModel()
    local ws = workspace
    local rep = ws:FindFirstChild("Replicated")
    if not rep then return nil end
    return rep:FindFirstChild(LP.Name)
end

local function isToppled(model)
    local torso = model and model:FindFirstChild("Torso", true)
    if not torso then return false end
    local up = torso.CFrame.UpVector
    return math.abs(up.Y) < math.clamp(tonumber(S.Tilt) or 0.55, 0.1, 0.95)
end

local nextAt = 0

RunService.Heartbeat:Connect(function()
    local model = beastModel()
    toppled = isToppled(model)

    if not S.Auto then return end
    if not lastArgs then return end

    local now = os.clock()
    local rate = math.clamp(tonumber(S.Rate) or 30, 1, 90)
    if now < nextAt then return end
    nextAt = now + (1 / rate)

    local a1 = lastArgs[1]
    local a2 = lastArgs[2]

    pcall(function()
        remote:FireServer(a1 or Vector2.zero, a2 or Vector2.zero, toppled, toppled)
    end)
    sent = sent + 1
end)

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Anti ragdoll", IconName = "activity" })

box:AddToggle("Auto", {
    Text = "Recover instantly",
    Default = true,
    Tooltip = "When the beast is toppled it re-sends the recovery input at the chosen rate.",
    Callback = function(v)
        S.Auto = v
        if v then install() end
        Library:Notify({ Title = CFG.HubName, Description = "Recover " .. (v and "ON" or "OFF"), Icon = v and "check" or "x", Time = 2 })
    end,
})

if Toggles.Auto then
    pcall(function()
        Toggles.Auto:AddKeyPicker("AutoBind", { Text = "Recover bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
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

box:AddSlider("Tilt", {
    Text = "Toppled threshold",
    Default = S.Tilt,
    Min = 0.1,
    Max = 0.95,
    Rounding = 2,
    Tooltip = "Lower = only trigger when almost upside down.",
    Callback = function(v) S.Tilt = v end,
})

box:AddDivider("Status")

local status = box:AddLabel("waiting")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

install()

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Beasts do
        pcall(function()
            status:SetText(string.format("%s · toppled=%s · sent %d",
                S.Auto and "armed" or "off",
                tostring(toppled),
                sent))
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
    S.Auto = false
    if installed and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
    end
    getgenv().__rat4080Beasts = nil
end)

Library:Notify({ Title = CFG.HubName, Description = "Anti ragdoll ready · " .. CFG.MenuKey, Icon = "check", Time = 3 })

return { Library = Library, Window = Window, State = S }
