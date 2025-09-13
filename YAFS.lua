--========================================
-- Rayfield setup + helpers
--========================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    LoadingTitle = "Loading the script...",
    LoadingSubtitle = "💫",
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

--========================================
-- Generator Tab
--========================================
local autoRepair = false
local repairCooldown = 6.2
local lastRepair = 0

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
        if num and num >= 2.4 and num <= 15 then
            repairCooldown = num
            Rayfield:Notify({Title="Generator", Content="Cooldown set to "..num, Duration=1.4})
        else
            Rayfield:Notify({Title="Generator", Content="Cooldown must be 2.4 - 15", Duration=1.6})
        end
    end
})

GeneratorTab:CreateButton({
    Name = "Manual Repair Fire (nearest)",
    Callback = function()
        local now = tick()
        if now - lastRepair < 2.4 then
            Rayfield:Notify({Title="Generator", Content="You're firing too fast!", Duration=1.2})
            return
        end

        local gen, dist = getClosestGenerator(12)
        if not gen then
            Rayfield:Notify({Title="Generator", Content="No generator found nearby.", Duration=1.5})
            return
        end

        local re = gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")
        if re then
            -- Manual fire regardless of whether you're currently playing the repair animation
            local ok, err = pcall(function() re:FireServer() end)
            if ok then
                lastRepair = now
                Rayfield:Notify({Title="Generator", Content="Fired RE on generator ("..tostring(math.floor(dist)).." studs)", Duration=1.2})
            else
                Rayfield:Notify({Title="Generator", Content="Failed to fire: "..tostring(err), Duration=1.6})
            end
        else
            Rayfield:Notify({Title="Generator", Content="Generator remote not found.", Duration=1.5})
        end
    end
})

-- Auto-repair: only fires while player is actually repairing and respects cooldown
task.spawn(function()
    while task.wait(0.2) do
        if not autoRepair then
            -- keep lastRepair fresh to avoid instant-fire after enabling
            lastRepair = tick()
        else
            if isRepairing() then
                local now = tick()
                if now - lastRepair >= repairCooldown then
                    local gen, dist = getClosestGenerator(12)
                    if gen and gen:FindFirstChild("Remotes") then
                        local re = gen.Remotes:FindFirstChild("RE")
                        if re then
                            local ok, err = pcall(function() re:FireServer() end)
                            if ok then
                                lastRepair = now
                            end
                        end
                    end
                end
            end
        end
    end
end)

--========================================
-- ESP Tab (optimized + chams + footprints)
--========================================
-- Color & state tables
local Colors = {
    PlayerNames    = Color3.fromRGB(255,255,255),
    SurvivorText   = Color3.fromRGB(255,191,0),
    KillerText     = Color3.fromRGB(255,0,0),
    SurvivorChams  = Color3.fromRGB(255,191,0),
    KillerChams    = Color3.fromRGB(255,0,0),
    Consumables    = Color3.fromRGB(255,106,180),
    Deployables    = Color3.fromRGB(191,255,191),
    Generator      = Color3.fromRGB(255,255,255),
    FakeGenerator  = Color3.fromRGB(128,0,128),
    Footprints     = Color3.fromRGB(255,0,0)
}

local ESPStates = {
    Text = false,
    Chams = false,
    Consumables = false,
    Deployables = false,
    Generators = false,
    FakeGenerators = false,
    Footprints = false
}

local ESPExtraInfo = false

-- Caches
local playerESPCache = {}    -- [character] = {Billboard, MainLabel, ExtraLabel, Aura}
local objectAuraCache = {}   -- [object] = Highlight
local footprintCache = {}    -- [part] = Highlight

-- Generic aura creator used for map objects & footprints & players (name 'Aura' so destroyChildrenByName works)
local function createAura(obj, color)
    if not obj or not obj.Parent then return end
    if obj:FindFirstChild("Aura") then
        -- update colors if already exists
        local h = obj:FindFirstChild("Aura")
        if h and h:IsA("Highlight") then
            h.FillColor = color
            h.OutlineColor = color
        end
        return
    end
    local h = Instance.new("Highlight")
    h.Name = "Aura"
    h.Adornee = obj
    h.FillColor = color
    h.FillTransparency = 0.5
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.Parent = obj
end

