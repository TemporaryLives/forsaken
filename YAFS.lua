--=====================================================================--
-- Yet Another Forsaken Script (Skidded, don't expect it to be polished) --
--=====================================================================--

--// Rayfield Setup
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    LoadingTitle = "Loading the script...",
    LoadingSubtitle = "💫",
    ConfigurationSaving = {
        Enabled = false
    }
})

--// Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer


--========================================================
-- Helpers
--========================================================

local function destroyChildrenByName(obj, name)
    for _, child in ipairs(obj:GetChildren()) do
        if child.Name == name then
            child:Destroy()
        end
    end
end

local function getMap()
    return workspace:FindFirstChild("Map")
       and workspace.Map:FindFirstChild("Ingame")
       and workspace.Map.Ingame:FindFirstChild("Map")
end

local function getClosestGenerator(maxDist)
    local map = getMap()
    if not map then return end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local closest, dist = nil, maxDist or 12
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and obj:FindFirstChild("Remotes") then
            if obj:FindFirstChild("Progress") and obj.Progress.Value < 100 then
                local main = obj:FindFirstChild("Main")
                if main and main:IsA("Part") then
                    local d = (hrp.Position - main.Position).Magnitude
                    if d < dist then
                        closest, dist = obj, d
                    end
                end
            end
        end
    end

    return closest
end

local function isRepairing()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation and (
                track.Animation.AnimationId == "rbxassetid://82691533602949" or
                track.Animation.AnimationId == "rbxassetid://122604262087779" or
                track.Animation.AnimationId == "rbxassetid://130355893361522"
            ) then
                return true
            end
        end
    end
    return false
end


--========================================================
-- Generator Tab
--========================================================

local GeneratorTab = Window:CreateTab("Generator Tab", 96559240692119)
local autoRepair = false
local repairCooldown = 3.1
local lastRepair = 0

GeneratorTab:CreateToggle({
    Name = "Auto-Repair Generators",
    CurrentValue = false,
    Callback = function(v)
        autoRepair = v
    end
})

GeneratorTab:CreateInput({
    Name = "Repair Cooldown (2.4 - 8)",
    PlaceholderText = tostring(repairCooldown),
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        local num = tonumber(val)
        if num and num >= 2.4 and num <= 8 then
            repairCooldown = num
        end
    end
})

GeneratorTab:CreateButton({
    Name = "Manual Repair Fire",
    Callback = function()
        local now = tick()
        if now - lastRepair < 2.4 then
            Rayfield:Notify({
                Title = "Cooldown",
                Content = "You must wait 2.4s before firing again.",
                Duration = 2
            })
            return
        end

        local gen = getClosestGenerator(12)
        if gen and isRepairing() then
            local re = gen.Remotes:FindFirstChild("RE")
            if re then
                re:FireServer()
                lastRepair = now
            end
        end
    end
})

task.spawn(function()
    while true do
        task.wait(0.2)
        if autoRepair then
            if isRepairing() then
                local now = tick()
                if now - lastRepair >= repairCooldown then
                    local gen = getClosestGenerator(12)
                    if gen and gen:FindFirstChild("Remotes") then
                        local re = gen.Remotes:FindFirstChild("RE")
                        if re then
                            re:FireServer()
                            lastRepair = now
                        end
                    end
                end
            else
                lastRepair = tick()
            end
        end
    end
end)

--========================================================
-- ESP Tab
--========================================================

local ESPTab = Window:CreateTab("ESP Tab", 4483362458)

local Colors = {
    SurvivorText   = Color3.fromRGB(255,191,0),
    KillerText     = Color3.fromRGB(255,0,0),
    SurvivorAura   = Color3.fromRGB(255,191,0),
    KillerAura     = Color3.fromRGB(255,0,0),
    Consumables    = Color3.fromRGB(255,106,180),
    Deployables    = Color3.fromRGB(191,255,191),
    Generator      = Color3.fromRGB(255,255,255),
    FakeGenerator  = Color3.fromRGB(128,0,128),
    Footprints     = Color3.fromRGB(0,255,255)
}

local ESPStates = {
    Text = false,
    AuraPlayers = false,
    Consumables = false,
    Deployables = false,
    Generators = false,
    FakeGenerators = false,
    Footprints = false
}

local ESPExtraInfo = false


