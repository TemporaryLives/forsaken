----------------------------------------------------------------
-- Yet Another Forsaken Script (Skidded and ChatGPT'd Version.)
----------------------------------------------------------------

--// Rayfield Setup
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    LoadingTitle = "Loading the script...",
    LoadingSubtitle = "💫",
    ConfigurationSaving = { Enabled = false }
})

--// Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function destroyChildrenByName(obj, name)
    for _,child in ipairs(obj:GetChildren()) do
        if child.Name == name then child:Destroy() end
    end
end

--// Helper: Get Map
local function getMap()
    return workspace:FindFirstChild("Map")
        and workspace.Map:FindFirstChild("Ingame")
        and workspace.Map.Ingame:FindFirstChild("Map")
end

--// Helper: Find Closest Valid Generator
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

--// Detect if player is repairing (simple animation check)
local function isRepairing()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation and (
                track.Animation.AnimationId == "rbxassetid://82691533602949" or -- center
                track.Animation.AnimationId == "rbxassetid://122604262087779" or -- left
                track.Animation.AnimationId == "rbxassetid://130355893361522"    -- right
            ) then
                return true
            end
        end
    end
    return false
end

----------------------------------------------------------------
-- Generator Tab
----------------------------------------------------------------
local GeneratorTab = Window:CreateTab("Generator Tab", 4483362458)
local autoRepair = false
local repairCooldown = 3.1
local lastRepair = 0

GeneratorTab:CreateToggle({
    Name="Auto-Repair Generators",
    CurrentValue=false,
    Callback=function(v) autoRepair = v end
})

GeneratorTab:CreateInput({
    Name="Repair Cooldown (2.4 - 8)",
    PlaceholderText=tostring(repairCooldown),
    RemoveTextAfterFocusLost=false,
    Callback=function(val)
        local num = tonumber(val)
        if num and num >= 2.4 and num <= 8 then
            repairCooldown = num
        end
    end
})

-- Manual repair button (fires once)
GeneratorTab:CreateButton({
    Name = "Manual Repair Fire",
    Callback = function()
        local gen = getClosestGenerator(12)
        if gen and isRepairing() then
            local re = gen.Remotes:FindFirstChild("RE")
            if re then
                re:FireServer()
                lastRepair = tick()
            end
        end
    end
})

-- Auto repair loop
task.spawn(function()
    while true do
        task.wait(0.2)
        if autoRepair then
            if isRepairing() then
                local now = tick()

                -- Only fire when cooldown passes, never instantly on enter
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
                -- Reset cooldown to current time (prevents instant fire on re-entry)
                lastRepair = tick()
            end
        end
    end
end)

----------------------------------------------------------------
-- Part 2: ESP Tab
----------------------------------------------------------------
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
    Text=false, AuraPlayers=false,
    Consumables=false, Deployables=false,
    Generators=false, FakeGenerators=false,
    Footprints=false
}

-- Text ESP
local function createTextESP(character, textColor)
    if not character:FindFirstChild("HumanoidRootPart") then return end
    if character:FindFirstChild("ESPText") then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPText"
    billboard.Adornee = character.HumanoidRootPart
    billboard.Size = UDim2.new(0,100,0,25)
    billboard.StudsOffset = Vector3.new(0,3.5,0)
    billboard.AlwaysOnTop = true
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.TextColor3 = textColor
    label.Font = Enum.Font.Bodoni
    label.TextSize = 18
    label.Text = character.Name
    label.Parent = billboard
    billboard.Parent = character
end

-- Aura ESP
local function createAura(obj, color)
    if obj:FindFirstChild("PlayerAura") then return end -- skip if aura exists
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

-- Cleanup aura if "PlayerAura" overrides
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

-- Main ESP loop
task.spawn(function()
    while true do
        task.wait(0.5)
        local map = getMap()

        -- Survivors
        local survivors = workspace.Players:FindFirstChild("Survivors")
        if survivors then
            for _,char in ipairs(survivors:GetChildren()) do
                if ESPStates.Text then createTextESP(char, Colors.SurvivorText) else destroyChildrenByName(char,"ESPText") end
                if ESPStates.AuraPlayers then createAura(char, Colors.SurvivorAura) else destroyChildrenByName(char,"Aura") end
                handleAuraConflict(char)
            end
        end

        -- Killers
        local killers = workspace.Players:FindFirstChild("Killers")
        if killers then
            for _,char in ipairs(killers:GetChildren()) do
                if ESPStates.Text then createTextESP(char, Colors.KillerText) else destroyChildrenByName(char,"ESPText") end
                if ESPStates.AuraPlayers then createAura(char, Colors.KillerAura) else destroyChildrenByName(char,"Aura") end
                handleAuraConflict(char)
            end
        end

        if map then
            for _,obj in ipairs(map:GetChildren()) do
                if obj.Name == "Generator" and obj:FindFirstChild("Progress") then
                    if ESPStates.Generators and obj.Progress.Value < 100 then createAura(obj, Colors.Generator) else destroyChildrenByName(obj,"Aura") end
                elseif obj.Name == "FakeGenerator" then
                    if ESPStates.FakeGenerators then createAura(obj, Colors.FakeGenerator) else destroyChildrenByName(obj,"Aura") end
                elseif obj.Name == "Medkit" or obj.Name == "BloxyCola" then
                    if ESPStates.Consumables then createAura(obj, Colors.Consumables) else destroyChildrenByName(obj,"Aura") end
                elseif obj.Name == "BuildermanSentry" or obj.Name == "BuildermanDispenser" or string.find(obj.Name,"TaphTripwire") or obj.Name == "SubspaceTripmine" then
                    if ESPStates.Deployables then createAura(obj, Colors.Deployables) else destroyChildrenByName(obj,"Aura") end
                end
            end

            for _,folder in ipairs(workspace.Map.Ingame:GetChildren()) do
                if string.find(folder.Name,"Shadows") then
                    for _,shadow in ipairs(folder:GetChildren()) do
                        shadow.Transparency=0
                        if ESPStates.Footprints then createAura(shadow, Colors.Footprints) else destroyChildrenByName(shadow,"Aura") end
                    end
                end
            end
        end
    end
end)

