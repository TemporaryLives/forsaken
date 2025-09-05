--==============================================================
-- YAFS — PART 1: Notifications + Generator Tab
--==============================================================

--// Rayfield Setup (UI framework only; we DO NOT use Rayfield:Notify)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--==============================================================
-- Notification System (Left stack, subtle grey bg, white outline)
--==============================================================
do
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local notifGui = playerGui:FindFirstChild("NotificationGui") or Instance.new("ScreenGui")
    notifGui.Name = "NotificationGui"
    notifGui.ResetOnSpawn = false
    notifGui.IgnoreGuiInset = true
    notifGui.Parent = playerGui

    local holder = notifGui:FindFirstChild("NotificationHolder")
    if not holder then
        holder = Instance.new("Frame")
        holder.Name = "NotificationHolder"
        holder.AnchorPoint = Vector2.new(0, 0)
        holder.Position = UDim2.new(0, 20, 0, 60) -- left stack
        holder.Size = UDim2.new(0, 320, 1, -60)
        holder.BackgroundTransparency = 1
        holder.Parent = notifGui

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Parent = holder
    end

    local notifWidth, notifHeight = 300, 78

    local function FadeContents(frame, targetTransparency, time, bgTarget)
        for _, obj in ipairs(frame:GetDescendants()) do
            if obj:IsA("TextLabel") then
                TweenService:Create(obj, TweenInfo.new(time), {TextTransparency = targetTransparency}):Play()
            elseif obj:IsA("ImageLabel") then
                TweenService:Create(obj, TweenInfo.new(time), {ImageTransparency = targetTransparency}):Play()
            end
        end
        TweenService:Create(frame, TweenInfo.new(time), {BackgroundTransparency = bgTarget}):Play()
    end

    _G.CreateNotification = function(titleText, descText, iconId, duration)
        duration = duration or 3

        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, notifWidth, 0, notifHeight)
        notif.BackgroundColor3 = Color3.fromRGB(28, 28, 34) -- subtle grey (not pure black)
        notif.BackgroundTransparency = 1 -- start hidden
        notif.Position = UDim2.new(0, -notifWidth, 0, 0) -- slide in from left
        notif.Parent = holder
        notif.LayoutOrder = math.floor(os.clock() * 1000)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = notif

        -- thin white outline (Rayfield vibe)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 1
        stroke.Transparency = 0.6
        stroke.Parent = notif

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Position = UDim2.new(0, 12, 0.5, -20)
        icon.BackgroundTransparency = 1
        icon.ImageTransparency = 1
        icon.Image = iconId and ("rbxassetid://" .. tostring(iconId)) or ""
        icon.Parent = notif

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -64, 0, 22)
        title.Position = UDim2.new(0, 64, 0, 10)
        title.BackgroundTransparency = 1
        title.TextTransparency = 1
        title.Text = titleText or "Notification"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 16
        title.Font = Enum.Font.SourceSansBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = notif

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -64, 0, 36)
        desc.Position = UDim2.new(0, 64, 0, 34)
        desc.BackgroundTransparency = 1
        desc.TextTransparency = 1
        desc.Text = descText or ""
        desc.TextColor3 = Color3.fromRGB(220, 220, 220)
        desc.TextSize = 14
        desc.Font = Enum.Font.SourceSans
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextYAlignment = Enum.TextYAlignment.Top
        desc.TextWrapped = true
        desc.Parent = notif

        TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 0, 0, notif.Position.Y.Offset)}
        ):Play()
        FadeContents(notif, 0, 0.4, 0.15) -- background to slight visible

        task.delay(duration, function()
            if notif.Parent then
                TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    {Position = UDim2.new(0, -notifWidth, 0, notif.Position.Y.Offset)}
                ):Play()
                FadeContents(notif, 1, 0.3, 1) -- fade out
                task.delay(0.3, function()
                    if notif.Parent then notif:Destroy() end
                end)
            end
        end)
    end
end

--==============================================================
-- Helpers (safe map access)
--==============================================================
local function getIngame()
    local Map = workspace:FindFirstChild("Map")
    if not Map then return nil end
    local Ingame = Map:FindFirstChild("Ingame")
    return Ingame
