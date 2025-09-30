-- // Load Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Just Yet Another Forsaken Script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "[Galaxy] [Star]",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    }
})

local GenTab = Window:CreateTab("Generator")

--========================================
-- Helpers
--========================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
            -- skip fake generators
            if obj.Name ~= "Fake generator" then
                local main = obj:FindFirstChild("Generator") or obj:FindFirstChild("Root") or obj:FindFirstChild("Base")
                if main and main:IsA("BasePart") then
                    local d = (hrp.Position - main.Position).Magnitude
                    if d < dist then
                        closest, dist = obj, d
                    end
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

GenTab:CreateToggle({
    Name = "Auto-Repair Generators",
    CurrentValue = false,
    Callback = function(v) autoRepair = v end
})

GenTab:CreateInput({
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

GenTab:CreateButton({
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
-- ESP Tab
--========================================
local ESPTab = Window:CreateTab("ESP")

-- ESP State Management
local ESPState = {
    PlayerHighlights = false,
    PlayerESP = false,
    Items = false,
    Generators = false,
    FakeGenerators = false,
    SurvivorDeployables = false,
    KillerMinions = false,
    DigitalFootprints = false
}

-- Storage for cleanup
local ESPConnections = {}
local ESPObjects = {}

-- Color Definitions
local Colors = {
    Survivor = Color3.fromRGB(60, 179, 113), -- calm forest green
    Killer = Color3.fromRGB(255, 99, 71), -- soft red
    Item = Color3.fromRGB(64, 224, 208), -- teal
    Generator = Color3.fromRGB(255, 255, 255), -- white
    FakeGenerator = Color3.fromRGB(138, 43, 226), -- soft violet
    SurvivorDeployable = Color3.fromRGB(152, 251, 152), -- mint green
    KillerMinion = Color3.fromRGB(255, 99, 71), -- soft red
    DigitalFootprint = Color3.fromRGB(255, 99, 71) -- soft red
}

--========================================
-- Helper Functions
--========================================
local function hasPlayerAura(model)
    return model:FindFirstChild("PlayerAura") and model.PlayerAura:IsA("Highlight")
end

local function createHighlight(parent, color, name)
    if parent:FindFirstChild(name or "Aura") then
        return parent[name or "Aura"]
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = name or "Aura"
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = parent
    return highlight
end

local function createESPLabel(parent, color, textLines)
    if parent:FindFirstChild("ESPLabel") then
        return parent.ESPLabel
    end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESPLabel"
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = parent
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = billboardGui
    
    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = container
    
    for i, text in ipairs(textLines) do
        local label = Instance.new("TextLabel")
        label.Name = "Line" .. i
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.5
        label.TextScaled = false
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.LayoutOrder = i
        label.Parent = container
    end
    
    return billboardGui
end

local function removeESP(parent, espType)
    if espType == "highlight" or espType == "both" then
        local highlight = parent:FindFirstChild("Aura")
        if highlight then highlight:Destroy() end
    end
    
    if espType == "label" or espType == "both" then
        local label = parent:FindFirstChild("ESPLabel")
        if label then label:Destroy() end
    end
end

--========================================
-- Player Highlights & ESP
--========================================
local function applyPlayerHighlight(character, color)
    if not ESPState.PlayerHighlights then return end
    if hasPlayerAura(character) then return end
    
    createHighlight(character, color, "Aura")
end

local function applyPlayerESP(character, color, modelName)
    if not ESPState.PlayerESP then return end
    if hasPlayerAura(character) then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    if not head or not humanoid then return end
    
    local health = math.floor(humanoid.Health)
    local textLines = {modelName, health .. " HP"}
    
    createESPLabel(head, color, textLines)
end

local function updatePlayerESP(character, color, modelName)
    if not ESPState.PlayerESP then return end
    
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not head or not humanoid then return end
    
    local billboard = head:FindFirstChild("ESPLabel")
    if billboard then
        local container = billboard:FindFirstChild("Frame")
        if container then
            local healthLabel = container:FindFirstChild("Line2")
            if healthLabel then
                healthLabel.Text = math.floor(humanoid.Health) .. " HP"
            end
        end
    end
end

local function handlePlayer(model, isSurvivor)
    local color = isSurvivor and Colors.Survivor or Colors.Killer
    local modelName = model.Name
    
    -- Apply initial ESP
    applyPlayerHighlight(model, color)
    applyPlayerESP(model, color, modelName)
    
    -- Monitor for PlayerAura changes
    local auraCheckConnection
    auraCheckConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not model.Parent or model.Parent.Name == "Ragdolls" then
            if auraCheckConnection then auraCheckConnection:Disconnect() end
            removeESP(model, "both")
            return
        end
        
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            if auraCheckConnection then auraCheckConnection:Disconnect() end
            removeESP(model, "both")
            return
        end
        
        -- Check every 0.8 seconds for PlayerAura
        task.wait(0.8)
        
        if hasPlayerAura(model) then
            removeESP(model, "both")
        else
            if ESPState.PlayerHighlights and not model:FindFirstChild("Aura") then
                applyPlayerHighlight(model, color)
            end
            if ESPState.PlayerESP then
                local head = model:FindFirstChild("Head")
                if head and not head:FindFirstChild("ESPLabel") then
                    applyPlayerESP(model, color, modelName)
                else
                    updatePlayerESP(model, color, modelName)
                end
            end
        end
    end)
    
    table.insert(ESPConnections, auraCheckConnection)
end

local function monitorPlayerFolder(folder, isSurvivor)
    -- Handle existing players
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            handlePlayer(model, isSurvivor)
        end
    end
    
    -- Monitor new players
    local addedConnection = folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            task.wait(0.1) -- Small delay for character to load
            handlePlayer(child, isSurvivor)
        end
    end)
    
    local removedConnection = folder.ChildRemoved:Connect(function(child)
        removeESP(child, "both")
    end)
    
    table.insert(ESPConnections, addedConnection)
    table.insert(ESPConnections, removedConnection)
end

--========================================
-- Items ESP
--========================================
local function applyItemESP(item)
    if not ESPState.Items then return end
    createHighlight(item, Colors.Item, "Aura")
end

local function monitorItems()
    local map = getMap()
    if not map then return end
    
    for _, item in ipairs(map:GetChildren()) do
        if item.Name == "Medkit" or item.Name == "BloxyCola" then
            applyItemESP(item)
        end
    end
    
    local addedConnection = map.ChildAdded:Connect(function(child)
        if child.Name == "Medkit" or child.Name == "BloxyCola" then
            applyItemESP(child)
        end
    end)
    
    local removedConnection = map.ChildRemoved:Connect(function(child)
        removeESP(child, "highlight")
    end)
    
    table.insert(ESPConnections, addedConnection)
    table.insert(ESPConnections, removedConnection)
end

--========================================
-- Generator ESP
--========================================
local function createGeneratorLabel(generator)
    local progress = generator:FindFirstChild("Progress")
    if not progress then return end
    
    local main = generator:FindFirstChild("Generator") or generator:FindFirstChild("Root") or generator:FindFirstChild("Base")
    if not main or not main:IsA("BasePart") then return end
    
    if main:FindFirstChild("GeneratorESP") then return end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "GeneratorESP"
    billboardGui.Size = UDim2.new(0, 150, 0, 30)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = main
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.Generator
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboardGui
    
    -- Update progress
    local function updateProgress()
        local currentProgress = progress.Value
        label.Text = math.floor(currentProgress) .. "%"
        
        if currentProgress >= 100 then
            removeESP(generator, "highlight")
            if billboardGui then billboardGui:Destroy() end
        end
    end
    
    updateProgress()
    local progressConnection = progress:GetPropertyChangedSignal("Value"):Connect(updateProgress)
    table.insert(ESPConnections, progressConnection)
end

local function applyGeneratorESP(generator)
    if not ESPState.Generators then return end
    
    local progress = generator:FindFirstChild("Progress")
    if not progress or progress.Value >= 100 then return end
    
    createHighlight(generator, Colors.Generator, "Aura")
    createGeneratorLabel(generator)
end

local function monitorGenerators()
    local map = getMap()
    if not map then return end
    
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and obj:FindFirstChild("Remotes") and obj:FindFirstChild("Progress") then
            applyGeneratorESP(obj)
        end
    end
    
    local addedConnection = map.ChildAdded:Connect(function(child)
        if child.Name == "Generator" and child:FindFirstChild("Remotes") and child:FindFirstChild("Progress") then
            applyGeneratorESP(child)
        end
    end)
    
    table.insert(ESPConnections, addedConnection)
end

--========================================
-- Fake Generator ESP
--========================================
local function applyFakeGeneratorESP(fakeGen)
    if not ESPState.FakeGenerators then return end
    createHighlight(fakeGen, Colors.FakeGenerator, "Aura")
end

local function monitorFakeGenerators()
    local map = getMap()
    if not map then return end
    
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "FakeGenerator" then
            applyFakeGeneratorESP(obj)
        end
    end
    
    local addedConnection = map.ChildAdded:Connect(function(child)
        if child.Name == "FakeGenerator" then
            applyFakeGeneratorESP(child)
        end
    end)
    
    table.insert(ESPConnections, addedConnection)
end

--========================================
-- Survivor Deployables ESP
--========================================
local function isSurvivorDeployable(name)
    return name == "BuildermanSentry" or 
           name == "BuildermanDispenser" or 
           name == "TaphTripmine" or 
           name:find("TaphTripwire")
end

local function applyDeployableESP(deployable)
    if not ESPState.SurvivorDeployables then return end
    createHighlight(deployable, Colors.SurvivorDeployable, "Aura")
end

local function monitorSurvivorDeployables()
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if not ingame then return end
    
    for _, obj in ipairs(ingame:GetChildren()) do
        if isSurvivorDeployable(obj.Name) then
            applyDeployableESP(obj)
        end
    end
    
    local addedConnection = ingame.ChildAdded:Connect(function(child)
        if isSurvivorDeployable(child.Name) then
            applyDeployableESP(child)
        end
    end)
    
    table.insert(ESPConnections, addedConnection)
end

--========================================
-- Killer Minions ESP
--========================================
local function isKillerMinion(name)
    return name == "Mafia1" or name == "Mafia2" or name == "Mafia3" or name == "Mafia4" or
           name == "PizzaDeliveryRig" or name == "Zombie"
end

local function applyMinionESP(minion)
    if not ESPState.KillerMinions then return end
    createHighlight(minion, Colors.KillerMinion, "Aura")
end

local function monitorKillerMinions()
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if not ingame then return end
    
    for _, obj in ipairs(ingame:GetChildren()) do
        if isKillerMinion(obj.Name) then
            applyMinionESP(obj)
        end
    end
    
    local addedConnection = ingame.ChildAdded:Connect(function(child)
        if isKillerMinion(child.Name) then
            applyMinionESP(child)
        end
    end)
    
    table.insert(ESPConnections, addedConnection)
end

--========================================
-- Digital Footprints ESP
--========================================
local function applyFootprintESP(shadow)
    if not ESPState.DigitalFootprints then return end
    
    if shadow:IsA("BasePart") then
        shadow.Transparency = 0
        createHighlight(shadow, Colors.DigitalFootprint, "Aura")
    end
    
    -- Handle models containing Shadow parts
    if shadow:IsA("Model") then
        for _, part in ipairs(shadow:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "Shadow" then
                part.Transparency = 0
            end
        end
        createHighlight(shadow, Colors.DigitalFootprint, "Aura")
    end
end

local function monitorDigitalFootprints()
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if not ingame then return end
    
    for _, obj in ipairs(ingame:GetChildren()) do
        if obj.Name == "Shadow" or obj.Name:find("Shadows") then
            applyFootprintESP(obj)
        end
    end
    
    local addedConnection = ingame.ChildAdded:Connect(function(child)
        if child.Name == "Shadow" or child.Name:find("Shadows") then
            applyFootprintESP(child)
        end
    end)
    
    table.insert(ESPConnections, addedConnection)
end

--========================================
-- Cleanup Function
--========================================
local function cleanupESP()
    -- Disconnect all connections
    for _, connection in ipairs(ESPConnections) do
        if connection then connection:Disconnect() end
    end
    ESPConnections = {}
    
    -- Remove all highlights and labels
    for _, player in ipairs(workspace.Players.Survivors:GetChildren()) do
        removeESP(player, "both")
    end
    for _, player in ipairs(workspace.Players.Killers:GetChildren()) do
        removeESP(player, "both")
    end
    
    local map = getMap()
    if map then
        for _, obj in ipairs(map:GetChildren()) do
            removeESP(obj, "both")
            local main = obj:FindFirstChild("Generator") or obj:FindFirstChild("Root") or obj:FindFirstChild("Base")
            if main then
                local genESP = main:FindFirstChild("GeneratorESP")
                if genESP then genESP:Destroy() end
            end
        end
    end
    
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if ingame then
        for _, obj in ipairs(ingame:GetChildren()) do
            removeESP(obj, "both")
            
            -- Restore Shadow transparency
            if obj.Name == "Shadow" and obj:IsA("BasePart") then
                obj.Transparency = 1
            end
        end
    end
end

--========================================
-- ESP Toggles
--========================================

ESPTab:CreateToggle({
    Name = "Show Player Highlights",
    CurrentValue = false,
    Flag = "PlayerHighlights",
    Callback = function(value)
        ESPState.PlayerHighlights = value
        
        if value then
            local survivorsFolder = workspace.Players:FindFirstChild("Survivors")
            local killersFolder = workspace.Players:FindFirstChild("Killers")
            
            if survivorsFolder then
                monitorPlayerFolder(survivorsFolder, true)
            end
            if killersFolder then
                monitorPlayerFolder(killersFolder, false)
            end
        else
            -- Remove only highlights, keep labels if ESP is on
            for _, player in ipairs(workspace.Players.Survivors:GetChildren()) do
                removeESP(player, "highlight")
            end
            for _, player in ipairs(workspace.Players.Killers:GetChildren()) do
                removeESP(player, "highlight")
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Player ESP",
    CurrentValue = false,
    Flag = "PlayerESP",
    Callback = function(value)
        ESPState.PlayerESP = value
        
        if value then
            local survivorsFolder = workspace.Players:FindFirstChild("Survivors")
            local killersFolder = workspace.Players:FindFirstChild("Killers")
            
            if survivorsFolder then
                monitorPlayerFolder(survivorsFolder, true)
            end
            if killersFolder then
                monitorPlayerFolder(killersFolder, false)
            end
        else
            -- Remove only labels, keep highlights if highlights are on
            for _, player in ipairs(workspace.Players.Survivors:GetChildren()) do
                removeESP(player, "label")
            end
            for _, player in ipairs(workspace.Players.Killers:GetChildren()) do
                removeESP(player, "label")
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Items",
    CurrentValue = false,
    Flag = "Items",
    Callback = function(value)
        ESPState.Items = value
        
        if value then
            monitorItems()
        else
            local map = getMap()
            if map then
                for _, item in ipairs(map:GetChildren()) do
                    if item.Name == "Medkit" or item.Name == "BloxyCola" then
                        removeESP(item, "highlight")
                    end
                end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Generators",
    CurrentValue = false,
    Flag = "Generators",
    Callback = function(value)
        ESPState.Generators = value
        
        if value then
            monitorGenerators()
        else
            local map = getMap()
            if map then
                for _, gen in ipairs(map:GetChildren()) do
                    if gen.Name == "Generator" then
                        removeESP(gen, "highlight")
                        local main = gen:FindFirstChild("Generator") or gen:FindFirstChild("Root") or gen:FindFirstChild("Base")
                        if main then
                            local genESP = main:FindFirstChild("GeneratorESP")
                            if genESP then genESP:Destroy() end
                        end
                    end
                end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Fake Generators",
    CurrentValue = false,
    Flag = "FakeGenerators",
    Callback = function(value)
        ESPState.FakeGenerators = value
        
        if value then
            monitorFakeGenerators()
        else
            local map = getMap()
            if map then
                for _, fakeGen in ipairs(map:GetChildren()) do
                    if fakeGen.Name == "FakeGenerator" then
                        removeESP(fakeGen, "highlight")
                    end
                end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Survivor Deployables",
    CurrentValue = false,
    Flag = "SurvivorDeployables",
    Callback = function(value)
        ESPState.SurvivorDeployables = value
        
        if value then
            monitorSurvivorDeployables()
        else
            local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
            if ingame then
                for _, obj in ipairs(ingame:GetChildren()) do
                    if isSurvivorDeployable(obj.Name) then
                        removeESP(obj, "highlight")
                    end
                end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Killer Minions",
    CurrentValue = false,
    Flag = "KillerMinions",
    Callback = function(value)
        ESPState.KillerMinions = value
        
        if value then
            monitorKillerMinions()
        else
            local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
            if ingame then
                for _, obj in ipairs(ingame:GetChildren()) do
                    if isKillerMinion(obj.Name) then
                        removeESP(obj, "highlight")
                    end
                end
            end
        end
    end
})

ESPTab:CreateToggle({
    Name = "Show Digital Footprints",
    CurrentValue = false,
    Flag = "DigitalFootprints",
    Callback = function(value)
        ESPState.DigitalFootprints = value
        
        if value then
            monitorDigitalFootprints()
        else
            local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
            if ingame then
                for _, obj in ipairs(ingame:GetChildren()) do
                    if obj.Name == "Shadow" or obj.Name:find("Shadows") then
                        removeESP(obj, "highlight")
                        
                        -- Restore transparency
                        if obj:IsA("BasePart") then
                            obj.Transparency = 1
                        end
                        if obj:IsA("Model") then
                            for _, part in ipairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") and part.Name == "Shadow" then
                                    part.Transparency = 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
})