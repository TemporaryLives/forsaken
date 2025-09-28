--========================================
-- Rayfield setup + helpers
--========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- try Rayfield load safely
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not ok or not Rayfield then
    warn("Rayfield failed to load. GUI will not work.")
    return
end

-- Main window
local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    Icon = 92999214922543,
    LoadingTitle = "Loading the script...",
    LoadingSubtitle = "💫",
    ShowText = "Menu",
    ConfigurationSaving = { Enabled = false }
})

-- Tabs with your icons
local GeneratorTab = Window:CreateTab("Generator Tab", 96559240692119)
local ESPTab       = Window:CreateTab("ESP Tab", 114055269167425)
local PlayerTab    = Window:CreateTab("Player Tab", 89251076279188)
local MiscTab      = Window:CreateTab("Misc Tab", 72612560514066)

-- Helpers
local function destroyChildrenByName(obj, name)
    if not obj then return end
    for _, child in ipairs(obj:GetChildren()) do
        if child.Name == name then
            child:Destroy()
        end
    end
end

local function getMap()
    local root = workspace:FindFirstChild("Map")
    if not root then return nil end
    local ingame = root:FindFirstChild("Ingame")
    if not ingame then return nil end
    return ingame:FindFirstChild("Map")
end

local function getClosestGenerator(maxDist)
    local map = getMap()
    if not map then return nil, math.huge end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, math.huge end

    local closest, dist = nil, maxDist or 12
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and obj:FindFirstChild("Remotes") and obj:FindFirstChild("Progress") then
            local main = obj:FindFirstChild("Main") or obj:FindFirstChild("Root") or obj:FindFirstChild("Base")
            if main and main:IsA("BasePart") then
                local d = (hrp.Position - main.Position).Magnitude
                if d < dist then
                    closest, dist = obj, d
                end
            end
        end
    end
    return closest, dist
end

--========================================
-- Generator Tab
--========================================
local autoRepair = false
local repairCooldown = 6.2
local lastRepair = 0
local lastManual = 0

-- repair animation ids
local _REPAIR_ANIMS = {
    ["rbxassetid://82691533602949"]  = true,
    ["rbxassetid://122604262087779"] = true,
    ["rbxassetid://130355934640695"] = true,
}

local function isRepairing()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation and _REPAIR_ANIMS[tostring(track.Animation.AnimationId)] then
                return true
            end
        end
    end
    return false
end

GeneratorTab:CreateToggle({
    Name = "Auto-Repair Generators",
    CurrentValue = false,
    Callback = function(v) autoRepair = v end
})

GeneratorTab:CreateInput({
    Name = "Repair Cooldown (2.4 - 15) (auto)",
    PlaceholderText = tostring(repairCooldown),
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        local num = tonumber(val)
        if num and num >= 2.4 and num <= 15 then
            repairCooldown = num
            Rayfield:Notify({Title="Generator", Content="Auto-repair cooldown set to "..num, Duration=1.4})
        else
            Rayfield:Notify({Title="Generator", Content="Value must be 2.4 - 15", Duration=1.6})
        end
    end
})

GeneratorTab:CreateButton({
    Name = "Manual Repair Fire (hard min 2.4s)",
    Callback = function()
        local now = tick()
        if now - lastManual < 2.4 then
            Rayfield:Notify({Title="Generator", Content="Minimum 2.4s between manual fires!", Duration=1.5})
            return
        end

        local gen, dist = getClosestGenerator(12)
        if not gen then
            Rayfield:Notify({Title="Generator", Content="No generator found nearby.", Duration=1.6})
            return
        end

        local re = gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")
        if re then
            local ok, err = pcall(function() re:FireServer() end)
            if ok then
                lastManual = now
                Rayfield:Notify({Title="Generator", Content="Manual repair fired ("..math.floor(dist).." studs).", Duration=1.4})
            else
                Rayfield:Notify({Title="Generator", Content="Failed: "..tostring(err), Duration=2.2})
            end
        else
            Rayfield:Notify({Title="Generator", Content="Generator RE remote not found.", Duration=1.6})
        end
    end
})