end

local function getMapFolder()
    local Ingame = getIngame()
    if not Ingame then return nil end
    return Ingame:FindFirstChild("Map")
end

--==============================================================
-- Window + Tabs
--==============================================================
local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    LoadingTitle = "Loading the script...",
    LoadingSubtitle = "💫",
    ConfigurationSaving = { Enabled = false }
})

local GeneratorTab = Window:CreateTab("Generator", 4483362458)

--==============================================================
-- Generator: Auto-Repair (closest ≤ 5 studs) + cooldown input
--==============================================================
local FixingLoopAnimations = {
    Center = "rbxassetid://82691533602949",
    Left   = "rbxassetid://122604262087779",
    Right  = "rbxassetid://130355934640695"
}

local RANGE = 5 -- per your spec
local MIN_COOLDOWN, MAX_COOLDOWN, DEFAULT_COOLDOWN = 2.4, 6, 3.1
local cooldown = DEFAULT_COOLDOWN
local lastFire = 0
local autoEnabled = false
local notifiedFakes = {}

-- expose on the UI: show the live cooldown next to name
local cooldownInputRef -- to rename control label on change

local function isFixing()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        for _, animId in pairs(FixingLoopAnimations) do
            if track.Animation and track.Animation.AnimationId == animId then
                return true
            end
        end
    end
    return false
end

local function getClosestGenerator()
    local map = getMapFolder()
    if not map then return nil end

    local best, bestDist
    for _, obj in ipairs(map:GetChildren()) do
        if (obj.Name == "Generator" or obj.Name == "FakeGenerator") and obj:FindFirstChild("Remotes") then
            local prog = obj:FindFirstChild("Progress")
            local remote = obj.Remotes:FindFirstChild("RE")
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if prog and remote and part and tonumber(prog.Value) and prog.Value < 100 then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d <= RANGE and (not bestDist or d < bestDist) then
                        best = {obj = obj, remote = remote, prog = prog, part = part}
                        bestDist = d
                    end
                end
            end
        end
    end
    return best
end

local function tryFire(genPack)
    if not genPack then return end
    if not isFixing() then return end

    -- Fake generator warning once per object
    if genPack.obj.Name == "FakeGenerator" then
        if not notifiedFakes[genPack.obj] then
            notifiedFakes[genPack.obj] = true
            _G.CreateNotification("Fake Generator", "This generator is fake.", 6031280882, 3.5)
        end
        return
    end

    local now = tick()
    if now - lastFire < MIN_COOLDOWN then
        _G.CreateNotification("Too Fast", "Slow down — minimum interval is " .. tostring(MIN_COOLDOWN) .. "s.", 6031280882, 3)
        return
    end
    if now - lastFire < cooldown then
        -- respect user cooldown setting
        return
    end

    genPack.remote:FireServer()
    lastFire = now
end

-- UI
GeneratorTab:CreateToggle({
    Name = "Auto-Repair Generators (≤5 studs)",
    CurrentValue = false,
    Callback = function(on)
        autoEnabled = on
        _G.CreateNotification(on and "Auto-Repair: ON" or "Auto-Repair: OFF",
            "Cooldown: " .. tostring(cooldown) .. "s", 6031068420, 2)
    end
})

cooldownInputRef = GeneratorTab:CreateInput({
    Name = ("Cooldown: %0.1fs (min %.1f / max %.1f)"):format(cooldown, MIN_COOLDOWN, MAX_COOLDOWN),
    PlaceholderText = tostring(cooldown),
    RemoveTextAfterFocusLost = false,
    Callback = function(txt)
        local n = tonumber(txt)
        if n then
            cooldown = math.clamp(n, MIN_COOLDOWN, MAX_COOLDOWN)
            -- Rayfield input controls accept Set() in some builds; if not, renaming still works
            cooldownInputRef:Set(("%0.1f"):format(cooldown))
            cooldownInputRef.Settings.Name = ("Cooldown: %0.1fs (min %.1f / max %.1f)"):format(cooldown, MIN_COOLDOWN, MAX_COOLDOWN)
            _G.CreateNotification("Cooldown Updated", ("Now %0.1fs"):format(cooldown), 6031068420, 2)
        else
            _G.CreateNotification("Invalid Number", "Enter a numeric value.", 6031280882, 2)
        end
    end
})

