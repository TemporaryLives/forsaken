--========================================
-- Rayfield setup + helpers
--========================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
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

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Generic helpers
local function destroyChildrenByName(obj, name)
    if not obj then return end
    for _, child in ipairs(obj:GetChildren()) do
        if child.Name == name then
            child:Destroy()
        end
    end
end

-- Robust getMap() — returns workspace.Map.Ingame.Map or nil
local function getMap()
    local root = workspace:FindFirstChild("Map")
    if not root then return nil end
    local ingame = root:FindFirstChild("Ingame")
    if not ingame then return nil end
    return ingame:FindFirstChild("Map")
end

-- getClosestGenerator returns generator, distance (or nil)
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

-- Correct repair animation IDs (use the three you provided)
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

--========================================================
-- Generator Tab
--========================================================
local GeneratorTab = Window:CreateTab("Generator Tab", 96559240692119)

local autoRepair = false
local repairCooldown = 6.2
local lastRepair = 0
local lastManual = 0

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
        if now - lastManual < 2.4 then
            Rayfield:Notify({
                Title = "Cooldown",
                Content = "Minimum 2.4s between manual fires!",
                Duration = 1.5
            })
            return
        end

        local gen = getClosestGenerator(12)
        if gen and isRepairing() then
            local re = gen.Remotes:FindFirstChild("RE")
            if re then
                re:FireServer()
                lastManual = now
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
        elseif not isRepairing() then
            lastRepair = tick()
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
    Extra = false,
    AuraPlayers = false,
    Consumables = false,
    Deployables = false,
    Generators = false,
    FakeGenerators = false,
    Footprints = false
}

local function removeESP(char)
    destroyChildrenByName(char, "ESPGui")
    destroyChildrenByName(char, "Aura")
end

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

local function getAllValidPlayers()
    local result = {}
    for _, folder in ipairs({workspace.Players:FindFirstChild("Survivors"), workspace.Players:FindFirstChild("Killers")}) do
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

local function createESP(character, textColor)
    destroyChildrenByName(character, "ESPGui")

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPGui"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 180, 0, 28)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 4.5, 0)

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    layout.Parent = billboard

    local mainLabel = Instance.new("TextLabel")
    mainLabel.Size = UDim2.new(1, 0, 0, 18)
    mainLabel.BackgroundTransparency = 1
    mainLabel.TextColor3 = textColor
    mainLabel.Font = Enum.Font.GothamBold
    mainLabel.TextSize = 16
    mainLabel.Text = character.Name
    mainLabel.Parent = billboard

    if ESPStates.Extra then
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
        elseif ESPStates.Deployables and (obj.Name == "BuildermanSentry" or obj.Name == "BuildermanDispenser" or string.find(obj.Name, "TaphTripwire") or obj.Name == "SubspaceTripmine") then
            createAura(obj, Colors.Deployables)
        else
            destroyChildrenByName(obj, "Aura")
        end
    end

    local ingameMap = getMap()
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

task.spawn(function()
    while true do
        task.wait(0.5)
        updateObjectHighlights()

        for _, char in ipairs(getAllValidPlayers()) do
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and not workspace.Ragdolls:FindFirstChild(char.Name) then
                local isKiller = workspace.Players.Killers:FindFirstChild(char.Name) ~= nil
                if ESPStates.Text then
                    createESP(char, isKiller and Colors.KillerText or Colors.SurvivorText)
                else
                    removeESP(char)
                end

                if ESPStates.AuraPlayers then
                    createAura(char, isKiller and Colors.KillerAura or Colors.SurvivorAura)
                else
                    destroyChildrenByName(char, "Aura")
                end
            else
                removeESP(char)
            end
        end
    end
end)