-- ESP Toggles
ESPTab:CreateToggle({Name="Show ESP (Text)",CurrentValue=false,Callback=function(s) ESPStates.Text=s end})
ESPTab:CreateToggle({Name="Highlight Players",CurrentValue=false,Callback=function(s) ESPStates.AuraPlayers=s end})
ESPTab:CreateToggle({Name="Show Consumables",CurrentValue=false,Callback=function(s) ESPStates.Consumables=s end})
ESPTab:CreateToggle({Name="Show Deployables",CurrentValue=false,Callback=function(s) ESPStates.Deployables=s end})
ESPTab:CreateToggle({Name="Show Generators (<100)",CurrentValue=false,Callback=function(s) ESPStates.Generators=s end})
ESPTab:CreateToggle({Name="Show Fake Generators",CurrentValue=false,Callback=function(s) ESPStates.FakeGenerators=s end})
ESPTab:CreateToggle({Name="Show Digital Footprints",CurrentValue=false,Callback=function(s) ESPStates.Footprints=s end})

----------------------------------------------------------------
-- Part 3: Player Tab
----------------------------------------------------------------
local PlayerTab = Window:CreateTab("Player Tab",4483362458)
local Sprinting = require(ReplicatedStorage.Systems.Character.Game.Sprinting)

-- Infinite stamina
PlayerTab:CreateToggle({
    Name="Infinite Stamina",
    CurrentValue=false,
    Callback=function(state)
        Sprinting.StaminaLossDisabled=state
        if state then Sprinting.SprintSpeed=24 end
    end
})

-- Custom stamina
local custom=false
local gain,loss,speed=20,10,24
PlayerTab:CreateToggle({
    Name="Custom Stamina",
    CurrentValue=false,
    Callback=function(state)
        custom=state
        Sprinting.StaminaLossDisabled=not state
        if state then
            Sprinting.StaminaGain=gain
            Sprinting.StaminaLoss=loss
            Sprinting.SprintSpeed=speed
        end
    end
})
PlayerTab:CreateInput({Name="Stamina Gain",PlaceholderText=tostring(gain),RemoveTextAfterFocusLost=false,Callback=function(v)local n=tonumber(v) if n then gain=n if custom then Sprinting.StaminaGain=gain end end end})
PlayerTab:CreateInput({Name="Stamina Loss",PlaceholderText=tostring(loss),RemoveTextAfterFocusLost=false,Callback=function(v)local n=tonumber(v) if n then loss=n if custom then Sprinting.StaminaLoss=loss end end end})
PlayerTab:CreateInput({Name="Sprint Speed",PlaceholderText=tostring(speed),RemoveTextAfterFocusLost=false,Callback=function(v)local n=tonumber(v) if n then speed=n if custom then Sprinting.SprintSpeed=speed end end end})

----------------------------------------------------------------
-- Part 4: Misc Tab (Updated)
----------------------------------------------------------------
local MiscTab = Window:CreateTab("Misc Tab", 4483362458)

-- Round Timer reference
local RoundTimer = LocalPlayer.PlayerGui:WaitForChild("RoundTimer").Main

-- Slider for Round Timer X axis
MiscTab:CreateSlider({
    Name = "Round Timer X Position",
    Range = {-1, 1}, -- Roblox UDim2 scale range
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.5, -- Default center
    Callback = function(val)
        RoundTimer.Position = UDim2.new(val, 0, RoundTimer.Position.Y.Scale, RoundTimer.Position.Y.Offset)

        Rayfield:Notify({
            Title = "Misc",
            Content = "Round Timer X set to " .. tostring(val),
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- Block Subspaced Effects toggle
MiscTab:CreateToggle({
    Name = "Block Subspaced Effects",
    CurrentValue = false,
    Callback = function(state)
        local sub = ReplicatedStorage.Modules.StatusEffects.SurvivorExclusive
        if sub:FindFirstChild("Subspaced") then
            sub.Subspaced.Name = state and "SubzeroSpaced" or "Subspaced"
        end

        Rayfield:Notify({
            Title = "Misc",
            Content = state and "Subspaced blocked!" or "Subspaced restored!",
            Duration = 2,
            Image = 4483362458
        })
    end
})