-- Create ESP text above players
local function createTextESP(character, textColor)
    if character == LocalPlayer.Character then return end
    if not character:FindFirstChild("HumanoidRootPart") then return end
    if character:FindFirstChild("ESPText") then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPText"
    billboard.Adornee = character.HumanoidRootPart
    billboard.Size = UDim2.new(0, 100, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = textColor
    label.Font = Enum.Font.Bodoni
    label.TextSize = 18
    label.Text = character.Name
    label.Parent = billboard

    billboard.Parent = character
end


-- Create ESP with extra info (@username + HP)
local function createExtraInfoESP(character)
    if character == LocalPlayer.Character then return end
    if not character:FindFirstChild("HumanoidRootPart") then return end
    if character:FindFirstChild("ESPExtraInfo") then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local player = Players:GetPlayerFromCharacter(character)
    if not humanoid or not player then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPExtraInfo"
    billboard.Adornee = character.HumanoidRootPart
    billboard.Size = UDim2.new(0, 150, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2.2, 0)
    billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.Text = "@" .. player.Name .. " | HP: " .. math.floor(humanoid.Health)
    label.Parent = billboard

    humanoid.HealthChanged:Connect(function(hp)
        if label and label.Parent then
            label.Text = "@" .. player.Name .. " | HP: " .. math.floor(hp)
        end
    end)

    billboard.Parent = character
end


-- Aura highlights
local function createAura(obj, color)
    if obj == LocalPlayer.Character then return end
    if obj:FindFirstChild("PlayerAura") then return end
    if obj:FindFirstChild("Aura") then return end

    local h = Instance.new("Highlight")
    h.Name = "Aura"
    h.Adornee = obj
    h.FillColor = color
    h.FillTransparency = 0.5
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.Parent = obj
end


-- Handle aura conflicts between Aura & PlayerAura
local function handleAuraConflict(obj)
    local aura = obj:FindFirstChild("Aura")
    local pa = obj:FindFirstChild("PlayerAura")
    if aura and pa then
        aura.Enabled = false
        pa:GetPropertyChangedSignal("Name"):Connect(function()
            if pa.Name == "goodbai" then
                pa.Destroying:Wait()
                aura.Enabled = true
            end
        end)
    end
end


-- ESP updater loop
task.spawn(function()
    while true do
        task.wait(0.5)
        local map = getMap()

        -- Survivors
        local survivors = workspace.Players:FindFirstChild("Survivors")
        if survivors then
            for _, char in ipairs(survivors:GetChildren()) do
                if ESPStates.Text then
                    createTextESP(char, Colors.SurvivorText)
                    if ESPExtraInfo then
                        createExtraInfoESP(char)
                    else
                        destroyChildrenByName(char, "ESPExtraInfo")
                    end
                else
                    destroyChildrenByName(char, "ESPText")
                    destroyChildrenByName(char, "ESPExtraInfo")
                end

                if ESPStates.AuraPlayers then
                    createAura(char, Colors.SurvivorAura)
                else
                    destroyChildrenByName(char, "Aura")
                end

                handleAuraConflict(char)
            end
        end

        -- Killers
        local killers = workspace.Players:FindFirstChild("Killers")
        if killers then
            for _, char in ipairs(killers:GetChildren()) do
                if ESPStates.Text then
                    createTextESP(char, Colors.KillerText)
                    if ESPExtraInfo then
                        createExtraInfoESP(char)
                    else
                        destroyChildrenByName(char, "ESPExtraInfo")
                    end
                else
                    destroyChildrenByName(char, "ESPText")
                    destroyChildrenByName(char, "ESPExtraInfo")
                end

                if ESPStates.AuraPlayers then
                    createAura(char, Colors.KillerAura)
                else
                    destroyChildrenByName(char, "Aura")
                end

                handleAuraConflict(char)
            end
        end

        -- Map objects
        if map then
            for _, obj in ipairs(map:GetChildren()) do
                if obj.Name == "Generator" and obj:FindFirstChild("Progress") then
                    if ESPStates.Generators and obj.Progress.Value < 100 then
                        createAura(obj, Colors.Generator)
                    else
                        destroyChildrenByName(obj, "Aura")
                    end
                elseif obj.Name == "FakeGenerator" then
                    if ESPStates.FakeGenerators then
                        createAura(obj, Colors.FakeGenerator)
                    else
                        destroyChildrenByName(obj, "Aura")
                    end
                elseif obj.Name == "Medkit" or obj.Name == "BloxyCola" then
                    if ESPStates.Consumables then
                        createAura(obj, Colors.Consumables)
                    else
                        destroyChildrenByName(obj, "Aura")
                    end
                elseif obj.Name == "BuildermanSentry"
                    or obj.Name == "BuildermanDispenser"
                    or string.find(obj.Name, "TaphTripwire")
                    or obj.Name == "SubspaceTripmine" then
                    if ESPStates.Deployables then
                        createAura(obj, Colors.Deployables)
                    else
                        destroyChildrenByName(obj, "Aura")
                    end
                end
            end

            -- Footprints
            for _, folder in ipairs(workspace.Map.Ingame:GetChildren()) do
                if string.find(folder.Name, "Shadows") then
                    for _, shadow in ipairs(folder:GetChildren()) do
                        shadow.Transparency = 0
                        if ESPStates.Footprints then
                            createAura(shadow, Colors.Footprints)
                        else
                            destroyChildrenByName(shadow, "Aura")
                        end
                    end
                end
            end
        end
    end
end)


-- ESP Toggles
ESPTab:CreateToggle({
    Name = "Show ESP (Text)",
    CurrentValue = false,
    Callback = function(s) ESPStates.Text = s end
})

ESPTab:CreateToggle({
    Name = "Highlight Players",
    CurrentValue = false,
    Callback = function(s) ESPStates.AuraPlayers = s end
})

ESPTab:CreateToggle({
    Name = "Show Consumables",
    CurrentValue = false,
    Callback = function(s) ESPStates.Consumables = s end
})

ESPTab:CreateToggle({
    Name = "Show Deployables",
    CurrentValue = false,
    Callback = function(s) ESPStates.Deployables = s end
})

ESPTab:CreateToggle({
    Name = "Show Generators (<100)",
    CurrentValue = false,
    Callback = function(s) ESPStates.Generators = s end
})

ESPTab:CreateToggle({
    Name = "Show Fake Generators",
    CurrentValue = false,
    Callback = function(s) ESPStates.FakeGenerators = s end
})

ESPTab:CreateToggle({
    Name = "Show Digital Footprints",
    CurrentValue = false,
    Callback = function(s) ESPStates.Footprints = s end
})

ESPTab:CreateToggle({
    Name = "ESP Extra Info",
    CurrentValue = false,
    Callback = function(s) ESPExtraInfo = s end
})

--========================================================
-- Fake Generator Detection
--========================================================

local function setupFakeGenDetection(gen)
    if gen:FindFirstChild("Main") then
        gen.Main.Touched:Connect(function(hit)
            local char = hit.Parent
            if char == LocalPlayer.Character then
                Rayfield:Notify({
                    Title = "Warning",
                    Content = "This is a fake generator!",
                    Duration = 3,
                    Image = 4483362458
                })
            end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        local map = getMap()
        if map then
            for _, obj in ipairs(map:GetChildren()) do
                if obj.Name == "FakeGenerator" and not obj:FindFirstChild("FakeGenDetect") then
                    local tag = Instance.new("BoolValue")
                    tag.Name = "FakeGenDetect"
                    tag.Parent = obj
                    setupFakeGenDetection(obj)
                end
            end
        end
    end
end)

--========================================================
-- Player Tab
--========================================================

local PlayerTab = Window:CreateTab("Player Tab", 4483362458)
local Sprinting = require(ReplicatedStorage.Systems.Character.Game.Sprinting)

-- Infinite stamina toggle
PlayerTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(state)
        Sprinting.StaminaLossDisabled = state
        if state then
            Sprinting.SprintSpeed = 24
        end
    end
})