task.spawn(function()
    while true do
        task.wait(0.2)
        if autoRepair and isRepairing() then
            local now = tick()
            if now - lastRepair >= repairCooldown then
                local gen, _ = getClosestGenerator(12)
                if gen and gen:FindFirstChild("Remotes") then
                    local re = gen.Remotes:FindFirstChild("RE")
                    if re then
                        pcall(function() re:FireServer() end)
                        lastRepair = now
                    end
                end
            end
        else
            lastRepair = tick()
        end
    end
end)
--========================================
-- ESP Tab (full)
--========================================
-- Uses ESPTab from setup block

local Colors = {
    SurvivorText   = Color3.fromRGB(255,191,0),
    KillerText     = Color3.fromRGB(255,0,0),
    SurvivorAura   = Color3.fromRGB(255,191,0),
    KillerAura     = Color3.fromRGB(255,0,0),
    Consumables    = Color3.fromRGB(0,200,255),
    Deployables    = Color3.fromRGB(255,165,0),
    Generator      = Color3.fromRGB(0,200,0),
    FakeGenerator  = Color3.fromRGB(128,0,128),
    Footprints     = Color3.fromRGB(0,255,255)
}

local ESPStates = {
    Text = false,
    Extra = false,          -- extra info (username + HP)
    AuraPlayers = false,    -- chams/highlight on players
    Consumables = false,
    Deployables = false,
    Generators = false,
    FakeGenerators = false,
    Footprints = false
}

-- caches to avoid recreating UI every loop
local playerESPCache = {}    -- [character] = {Billboard, MainLabel, ExtraLabel}
local highlightCache = {}    -- [instance] = Highlight

local function safeDestroy(obj)
    if obj and obj.Parent then
        pcall(function() obj:Destroy() end)
    end
end

local function createHighlight(adorned, color)
    if not adorned or not adorned:IsDescendantOf(workspace) then return end
    -- remove existing highlight first
    if highlightCache[adorned] then
        safeDestroy(highlightCache[adorned])
        highlightCache[adorned] = nil
    end
    local h = Instance.new("Highlight")
    h.Name = "Aura"
    h.Adornee = adorned
    h.FillColor = color
    h.FillTransparency = 0.5
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.Parent = adorned
    highlightCache[adorned] = h
    return h
end

local function removeHighlight(adorned)
    if not adorned then return end
    destroyChildrenByName(adorned, "Aura")
    highlightCache[adorned] = nil
end

-- Player ESP
local function createPlayerESP(character)
    if not character or playerESPCache[character] then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPGui"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 4.5, 0)
    billboard.Parent = character

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    layout.Parent = billboard

    local mainLabel = Instance.new("TextLabel")
    mainLabel.Size = UDim2.new(1, 0, 0, 18)
    mainLabel.BackgroundTransparency = 1
    mainLabel.Font = Enum.Font.GothamBold
    mainLabel.TextSize = 16
    mainLabel.Text = character.Name
    mainLabel.Parent = billboard

    local extraLabel
    if ESPStates.Extra then
        extraLabel = Instance.new("TextLabel")
        extraLabel.Size = UDim2.new(1, 0, 0, 14)
        extraLabel.BackgroundTransparency = 1
        extraLabel.Font = Enum.Font.Gotham
        extraLabel.TextSize = 14
        extraLabel.Parent = billboard
        -- health update connector set below
    end

    -- store and connect health if needed
    playerESPCache[character] = {Billboard = billboard, MainLabel = mainLabel, ExtraLabel = extraLabel}
    if extraLabel then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            extraLabel.Text = "HP: "..math.floor(humanoid.Health)
            humanoid.HealthChanged:Connect(function(hp)
                if extraLabel and extraLabel.Parent then
                    extraLabel.Text = "HP: "..math.floor(hp)
                end
            end)
        end
    end