ESPTab:CreateToggle({ Name = "Show ESP", CurrentValue = false, Callback = function(s) ESPStates.Text = s end })
ESPTab:CreateToggle({ Name = "Show Extra ESP Info", CurrentValue = false, Callback = function(s)
    ESPStates.Extra = s
    for _, char in ipairs(getAllValidPlayers()) do
        destroyChildrenByName(char, "ESPGui")
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
-- Try to require Sprinting safely
local SprintingModule
local ok, err = pcall(function()
    SprintingModule = require(ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Character"):WaitForChild("Game"):WaitForChild("Sprinting"))
end)
if not ok then
    -- If require fails, warn but keep UI (attempts to require again when toggles used)
    Rayfield:Notify({Title="Player", Content="Couldn't require Sprinting module right now.", Duration=2})
end

local custom = false
local gain, loss, speed = 20, 10, 24

local function applyStaminaSettings()
    local success2, m = pcall(function()
        return require(ReplicatedStorage.Systems.Character.Game.Sprinting)
    end)
    if not success2 or not m then
        Rayfield:Notify({Title="Player", Content="Sprinting module not available.", Duration=1.8})
        return
    end
    if custom then
        m.StaminaGain = gain
        m.StaminaLoss = loss
        m.SprintSpeed = speed
        m.StaminaLossDisabled = false
    else
        -- either infinite or restore defaults depending on toggle
        -- We'll keep default values (from your previous notes)
        m.StaminaGain = 20
        m.StaminaLoss = 10
        m.SprintSpeed = 24
    end
end

PlayerTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Callback = function(state)
        custom = false
        local success2, m = pcall(function() return require(ReplicatedStorage.Systems.Character.Game.Sprinting) end)
        if success2 and m then
            m.StaminaLossDisabled = state
            if state then m.SprintSpeed = 24 end
        else
            Rayfield:Notify({Title="Player", Content="Sprinting module not ready.", Duration=1.5})
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

PlayerTab:CreateInput({
    Name = "Stamina Gain",
    PlaceholderText = tostring(gain),
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then gain = n; if custom then applyStaminaSettings() end end
    end
})

PlayerTab:CreateInput({
    Name = "Stamina Loss",
    PlaceholderText = tostring(loss),
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then loss = n; if custom then applyStaminaSettings() end end
    end
})

PlayerTab:CreateInput({
    Name = "Sprint Speed",
    PlaceholderText = tostring(speed),
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local n = tonumber(v)
        if n then speed = n; if custom then applyStaminaSettings() end end
    end
})

--========================================================
-- Misc Tab
--========================================================
local MiscTab = Window:CreateTab("Misc Tab", 72612560514066)

local RoundTimer = LocalPlayer.PlayerGui:WaitForChild("RoundTimer").Main

-- Disable Privated Stats button
MiscTab:CreateButton({
    Name = "Disable Privated Stats",
    Callback = function()
        local privacyFolder = Players.LocalPlayer:FindFirstChild("PlayerData") 
            and Players.LocalPlayer.PlayerData:FindFirstChild("Settings") 
            and Players.LocalPlayer.PlayerData.Settings:FindFirstChild("Privacy")

        if privacyFolder then
            for _, child in ipairs(privacyFolder:GetChildren()) do
                child:Destroy()
            end
            Rayfield:Notify({
                Title = "Misc",
                Content = "Who needed to hide their stats anyways.",
                Duration = 3,
                Image = 4483362458
            })
        else
            Rayfield:Notify({
                Title = "Misc",
                Content = "Privacy folder not found.",
                Duration = 3,
                Image = 4483362458
            })
        end
    end
})

MiscTab:CreateSlider({
    Name = "Round Timer X Position",
    Range = {0.2, 0.8},
    Increment = 0.01,
    CurrentValue = 0.5,
    Callback = function(val)
        RoundTimer.Position = UDim2.new(val, 0, RoundTimer.Position.Y.Scale, RoundTimer.Position.Y.Offset)
    end
})

MiscTab:CreateButton({
    Name = "Reset Round Timer Position",
    Callback = function()
        RoundTimer.Position = UDim2.new(0.5, 0, -0.0175, 0)
    end
})

MiscTab:CreateToggle({
    Name = "Block Subspaced Effects",
    CurrentValue = false,
    Callback = function(state)
        local sub = ReplicatedStorage.Modules.StatusEffects.SurvivorExclusive
        local subspace = sub:FindFirstChild("Subspaced")
        local subzero = sub:FindFirstChild("Subzerospaced")

        if state then
            if subspace then subspace.Name = "Subzerospaced" end
        else
            if subzero then subzero.Name = "Subspaced" end
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
            if teleported then
                notify("c00lgui Tracker","@"..player.Name.." teleported.")
            else
                notify("c00lgui Tracker","@"..player.Name.."'s c00lgui cancelled.")
            end
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