--=====================================================================
--  RAT 4080 — HOUSE ESP
--  Batteries (drawer markers) + Intruder with distance.
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  HOUSE",
    Footer = "esp",
    Icon = "scan-eye",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local S = {
    Batteries = true,
    Monster = true,
}

local Library, Window, Toggles, Options

do
    local prev = getgenv().__rat4080House
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
    getgenv().__rat4080House = nil
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
    Main = Window:AddTab("ESP", "scan-eye"),
    Settings = Window:AddTab("Settings", "settings"),
}

--=========================================================
--  DRAWING
--=========================================================
local entries = {}

local function makeEntry()
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Transparency = 1

    local label = Drawing.new("Text")
    label.Size = 14
    label.Center = true
    label.Outline = true
    label.OutlineColor = Color3.new(0, 0, 0)

    return { box = box, label = label }
end

local function freeEntry(e)
    pcall(function() e.box:Remove() end)
    pcall(function() e.label:Remove() end)
end

local function getTargets()
    local list = {}

    if S.Batteries then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and v.Name:lower():find("battery", 1, true) then
                list[#list + 1] = { part = v, text = "Battery", color = Color3.fromRGB(90, 220, 120) }
            end
        end
    end

    if S.Monster then
        local system = workspace:FindFirstChild("IntruderSystem")
        local intruder = system and system:FindFirstChild("Intruder")
        local root = intruder and (intruder.PrimaryPart or intruder:FindFirstChild("HumanoidRootPart") or intruder:FindFirstChildWhichIsA("BasePart"))
        if root then
            list[#list + 1] = { part = root, text = "INTRUDER", color = Color3.fromRGB(255, 60, 60), model = intruder }
        end
    end

    return list
end

local function update()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local targets = getTargets()
    local seen = {}

    for _, t in ipairs(targets) do
        local part = t.part
        if part and part.Parent then
            local entry = entries[part] or makeEntry()
            entries[part] = entry
            seen[part] = true

            local pos = part.Position
            local screen, onScreen = cam:WorldToViewportPoint(pos)
            local dist = (pos - cam.CFrame.Position).Magnitude

            if onScreen then
                local size = 14
                pcall(function()
                    local model = t.model
                    if model then
                        local _, boxSize = model:GetBoundingBox()
                        size = math.max(boxSize.Y, 4)
                    else
                        size = math.max(part.Size.Y, 2)
                    end
                end)

                local top = cam:WorldToViewportPoint(pos + Vector3.new(0, size / 2, 0))
                local bottom = cam:WorldToViewportPoint(pos - Vector3.new(0, size / 2, 0))
                local h = math.abs(bottom.Y - top.Y)
                local w = h * 0.6

                entry.box.Visible = true
                entry.box.Color = t.color
                entry.box.Position = Vector2.new(screen.X - w / 2, top.Y)
                entry.box.Size = Vector2.new(math.max(w, 2), math.max(h, 2))

                entry.label.Visible = true
                entry.label.Color = t.color
                entry.label.Position = Vector2.new(screen.X, top.Y - 16)
                entry.label.Text = string.format("%s [%d]", t.text, math.floor(dist))
            else
                entry.box.Visible = false
                entry.label.Visible = false
            end
        end
    end

    for part, entry in pairs(entries) do
        if not seen[part] then
            freeEntry(entry)
            entries[part] = nil
        end
    end
end

local conn = RunService.RenderStepped:Connect(function()
    pcall(update)
end)

--=========================================================
--  UI
--=========================================================
local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Targets", IconName = "scan-eye" })

box:AddToggle("Batteries", {
    Text = "Battery ESP",
    Default = true,
    Tooltip = "Highlights battery markers inside drawers.",
    Callback = function(v) S.Batteries = v end,
})

box:AddToggle("Monster", {
    Text = "Monster ESP",
    Default = true,
    Tooltip = "Highlights the Intruder with distance.",
    Callback = function(v) S.Monster = v end,
})

local status = box:AddLabel("scanning")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

task.spawn(function()
    while getgenv().__rat4080House do
        pcall(function()
            local count = 0
            for _ in pairs(entries) do count += 1 end
            status:SetText(string.format("targets: %d · battery %s · monster %s", count, S.Batteries and "on" or "off", S.Monster and "on" or "off"))
        end)
        task.wait(0.4)
    end
end)

getgenv().__rat4080House = {
    State = S,
    Library = Library,
    restore = function()
        if conn then pcall(function() conn:Disconnect() end) end
        for _, e in pairs(entries) do freeEntry(e) end
        entries = {}
        getgenv().__rat4080House = nil
    end,
}

Library:OnUnload(function()
    getgenv().__rat4080House = nil
    if conn then pcall(function() conn:Disconnect() end) end
    for _, e in pairs(entries) do freeEntry(e) end
    entries = {}
end)

Library:Notify({ Title = CFG.HubName, Description = "House ESP ready · " .. CFG.MenuKey, Icon = "scan-eye", Time = 3 })

return { Library = Library, Window = Window, State = S }
