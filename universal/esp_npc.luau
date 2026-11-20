--=====================================================================
--  RAT 4080 — NPC ESP (no GUI)
--  Boxes + names + distance for Workspace.Passengers / PartyPuppets.
--  F1 toggles. F2 cycles the highlighted name.
--=====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

if getgenv().__esp4080 and getgenv().__esp4080.destroy then
    pcall(getgenv().__esp4080.destroy)
end

local S = {
    Enabled = true,
    Highlight = "Widow",
    MaxDistance = 800,
    Names = { "Widow", "Elder", "Tweed", "Secretary", "Banker", "Agent", "Clerk", "Typist", "Analyst", "Courier", "Puppet" },
    HighlightIndex = 1,
}

local FOLDERS = { "Passengers", "PartyPuppets", "Tanks" }

local entries = {}

local function makeEntry()
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Transparency = 1

    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = true
    text.Outline = true
    text.OutlineColor = Color3.new(0, 0, 0)

    return { box = box, text = text }
end

local function freeEntry(e)
    pcall(function() e.box:Remove() end)
    pcall(function() e.text:Remove() end)
end

local function collect()
    local out = {}
    for _, folderName in ipairs(FOLDERS) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    out[#out + 1] = model
                end
            end
        end
    end
    return out
end

local function colorFor(name)
    if S.Highlight ~= "" and name:lower():find(S.Highlight:lower(), 1, true) then
        return Color3.fromRGB(255, 60, 60)
    end
    return Color3.fromRGB(220, 220, 220)
end

local function update()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local models = collect()
    local seen = {}

    for i, model in ipairs(models) do
        local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
        if ok and cf then
            local entry = entries[model] or makeEntry()
            entries[model] = entry
            seen[model] = true

            local dist = (cf.Position - cam.CFrame.Position).Magnitude
            if S.Enabled and dist <= S.MaxDistance then
                local center = cf.Position
                local corner = center + Vector3.new(size.X / 2, size.Y / 2, size.Z / 2)
                local topLeft = cam:WorldToViewportPoint(center + Vector3.new(-size.X / 2, size.Y / 2, 0))
                local topRight = cam:WorldToViewportPoint(center + Vector3.new(size.X / 2, size.Y / 2, 0))
                local bottomLeft = cam:WorldToViewportPoint(center + Vector3.new(-size.X / 2, -size.Y / 2, 0))

                local screenCenter, onScreen = cam:WorldToViewportPoint(center)
                if onScreen then
                    local w = math.abs(topRight.X - topLeft.X)
                    local h = math.abs(bottomLeft.Y - topLeft.Y)
                    local x = topLeft.X
                    local y = topLeft.Y
                    local color = colorFor(model.Name)

                    entry.box.Visible = true
                    entry.box.Color = color
                    entry.box.Position = Vector2.new(x, y)
                    entry.box.Size = Vector2.new(math.max(w, 2), math.max(h, 2))

                    entry.text.Visible = true
                    entry.text.Color = color
                    entry.text.Position = Vector2.new(x + w / 2, y - 14)
                    entry.text.Text = string.format("%s [%d]", model.Name, math.floor(dist))
                else
                    entry.box.Visible = false
                    entry.text.Visible = false
                end
            else
                entry.box.Visible = false
                entry.text.Visible = false
            end
        end
    end

    for model, entry in pairs(entries) do
        if not seen[model] then
            freeEntry(entry)
            entries[model] = nil
        end
    end
end

local conn = RunService.RenderStepped:Connect(function()
    local ok, err = pcall(update)
    if not ok then
        warn("[4080] esp: " .. tostring(err))
    end
end)

local inputConn = UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        S.Enabled = not S.Enabled
        if not S.Enabled then
            for _, e in pairs(entries) do
                e.box.Visible = false
                e.text.Visible = false
            end
        end
        print("[4080] esp " .. (S.Enabled and "on" or "off"))
    elseif input.KeyCode == Enum.KeyCode.F2 then
        S.HighlightIndex = S.HighlightIndex % #S.Names + 1
        S.Highlight = S.Names[S.HighlightIndex]
        print("[4080] highlight: " .. S.Highlight)
    end
end)

getgenv().__esp4080 = {
    State = S,
    destroy = function()
        pcall(function() conn:Disconnect() end)
        pcall(function() inputConn:Disconnect() end)
        for _, e in pairs(entries) do freeEntry(e) end
        entries = {}
        getgenv().__esp4080 = nil
    end,
}

print("[4080] esp ready · F1 toggle · F2 highlight")
return getgenv().__esp4080