end

local function removePlayerESP(character)
    local data = playerESPCache[character]
    if data then
        safeDestroy(data.Billboard)
        playerESPCache[character] = nil
    end
    removeHighlight(character)
end

local function updatePlayerVisuals(character)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then removePlayerESP(character); return end

    -- If character moved to ragdoll folder -> remove ESP
    local ragdollFolder = workspace:FindFirstChild("Ragdolls")
    if ragdollFolder and ragdollFolder:FindFirstChild(character.Name) then
        removePlayerESP(character)
        return
    end

    -- create if needed
    if ESPStates.Text and not playerESPCache[character] then
        createPlayerESP(character)
    end

    -- update name color & extra info
    local cache = playerESPCache[character]
    local isKiller = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers") and workspace.Players.Killers:FindFirstChild(character.Name)
    local nameColor = isKiller and Colors.KillerText or Colors.SurvivorText
    if cache and cache.MainLabel then
        cache.MainLabel.TextColor3 = nameColor
    end

    -- chams / aura
    if ESPStates.AuraPlayers then
        local c = isKiller and Colors.KillerAura or Colors.SurvivorAura
        createHighlight(character, c)
    else
        removeHighlight(character)
    end

    -- ensure billboard visibility respects toggle and distance
    if cache and cache.Billboard then
        local cam = workspace.CurrentCamera
        if cam and cache.Billboard.Adornee and cache.Billboard.Adornee.Parent then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (cam.CFrame.Position - hrp.Position).Magnitude
                cache.Billboard.Enabled = ESPStates.Text and dist <= 700
                -- scale text size with distance
                for _, ui in ipairs(cache.Billboard:GetChildren()) do
                    if ui:IsA("TextLabel") then
                        local scale = math.clamp(18 - (dist * 0.02), 13, 18)
                        ui.TextSize = ui.TextSize > 14 and scale or math.clamp(scale - 2, 11, 14)
                    end
                end
            end
        end
    end
end

-- Map object highlights (generators, items)
local function updateMapObjects()
    local map = getMap()
    if not map then
        -- cleanup any cached highlights on map objects if map disappeared
        for obj, h in pairs(highlightCache) do
            if obj and obj:IsDescendantOf(workspace) == false then
                safeDestroy(h)
                highlightCache[obj] = nil
            end
        end
        return
    end

    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and ESPStates.Generators and obj:FindFirstChild("Progress") and obj.Progress.Value < 100 then
            createHighlight(obj, Colors.Generator)
        elseif obj.Name == "FakeGenerator" and ESPStates.FakeGenerators then
            createHighlight(obj, Colors.FakeGenerator)
        elseif (obj.Name == "Medkit" or obj.Name == "BloxyCola") and ESPStates.Consumables then
            createHighlight(obj, Colors.Consumables)
        elseif ESPStates.Deployables and (obj.Name == "BuildermanSentry" or obj.Name == "BuildermanDispenser" or (obj.Name and string.find(obj.Name, "TaphTripwire")) or obj.Name == "SubspaceTripmine") then
            createHighlight(obj, Colors.Deployables)
        else
            removeHighlight(obj)
        end
    end
end

-- Footprints (Shadows) handling
local function updateFootprints()
    local ingameRoot = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame")
    if not ingameRoot then return end
    for _, folder in ipairs(ingameRoot:GetChildren()) do
        if string.find(folder.Name or "", "Shadows") then
            for _, shadow in ipairs(folder:GetChildren()) do
                if shadow:IsA("BasePart") then
                    shadow.Transparency = 0
                    if ESPStates.Footprints then
                        createHighlight(shadow, Colors.Footprints)
                    else
                        removeHighlight(shadow)
                    end
                end
            end
        end
    end
end

