--[[
    Yet Another Forsaken Script [Revamp]
   
--]]

--//===[ Dependencies and Setup ]===//--
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name="Yet Another Forsaken Script",
    LoadingTitle="YAFS",
    LoadingSubtitle="Loading...✨",
    ConfigurationSaving={Enabled=false},
    Discord={Enabled=false}
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

--//===[ Utility Functions ]===//--
local function getMap()
    local root = workspace:FindFirstChild("Map")
    return root and root:FindFirstChild("Ingame") and root.Ingame:FindFirstChild("Map")
end

local function getClosestGenerator(maxDist)
    local map, hrp = getMap(), LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not (map and hrp) then return end
    local closest, dist = nil, maxDist or 10
    for _, g in ipairs(map:GetChildren()) do
        if g.Name=="Generator" and g:FindFirstChild("Remotes") and g:FindFirstChild("Progress") then
            local pos = (g.PrimaryPart and g.PrimaryPart.Position) or g:GetPivot().Position
            local d = (hrp.Position - pos).Magnitude
            if d < dist then closest, dist = g, d end
        end
    end
    return closest
end

local function playFireSound()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://81355841754389"
    s.Volume = 1
    s.Parent = workspace
    s:Play()
    game:GetService("Debris"):AddItem(s, 5)
end

--//===[ Generator Tab ]===//--
local GenTab = Window:CreateTab("Generator", 96559240692119)

local autoRepair, repairCooldown, lastRepair, lastManual = false, 6.2, 0, 0
local _REPAIR_ANIMS = {
    ["rbxassetid://82691533602949"]=true,
    ["rbxassetid://122604262087779"]=true,
    ["rbxassetid://130355934640695"]=true
}

local function isRepairing()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
        if t.Animation and _REPAIR_ANIMS[tostring(t.Animation.AnimationId)] then return true end
    end
end

GenTab:CreateToggle({
    Name="Auto-Repair Generators",
    CurrentValue=false,
    Callback=function(v) autoRepair=v end
})

GenTab:CreateInput({
    Name="Repair Cooldown (2.4 - 15)",
    PlaceholderText=tostring(repairCooldown),
    Callback=function(v)
        local n=tonumber(v)
        if n then
            repairCooldown=math.clamp(n,2.4,15)
            Rayfield:Notify({Title="Generator",Content="Cooldown set to "..repairCooldown,Duration=1.4})
        end
    end
})

GenTab:CreateButton({
    Name="Manual Repair Fire (min 2.4s)",
    Callback=function()
        local now=tick()
        if now-lastManual<2.4 then return end
        local g=getClosestGenerator(10)
        if g and g:FindFirstChild("Remotes") then
            local re=g.Remotes:FindFirstChild("RE")
            if re then
                pcall(function() re:FireServer() end)
                playFireSound()
                lastManual=now
            end
        end
    end
})

-- Generator Auto-Repair Loop
local inRange, prevInRange, entryTime = false, false, 0
task.spawn(function()
    while task.wait(0.2) do
        if autoRepair and isRepairing() then
            local now = tick()
            local g = getClosestGenerator(10)
            inRange = g ~= nil

            if inRange and not prevInRange then
                entryTime = now
            end

            if inRange and g and now - lastRepair >= repairCooldown and now - entryTime >= repairCooldown then
                local re = g:FindFirstChild("Remotes") and g.Remotes:FindFirstChild("RE")
                if re then
                    pcall(function() re:FireServer() end)
                    playFireSound()
                    lastRepair = now
                    entryTime = now
                end
            end

            prevInRange = inRange
        else
            prevInRange = false
        end
    end
end)

--//===[ ESP Tab ]===//--
local ESPTab = Window:CreateTab("ESP", 114055269167425)

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

local ESPConnections = {}

