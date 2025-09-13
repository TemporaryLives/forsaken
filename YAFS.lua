--=====================================================================--
-- Yet Another Forsaken Script (Skidded, don't expect it to be polished) --
--=====================================================================--

--// Rayfield Setup
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    Icon = 92999214922543,
    LoadingTitle = "Loading the script...",
    LoadingSubtitle = "💫",
    ShowText = "Menu",
    ConfigurationSaving = {
        Enabled = false
    }
})

-- Ensure General table exists
Rayfield.settingsTable.General = Rayfield.settingsTable.General or {}
Rayfield.settingsTable.General.rayfieldprompts = Rayfield.settingsTable.General.rayfieldprompts or {Value = false}

-- Now set it safely
Rayfield.settingsTable.General.rayfieldprompts.Value = false

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
local repairCooldown = 6.2
local lastRepair = 0

GeneratorTab:CreateToggle({
    Name = "Auto-Repair Generators",
    CurrentValue = false,
    Callback = function(v)
        autoRepair = v
    end
})

GeneratorTab:CreateInput({
    Name = "Repair Cooldown (2.4 - 15)",
    PlaceholderText = tostring(repairCooldown),
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        local num = tonumber(val)
        if num and num >= 2.4 and num <= 15 then
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
                Content = "You're firing it too fast!",
                Duration = 1.5
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

local ESPTab = Window:CreateTab("ESP Tab", 114055269167425)

local Colors = {
    SurvivorText   = Color3.fromRGB(255,191,0),
    KillerText     = Color3.fromRGB(255,0,0),
    SurvivorAura   = Color3.fromRGB(255,191,0),
    KillerAura     = Color3.fromRGB(255,0,0),
    Consumables    = Color3.fromRGB(255,106,180),
    Deployables    = Color3.fromRGB(191,255,191),
    Generator      = Color3.fromRGB(255,255,255),
    FakeGenerator  = Color3.fromRGB(128,0,128),
    Footprints     = Color3.fromRGB(255,0,0)
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

-- Helper to destroy specific children
local function destroyChildrenByName(obj, name)
    for _, child in ipairs(obj:GetChildren()) do
        if child.Name == name then
            child:Destroy()
        end
    end
end

-- Remove ESP & Aura from a character
local function removeESP(char)
    destroyChildrenByName(char, "ESPGui")
    destroyChildrenByName(char, "Aura")
end

-- Create Aura Highlight
local function createAura(obj, color)
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

-- Return all valid player characters (Survivors + Killers) excluding LocalPlayer
local function getAllValidPlayers()
    local result = {}
    local survivorsFolder = workspace.Players:FindFirstChild("Survivors")
    local killersFolder = workspace.Players:FindFirstChild("Killers")
    for _, folder in ipairs({survivorsFolder, killersFolder}) do
        if folder then
            for _, char in ipairs(folder:GetChildren()) do
                if char ~= LocalPlayer.Character then
                    table.insert(result, char)
                end
            end
        end
    end
    return result
end

-- Create Player ESP with UIListLayout
local function createESP(character, textColor)
    if character:FindFirstChild("ESPGui") then
        destroyChildrenByName(character, "ESPGui") -- refresh ESP
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPGui"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 180, 0, 28) -- smaller height for tighter spacing
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 4.5, 0)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1) -- tight spacing
    layout.Parent = billboard

    -- Main Name Label
    local mainLabel = Instance.new("TextLabel")
    mainLabel.Size = UDim2.new(1, 0, 0, 18)
    mainLabel.BackgroundTransparency = 1
    mainLabel.TextColor3 = textColor
    mainLabel.Font = Enum.Font.GothamBold
    mainLabel.TextSize = 16
    mainLabel.Text = character.Name
    mainLabel.Parent = billboard

    -- Extra Info (@username + HP)
    if ESPExtraInfo then
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            local extraLabel = Instance.new("TextLabel")
            extraLabel.Size = UDim2.new(1, 0, 0, 16)
            extraLabel.BackgroundTransparency = 1
            extraLabel.TextColor3 = Color3.fromRGB(255,255,255)
            extraLabel.Font = Enum.Font.GothamBold
            extraLabel.TextSize = 14
            extraLabel.Text = "@" .. player.Name .. " | HP: " .. math.floor(humanoid.Health)
            extraLabel.Parent = billboard

            humanoid.HealthChanged:Connect(function(hp)
                if extraLabel.Parent then
                    extraLabel.Text = "@" .. player.Name .. " | HP: " .. math.floor(hp)
                end
            end)
        end
    end

    billboard.Parent = character
end

-- Update highlights for map objects
local function updateObjectHighlights()
    local map = getMap()
    if not map then return end

    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and ESPStates.Generators and obj:FindFirstChild("Progress") and obj.Progress.Value < 100 then
            createAura(obj, Colors.Generator)
        elseif obj.Name == "FakeGenerator" and ESPStates.FakeGenerators then
            createAura(obj, Colors.FakeGenerator)
        elseif (obj.Name == "Medkit" or obj.Name == "BloxyCola") and ESPStates.Consumables then
            createAura(obj, Colors.Consumables)
        elseif (obj.Name == "BuildermanSentry" or obj.Name == "BuildermanDispenser" or string.find(obj.Name, "TaphTripwire") or obj.Name == "SubspaceTripmine") and ESPStates.Deployables then
            createAura(obj, Colors.Deployables)
        else
            destroyChildrenByName(obj, "Aura")
        end
    end

    -- Footprints
    local ingameMap = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") and workspace.Map.Ingame:FindFirstChild("Map")
    if ingameMap then
        for _, folder in ipairs(ingameMap:GetChildren()) do
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

-- Remove ESP from Ragdolls
local function trackRagdolls()
    local ragdollsFolder = workspace:FindFirstChild("Ragdolls")
    if not ragdollsFolder then return end
    for _, ragdoll in ipairs(ragdollsFolder:GetChildren()) do
        if not ragdoll:FindFirstChild("CleanedESP") then
            local tag = Instance.new("BoolValue")
            tag.Name = "CleanedESP"
            tag.Parent = ragdoll
            removeESP(ragdoll)
        end
    end
end

-- Main ESP Loop
task.spawn(function()
    while true do
        task.wait(0.5)
        trackRagdolls()
        updateObjectHighlights()

        for _, char in ipairs(getAllValidPlayers()) do
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local color = workspace.Players.Killers:FindFirstChild(char.Name) and Colors.KillerText or Colors.SurvivorText
                if ESPStates.Text then
                    createESP(char, color)
                else
                    removeESP(char)
                end

                if ESPStates.AuraPlayers then
                    local auraColor = workspace.Players.Killers:FindFirstChild(char.Name) and Colors.KillerAura or Colors.SurvivorAura
                    createAura(char, auraColor)
                else
                    destroyChildrenByName(char, "Aura")
                end
            else
                removeESP(char)
            end
        end
    end
end)

-- Distance-based scaling & 700-stud cutoff
RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end

    for _, char in ipairs(getAllValidPlayers()) do
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (cam.CFrame.Position - hrp.Position).Magnitude
            local gui = char:FindFirstChild("ESPGui")
            if gui then
                gui.Enabled = dist <= 700
                for _, label in ipairs(gui:GetChildren()) do
                    if label:IsA("TextLabel") then
                        local scale = math.clamp(18 - (dist * 0.02), 13, 18)
                        label.TextSize = label.TextSize > 14 and scale or math.clamp(scale - 2, 11, 14)
                    end
                end
            end
        end
    end
end)