GeneratorTab:CreateButton({
    Name = "Manual Fire Repair",
    Callback = function()
        local g = getClosestGenerator()
        if g then
            tryFire(g)
        else
            _G.CreateNotification("No Generator Nearby", "Stand within 5 studs of a generator < 100%.", 6031280882, 3)
        end
    end
})

-- Auto loop
RunService.Heartbeat:Connect(function()
    if not autoEnabled then return end
    local g = getClosestGenerator()
    if g then tryFire(g) end
end)

--==============================================================
-- YAFS — PART 2: ESP, Player, Misc
--==============================================================

-- Assumes Rayfield Window already created in Part 1
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Reuse helpers from Part 1 if this file is standalone.
local function getIngame()
    local Map = workspace:FindFirstChild("Map")
    if not Map then return nil end
    return Map:FindFirstChild("Ingame")
end
local function getMapFolder()
    local Ingame = getIngame()
    return Ingame and Ingame:FindFirstChild("Map") or nil
end

--==============================================================
-- ESP Tab
--==============================================================
local ESPTab = Rayfield:CreateTab("ESP", 4483362458)

local Colors = {
    TextSurvivor = Color3.fromRGB(255,191,0),
    TextKiller = Color3.fromRGB(255,0,0),
    HighlightSurvivor = Color3.fromRGB(255,191,0),
    HighlightKiller = Color3.fromRGB(255,0,0),
    HighlightConsumables = Color3.fromRGB(255,106,180),
    HighlightDeployables = Color3.fromRGB(191,255,191),
    HighlightGenerator = Color3.fromRGB(255,255,255),
    HighlightFakeGenerator = Color3.fromRGB(128,0,128),
    HighlightDigitalFootprints = Color3.fromRGB(0,255,255)
}

local ESPStates = {
    TextESP = false,
    HighlightPlayers = false,
    Consumables = false,
    Deployables = false,
    Generators = false,
    FakeGenerators = false,
    DigitalFootprints = false
}

-- bookkeeping to prevent leaks
local trackedConnections = {} -- [Instance] = {conn, conn,...}
local function trackConn(obj, conn)
    trackedConnections[obj] = trackedConnections[obj] or {}
    table.insert(trackedConnections[obj], conn)
end
local function clearTracked(obj)
    if trackedConnections[obj] then
        for _,c in ipairs(trackedConnections[obj]) do
            if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
        end
        trackedConnections[obj] = nil
    end
end

-- destroy helpers (only ours)
local function destroyChildrenByName(parent, name)
    for _,v in ipairs(parent:GetChildren()) do
        if v.Name == name then v:Destroy() end
    end
end

--==============================================================
-- ESP: Billboard Text (AccanthisADFStd via Enum.Font.Bodoni)
--==============================================================
local function createTextESP(character, textColor)
    if not character or character == LocalPlayer.Character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- update/replace to avoid dupes
    destroyChildrenByName(character, "RayESPText")

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RayESPText"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0) -- higher
    billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = textColor
    label.Font = Enum.Font.Bodoni -- AccanthisADFStd-Regular
    label.TextSize = 18
    label.Text = character.Name
    label.Parent = billboard

    billboard.Parent = character
end

--==============================================================
-- ESP: Highlight with aura awareness
--   - Players: respect PlayerAura; when it becomes "goodbai" and dies, add ours
--   - Deployables: co-exist (always add ours)
--==============================================================
local function addOurHighlight(obj, color)
    if not obj:FindFirstChild("RayHighlight") then
        local h = Instance.new("Highlight")
        h.Name = "RayHighlight"
        h.Adornee = obj
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor = color
        h.FillTransparency = 0.5
        h.OutlineColor = color
        h.OutlineTransparency = 0
        h.Parent = obj
    end