local function removeAura(obj)
    if not obj then return end
    destroyChildrenByName(obj, "Aura")
end

-- Player ESP creation (doesn't spam - created once per character)
local function createPlayerESP(character)
    if not character or playerESPCache[character] then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPGui"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 180, 0, 28)
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

    local extraLabel = nil
    if ESPExtraInfo then
        local plr = Players:GetPlayerFromCharacter(character)
        if plr then
            extraLabel = Instance.new("TextLabel")
            extraLabel.Size = UDim2.new(1,0,0,16)
            extraLabel.BackgroundTransparency = 1
            extraLabel.TextColor3 = Color3.fromRGB(255,255,255)
            extraLabel.Font = Enum.Font.GothamBold
            extraLabel.TextSize = 14
            extraLabel.Text = "@"..plr.Name.." | HP: "..math.floor(humanoid.Health)
            extraLabel.Parent = billboard
            humanoid.HealthChanged:Connect(function(hp)
                if extraLabel.Parent then extraLabel.Text = "@"..plr.Name.." | HP: "..math.floor(hp) end
            end)
        end
    end

    -- create placeholder aura (visibility controlled later)
    createAura(character, Colors.SurvivorChams)

    playerESPCache[character] = {
        Billboard = billboard,
        MainLabel = mainLabel,
        ExtraLabel = extraLabel
    }
end

local function removePlayerESP(character)
    local cache = playerESPCache[character]
    if not cache then return end
    if cache.Billboard and cache.Billboard.Parent then cache.Billboard:Destroy() end
    removeAura(character)
    playerESPCache[character] = nil
end

local function updatePlayerESP(character)
    local cache = playerESPCache[character]
    if not cache then return end
    local isKiller = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers") and workspace.Players.Killers:FindFirstChild(character.Name)
    local nameColor = isKiller and Colors.KillerText or Colors.SurvivorText
    cache.MainLabel.TextColor3 = Colors.PlayerNames or nameColor

    -- visibility toggles
    cache.Billboard.Enabled = ESPStates.Text
    if ESPStates.Chams then
        local c = isKiller and Colors.KillerChams or Colors.SurvivorChams
        createAura(character, c)
    else
        removeAura(character)
    end
end

-- Update map object highlights (generators, items, deployables, fake gens)
local function updateObjectHighlights()
    local map = getMap()
    if not map then return end

    -- iterate map children
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and ESPStates.Generators and obj:FindFirstChild("Progress") and obj.Progress.Value < 100 then
            createAura(obj, Colors.Generator)
        elseif obj.Name == "FakeGenerator" and ESPStates.FakeGenerators then
            createAura(obj, Colors.FakeGenerator)
        elseif (obj.Name == "Medkit" or obj.Name == "BloxyCola") and ESPStates.Consumables then
            createAura(obj, Colors.Consumables)
        elseif (obj.Name == "BuildermanSentry" or obj.Name == "BuildermanDispenser" or (obj.Name and string.find(obj.Name, "TaphTripwire")) or obj.Name == "SubspaceTripmine") and ESPStates.Deployables then
            createAura(obj, Colors.Deployables)
        else
            removeAura(obj)
        end
    end
end

-- Footprints logic (scans "Shadows" folders inside workspace.Map.Ingame)
local function updateFootprints()
    local ingameRoot = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame")
    if not ingameRoot then return end
    for _, folder in ipairs(ingameRoot:GetChildren()) do
        if string.find(folder.Name or "", "Shadows") then
            for _, shadow in ipairs(folder:GetChildren()) do
                if shadow:IsA("BasePart") then
                    shadow.Transparency = 0
                    if ESPStates.Footprints then
                        createAura(shadow, Colors.Footprints)
                    else
                        removeAura(shadow)
                    end
                end
            end
        end
    end
end

-- cleanup caches when players/objects removed
local function cleanupCaches()
    for char, _ in pairs(playerESPCache) do
        if not char.Parent or not char:IsDescendantOf(workspace) then
            removePlayerESP(char)
        end
    end
end

-- Main ESP updater (runs periodically; not per-frame)
task.spawn(function()
    while task.wait(0.6) do
        -- create/update player ESP for survivors and killers
        local playersRoot = workspace:FindFirstChild("Players")
        if playersRoot then
            local surv = playersRoot:FindFirstChild("Survivors")
            local kill = playersRoot:FindFirstChild("Killers")
            for _, folder in ipairs({surv, kill}) do
                if folder then
                    for _, char in ipairs(folder:GetChildren()) do
                        if char ~= LocalPlayer.Character then
                            if not playerESPCache[char] then createPlayerESP(char) end
                            updatePlayerESP(char)
                        end
                    end
                end
            end
        end

        -- cleanup stale
        cleanupCaches()

        -- object highlights + footprints
        updateObjectHighlights()
        updateFootprints()
    end
end)

-- RenderStepped scaling for text + distance culling (runs per-frame)
RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    for char, cache in pairs(playerESPCache) do
        if cache and cache.Billboard and cache.Billboard.Parent then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (cam.CFrame.Position - hrp.Position).Magnitude
                cache.Billboard.Enabled = ESPStates.Text and dist <= 700
                -- scale text size based on distance
                for _, ui in ipairs(cache.Billboard:GetChildren()) do
                    if ui:IsA("TextLabel") then
                        local scale = math.clamp(18 - (dist * 0.02), 13, 18)
                        ui.TextSize = ui.TextSize > 14 and scale or math.clamp(scale - 2, 11, 14)
                    end
                end
            end
        end
    end
end)