local Colors = {
    Survivor = Color3.fromRGB(60, 179, 113),
    Killer = Color3.fromRGB(255, 99, 71),
    Item = Color3.fromRGB(64, 224, 208),
    Generator = Color3.fromRGB(255, 255, 255),
    FakeGenerator = Color3.fromRGB(138, 43, 226),
    SurvivorDeployable = Color3.fromRGB(152, 251, 152),
    KillerMinion = Color3.fromRGB(255, 99, 71),
    DigitalFootprint = Color3.fromRGB(255, 99, 71)
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Robust local player filtering: check Character instance, not Name
local function isLocalPlayerModel(model)
    return LocalPlayer.Character and model == LocalPlayer.Character
end

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

-- ESP label with dynamic size based on distance
local function createESPLabel(parent, color, textLines)
    local existing = parent:FindFirstChild("ESPLabel")
    if existing then existing:Destroy() end -- always destroy and recreate for distance resizing
    
    local gui = Instance.new("BillboardGui")
    gui.Name = "ESPLabel"
    gui.Size = UDim2.new(4, 0, 1, 0)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 500
    gui.Adornee = parent
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "Frame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, -5)
    layout.Parent = frame

    for i, text in ipairs(textLines) do
        local label = Instance.new("TextLabel")
        label.Name = "Line" .. i
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color
        label.TextStrokeTransparency = 0.5
        label.TextSize = 16
        label.Font = Enum.Font.GothamBold
        label.Parent = frame
    end

    -- Distance-based resizing
    local runConn
    runConn = game:GetService("RunService").RenderStepped:Connect(function()
        if not gui.Parent or not gui.Parent:IsDescendantOf(game) then
            runConn:Disconnect()
            return
        end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local headPos = parent.Position
        local camPos = camera.CFrame.Position
        local dist = (headPos-camPos).Magnitude
        -- BillboardGui size scales with distance: larger when far away, but capped
        -- Normal size at 0-60 studs, max 2x at 150+ studs
        local scale = math.clamp(1.0 + ((dist-60)/90)*1, 1, 2)
        gui.Size = UDim2.new(4*scale,0,1*scale,0)
    end)

    return gui
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

local function applyPlayerHighlight(character, color)
    if not ESPState.PlayerHighlights or hasPlayerAura(character) then return end
    if isLocalPlayerModel(character) then return end -- Don't highlight local player
    createHighlight(character, color, "Aura")
end

local function applyPlayerESP(character, color, modelName)
    if not ESPState.PlayerESP or hasPlayerAura(character) then return end
    if isLocalPlayerModel(character) then return end -- Don't show ESP on local player
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    if not head or not humanoid then return end
    
    local hp = math.floor(humanoid.Health)
    local maxHp = math.floor(humanoid.MaxHealth)
    createESPLabel(head, color, {"[ " .. modelName .. " ]", hp .. " / " .. maxHp .. " HP"})
end

local function updatePlayerESP(character, color, modelName)
    if not ESPState.PlayerESP then return end
    if isLocalPlayerModel(character) then return end -- Don't update ESP for local player
    
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not head or not humanoid then return end
    
    local gui = head:FindFirstChild("ESPLabel")
    if not gui then return end
    
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    
    local healthLabel = frame:FindFirstChild("Line2")
    if healthLabel then
        local hp = math.floor(humanoid.Health)
        local maxHp = math.floor(humanoid.MaxHealth)
        healthLabel.Text = hp .. " / " .. maxHp .. " HP"
    end
end

local function handlePlayer(model, isSurvivor)
    if isLocalPlayerModel(model) then return end -- Don't ESP/highlight local player
    
    local color = isSurvivor and Colors.Survivor or Colors.Killer
    local modelName = model.Name
    
    applyPlayerHighlight(model, color)
    applyPlayerESP(model, color, modelName)
    
    local connections = {}
    local check; check = game:GetService("RunService").Heartbeat:Connect(function()
        if not model.Parent or model.Parent.Name == "Ragdolls" then
            check:Disconnect()
            for _, c in ipairs(connections) do c:Disconnect() end
            removeESP(model, "both")
            return
        end
        
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            check:Disconnect()
            for _, c in ipairs(connections) do c:Disconnect() end
            removeESP(model, "both")
            return
        end
        
        task.wait(0.8)
        
        if hasPlayerAura(model) then
            removeESP(model, "both")
        else
            if ESPState.PlayerHighlights and not model:FindFirstChild("Aura") then
                applyPlayerHighlight(model, color)
            end
            
            local head = model:FindFirstChild("Head")
            if ESPState.PlayerESP then
                if head and not head:FindFirstChild("ESPLabel") then
                    applyPlayerESP(model, color, modelName)
                else
                    updatePlayerESP(model, color, modelName)
                end
            elseif head then
                local label = head:FindFirstChild("ESPLabel")
                if label then label:Destroy() end
            end
        end
    end)
    
    table.insert(ESPConnections, check)
    table.insert(connections, check)
end

local function monitorPlayerFolder(folder, isSurvivor)
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then handlePlayer(model, isSurvivor) end
    end
    
    local add = folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            task.wait(0.1)
            handlePlayer(child, isSurvivor)
        end
    end)
    
    local remove = folder.ChildRemoved:Connect(function(child)
        removeESP(child, "both")
    end)
    
    table.insert(ESPConnections, add)
    table.insert(ESPConnections, remove)
