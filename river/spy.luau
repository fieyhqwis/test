--=====================================================================
--  RAT 4080 — REMOTE SPY
--  Logs every FireServer call with its arguments (hookmetamethod).
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CFG = {
    HubName = "RAT 4080",
    WindowTitle = "RAT 4080  //  REMOTE SPY",
    Footer = "FireServer logger",
    Icon = "radio",
    Repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    MenuKey = "RightShift",
}

local Library, Window, Toggles, Options

do
    local prev = getgenv().__rat4080Spy
    if prev and prev.Library and prev.Library.Unload then
        pcall(function() prev.Library:Unload() end)
    end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("ScreenGui") and (inst.Name == "Obsidian" or inst.Name == "ObsidianLoading") then
            pcall(function() inst:Destroy() end)
        end
    end
    getgenv().__rat4080Spy = nil
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
    Main = Window:AddTab("Spy", "radio"),
    Settings = Window:AddTab("Settings", "settings"),
}

local log = {}
local enabled = false
local maxLines = 18
local hooked = false
local oldNamecall = nil

local function fmt(v)
    local t = typeof(v)
    if t == "number" then return string.format("%.0f", v) end
    if t == "string" then return v:sub(1, 40) end
    if t == "Instance" then return v.Name end
    if t == "Vector3" then return string.format("%.0f,%.0f,%.0f", v.X, v.Y, v.Z) end
    if t == "CFrame" then local p = v.Position return string.format("cf %.0f,%.0f,%.0f", p.X, p.Y, p.Z) end
    if t == "boolean" then return tostring(v) end
    return t
end

local function install()
    if hooked then return true end
    if type(hookmetamethod) ~= "function" then return false end

    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if enabled and typeof(self) == "Instance" then
            local method = getnamecallmethod and getnamecallmethod() or ""
            if method == "FireServer" or method == "InvokeServer" then
                local args = table.pack(...)
                local parts = {}
                for i = 1, math.min(args.n, 4) do
                    parts[#parts + 1] = fmt(args[i])
                end
                log[#log + 1] = string.format("%s(%s)", self.Name, table.concat(parts, ", "))
                if #log > maxLines then table.remove(log, 1) end
            end
        end
        return oldNamecall(self, ...)
    end)

    hooked = true
    return true
end

local function uninstall()
    if hooked and oldNamecall then
        pcall(function() hookmetamethod(game, "__namecall", oldNamecall) end)
    end
    hooked = false
    oldNamecall = nil
end

local box = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Spy", IconName = "radio" })

box:AddToggle("Enabled", {
    Text = "Capture remotes",
    Default = false,
    Tooltip = "Logs FireServer / InvokeServer calls with their arguments.",
    Callback = function(v)
        enabled = v
        if v then
            local ok = install()
            Library:Notify({ Title = CFG.HubName, Description = ok and "Spy ON" or "hookmetamethod unavailable", Icon = ok and "check" or "x", Time = 3 })
        else
            Library:Notify({ Title = CFG.HubName, Description = "Spy OFF", Icon = "x", Time = 3 })
        end
    end,
})

if Toggles.Enabled then
    pcall(function()
        Toggles.Enabled:AddKeyPicker("SpyBind", { Text = "Spy bind", Default = "None", Mode = "Toggle", SyncToggleState = true })
    end)
end

box:AddButton({
    Text = "Clear log",
    Icon = "trash-2",
    Func = function()
        log = {}
    end,
})

box:AddDivider("Output")

local output = box:AddLabel("waiting")

local menu = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })

menu:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = CFG.MenuKey, NoUI = true, Text = "Menu keybind" })
menu:AddButton({ Text = "Close menu", Icon = "x", Func = function() pcall(function() Window:Toggle(false) end) end })
menu:AddButton({ Text = "Unload", Icon = "power", Func = function() pcall(function() Library:Unload() end) end })

Library.ToggleKeybind = Options.MenuKeybind

task.spawn(function()
    task.wait(1)
    while getgenv().__rat4080Spy do
        pcall(function()
            if #log == 0 then
                output:SetText(enabled and "listening..." or "spy off")
            else
                local lines = {}
                for i = math.max(1, #log - 7), #log do
                    lines[#lines + 1] = log[i]
                end
                output:SetText(table.concat(lines, "\n"))
            end
        end)
        task.wait(0.5)
    end
end)

getgenv().__rat4080Spy = {
    Library = Library,
    Log = log,
}

Library:OnUnload(function()
    uninstall()
    getgenv().__rat4080Spy = nil
end)

Library:Notify({ Title = CFG.HubName, Description = "Remote spy ready · " .. CFG.MenuKey, Icon = "check", Time = 3 })

return { Library = Library, Window = Window }