-- GUI Toggles + Color pickers
ESPTab:CreateToggle({ Name = "Show ESP", CurrentValue = false, Callback = function(s) ESPStates.Text = s end })
ESPTab:CreateToggle({ Name = "Show Chams", CurrentValue = false, Callback = function(s) ESPStates.Chams = s end })
ESPTab:CreateToggle({ Name = "Show Consumables", CurrentValue = false, Callback = function(s) ESPStates.Consumables = s end })
ESPTab:CreateToggle({ Name = "Show Deployables", CurrentValue = false, Callback = function(s) ESPStates.Deployables = s end })
ESPTab:CreateToggle({ Name = "Show Generators (<100)", CurrentValue = false, Callback = function(s) ESPStates.Generators = s end })
ESPTab:CreateToggle({ Name = "Show Fake Generators", CurrentValue = false, Callback = function(s) ESPStates.FakeGenerators = s end })
ESPTab:CreateToggle({ Name = "Show Digital Footprints", CurrentValue = false, Callback = function(s) ESPStates.Footprints = s end })
ESPTab:CreateToggle({ Name = "Show Extra ESP Info", CurrentValue = false, Callback = function(s)
    ESPExtraInfo = s
    -- rebuild player ESP so extra label is created/destroyed correctly
    for char, _ in pairs(playerESPCache) do
        removePlayerESP(char)
    end
end })

-- Color pickers
ESPTab:CreateColorPicker({ Name = "Player Name Color", Color = Colors.PlayerNames, Callback = function(c) Colors.PlayerNames = c end })
ESPTab:CreateColorPicker({ Name = "Survivor Chams", Color = Colors.SurvivorChams, Callback = function(c) Colors.SurvivorChams = c end })
ESPTab:CreateColorPicker({ Name = "Killer Chams", Color = Colors.KillerChams, Callback = function(c) Colors.KillerChams = c end })
ESPTab:CreateColorPicker({ Name = "Items Color", Color = Colors.Consumables, Callback = function(c) Colors.Consumables = c end })
ESPTab:CreateColorPicker({ Name = "Generators Color", Color = Colors.Generator, Callback = function(c) Colors.Generator = c end })
ESPTab:CreateColorPicker({ Name = "Footprints Color", Color = Colors.Footprints, Callback = function(c) Colors.Footprints = c end })

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