-- main updater (not per-frame, less intensive)
task.spawn(function()
    while true do
        task.wait(0.6)
        -- go through survivors + killers
        local playersRoot = workspace:FindFirstChild("Players")
        if playersRoot then
            for _, folderName in ipairs({"Survivors", "Killers"}) do
                local folder = playersRoot:FindFirstChild(folderName)
                if folder then
                    for _, char in ipairs(folder:GetChildren()) do
                        updatePlayerVisuals(char)
                    end
                end
            end
        end

        -- cleanup stale entries
        for char, _ in pairs(playerESPCache) do
            if not char.Parent or not char:IsDescendantOf(workspace) then
                removePlayerESP(char)
            end
        end

        -- objects + footprints
        updateMapObjects()
        updateFootprints()
    end
end)

-- GUI toggles (ordering: Show ESP, Extra Info immediately under it)
ESPTab:CreateToggle({ Name = "Show ESP", CurrentValue = false, Callback = function(s) ESPStates.Text = s end })
ESPTab:CreateToggle({ Name = "Show Extra ESP Info", CurrentValue = false, Callback = function(s)
    ESPStates.Extra = s
    -- rebuild all player billboards to include/exclude ExtraLabel
    for char, _ in pairs(playerESPCache) do
        removePlayerESP(char)
    end
end })
ESPTab:CreateToggle({ Name = "Highlight Players", CurrentValue = false, Callback = function(s) ESPStates.AuraPlayers = s end })
ESPTab:CreateToggle({ Name = "Show Consumables", CurrentValue = false, Callback = function(s) ESPStates.Consumables = s end })
ESPTab:CreateToggle({ Name = "Show Deployables", CurrentValue = false, Callback = function(s) ESPStates.Deployables = s end })
ESPTab:CreateToggle({ Name = "Show Generators (<100)", CurrentValue = false, Callback = function(s) ESPStates.Generators = s end })
ESPTab:CreateToggle({ Name = "Show Fake Generators", CurrentValue = false, Callback = function(s) ESPStates.FakeGenerators = s end })
ESPTab:CreateToggle({ Name = "Show Digital Footprints", CurrentValue = false, Callback = function(s) ESPStates.Footprints = s end })

--========================================
-- Player Tab
--========================================
local function safeRequireSprinting()
    local ok, mod = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting"))
    end)
    return ok and mod or nil
end

local custom = false
local gain, loss, speed = 20, 10, 24

local function applyStaminaSettings()
    local m = safeRequireSprinting()
    if not m then
        Rayfield:Notify({Title="Player", Content="Sprinting module not available.", Duration=1.8})
        return
    end
    if custom then
        m.StaminaGain = gain
        m.StaminaLoss = loss
        m.SprintSpeed = speed
        m.StaminaLossDisabled = false
    else
        m.StaminaGain = 20
        m.StaminaLoss = 10
        m.SprintSpeed = 24
    end
end

PlayerTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(state)
        local m = safeRequireSprinting()
        if not m then
            Rayfield:Notify({Title="Player", Content="Sprinting module not ready.", Duration=1.5})
            return
        end
        if state then
            m.StaminaLossDisabled = true
            m.SprintSpeed = 24
        else
            m.StaminaLossDisabled = false
        end
    end
})

PlayerTab:CreateToggle({
    Name = "Custom Stamina",
    CurrentValue = false,
    Callback = function(state)
        custom = state
        applyStaminaSettings()
    end
})

PlayerTab:CreateInput({ Name = "Stamina Gain", PlaceholderText = tostring(gain), RemoveTextAfterFocusLost = false,
    Callback = function(v) local n = tonumber(v) if n then gain = n; if custom then applyStaminaSettings() end end })

PlayerTab:CreateInput({ Name = "Stamina Loss", PlaceholderText = tostring(loss), RemoveTextAfterFocusLost = false,
    Callback = function(v) local n = tonumber(v) if n then loss = n; if custom then applyStaminaSettings() end end })