end

local function createHighlight(obj, fillColor, isDeployable, stateKey)
    if not obj or obj == LocalPlayer.Character then return end

    -- if toggle turned off during wait, bail early
    if stateKey and not ESPStates[stateKey] then return end

    if isDeployable then
        -- Deployables: keep game aura and add ours too
        addOurHighlight(obj, fillColor)
        return
    end

    -- Players: respect aura
    local existing = obj:FindFirstChildOfClass("Highlight")
    if existing then
        if existing.Name == "PlayerAura" then
            -- wait for it to rename to "goodbai" then die
            local renameConn = existing:GetPropertyChangedSignal("Name"):Connect(function()
                if existing.Name == "goodbai" then
                    local dyingConn
                    dyingConn = existing.Destroying:Connect(function()
                        if stateKey and ESPStates[stateKey] then
                            addOurHighlight(obj, fillColor)
                        end
                        if dyingConn then dyingConn:Disconnect() end
                    end)
                end
            end)
            trackConn(obj, renameConn)
            return
        elseif existing.Name == "goodbai" then
            local dyingConn
            dyingConn = existing.Destroying:Connect(function()
                if stateKey and ESPStates[stateKey] then
                    addOurHighlight(obj, fillColor)
                end
                if dyingConn then dyingConn:Disconnect() end
            end)
            trackConn(obj, dyingConn)
            return
        end
    end

    addOurHighlight(obj, fillColor)
end

--==============================================================
-- Apply / Clear ESP
--==============================================================
local function clearESP_All()
    -- remove all our highlights and billboards across known folders
    local Ingame = getIngame()
    if Ingame then
        for _,desc in ipairs(Ingame:GetDescendants()) do
            if desc.Name == "RayHighlight" and desc:IsA("Highlight") then
                desc:Destroy()
            elseif desc.Name == "RayESPText" and desc:IsA("BillboardGui") then
                desc:Destroy()
            end
        end
    end
    -- also clear on player characters
    for _,plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            destroyChildrenByName(char, "RayHighlight")
            destroyChildrenByName(char, "RayESPText")
        end
    end
    -- kill connections
    for obj,_ in pairs(trackedConnections) do
        clearTracked(obj)
    end
end

