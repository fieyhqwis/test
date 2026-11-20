--=====================================================================
--  RAT 4080 — DESYNC / GHOST
--  Freezes your character replication for a chosen window: the server
--  keeps the last position it received, other players see a statue,
--  you keep moving on your own client.
--  Requires an executor with native RakNet (Madium). Real works too,
--  but its RakNet hooks cost ~90% FPS while installed.
--=====================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  GHOST",
    Footer = "desync",
    Icon = "ghost",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
    ConfigFolder = "RAT4080/Desync",
    ConfigFile = "RAT4080/Desync/config.json",
}

local S = {
    Ghost = false,
    Burst = 3,
    BlockByte = 69,
    BlockAll = false,
    HideLocal = false,
    TpDistance = 30,
    ShowBox = true,
    UseId = true,
    BlockId = 161,
    UseByte = false,
}

local Library, Window, Toggles, Options

--=========================================================
--  CONFIG
--=========================================================
local function saveConfig()
    local ok = pcall(function()
        if not isfolder(CFG.ConfigFolder) then makefolder(CFG.ConfigFolder) end
        writefile(CFG.ConfigFile, game:GetService("HttpService"):JSONEncode({
            Burst = S.Burst,
            BlockByte = S.BlockByte,
            BlockAll = S.BlockAll,
            HideLocal = S.HideLocal,
            TpDistance = S.TpDistance,
            ShowBox = S.ShowBox,
            UseId = S.UseId,
            BlockId = S.BlockId,
            UseByte = S.UseByte,
        }))
    end)
    return ok
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
    S.Burst = tonumber(data.Burst) or S.Burst
    S.BlockByte = tonumber(data.BlockByte) or S.BlockByte
    S.BlockAll = data.BlockAll == true
    S.HideLocal = data.HideLocal == true
    S.TpDistance = tonumber(data.TpDistance) or S.TpDistance
    S.ShowBox = data.ShowBox ~= false
    S.UseId = data.UseId ~= false
    S.BlockId = tonumber(data.BlockId) or S.BlockId
    S.UseByte = data.UseByte == true
end

--=========================================================
--  CLEANUP
--=========================================================
do
    local prev = getgenv().__rat4080Ghost
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
    getgenv().__rat4080Ghost = nil
end

loadConfig()

local rn = rawget(getfenv(), "raknet") or raknet or RakNet

--=========================================================
--  LIBRARY
--=========================================================
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
    Main = Window:AddTab("Ghost", "ghost"),
    Settings = Window:AddTab("Settings", "settings"),
}

--=========================================================
--  GHOST CORE
--=========================================================
local stats = { blocked = 0, passed = 0, lastPrefix = "--", blockedPrefix = {} }
local ghostUntil = 0
local hooked = false
local hookFn = nil

