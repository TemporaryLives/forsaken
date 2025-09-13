--=====================================================================--
-- Yet Another Forsaken Script (Skidded, don't expect it to be good.)
--=====================================================================--

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
    local root = workspace:FindFirstChild("Map")
    if not root then return nil end
    local ingame = root:FindFirstChild("Ingame")
    if not ingame then return nil end
    return ingame:FindFirstChild("Map")
end

--========================================================
-- Generator Tab
--========================================================
local GeneratorTab = Window:CreateTab("Generator Tab", 96559240692119)

local autoRepair = false
local repairCooldown = 6.2
local lastRepair = 0

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
            ) then return true end
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
    Name = "Repair Cooldown (2.4 - 15)",
    PlaceholderText = tostring(repairCooldown),
    RemoveTextAfterFocusLost = false,
    Callback = function(val)
        local num = tonumber(val)
        if num and num >= 2.4 and num <= 15 then repairCooldown = num end
    end
})

GeneratorTab:CreateButton({
    Name = "Manual Repair Fire",
    Callback = function()
        local now = tick()
        if now - lastRepair < 2.4 then
            Rayfield:Notify({Title="Cooldown",Content="You're firing too fast!",Duration=1.5})
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
        if autoRepair and isRepairing() then
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
        elseif autoRepair then
            lastRepair = tick()
        end
    end
end)

--========================================================
-- ESP Tab
--========================================================
local ESPTab = Window:CreateTab("ESP", 4483362458)

-- ESP State Table
ESPStates = {
    Players = false,
    Chams = false,
    Items = false,
    Generators = false,
    Footprints = false
}

-- ESP Colors
Colors = {
    PlayerNames = Color3.fromRGB(255, 255, 255),
    SurvivorChams = Color3.fromRGB(255, 191, 0),
    KillerChams = Color3.fromRGB(255, 0, 0),
    Items = Color3.fromRGB(0, 255, 0),
    Generators = Color3.fromRGB(0, 200, 255),
    Footprints = Color3.fromRGB(255, 0, 255)
}

--========================================================
-- ESP Functions
--========================================================
local function updatePlayerESP()
    local surv = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
    local kill = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if not surv or not kill then return end

    local function handleModel(model, isKiller)
        if ESPStates.Players then
            createESP(model, Colors.PlayerNames)
        else
            destroyChildrenByName(model, "ESPTag")
        end

        if ESPStates.Chams then
            local c = isKiller and Colors.KillerChams or Colors.SurvivorChams
            createHighlight(model, c)
        else
            destroyChildrenByName(model, "Highlight")
        end
    end

    for _, m in ipairs(surv:GetChildren()) do handleModel(m, false) end
    for _, m in ipairs(kill:GetChildren()) do handleModel(m, true) end
end

local function updateItemESP()
    local map = getMap()
    if not map then return end
    for _, tool in ipairs(map:GetChildren()) do
        if tool:IsA("Tool") then
            if ESPStates.Items then
                createESP(tool, Colors.Items)
            else
                destroyChildrenByName(tool, "ESPTag")
            end
        end
    end
end

local function updateGeneratorESP()
    local map = getMap()
    if not map then return end
    local genFolder = map:FindFirstChild("Generator")
    if not genFolder then return end
    for _, gen in ipairs(genFolder:GetChildren()) do
        if ESPStates.Generators then
            createESP(gen, Colors.Generators)
        else
            destroyChildrenByName(gen, "ESPTag")
        end
    end
end

local function updateFootprints()
    local map = getMap()
    if not map then return end
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

--========================================================
-- Heartbeat Loop (refreshes ESP)
--========================================================
RunService.Heartbeat:Connect(function()
    updatePlayerESP()
    updateItemESP()
    updateGeneratorESP()
    updateFootprints()
end)

--========================================================
-- GUI Toggles
--========================================================
ESPTab:CreateToggle({
    Name = "Show Player ESP",
    CurrentValue = false,
    Callback = function(s) ESPStates.Players = s end
})

ESPTab:CreateToggle({
    Name = "Show Player Chams",
    CurrentValue = false,
    Callback = function(s) ESPStates.Chams = s end
})

ESPTab:CreateToggle({
    Name = "Show Item ESP",
    CurrentValue = false,
    Callback = function(s) ESPStates.Items = s end
})

ESPTab:CreateToggle({
    Name = "Show Generator ESP",
    CurrentValue = false,
    Callback = function(s) ESPStates.Generators = s end
})

ESPTab:CreateToggle({
    Name = "Show Digital Footprints",
    CurrentValue = false,
    Callback = function(s) ESPStates.Footprints = s end
})

--========================================================
-- Color Pickers
--========================================================
ESPTab:CreateColorPicker({
    Name = "Player Name ESP Color",
    Color = Colors.PlayerNames,
    Callback = function(c) Colors.PlayerNames = c end
})

ESPTab:CreateColorPicker({
    Name = "Survivor Chams Color",
    Color = Colors.SurvivorChams,
    Callback = function(c) Colors.SurvivorChams = c end
})

ESPTab:CreateColorPicker({
    Name = "Killer Chams Color",
    Color = Colors.KillerChams,
    Callback = function(c) Colors.KillerChams = c end
})

ESPTab:CreateColorPicker({
    Name = "Item ESP Color",
    Color = Colors.Items,
    Callback = function(c) Colors.Items = c end
})

ESPTab:CreateColorPicker({
    Name = "Generator ESP Color",
    Color = Colors.Generators,
    Callback = function(c) Colors.Generators = c end
})

ESPTab:CreateColorPicker({
    Name = "Footprints ESP Color",
    Color = Colors.Footprints,
    Callback = function(c) Colors.Footprints = c end
})

--========================================================
-- Player Tab
--========================================================
local PlayerTab = Window:CreateTab("Player Tab", 89251076279188)
local Sprinting = require(ReplicatedStorage.Systems.Character.Game.Sprinting)

PlayerTab:CreateToggle({
    Name="Infinite Stamina",CurrentValue=false,
    Callback=function(state)
        Sprinting.StaminaLossDisabled=state
        if state then Sprinting.SprintSpeed=24 end
    end
})

local custom=false
local gain,loss,speed=20,10,24
PlayerTab:CreateToggle({
    Name="Custom Stamina",CurrentValue=false,
    Callback=function(state)
        custom=state; Sprinting.StaminaLossDisabled=not state
        if state then
            Sprinting.StaminaGain=gain; Sprinting.StaminaLoss=loss; Sprinting.SprintSpeed=speed
        end
    end
})
PlayerTab:CreateInput({Name="Stamina Gain",PlaceholderText=tostring(gain),RemoveTextAfterFocusLost=false,
    Callback=function(v) local n=tonumber(v) if n then gain=n if custom then Sprinting.StaminaGain=gain end end end})
PlayerTab:CreateInput({Name="Stamina Loss",PlaceholderText=tostring(loss),RemoveTextAfterFocusLost=false,
    Callback=function(v) local n=tonumber(v) if n then loss=n if custom then Sprinting.StaminaLoss=loss end end end})
PlayerTab:CreateInput({Name="Sprint Speed",PlaceholderText=tostring(speed),RemoveTextAfterFocusLost=false,
    Callback=function(v) local n=tonumber(v) if n then speed=n if custom then Sprinting.SprintSpeed=speed end end end}
  
  --========================================================
-- Misc Tab
--========================================================
local MiscTab = Window:CreateTab("Misc Tab", 72612560514066)
local RoundTimer = LocalPlayer.PlayerGui:WaitForChild("RoundTimer").Main

MiscTab:CreateSlider({
    Name="Round Timer X Position",Range={0.2,0.8},Increment=0.01,CurrentValue=0.5,
    Callback=function(val) RoundTimer.Position=UDim2.new(val,0,RoundTimer.Position.Y.Scale,RoundTimer.Position.Y.Offset) end
})
MiscTab:CreateButton({Name="Reset Round Timer Position",Callback=function() RoundTimer.Position=UDim2.new(0.5,0,-0.0175,0) end})

MiscTab:CreateToggle({
    Name="Block Subspaced Effects",CurrentValue=false,
    Callback=function(state)
        local sub=ReplicatedStorage.Modules.StatusEffects.SurvivorExclusive
        if state and sub:FindFirstChild("Subspaced") then sub.Subspaced.Name="Subzerospaced"
        elseif not state and sub:FindFirstChild("Subzerospaced") then sub.Subzerospaced.Name="Subspaced" end
        Rayfield:Notify({Title="Misc",Content=state and "Subspaced blocked!" or "Subspaced restored!",Duration=2,Image=4483362458})
    end
})

-- c00lgui Tracker
local trackerEnabled=false
local cooldownTime=30
local lastTrigger,activeC00lParts={},{}

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
    if model:FindFirstChild("c00lgui") then setup(model.c00lgui) end
    model.ChildAdded:Connect(function(ch) if ch.Name=="c00lgui" then setup(ch) end end)
end

RunService.Heartbeat:Connect(function()
    if not trackerEnabled then return end
    for player,c00l in pairs(activeC00lParts) do
        local model=player.Character
        if not model or not c00l or not c00l:IsDescendantOf(model) then
            local teleported=false
            local hrp=model and model:FindFirstChild("HumanoidRootPart")
            if hrp then
                local map=getMap()
                local spawns=(map and map:FindFirstChild("SpawnPoints") and map.SpawnPoints:FindFirstChild("Survivors")) and map.SpawnPoints.Survivors:GetChildren() or {}
                for _,s in ipairs(spawns) do
                    if s.Name=="SurvivorSpawn" and (hrp.Position-s.Position).Magnitude<=25 then teleported=true break end
                end
            end
            if teleported then notify("c00lgui Tracker","@"..player.Name.." teleported.") else notify("c00lgui Tracker","@"..player.Name.."'s c00lgui cancelled.") end
            activeC00lParts[player]=nil
        end
    end
end)

MiscTab:CreateToggle({
    Name="c00lgui Tracker",CurrentValue=false,
    Callback=function(state)
        trackerEnabled=state
        if trackerEnabled then
            local surv=workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Survivors")
            if surv then
                for _,m in ipairs(surv:GetChildren()) do trackPlayer(m) end
                surv.ChildAdded:Connect(function(m) trackPlayer(m) end)
            end
        else activeC00lParts,lastTrigger={},{} end
    end
})