local function applyESP()
    local map = getMapFolder()
    local Ingame = getIngame()
    if not Ingame then return end

    -- Players (Survivors/Killers folders are under workspace.Players)
    local wPlayers = workspace:FindFirstChild("Players")
    if wPlayers then
        local Survivors = wPlayers:FindFirstChild("Survivors")
        local Killers   = wPlayers:FindFirstChild("Killers")

        if Survivors then
            for _,char in ipairs(Survivors:GetChildren()) do
                if ESPStates.TextESP then
                    createTextESP(char, Colors.TextSurvivor)
                end
                if ESPStates.HighlightPlayers then
                    createHighlight(char, Colors.HighlightSurvivor, false, "HighlightPlayers")
                end
            end
        end
        if Killers then
            for _,char in ipairs(Killers:GetChildren()) do
                if ESPStates.TextESP then
                    createTextESP(char, Colors.TextKiller)
                end
                if ESPStates.HighlightPlayers then
                    createHighlight(char, Colors.HighlightKiller, false, "HighlightPlayers")
                end
            end
        end
    end

    if map then
        if ESPStates.Generators then
            for _,gen in ipairs(map:GetChildren()) do
                if gen.Name == "Generator" then
                    local prog = gen:FindFirstChild("Progress")
                    if prog and tonumber(prog.Value) and prog.Value < 100 then
                        createHighlight(gen, Colors.HighlightGenerator, true, "Generators") -- allow coexist for world objs
                    end
                end
            end
        end
        if ESPStates.FakeGenerators then
            for _,fg in ipairs(map:GetChildren()) do
                if fg.Name == "FakeGenerator" then
                    createHighlight(fg, Colors.HighlightFakeGenerator, true, "FakeGenerators")
                end
            end
        end
        if ESPStates.Consumables then
            for _,item in ipairs(map:GetChildren()) do
                if item.Name=="Medkit" or item.Name=="BloxyCola" then
                    createHighlight(item, Colors.HighlightConsumables, true, "Consumables")
                end
            end
        end
        if ESPStates.Deployables then
            for _,item in ipairs(map:GetChildren()) do
                if item.Name=="BuildermanSentry"
                or item.Name=="BuildermanDispenser"
                or string.find(item.Name,"TaphTripwire")
                or item.Name=="SubspaceTripmine" then
                    createHighlight(item, Colors.HighlightDeployables, true, "Deployables")
                end
            end
        end
    end

    if ESPStates.DigitalFootprints then
        for _,folder in ipairs(Ingame:GetChildren()) do
            if string.find(folder.Name, "Shadows") then
                for _,shadow in ipairs(folder:GetChildren()) do
                    if shadow:IsA("BasePart") or shadow:IsA("Model") then
                        -- store and force visible
                        if shadow:IsA("BasePart") then
                            if shadow:GetAttribute("Ray_OrigTrans") == nil then
                                shadow:SetAttribute("Ray_OrigTrans", shadow.Transparency)
                            end
                            shadow.Transparency = 0
                        end
                        createHighlight(shadow, Colors.HighlightDigitalFootprints, true, "DigitalFootprints")
                    end
                end
                -- watch for new shadows
                local c = folder.ChildAdded:Connect(function(shadow)
                    if ESPStates.DigitalFootprints then
                        task.wait()
                        if shadow:IsA("BasePart") then
                            if shadow:GetAttribute("Ray_OrigTrans") == nil then
                                shadow:SetAttribute("Ray_OrigTrans", shadow.Transparency)
                            end
                            shadow.Transparency = 0
                        end
                        createHighlight(shadow, Colors.HighlightDigitalFootprints, true, "DigitalFootprints")
                    end
                end)
                trackConn(folder, c)
            end
        end
    end
end

-- Reapply when relevant folders spawn (safe; no errors if missing)
local function hookRespawns()
    -- Map/Ingame
    local Map = workspace:FindFirstChild("Map")
    if Map then
        local c1 = Map.ChildAdded:Connect(function(child)
            if child.Name == "Ingame" then
                task.wait(1)
                applyESP()
            end
        end)
        trackConn(Map, c1)
    end
    -- Players folders
    local wPlayers = workspace:FindFirstChild("Players")
    if wPlayers then
        local surv = wPlayers:FindFirstChild("Survivors")
        local kil  = wPlayers:FindFirstChild("Killers")
        if surv then
            local c2 = surv.ChildAdded:Connect(function() task.wait(0.2); applyESP() end)
            trackConn(surv, c2)
        end
        if kil then
            local c3 = kil.ChildAdded:Connect(function() task.wait(0.2); applyESP() end)
            trackConn(kil, c3)
        end
    end
end
hookRespawns()