-- Custom stamina settings
local custom = false
local gain, loss, speed = 20, 10, 24

PlayerTab:CreateToggle({
    Name = "Custom Stamina",
    CurrentValue = false,
    Callback = function(state)
        custom = state
        Sprinting.StaminaLossDisabled = not state
        if state then
            Sprinting.StaminaGain = gain
            Sprinting.StaminaLoss = loss
            Sprinting.SprintSpeed = speed
        end
    end
})

PlayerTab:CreateInput({
    Name = "Stamina Gain",
    PlaceholderText = tostring(gain),
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then
            gain = n
            if custom then
                Sprinting.StaminaGain = gain
            end
        end
    end
})

PlayerTab:CreateInput({
    Name = "Stamina Loss",
    PlaceholderText = tostring(loss),
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then
            loss = n
            if custom then
                Sprinting.StaminaLoss = loss
            end
        end
    end
})

PlayerTab:CreateInput({
    Name = "Sprint Speed",
    PlaceholderText = tostring(speed),
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then
            speed = n
            if custom then
                Sprinting.SprintSpeed = speed
            end
        end
    end
})

--========================================================
-- Misc Tab
--========================================================

local MiscTab = Window:CreateTab("Misc Tab", 4483362458)
local RoundTimer = LocalPlayer.PlayerGui:WaitForChild("RoundTimer").Main

-- Round Timer position slider
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

-- Reset Round Timer position button
MiscTab:CreateButton({
    Name = "Reset Round Timer Position",
    Callback = function()
        RoundTimer.Position = UDim2.new(0.5, 0, -0.0175, 0)
    end
})

-- Block Subspaced effects toggle
MiscTab:CreateToggle({
    Name = "Block Subspaced Effects",
    CurrentValue = false,
    Callback = function(state)
        local sub = ReplicatedStorage.Modules.StatusEffects.SurvivorExclusive
        local subspace = sub:FindFirstChild("Subspaced")
        local subzero = sub:FindFirstChild("Subzerospaced")

        if state then
            if subspace then
                subspace.Name = "Subzerospaced"
            end
        else
            if subzero then
                subzero.Name = "Subspaced"
            end
        end

        Rayfield:Notify({
            Title = "Misc",
            Content = state and "Subspaced blocked!" or "Subspaced restored!",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- c00lgui Tracker
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