-- ESP Toggles
ESPTab:CreateToggle({ Name = "Show ESP", CurrentValue = false, Callback = function(s) ESPStates.Text = s end })
ESPTab:CreateToggle({ Name = "Show Extra ESP Info", CurrentValue = false, Callback = function(s)
    ESPExtraInfo = s
    -- refresh all ESP to apply new extra info
    for _, char in ipairs(getAllValidPlayers()) do
        destroyChildrenByName(char, "ESPGui")
    end
end })
ESPTab:CreateToggle({ Name = "Highlight Players", CurrentValue = false, Callback = function(s)
    ESPStates.AuraPlayers = s
    for _, char in ipairs(getAllValidPlayers()) do
        if s then
            local auraColor = workspace.Players.Killers:FindFirstChild(char.Name) and Colors.KillerAura or Colors.SurvivorAura
            createAura(char, auraColor)
        else
            destroyChildrenByName(char, "Aura")
        end
    end
end })
ESPTab:CreateToggle({ Name = "Show Consumables", CurrentValue = false, Callback = function(s) ESPStates.Consumables = s end })
ESPTab:CreateToggle({ Name = "Show Deployables", CurrentValue = false, Callback = function(s) ESPStates.Deployables = s end })
ESPTab:CreateToggle({ Name = "Show Generators (<100)", CurrentValue = false, Callback = function(s) ESPStates.Generators = s end })
ESPTab:CreateToggle({ Name = "Show Fake Generators", CurrentValue = false, Callback = function(s) ESPStates.FakeGenerators = s end })
ESPTab:CreateToggle({ Name = "Show Digital Footprints", CurrentValue = false, Callback = function(s) ESPStates.Footprints = s end })


--========================================================
-- Player Tab
--========================================================

local PlayerTab = Window:CreateTab("Player Tab", 89251076279188)
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

local MiscTab = Window:CreateTab("Misc Tab", 72612560514066)

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