--==============================================================
-- ESP Toggles
--==============================================================
ESPTab:CreateToggle({
    Name = "Show ESP (Text over players)",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.TextESP = state
        if not state then
            -- remove only our text
            for _,plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char then destroyChildrenByName(char, "RayESPText") end
            end
        else
            applyESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Highlight Players",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.HighlightPlayers = state
        if not state then
            -- remove only our highlights from characters
            for _,plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char then destroyChildrenByName(char, "RayHighlight") end
            end
        else
            applyESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Consumables",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.Consumables = state
        if not state then
            local map = getMapFolder()
            if map then
                for _,obj in ipairs(map:GetDescendants()) do
                    if obj.Name == "RayHighlight" and obj:IsA("Highlight") then obj:Destroy() end
                end
            end
        else
            applyESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Survivor Deployables",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.Deployables = state
        if not state then
            local map = getMapFolder()
            if map then
                for _,obj in ipairs(map:GetDescendants()) do
                    if obj.Name == "RayHighlight" and obj:IsA("Highlight") then obj:Destroy() end
                end
            end
        else
            applyESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Generators (< 100%)",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.Generators = state
        if not state then
            local map = getMapFolder()
            if map then
                for _,obj in ipairs(map:GetDescendants()) do
                    if obj.Name == "RayHighlight" and obj:IsA("Highlight") then obj:Destroy() end
                end
            end
        else
            applyESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Fake Generators",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.FakeGenerators = state
        if not state then
            local map = getMapFolder()
            if map then
                for _,obj in ipairs(map:GetDescendants()) do
                    if obj.Name == "RayHighlight" and obj:IsA("Highlight") then obj:Destroy() end
                end
            end
        else
            applyESP()
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Digital Footprints",
    CurrentValue = false,
    Callback = function(state)
        ESPStates.DigitalFootprints = state
        if not state then
            -- remove highlights and restore transparency if we saved it
            local Ingame = getIngame()
            if Ingame then
                for _,folder in ipairs(Ingame:GetChildren()) do
                    if string.find(folder.Name, "Shadows") then
                        for _,shadow in ipairs(folder:GetChildren()) do
                            if shadow:IsA("BasePart") then
                                local orig = shadow:GetAttribute("Ray_OrigTrans")
                                if orig ~= nil then
                                    shadow.Transparency = orig
                                    shadow:SetAttribute("Ray_OrigTrans", nil)
                                end
                            end
                            destroyChildrenByName(shadow, "RayHighlight")
                        end
                    end
                end
            end
        else
            applyESP()
        end
    end
})

--==============================================================
-- Player Tab (same behavior; clean)
--==============================================================
local PlayerTab = Rayfield:CreateTab("Player", 4483362458)
local Sprinting = require(game:GetService("ReplicatedStorage").Systems.Character.Game.Sprinting)

local InfiniteEnabled = false
PlayerTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(state)
        InfiniteEnabled = state
        Sprinting.StaminaLossDisabled = state
        if state then
            Sprinting.SprintSpeed = 24
        end
        _G.CreateNotification("Infinite Stamina", state and "Enabled" or "Disabled", 6031068420, 2)
    end
})

local CustomEnabled = false
local StaminaGain, StaminaLoss, SprintSpeed = 20, 10, 24

PlayerTab:CreateToggle({
    Name = "Custom Stamina",
    CurrentValue = false,
    Callback = function(state)
        CustomEnabled = state
        Sprinting.StaminaLossDisabled = not state
        if state then
            Sprinting.StaminaGain = StaminaGain
            Sprinting.StaminaLoss = StaminaLoss
            Sprinting.SprintSpeed = SprintSpeed
        end
        _G.CreateNotification("Custom Stamina", state and "Enabled" or "Disabled", 6031068420, 2)
    end
})

PlayerTab:CreateInput({Name="Stamina Gain", PlaceholderText=tostring(StaminaGain), RemoveTextAfterFocusLost=false, Callback=function(val)
    local num = tonumber(val)
    if num then StaminaGain=num; if CustomEnabled then Sprinting.StaminaGain=StaminaGain end end
end})

PlayerTab:CreateInput({Name="Stamina Loss", PlaceholderText=tostring(StaminaLoss), RemoveTextAfterFocusLost=false, Callback=function(val)
    local num = tonumber(val)
    if num then StaminaLoss=num; if CustomEnabled then Sprinting.StaminaLoss=StaminaLoss end end
end})

PlayerTab:CreateInput({Name="Sprint Speed", PlaceholderText=tostring(SprintSpeed), RemoveTextAfterFocusLost=false, Callback=function(val)
    local num = tonumber(val)
    if num then SprintSpeed=num; if CustomEnabled then Sprinting.SprintSpeed=SprintSpeed end end
end})

--==============================================================
-- Misc Tab
--==============================================================
local MiscTab = Rayfield:CreateTab("Misc", 4483362458)

-- Round Timer Adjuster
do
    local pgui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local rt = pgui:FindFirstChild("RoundTimer")
        if rt and rt:FindFirstChild("Main") then
            local RoundTimerMain = rt.Main
            MiscTab:CreateButton({
                Name = "Reset Round Timer",
                Callback = function()
                    RoundTimerMain.Position = UDim2.new(0.5,0,-0.18,0)
                end
            })
        end
    end