end

local function applyItemESP(item)
    if ESPState.Items then createHighlight(item, Colors.Item, "Aura") end
end

local function monitorItems()
    local map = getMap()
    if not map then return end
    
    for _, item in ipairs(map:GetChildren()) do
        if item.Name == "Medkit" or item.Name == "BloxyCola" then
            applyItemESP(item)
        end
    end
    
    table.insert(ESPConnections, map.ChildAdded:Connect(function(child)
        if child.Name == "Medkit" or child.Name == "BloxyCola" then
            applyItemESP(child)
        end
    end))
end

local function createGeneratorLabel(generator)
    local progress = generator:FindFirstChild("Progress")
    if not progress then return end
    
    local main = generator.PrimaryPart or generator:FindFirstChild("Main")
    if not main or not main:IsA("BasePart") then return end
    
    local existing = main:FindFirstChild("GeneratorESP")
    if existing then
        local label = existing:FindFirstChild("TextLabel")
        if label then
            local val = progress.Value
            label.Text = math.floor(val) .. "%"
            if val >= 100 then
                removeESP(generator, "highlight")
                existing:Destroy()
            end
        end
        return
    end
    
    local gui = Instance.new("BillboardGui")
    gui.Name = "GeneratorESP"
    gui.Size = UDim2.new(4, 0, 1, 0)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 500
    gui.Parent = main
    
    local label = Instance.new("TextLabel")
    label.Name = "TextLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Colors.Generator
    label.TextStrokeTransparency = 0.5
    label.TextSize = 18
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
    
    local function update()
        local val = progress.Value
        label.Text = math.floor(val) .. "%"
        if val >= 100 then
            removeESP(generator, "highlight")
            if gui then gui:Destroy() end
        end
    end
    
    update()
    table.insert(ESPConnections, progress:GetPropertyChangedSignal("Value"):Connect(update))
end

local function applyGeneratorESP(gen)
    if not ESPState.Generators then return end
    local progress = gen:FindFirstChild("Progress")
    if not progress or progress.Value >= 100 then return end
    createHighlight(gen, Colors.Generator, "Aura")
    createGeneratorLabel(gen)
end

local function monitorGenerators()
    local map = getMap()
    if not map then return end
    
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and obj:FindFirstChild("Remotes") and obj:FindFirstChild("Progress") then
            applyGeneratorESP(obj)
        end
    end
    
    table.insert(ESPConnections, map.ChildAdded:Connect(function(child)
        if child.Name == "Generator" and child:FindFirstChild("Remotes") and child:FindFirstChild("Progress") then
            applyGeneratorESP(child)
        end
    end))