PlayerTab:CreateInput({ Name = "Sprint Speed", PlaceholderText = tostring(speed), RemoveTextAfterFocusLost = false,
    Callback = function(v) local n = tonumber(v) if n then speed = n; if custom then applyStaminaSettings() end end })

--========================================
-- Misc Tab
--========================================

-- Disable Privated Stats (all players, client-side only)
MiscTab:CreateButton({
    Name = "Disable Privated Stats",
    Callback = function()
        for _, plr in ipairs(Players:GetPlayers()) do
            local priv = plr:FindFirstChild("PlayerData")
                and plr.PlayerData:FindFirstChild("Settings")
                and plr.PlayerData.Settings:FindFirstChild("Privacy")
            if priv then
                for _, child in ipairs(priv:GetChildren()) do
                    child:Destroy()
                end
            end
        end
        Rayfield:Notify({
            Title = "Disable Privated Stats",
            Content = "Who needed to hide their stats anyways.",
            Duration = 6.5,
            Image = 4483362458
        })
    end
})

-- Round Timer
local RoundTimer = ReplicatedStorage:WaitForChild("RoundTimer", 10)
if RoundTimer then
    MiscTab:CreateSlider({
        Name = "Set Round Timer",
        Range = {0, 900},
        Increment = 5,
        CurrentValue = RoundTimer.Value,
        Callback = function(val)
            RoundTimer.Value = val
        end
    })

    MiscTab:CreateButton({
        Name = "Reset Round Timer",
        Callback = function()
            RoundTimer.Value = 0
            Rayfield:Notify({
                Title = "Round Timer",
                Content = "Round timer reset.",
                Duration = 6.5,
                Image = 4483362458
            })
        end
    })
end

-- Block Subspaced Effects toggle
MiscTab:CreateToggle({
    Name = "Block Subspaced Effects",
    CurrentValue = false,
    Callback = function(state)
        local survivorExclusive = ReplicatedStorage:FindFirstChild("Modules")
            and ReplicatedStorage.Modules:FindFirstChild("StatusEffects")
            and ReplicatedStorage.Modules.StatusEffects:FindFirstChild("SurvivorExclusive")

        if not survivorExclusive then
            warn("SurvivorExclusive folder not found!")
            return
        end

        -- Always try to rename safely
        local subspace = survivorExclusive:FindFirstChild("Subspaced")
        local subzero = survivorExclusive:FindFirstChild("Subzerospaced")

        if state then
            -- If turning ON, rename Subspaced → Subzerospaced (but only if not already done)
            if subspace then
                subspace.Name = "Subzerospaced"
            end
        else
            -- If turning OFF, rename Subzerospaced → Subspaced (but only if not already done)
            if subzero then
                subzero.Name = "Subspaced"
            end
        end
    end
})
-- Block Subspaced Effects toggle
MiscTab:CreateToggle({
    Name = "Block New Glitched Effects",
    CurrentValue = false,
    Callback = function(state)
        local survivorExclusive = ReplicatedStorage:FindFirstChild("Modules")
            and ReplicatedStorage.Modules:FindFirstChild("StatusEffects")
            and ReplicatedStorage.Modules.StatusEffects:FindFirstChild("KillerExclusive")

        if not survivorExclusive then
            warn("SurvivorExclusive folder not found!")
            return
        end

        -- Always try to rename safely
        local subspace = survivorExclusive:FindFirstChild("Glitched")
        local subzero = survivorExclusive:FindFirstChild("IhateyounewGlitched")

        if state then
            -- If turning ON, rename Subspaced → Subzerospaced (but only if not already done)
            if subspace then
                subspace.Name = "IhateyounewGlitched"
            end
        else
            -- If turning OFF, rename Subzerospaced → Subspaced (but only if not already done)
            if subzero then
                subzero.Name = "Glitched"
            end
        end
    end
})