local function charParts()
    local ch = LP.Character
    if not ch then return {} end
    local out = {}
    for _, v in ipairs(ch:GetDescendants()) do
        if v:IsA("BasePart") then out[#out + 1] = v end
    end
    return out
end

local function applyHide(on)
    for _, part in ipairs(charParts()) do
        pcall(function()
            part.LocalTransparencyModifier = on and 1 or 0
        end)
    end
end

local function isGhostActive()
    if S.Ghost then return true end
    return os.clock() < ghostUntil
end

local prefixCounts = {}

local function onPacket(packet)
    local sizeOk, size = pcall(function() return packet.Size end)
    if not sizeOk or type(size) ~= "number" then
        stats.passed += 1
        return
    end

    -- position packets are small; skipping big ones avoids copying world data
    if size > 512 then
        stats.passed += 1
        return
    end

    local ok, raw = pcall(function() return packet.AsString end)
    if not ok or type(raw) ~= "string" or #raw < 2 then
        stats.passed += 1
        return
    end

    local idOk, pid = pcall(function() return packet.PacketId end)
    local first, second = raw:byte(1), raw:byte(2)
    stats.lastPrefix = string.format("%d/%02X %02X", idOk and pid or -1, first, second)

    local key = string.format("%d:%02X%02X", idOk and pid or -1, first, second)
    prefixCounts[key] = (prefixCounts[key] or 0) + 1

    if not isGhostActive() then
        stats.passed += 1
        return
    end

    local hit = false
    if S.BlockAll then
        hit = true
    elseif S.UseId and idOk and pid == S.BlockId then
        hit = true
    elseif S.UseByte and first == 0xC3 and second == S.BlockByte then
        hit = true
    end

    if hit then
        stats.blocked += 1
        stats.blockedPrefix[key] = (stats.blockedPrefix[key] or 0) + 1
        pcall(function() packet:Block() end)
    else
        stats.passed += 1
    end
end

local function installHook()
    if hooked then return true end
    if not rn or type(rn.add_send_hook) ~= "function" then return false end
    hookFn = onPacket
    local ok = pcall(function() rn.add_send_hook(hookFn) end)
    hooked = ok
    return ok
end

local function removeHook()
    if not hooked or not hookFn then return end
    pcall(function() rn.remove_send_hook(hookFn) end)
    hooked = false
    hookFn = nil
end

local marker = nil

local function frozenCFrame()
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.CFrame or nil
end

local function hideMarker()
    if marker then
        pcall(function() marker:Destroy() end)
        marker = nil
    end
end

local function showMarker(cf)
    if not S.ShowBox or not cf then return end
    hideMarker()

    local part = Instance.new("Part")
    part.Name = "RAT4080_GHOST_HITBOX"
    part.Size = Vector3.new(4, 5, 2)
    part.CFrame = cf
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.ForceField
    part.Color = Color3.fromRGB(255, 40, 40)
    part.Transparency = 0.45
    part.Parent = workspace

    local gui = Instance.new("BillboardGui")
    gui.Name = "Tag"
    gui.Size = UDim2.fromScale(7, 1.6)
    gui.StudsOffset = Vector3.new(0, 3.8, 0)
    gui.AlwaysOnTop = true
    gui.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 95, 95)
    label.TextStrokeTransparency = 0.35
    label.Text = "SERVER SEES YOU HERE"
    label.Parent = gui

    marker = part
end

local function setGhost(on)
    S.Ghost = on
    if on then
        if not installHook() then
            S.Ghost = false
            Library:Notify({ Title = CFG.HubName, Description = "RakNet is not available", Icon = "x", Time = 3 })
            return false
        end
        applyHide(S.HideLocal)
        showMarker(frozenCFrame())
    else
        ghostUntil = 0
        applyHide(false)
        hideMarker()
    end
    return true
end

local function burst(seconds)
    if not installHook() then
        Library:Notify({ Title = CFG.HubName, Description = "RakNet is not available", Icon = "x", Time = 3 })
        return false
    end
    ghostUntil = os.clock() + seconds
    applyHide(S.HideLocal)
    showMarker(frozenCFrame())
    return true
end

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Desync", IconName = "ghost" })

box:AddToggle("Ghost", {
    Text = "Ghost mode",
    Default = false,
    Tooltip = "Stops sending your position to the server. Others see a statue.",
    Callback = function(v)
        if v and not setGhost(true) then
            pcall(function() Toggles.Ghost:SetValue(false) end)
            return
        end
        S.Ghost = v
        if not v then setGhost(false) end
    end,
})