end

local function applyFakeGeneratorESP(fake)
    if ESPState.FakeGenerators then createHighlight(fake, Colors.FakeGenerator, "Aura") end
end

local function monitorFakeGenerators()
    local map = getMap()
    if not map then return end
    
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "FakeGenerator" then applyFakeGeneratorESP(obj) end
    end
    
    table.insert(ESPConnections, map.ChildAdded:Connect(function(child)
        if child.Name == "FakeGenerator" then applyFakeGeneratorESP(child) end
    end))
end

local function isSurvivorDeployable(name)
    return name == "BuildermanSentry" or name == "BuildermanDispenser" or 
           name == "TaphTripmine" or name:find("TaphTripwire")
end

local function applyDeployableESP(obj)
    if ESPState.SurvivorDeployables then createHighlight(obj, Colors.SurvivorDeployable, "Aura") end
end

local function monitorSurvivorDeployables()
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if not ingame then return end
    
    for _, obj in ipairs(ingame:GetChildren()) do
        if isSurvivorDeployable(obj.Name) then applyDeployableESP(obj) end
    end
    
    table.insert(ESPConnections, ingame.ChildAdded:Connect(function(child)
        if isSurvivorDeployable(child.Name) then applyDeployableESP(child) end
    end))
end

local function isKillerMinion(name)
    return name == "Mafia1" or name == "Mafia2" or name == "Mafia3" or 
           name == "Mafia4" or name == "PizzaDeliveryRig" or name == "Zombie"
end

local function applyMinionESP(obj)
    if ESPState.KillerMinions then createHighlight(obj, Colors.KillerMinion, "Aura") end
end

local function monitorKillerMinions()
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if not ingame then return end
    
    for _, obj in ipairs(ingame:GetChildren()) do
        if isKillerMinion(obj.Name) then applyMinionESP(obj) end
    end
    
    table.insert(ESPConnections, ingame.ChildAdded:Connect(function(child)
        if isKillerMinion(child.Name) then applyMinionESP(child) end
    end))
end

local function applyFootprintESP(shadow)
    if not ESPState.DigitalFootprints then return end
    
    if shadow:IsA("Folder") and shadow.Name:find("Shadows") then
        local part = shadow:FindFirstChild("Shadow")
        if part and part:IsA("BasePart") then
            part.Transparency = 0
            createHighlight(part, Colors.DigitalFootprint, "Aura")
        end
    end
end

local function monitorDigitalFootprints()
    local ingame = workspace.Map and workspace.Map:FindFirstChild("Ingame")
    if not ingame then return end
    
    for _, obj in ipairs(ingame:GetChildren()) do
        if obj.Name:find("Shadows") then applyFootprintESP(obj) end
    end
    
    table.insert(ESPConnections, ingame.ChildAdded:Connect(function(child)
        if child.Name:find("Shadows") then
            task.wait(0.1)
            applyFootprintESP(child)
        end
    end))
end

local function cleanupESP()
    for _, conn in ipairs(ESPConnections) do
        if conn then conn:Disconnect() end
    end
    ESPConnections = {}
    
    local survivors = workspace.Players:FindFirstChild("Survivors")
    local killers = workspace.Players:FindFirstChild("Killers")
    
    if survivors then
        for _, player in ipairs(survivors:GetChildren()) do
            removeESP(player, "both")
        end
    end
    
    if killers then
        for _, player in ipairs(killers:GetChildren()) do
            removeESP(player, "both")
        end
    end
    
    local map = getMap()
    if map then
        for _, obj in ipairs(map:GetChildren()) do
            removeESP(obj, "both")
            local main = obj.PrimaryPart or obj:FindFirstChild("Main")
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
            if obj:IsA("Folder") and obj.Name:find("Shadows") then
                local part = obj:FindFirstChild("Shadow")
                if part and part:IsA("BasePart") then part.Transparency = 1 end
            end
        end
    end
