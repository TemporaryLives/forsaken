--[[
    Yet Another Forsaken Script [Revamp]
   
--]]

--//===[ Dependencies and Setup ]===//--
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name="Yet Another Forsaken Script",
    LoadingTitle="YAFS",
    LoadingSubtitle="Loading..."",
    ConfigurationSaving={Enabled=false},
    Discord={Enabled=false}
})

local Players  = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function playFireSound()
	local sound = ReplicatedStorage.Assets.Sounds.SFX.Generators.puzzleDone:Clone()
	sound.Parent = workspace
	sound:Play()
	game:GetService("Debris"):AddItem(sound, sound.TimeLength + 1)
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

--PlayerTab:CreateToggle({
    --Name="Show Expected Stamina",
    --CurrentValue=false,
    --Flag="ShowExpectedStamina",
    --Callback=function(v) if v then EnablePreview() else DisablePreview() end end
--})

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
MiscTab:CreateButton({
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
    Name = "Round Timer Position",
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
        local sub = game:GetService("ReplicatedStorage").Modules.StatusEffects.KillerExclusive

        if state then
            if sub:FindFirstChild("Glitched") then
                sub.Glitched.Name = "TheNewGlitched"
            end
        else
            if sub:FindFirstChild("TheNewGlitched") then
                sub.TheNewGlitched.Name = "Glitched"
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

--//===[ End of Script ]===//--