if Toggles.Ghost then
    pcall(function()
        Toggles.Ghost:AddKeyPicker("GhostBind", { Text = "Ghost bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddButton({
    Text = "Burst",
    Icon = "zap",
    Func = function()
        if burst(S.Burst) then
            Library:Notify({ Title = CFG.HubName, Description = string.format("Ghost for %ds", S.Burst), Icon = "zap", Time = 2 })
        end
    end,
})

box:AddSlider("Burst", {
    Text = "Burst seconds",
    Default = S.Burst,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(v)
        S.Burst = v
        saveConfig()
    end,
})

box:AddToggle("UseId", {
    Text = "Filter by packet id",
    Default = S.UseId,
    Tooltip = "Blocks every packet with the chosen id. This is what carries position in most games.",
    Callback = function(v)
        S.UseId = v
        saveConfig()
    end,
})

box:AddSlider("BlockId", {
    Text = "Position packet id",
    Default = S.BlockId,
    Min = 0,
    Max = 255,
    Rounding = 0,
    Tooltip = "161 in Voxel Wars. Try 195 if 161 does nothing.",
    Callback = function(v)
        S.BlockId = v
        saveConfig()
    end,
})

box:AddToggle("UseByte", {
    Text = "Filter by first bytes",
    Default = S.UseByte,
    Tooltip = "Extra filter: blocks C3 45 style packets. Only enable if the id filter misses.",
    Callback = function(v)
        S.UseByte = v
        saveConfig()
    end,
})

box:AddSlider("BlockByte", {
    Text = "Position byte",
    Default = S.BlockByte,
    Min = 0,
    Max = 255,
    Rounding = 0,
    Tooltip = "Second byte of the C3 packet. 69 = 0x45.",
    Callback = function(v)
        S.BlockByte = v
        saveConfig()
    end,
})

box:AddToggle("BlockAll", {
    Text = "Block all player packets",
    Default = S.BlockAll,
    Tooltip = "Also blocks remotes. Use only if the byte filter misses.",
    Callback = function(v)
        S.BlockAll = v
        saveConfig()
        if v then
            Library:Notify({ Title = CFG.HubName, Description = "Remotes will be blocked too", Icon = "alert-triangle", Time = 3 })
        end
    end,
})

box:AddToggle("HideLocal", {
    Text = "Hide my model locally",
    Default = S.HideLocal,
    Tooltip = "Cosmetic: your character becomes invisible on your own screen.",
    Callback = function(v)
        S.HideLocal = v
        applyHide(v and isGhostActive())
        saveConfig()
    end,
})

local move = Tabs.Main:AddGroupbox({ Side = "Right", Name = "Movement", IconName = "move" })

move:AddSlider("TpDistance", {
    Text = "Teleport studs",
    Default = S.TpDistance,
    Min = 5,
    Max = 150,
    Rounding = 0,
    Callback = function(v)
        S.TpDistance = v
        saveConfig()
    end,
})

move:AddButton({
    Text = "Teleport forward",
    Icon = "arrow-up",
    Func = function()
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local dist = tonumber(S.TpDistance) or 30
        pcall(function()
            hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -dist)
        end)
    end,
})

move:AddButton({
    Text = "Ghost + teleport",
    Icon = "ghost",
    Func = function()
        if not burst(S.Burst) then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local dist = tonumber(S.TpDistance) or 30
        if hrp then
            pcall(function()
                hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -dist)
            end)
        end
        Library:Notify({ Title = CFG.HubName, Description = "Ghost + TP", Icon = "zap", Time = 2 })
    end,
})

box:AddDivider("Status")

local status = box:AddLabel("idle")
local prefixLabel = box:AddLabel("last packet: --")
local counters = box:AddLabel("blocked 0 · passed 0")
local prefixTop = box:AddLabel("prefixes: --")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

--=========================================================
--  LOOP
--=========================================================
task.spawn(function()
    while getgenv().__rat4080Ghost do
        local active = isGhostActive()
        if not active and hooked and not S.Ghost then
            removeHook()
        end
        pcall(function()
            status:SetText(string.format("%s · burst %ds · byte %d",
                active and "GHOST" or "live",
                S.Burst,
                S.BlockByte))
            prefixLabel:SetText("last packet: " .. stats.lastPrefix)
            counters:SetText(string.format("blocked %d · passed %d", stats.blocked, stats.passed))
            local rows = {}
            for k, v in pairs(prefixCounts) do rows[#rows + 1] = { k = k, n = v } end
            table.sort(rows, function(a, b) return a.n > b.n end)
            local top = {}
            for i = 1, math.min(#rows, 4) do top[#top + 1] = rows[i].k .. "x" .. rows[i].n end
            prefixTop:SetText("prefixes: " .. table.concat(top, " "))
        end)
        task.wait(0.25)
    end
end)

task.spawn(function()
    while getgenv().__rat4080Ghost do
        if S.HideLocal and isGhostActive() then
            applyHide(true)
        end
        task.wait(0.5)
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    if isGhostActive() then
        applyHide(S.HideLocal)
        showMarker(frozenCFrame())
    end
end)

getgenv().__rat4080Ghost = {
    State = S,
    Library = Library,
    Stats = stats,
    Prefixes = prefixCounts,
    SetGhost = setGhost,
    Burst = burst,
    restore = function()
        S.Ghost = false
        ghostUntil = 0
        removeHook()
        applyHide(false)
        hideMarker()
    end,
}

Library:OnUnload(function()
    getgenv().__rat4080Ghost = nil
    S.Ghost = false
    ghostUntil = 0
    removeHook()
    applyHide(false)
    hideMarker()
end)

Library:Notify({
    Title = CFG.HubName,
    Description = "Ghost ready · " .. CFG.MenuKey,
    Icon = "ghost",
    Time = 3,
})

return { Library = Library, Window = Window, State = S }