end

ESPTab:CreateToggle({
    Name = "Show Player Highlights",
    CurrentValue = false,
    Flag = "PlayerHighlights",
    Callback = function(value)
        ESPState.PlayerHighlights = value
        if value then
            local survivors = workspace.Players:FindFirstChild("Survivors")
            local killers = workspace.Players:FindFirstChild("Killers")
            if survivors then monitorPlayerFolder(survivors, true) end
            if killers then monitorPlayerFolder(killers, false) end
        else
            local survivors = workspace.Players:FindFirstChild("Survivors")
            local killers = workspace.Players:FindFirstChild("Killers")
            if survivors then
                for _, p in ipairs(survivors:GetChildren()) do removeESP(p, "highlight") end
            end
            if killers then
                for _, p in ipairs(killers:GetChildren()) do removeESP(p, "highlight") end
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
            local survivors = workspace.Players:FindFirstChild("Survivors")
            local killers = workspace.Players:FindFirstChild("Killers")
            if survivors then monitorPlayerFolder(survivors, true) end
            if killers then monitorPlayerFolder(killers, false) end
        else
            local survivors = workspace.Players:FindFirstChild("Survivors")
            local killers = workspace.Players:FindFirstChild("Killers")
            if survivors then
                for _, p in ipairs(survivors:GetChildren()) do removeESP(p, "label") end
            end
            if killers then
                for _, p in ipairs(killers:GetChildren()) do removeESP(p, "label") end
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
                        local main = gen.PrimaryPart or gen:FindFirstChild("Main")
                        if main then
                            local esp = main:FindFirstChild("GeneratorESP")
                            if esp then esp:Destroy() end
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
                for _, fake in ipairs(map:GetChildren()) do
                    if fake.Name == "FakeGenerator" then removeESP(fake, "highlight") end
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
                    if isSurvivorDeployable(obj.Name) then removeESP(obj, "highlight") end
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
                    if isKillerMinion(obj.Name) then removeESP(obj, "highlight") end
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
                    if obj:IsA("Folder") and obj.Name:find("Shadows") then
                        local part = obj:FindFirstChild("Shadow")
                        if part and part:IsA("BasePart") then
                            removeESP(part, "highlight")
                            part.Transparency = 1
                        end
                    end
                end
            end
        end
    end
})
--//===[ Player Tab ]===//--
local PlayerTab = Window:CreateTab("Player", 89251076279188)
local Player = Players.LocalPlayer
local RS, UIS = game:GetService("RunService"), game:GetService("UserInputService")
local Sprinting = game.ReplicatedStorage.Systems.Character.Game.Sprinting
local stamina = require(Sprinting)

local DefaultStamina = {
    Max = stamina.MaxStamina,
    Min = stamina.MinStamina,
    Gain = stamina.StaminaGain,
    Loss = stamina.StaminaLoss,
    Speed = stamina.SprintSpeed,
    LossDisabled = stamina.StaminaLossDisabled
}

local function WarnConflict()
    Rayfield:Notify({
        Title="Conflict Detected",
        Content="You cannot use Infinite Stamina and Custom Stamina at the same time!",
        Duration=6,
        Image=4483362458
    })
end

local InfiniteToggle, CustomToggle
InfiniteToggle = PlayerTab:CreateToggle({
    Name="Infinite Stamina",
    CurrentValue=false,
    Flag="InfiniteStamina",
    Callback=function(v)
        if v and CustomToggle.CurrentValue then
            WarnConflict(); InfiniteToggle:Set(false); return
        end
        stamina.StaminaLossDisabled = v or DefaultStamina.LossDisabled
    end
})

CustomToggle = PlayerTab:CreateToggle({
    Name="Custom Stamina",
    CurrentValue=false,
    Flag="CustomStamina",
    Callback=function(v)
        if v and InfiniteToggle.CurrentValue then
            WarnConflict(); CustomToggle:Set(false); return
        end
        if not v then
            for k,vv in pairs(DefaultStamina) do stamina[k.."Stamina"]=vv end
            stamina.SprintSpeed = DefaultStamina.Speed
        end
    end
})