end

-- Block Subspaced Effects
MiscTab:CreateToggle({
    Name = "Block Subspaced Effects",
    CurrentValue = false,
    Callback = function(state)
        local subspaced = game:GetService("ReplicatedStorage").Modules.StatusEffects.SurvivorExclusive
        if subspaced:FindFirstChild("Subspaced") then
            subspaced.Subspaced.Name = state and "SubzeroSpaced" or "Subspaced"
        end
        _G.CreateNotification("Subspaced Effects", state and "Blocked" or "Restored", 6031068420, 2)
    end
})

-- c00lgui Tracker (safe map access + notifications)
do
    local trackerEnabled = false
    local cooldownTime = 30
    local lastTrigger = {}
    local activeC00lParts = {}

    local function notify(title, content)
        _G.CreateNotification(title, content, 6031068420, 4)
    end

    local function trackPlayer(model)
        local player = Players:GetPlayerFromCharacter(model)
        if not player then return end
        local function setupC00lListener(c00l)
            if not c00l then return end
            if lastTrigger[player] and (tick()-lastTrigger[player])<cooldownTime then return end
            lastTrigger[player] = tick()
            notify("c00lgui Tracker", "@"..player.Name.." is using c00lgui.")
            activeC00lParts[player] = c00l
        end
        local existing = model:FindFirstChild("c00lgui")
        if existing then setupC00lListener(existing) end
        local c = model.ChildAdded:Connect(function(child)
            if child.Name=="c00lgui" then setupC00lListener(child) end
        end)
        trackConn(model, c)
    end

    RunService.Heartbeat:Connect(function()
        for player,c00l in pairs(activeC00lParts) do
            local model=player.Character
            if not model or not c00l or not c00l:IsDescendantOf(model) then
                local hrp=model and model:FindFirstChild("HumanoidRootPart")
                local teleported=false
                if hrp then
                    local map = getMapFolder()
                    local spawns = map and map:FindFirstChild("SpawnPoints")
                    spawns = spawns and spawns:FindFirstChild("Survivors")
                    spawns = spawns and spawns:GetChildren() or {}
                    for _,spawn in ipairs(spawns) do
                        if spawn.Name=="SurvivorSpawn" and (hrp.Position-spawn.Position).Magnitude<=25 then
                            teleported=true
                            break
                        end
                    end
                end
                if teleported then
                    notify("c00lgui Tracker","@"..player.Name.." has successfully teleported.")
                else
                    notify("c00lgui Tracker","@"..player.Name.."'s c00lgui has been cancelled.")
                end
                activeC00lParts[player]=nil
            end
        end
    end)

    local function startTracker()
        local wPlayers = workspace:FindFirstChild("Players")
        local survivorsFolder = wPlayers and wPlayers:FindFirstChild("Survivors")
        if survivorsFolder then
            for _,model in ipairs(survivorsFolder:GetChildren()) do
                if model.Name=="007n7" then trackPlayer(model) end
            end
            local c = survivorsFolder.ChildAdded:Connect(function(model)
                if model.Name=="007n7" then trackPlayer(model) end
            end)
            trackConn(survivorsFolder, c)
        end
    end

    MiscTab:CreateToggle({
        Name="c00lgui Tracker",
        CurrentValue=false,
        Callback=function(state)
            trackerEnabled=state
            if trackerEnabled then startTracker() end
            _G.CreateNotification("c00lgui Tracker", state and "Enabled" or "Disabled", 6031068420, 2)
        end
    })
end

--==============================================================
-- Final: Light reapply on round changes
--==============================================================
local function softReapplyLoop()
    -- periodically try to reapply lightweight ESP when toggles are on,
    -- without spamming or heavy loops
    local last = 0
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - last >= 1.0 then
            last = now
            if ESPStates.TextESP or ESPStates.HighlightPlayers or ESPStates.Generators
               or ESPStates.FakeGenerators or ESPStates.Consumables
               or ESPStates.Deployables or ESPStates.DigitalFootprints then
                applyESP()
            end
        end
    end)
end
softReapplyLoop()