local function MakeInput(name, def, apply)
    PlayerTab:CreateInput({
        Name=name,
        PlaceholderText=tostring(def),
        RemoveTextAfterFocusLost=false,
        Callback=function(txt)
            local num=tonumber(txt)
            if num and CustomToggle.CurrentValue then apply(num) end
        end
    })
end

MakeInput("Max Stamina", DefaultStamina.Max, function(n) stamina.MaxStamina=n end)
MakeInput("Min Stamina", DefaultStamina.Min, function(n) stamina.MinStamina=n end)
MakeInput("Stamina Gain", DefaultStamina.Gain, function(n) stamina.StaminaGain=n end)
MakeInput("Stamina Loss", DefaultStamina.Loss, function(n) stamina.StaminaLoss=n end)
MakeInput("Sprint Speed", DefaultStamina.Speed, function(n) stamina.SprintSpeed=n end)

--=== Expected Stamina Preview ===--
local preview = {
    cons = {},
    StaminaLabel = nil,
    currentStam = 0,
    created = false,
    lastCheck = 0,
    forceSim = false, -- backup detection
}

local function nearestSurvivor(pos)
    local closestDist = nil
    for _, s in ipairs(workspace.Players.Survivors:GetChildren()) do
        local hrp = s:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (hrp.Position - pos).Magnitude
            if not closestDist or dist < closestDist then
                closestDist = dist
            end
        end
    end
    return closestDist
end

local function EnablePreview()
    if preview.created then
        preview.StaminaLabel.Visible = true
        return
    end

    local ui = Player.PlayerGui:FindFirstChild("MainUI")
    if not ui then return end

    preview.StaminaLabel = makeLabel(ui, "StaminaLabel")
    preview.currentStam = 100
    local hum, root, char = nil, nil, nil
    local lastIsKiller = nil

    -- Character setup
    local function charAdded(c)
        char = c
        hum = c:WaitForChild("Humanoid")
        root = c:WaitForChild("HumanoidRootPart")
        preview.currentStam = 100
    end
    if Player.Character then charAdded(Player.Character) end
    Player.CharacterAdded:Connect(charAdded)

    -- Real stamina label from the game
    local realStamLabel = Player.PlayerGui
        :WaitForChild("TemporaryUI")
        :WaitForChild("PlayerInfo")
        :WaitForChild("Bars")
        :WaitForChild("Stamina")
        :WaitForChild("Amount")

    -- Connections
    preview.cons = {
        RS.RenderStepped:Connect(function(dt)
            if not (hum and root and char) then return end

            -- Check role
            local inKillers = workspace.Players:FindFirstChild("Killers")
            local isKiller = (inKillers and char.Parent == inKillers) or false

            if lastIsKiller ~= nil and lastIsKiller ~= isKiller then
                local newMax = isKiller and 110 or (CustomToggle.CurrentValue and stamina.MaxStamina or DefaultStamina.Max)
                preview.currentStam = newMax
            end
            lastIsKiller = isKiller

            -- Stamina values
            local maxStam = isKiller and 110 or (CustomToggle.CurrentValue and stamina.MaxStamina or DefaultStamina.Max)
            local gain    = CustomToggle.CurrentValue and stamina.StaminaGain or DefaultStamina.Gain
            local loss    = CustomToggle.CurrentValue and stamina.StaminaLoss or DefaultStamina.Loss
            local thresh  = 0.5
            local range   = 100

            -- Sprint detection
            local fovMult = char:FindFirstChild("FOVMultipliers")
            local sprintingVal = fovMult and fovMult:FindFirstChild("Sprinting")
            local active = sprintingVal and sprintingVal.Value > 1
            local moving = hum.MoveDirection.Magnitude > 0 and Vector3.new(root.Velocity.X,0,root.Velocity.Z).Magnitude > thresh

            -- Drain logic
            local draining
            if isKiller then
                local near = nearestSurvivor(root.Position)
                draining = active and moving and (near and near <= range)
            else
                draining = active and moving
            end

            -- Detect infinite stamina mode
            local isInfinite = InfiniteToggle.CurrentValue
            if not isInfinite and active and moving and tick() - preview.lastCheck > 0.5 then
                preview.lastCheck = tick()
                local before = tonumber(realStamLabel.Text) or 0
                task.delay(0.25, function()
                    local after = tonumber(realStamLabel.Text) or 0
                    if active and moving and after == before then
                        preview.forceSim = true
                    else
                        preview.forceSim = false
                    end
                end)
            end

            -- Decide whether to simulate or mirror
            if isInfinite or preview.forceSim then
                preview.currentStam = math.clamp(
                    preview.currentStam + (draining and -loss or gain) * dt,
                    0, maxStam
                )
                preview.StaminaLabel.Text = string.format("Expected %s: %d/%d",
                    isKiller and "Killer" or "Survivor",
                    math.floor(preview.currentStam + 0.5),
                    maxStam
                )
            else
                preview.StaminaLabel.Text = "Stamina: " .. realStamLabel.Text
            end

            preview.StaminaLabel.Visible = true
        end)
    }

    preview.created = true
end

local function DisablePreview()
    if preview.StaminaLabel then
        preview.StaminaLabel.Visible = false
        preview.StaminaLabel.Position = UDim2.new(-1, 0, 0, 0) -- move offscreen just in case
    end

    preview.created = false 
end

PlayerTab:CreateToggle({
    Name="Show Expected Stamina",
    CurrentValue=false,
    Flag="ShowExpectedStamina",
    Callback=function(v) if v then EnablePreview() else DisablePreview() end end
})

--=== Ingame Apply ===--
local Ingame=workspace:WaitForChild("Map"):WaitForChild("Ingame")
Ingame.ChildAdded:Connect(function(c)
    if c.Name=="Map" then
        task.wait(1)
        if InfiniteToggle.CurrentValue then
            stamina.StaminaLossDisabled=true
        elseif CustomToggle.CurrentValue then
            local flags=Rayfield.Flags
            local function applyFlag(name,field)
                local v=tonumber(flags[name].CurrentValue)
                if v then stamina[field]=v end
            end
            applyFlag("Max Stamina","MaxStamina")
            applyFlag("Min Stamina","MinStamina")
            applyFlag("Stamina Gain","StaminaGain")
            applyFlag("Stamina Loss","StaminaLoss")
            applyFlag("Sprint Speed","SprintSpeed")
        end
    end
end)

--//===[ Misc Tab ]===//--
local MiscTab = Window:CreateTab("Misc", 72612560514066)
local RoundTimer = LocalPlayer.PlayerGui:WaitForChild("RoundTimer").Main

-- Privacy Settings Toggle
MiscTab:CreateToggle({
    Name = "Delete Privacy Settings",
    CurrentValue = false,
    Flag = "DeletePrivacy",
    Callback = function(Value)
        if Value then
            for _, player in pairs(Players:GetPlayers()) do
                local privacyFolder = player:FindFirstChild("PlayerData")
                    and player.PlayerData:FindFirstChild("Settings")
                    and player.PlayerData.Settings:FindFirstChild("Privacy")
                if privacyFolder then
                    for _, item in pairs(privacyFolder:GetChildren()) do
                        item:Destroy()
                    end
                end
            end
        end
    end,
})

MiscTab:CreateSlider({
    Name = "Round Timer X Position",
    Range = {0.2, 0.8},
    Increment = 0.01,
    CurrentValue = 0.5,
    Callback = function(val)
        RoundTimer.Position = UDim2.new(
            val,
            0,
            RoundTimer.Position.Y.Scale,
            RoundTimer.Position.Y.Offset
        )
    end
})

MiscTab:CreateButton({
    Name = "Reset Round Timer Position",
    Callback = function()
        RoundTimer.Position = UDim2.new(0.5, 0, -0.0175, 0)
    end
})

MiscTab:CreateToggle({
    Name = "Block Subspaced Effect",
    CurrentValue = false,
    Callback = function(state)
        local sub = game:GetService("ReplicatedStorage").Modules.StatusEffects.SurvivorExclusive

        if state then
            if sub:FindFirstChild("Subspaced") then
                sub.Subspaced.Name = "Subzerospaced"
            end
        else
            if sub:FindFirstChild("Subzerospaced") then
                sub.Subzerospaced.Name = "Subspaced"
            end
        end

        Rayfield:Notify({
            Title = "Misc",
            Content = state and "Subspaced blocked." or "Subspaced restored.",
            Duration = 2,
            Image = 4483362458
        })
    end
})

MiscTab:CreateToggle({
    Name = "Block New Glitched Effect",
    CurrentValue = false,
    Callback = function(state)
        local sub = game:GetService("ReplicatedStorage").Modules.StatusEffects.KillerrExclusive

        if state then
            if sub:FindFirstChild("Glitched") then
                sub.Subspaced.Name = "TheNewGlitched"
            end
        else
            if sub:FindFirstChild("TheNewGlitched") then
                sub.Subzerospaced.Name = "Glitched"
            end
        end

        Rayfield:Notify({
            Title = "Misc",
            Content = state and "New Glitched blocked." or "New Glitched restored.",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- c00lgui Tracker implementation and toggle
-- (Tracker code grouped and documented here)
local trackerEnabled=false
local cooldownTime=30
local lastTrigger={}
local activeC00lParts={}
local function notify(t,c) Rayfield:Notify({Title=t,Content=c,Duration=6.5,Image=4483362458}) end

local function trackPlayer(model)
    local player=Players:GetPlayerFromCharacter(model)
    if not player then return end
    local function setup(c00l)
        if not c00l then return end
        if lastTrigger[player] and (tick()-lastTrigger[player])<cooldownTime then return end
        lastTrigger[player]=tick()
        notify("c00lgui Tracker","@"..player.Name.." is using c00lgui.")
        activeC00lParts[player]=c00l
    end
    local existing=model:FindFirstChild("c00lgui")
    if existing then setup(existing) end
    model.ChildAdded:Connect(function(ch) if ch.Name=="c00lgui" then setup(ch) end end)
end

RunService.Heartbeat:Connect(function()
    for player,c00l in pairs(activeC00lParts) do
        local model=player.Character
        if not model or not c00l or not c00l:IsDescendantOf(model) then
            local hrp=model and model:FindFirstChild("HumanoidRootPart")
            local teleported=false
            if hrp then
                local spawns=getMap() and workspace.Map.Ingame.Map.SpawnPoints.Survivors:GetChildren() or {}
                for _,s in ipairs(spawns) do
                    if s.Name=="SurvivorSpawn" and (hrp.Position-s.Position).Magnitude<=25 then
                        teleported=true break
                    end
                end
            end
            if teleported then notify("c00lgui Tracker","@"..player.Name.." teleported.")
            else notify("c00lgui Tracker","@"..player.Name.."'s c00lgui cancelled.") end
            activeC00lParts[player]=nil
        end
    end
end)

MiscTab:CreateToggle({
    Name="c00lgui Tracker",
    CurrentValue=false,
    Callback=function(s)
        trackerEnabled=s
        if trackerEnabled then
            local surv=workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if surv then
                for _,m in ipairs(surv:GetChildren()) do if m.Name=="007n7" then trackPlayer(m) end end
                surv.ChildAdded:Connect(function(m) if m.Name=="007n7" then trackPlayer(m) end end)
            end
        end
    end
})

--//===[ End of Script ]===//--
