--[[   Yet Another Forsaken Script [Revamp] ]]--

--// =====[ Dependencies & Core Services ]===== //--
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Yet Another Forsaken Script",
    LoadingTitle = "YAFS",
    LoadingSubtitle = "Loading...",
    ShowText = "Open Menu",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false}
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// =====[ Utility Functions ]===== //--
local function getMap()
    local root = Workspace:FindFirstChild("Map")
    if not root then return nil end
    local ingame = root:FindFirstChild("Ingame")
    return ingame and ingame:FindFirstChild("Map") or nil
end

local function getClosestGenerator(maxDist)
    local map = getMap()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not (map and hrp) then return nil end
    local closest, dist = nil, maxDist or 10
    for _, g in ipairs(map:GetChildren()) do
        if g.Name == "Generator" and g:FindFirstChild("Remotes") and g:FindFirstChild("Progress") then
            local pos = (g.PrimaryPart and g.PrimaryPart.Position) or g:GetPivot().Position
            local d = (hrp.Position - pos).Magnitude
            if d < dist then
                closest, dist = g, d
            end
        end
    end
    return closest
end

local function playFireSound()
    local sound = ReplicatedStorage.Assets.Sounds.SFX.Generators.puzzleDone:Clone()
    sound.Parent = Workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, sound.TimeLength + 1)
end

--// =====[ Generator Tab ]===== //--
local GenTab = Window:CreateTab("Generator", 96559240692119)
local autoRepair, repairCooldown, lastRepair, lastManual = false, 6.2, 0, 0
local _REPAIR_ANIMS = {
    ["rbxassetid://82691533602949"] = true,
    ["rbxassetid://122604262087779"] = true,
    ["rbxassetid://130355934640695"] = true
}

local function isRepairing()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
        if t.Animation and _REPAIR_ANIMS[tostring(t.Animation.AnimationId)] then
            return true
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
    Name = "Repair Cooldown (2.4 - 15)",
    PlaceholderText = tostring(repairCooldown),
    Callback = function(v)
        local n = tonumber(v)
        if n then
            repairCooldown = math.clamp(n, 2.4, 15)
            Rayfield:Notify({ Title = "Generator", Content = "Cooldown set to " .. repairCooldown, Duration = 1.4 })
        end
    end
})

GenTab:CreateButton({
    Name = "Manual Repair Fire (min 2.4s)",
    Callback = function()
        local now = tick()
        if now - lastManual < 2.4 then return end
        local g = getClosestGenerator(10)
        if g and g:FindFirstChild("Remotes") then
            local re = g.Remotes:FindFirstChild("RE")
            if re then
                pcall(function() re:FireServer() end)
                playFireSound()
                lastManual = now
            end
        end
    end
})

-- Generator Auto-Repair Loop
task.spawn(function()
    local inRange, prevInRange, entryTime = false, false, 0
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

--// =====[ ESP Tab ]===== //--
local ESPTab = Window:CreateTab("ESP", 114055269167425)

-- ==== ESP Config ====
local ESPConfig = {
    Items = {"Medkit", "BloxyCola"},
    Minions = {"1x1x1x1Zombie", "PizzaDeliveryRig", "Mafia1", "Mafia2", "Mafia3", "Mafia4"},
    Generators = {"Generator"},
    FakeGenerators = {"FakeGenerator},
    Deployables = {"BuildermanSentry", "BuildermanDispenser", "SubspaceTripmine", "TaphTripwire"},
    Footprints = {"Shadow", "Shadows"},
}

-- ==== ESP Colors ====
local COLORS = {
    Survivor = Color3.fromRGB(0, 119, 0),
    Killer = Color3.fromRGB(170, 0, 0),
    Items = Color3.fromRGB(187, 0, 187),
    Deployables = Color3.fromRGB(72, 145, 108),
    Generators = Color3.fromRGB(255, 200, 0),
    FakeGenerators = Color3.fromRGB(85, 0, 127),
    Minions = Color3.fromRGB(170, 0, 0),
    Footprints = Color3.fromRGB(170, 0, 0),
}

-- ==== ESP Tracking Tables ====
local highlights = setmetatable({}, { __mode = "k" })
local drawings = setmetatable({}, { __mode = "k" })
local playerCharToPlayer = {}

-- ==== ESP Utility Functions ====
local function safePcall(fn, ...) return pcall(fn, ...) end
local function isInstanceAlive(inst) return inst and inst.Parent end
local function getPlayerFromCharacter(model)
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character == model then return pl end
    end
    return nil
end
local function matchesAnySubstring(name, list)
    if not name then return false end
    for _, key in ipairs(list) do
        if type(key) == "string" then
            if string.sub(key,1,1) == "@" then
                if name == string.sub(key,2) then return true end
            else
                if string.find(name, key) then return true end
            end
        end
    end
    return false
end

local function addHighlightInstance(target, tag, color)
    if not isInstanceAlive(target) then return end
    highlights[target] = highlights[target] or {}
    if highlights[target][tag] then return end

    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name = ("esp_highlight_%s"):format(tag)
        h.Adornee = target
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor = color
        h.FillTransparency = 1
        h.OutlineColor = color
        h.OutlineTransparency = 0
        h.Parent = target
        return h
    end)
    if ok and hl then
        highlights[target][tag] = { hl = hl, color = color }
    end
end

local function removeHighlightInstance(target, tag)
    if not target then return end
    local t = highlights[target]
    if t and t[tag] then
        pcall(function() t[tag].hl:Destroy() end)
        t[tag] = nil
    end
    if t then
        local any = false
        for _,_ in pairs(t) do any = true; break end
        if not any then highlights[target] = nil end
    end
end

local function addDrawingText(target, tag, color, textFn)
    if not Drawing then return end
    if not isInstanceAlive(target) then return end
    drawings[target] = drawings[target] or {}
    if drawings[target][tag] then return end

    local ok, textObj = pcall(function()
        local t = Drawing.new("Text")
        t.Visible = false
        t.Center = true
        t.Outline = true
        t.Font = 2
        t.Size = 14
        t.Color = color
        return t
    end)
    if ok and textObj then
        drawings[target][tag] = { d = textObj, color = color, textFn = textFn or function() return "" end }
    end
end

local function removeDrawingText(target, tag)
    if not target or not drawings[target] or not drawings[target][tag] then return end
    local data = drawings[target][tag]
    pcall(function() data.d:Remove() end)
    drawings[target][tag] = nil
    local any = false
    for _,_ in pairs(drawings[target] or {}) do any = true; break end
    if not any then drawings[target] = nil end
end

local function clearCategory(tag)
    for inst, map in pairs(highlights) do
        if map[tag] then
            removeHighlightInstance(inst, tag)
        end
    end
    for inst, map in pairs(drawings) do
        if map[tag] then
            removeDrawingText(inst, tag)
        end
    end
end

local function recolorCategory(tag, color)
    for inst, map in pairs(highlights) do
        if map[tag] and map[tag].hl and isInstanceAlive(map[tag].hl) then
            pcall(function()
                map[tag].hl.FillColor = color
                map[tag].hl.OutlineColor = color
                map[tag].color = color
            end)
        end
    end
    for inst, map in pairs(drawings) do
        if map[tag] and map[tag].d and isInstanceAlive(inst) then
            pcall(function()
                map[tag].d.Color = color
                map[tag].color = color
            end)
        end
    end
end

-- ==== Finder ====
local function findCategoryObjects(category)
    local found = {}
    if category == "Players" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character.PrimaryPart then
                table.insert(found, p.Character)
            end
        end
        return found
    end

    local list = ESPConfig[category]
    if not list then return found end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        local consider = obj
        if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
            consider = obj.Parent
        end
        if (consider:IsA("Model") or consider:IsA("BasePart") or consider:IsA("Folder")) and isInstanceAlive(consider) then
            if matchesAnySubstring(consider.Name, list) then
                table.insert(found, consider)
            end
        end
    end
    return found
end

local function getGeneratorProgressText(genModel)
    local prog = genModel:FindFirstChild("Progress")
    if not prog or not prog:IsA("NumberValue") then
        for _, d in ipairs(genModel:GetDescendants()) do
            if d:IsA("NumberValue") and d.Name == "Progress" then prog = d; break end
        end
    end
    if prog then
        local v = tonumber(prog.Value) or 0
        return string.format("[Generator] %d%%", math.clamp(math.floor(v),0,100))
    end
    return "[Generator]"
end

-- ==== ESP Toggle Handlers ====
local toggles = {
    HighlightPlayers = false,
    ESPPlayers = false,
    Items = false,
    Deployables = false,
    Generators = false,
    FakeGenerators = false,
    Minions = false,
    Footprints = false,
}

local function enableHighlightPlayers()
    toggles.HighlightPlayers = true
    for _, char in ipairs(findCategoryObjects("Players")) do
        local pl = getPlayerFromCharacter(char)
        local role = (pl and pl.Team and pl.Team.Name == "Killers") and "Killer" or "Survivor"
        addHighlightInstance(char, "Players", COLORS[role])
    end
end
local function disableHighlightPlayers() toggles.HighlightPlayers = false; clearCategory("Players") end

local function enableESPPlayers()
    toggles.ESPPlayers = true
    for _, char in ipairs(findCategoryObjects("Players")) do
        local pl = getPlayerFromCharacter(char)
        local role = (pl and pl.Team and pl.Team.Name == "Killers") and "Killer" or "Survivor"
        local head = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
        if head then
            addDrawingText(head, "ESPPlayers", COLORS[role], function()
                local ownerName = pl and "@" .. pl.Name or "@Model"
                return string.format("[%s]\n%s", char.Name, ownerName)
            end)
        end
    end
end
local function disableESPPlayers() toggles.ESPPlayers = false; clearCategory("ESPPlayers") end

local function enableGenericCategory(cfgName, tag, colorKey)
    toggles[tag] = true
    local arr = findCategoryObjects(cfgName)
    for _, obj in ipairs(arr) do
        addHighlightInstance(obj, tag, COLORS[colorKey])
        if tag == "Generators" then
            local attachPart = obj:FindFirstChildWhichIsA("BasePart") or obj:FindFirstChild("PrimaryPart")
            if attachPart then
                addDrawingText(attachPart, "Generators", COLORS.Generators, function() return getGeneratorProgressText(obj) end)
            end
        end
    end
end
local function disableGenericCategory(tag)
    toggles[tag] = false
    clearCategory(tag)
end

-- ==== Rendered Updates: Highlight & Drawings Fade/Position Loop ====
RunService:BindToRenderStep("ESP_Update", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camPos = Camera.CFrame.Position
    for inst, map in pairs(highlights) do
        if not isInstanceAlive(inst) then
            for tag,_ in pairs(map) do removeHighlightInstance(inst, tag) end
        else
            for tag, entry in pairs(map) do
                if entry and entry.hl and isInstanceAlive(entry.hl) then
                    local pos
                    if inst:IsA("Model") and inst.PrimaryPart then pos = inst.PrimaryPart.Position
                    elseif inst:IsA("BasePart") then pos = inst.Position
                    else
                        local pr = inst:FindFirstChildWhichIsA("BasePart")
                        pos = pr and pr.Position
                    end
                    if pos then
                        local dist = (camPos - pos).Magnitude
                        local t = math.clamp(dist / 140, 0.25, 0.95)
                        pcall(function() entry.hl.FillTransparency = t end)
                    end
                end
            end
        end
    end

    if Drawing then
        for inst, map in pairs(drawings) do
            if not isInstanceAlive(inst) then
                for tag,_ in pairs(map) do removeDrawingText(inst, tag) end
            else
                local worldPos
                if inst:IsA("BasePart") then worldPos = inst.Position
                elseif inst:IsA("Model") and inst.PrimaryPart then worldPos = inst.PrimaryPart.Position
                else
                    local bp = inst:FindFirstChildWhichIsA("BasePart")
                    worldPos = bp and bp.Position
                end
                if worldPos then
                    local screenPos, onscreen = Camera:WorldToViewportPoint(worldPos)
                    for tag, entry in pairs(map) do
                        local d = entry.d
                        if d then
                            if onscreen then
                                local dist = (camPos - worldPos).Magnitude
                                if dist > 600 then
                                    d.Visible = false
                                else
                                    d.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                                    local ok, txt = pcall(function() return entry.textFn and entry.textFn() or "" end)
                                    if ok then d.Text = txt end
                                    local size = math.clamp(16 - (dist/80), 10, 18)
                                    d.Size = size
                                    d.Color = entry.color or d.Color
                                    d.Visible = true
                                end
                            else
                                d.Visible = false
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==== UI ====
ESPTab:CreateToggle({
    Name = "Highlight Players",
    CurrentValue = false,
    Flag = "HighlightPlayers",
    Callback = function(v)
        if v then enableHighlightPlayers() else disableHighlightPlayers() end
    end
})

ESPTab:CreateToggle({
    Name = "ESP Players",
    CurrentValue = false,
    Flag = "ESPPlayers",
    Callback = function(v)
        if v then enableESPPlayers() else disableESPPlayers() end
    end
})

-- Generic toggles
local genericCategories = {
    {name="Highlight Items", cfg="Items"},
    {name="Highlight Survivor Deployables", cfg="Deployables"},
    {name="Highlight Generators (includes text)", cfg="Generators"},
    {name="Highlight Fake Generators", cfg="FakeGenerators"},
    {name="Highlight Killer Minions", cfg="Minions"},
    {name="Highlight Digital Footprints", cfg="Footprints"},
}
for _, info in ipairs(genericCategories) do
    ESPTab:CreateToggle({
        Name = info.name,
        CurrentValue = false,
        Flag = "Highlight" .. info.cfg,
        Callback = function(v)
            if v then enableGenericCategory(info.cfg, info.cfg, info.cfg) else disableGenericCategory(info.cfg) end
        end
    })
end

ESPTab:CreateButton({
    Name = "Reload ESP",
    Callback = function()
        for inst, map in pairs(highlights) do
            for tag,_ in pairs(map) do removeHighlightInstance(inst, tag) end
        end
        for inst, map in pairs(drawings) do
            for tag,_ in pairs(map) do removeDrawingText(inst, tag) end
        end
        highlights = setmetatable({}, { __mode = "k" })
        drawings = setmetatable({}, { __mode = "k" })
        Rayfield:Notify({ Title = "ESP", Content = "Refreshed and cleared", Duration = 2 })
    end
})

-- Color pickers for all categories
local function addGenericColorPicker(name, key)
    ESPTab:CreateColorPicker({
        Name = name .. " Color",
        Color = COLORS[key],
        Flag = "ESP_" .. key .. "Color",
        Callback = function(c)
            COLORS[key] = c
            recolorCategory(key, c)
        end
    })
end
addGenericColorPicker("Survivor", "Survivor")
addGenericColorPicker("Killer", "Killer")
addGenericColorPicker("Item", "Items")
addGenericColorPicker("Deployable", "Deployables")
addGenericColorPicker("Generator", "Generators")
addGenericColorPicker("Fake Generator", "FakeGenerators")
addGenericColorPicker("Minion", "Minions")
addGenericColorPicker("Footprint", "Footprints")

--// =====[ Player Tab ]===== //--
local PlayerTab = Window:CreateTab("Player", 89251076279188)
local RS, UIS = RunService, game:GetService("UserInputService")
local Sprinting = ReplicatedStorage.Systems.Character.Game.Sprinting
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
        Title = "Conflict Detected",
        Content = "You cannot use Infinite Stamina and Custom Stamina at the same time!",
        Duration = 6,
        Image = 4483362458
    })
end

local InfiniteToggle, CustomToggle
InfiniteToggle = PlayerTab:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = false,
    Flag = "InfiniteStamina",
    Callback = function(v)
        if v and CustomToggle.CurrentValue then
            WarnConflict(); InfiniteToggle:Set(false); return
        end
        stamina.StaminaLossDisabled = v or DefaultStamina.LossDisabled
    end
})

CustomToggle = PlayerTab:CreateToggle({
    Name = "Custom Stamina",
    CurrentValue = false,
    Flag = "CustomStamina",
    Callback = function(v)
        if v and InfiniteToggle.CurrentValue then
            WarnConflict(); CustomToggle:Set(false); return
        end
        if not v then
            for k,vv in pairs(DefaultStamina) do stamina[k .. "Stamina"] = vv end
            stamina.SprintSpeed = DefaultStamina.Speed
        end
    end
})

local function MakeInput(name, def, apply)
    PlayerTab:CreateInput({
        Name = name,
        PlaceholderText = tostring(def),
        RemoveTextAfterFocusLost = false,
        Callback = function(txt)
            local num = tonumber(txt)
            if num and CustomToggle.CurrentValue then apply(num) end
        end
    })
end

MakeInput("Max Stamina", DefaultStamina.Max, function(n) stamina.MaxStamina = n end)
MakeInput("Min Stamina", DefaultStamina.Min, function(n) stamina.MinStamina = n end)
MakeInput("Stamina Gain", DefaultStamina.Gain, function(n) stamina.StaminaGain = n end)
MakeInput("Stamina Loss", DefaultStamina.Loss, function(n) stamina.StaminaLoss = n end)
MakeInput("Sprint Speed", DefaultStamina.Speed, function(n) stamina.SprintSpeed = n end)

--// =====[ Misc Tab ]===== //--
local MiscTab = Window:CreateTab("Misc", 72612560514066)
local RoundTimer = LocalPlayer.PlayerGui:WaitForChild("RoundTimer").Main

MiscTab:CreateToggle({
    Name = "Enable FullBright",
    CurrentValue = false,
    Callback = function(state)
        if not _G.FullBrightExecuted then
            _G.FullBrightExecuted,_G.FullBrightEnabled=true,false
            local L=game:GetService("Lighting")
            local N={Brightness=L.Brightness,ClockTime=L.ClockTime,FogEnd=L.FogEnd,GlobalShadows=L.GlobalShadows,Ambient=L.Ambient}
            local F={Brightness=1,ClockTime=12,FogEnd=786543,GlobalShadows=false,Ambient=Color3.fromRGB(178,178,178)}
            for p,v in pairs(F)do L[p]=v L:GetPropertyChangedSignal(p):Connect(function()if L[p]~=v and L[p]~=N[p]then N[p]=L[p]repeat task.wait()until _G.FullBrightEnabled L[p]=v end end)end
            task.spawn(function()local l=true repeat task.wait()until _G.FullBrightEnabled while task.wait()do if _G.FullBrightEnabled~=l then for p,v in pairs(_G.FullBrightEnabled and F or N)do L[p]=v end l=_G.FullBrightEnabled end end end)
        end
        _G.FullBrightEnabled=state
    end
})

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
        local sub = ReplicatedStorage.Modules.StatusEffects.SurvivorExclusive

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
        local sub = ReplicatedStorage.Modules.StatusEffects.KillerExclusive

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

-- [ c00lgui Tracker ]
local trackerEnabled = false
local cooldownTime = 30
local lastTrigger = {}
local activeC00lParts = {}

local function notify(t, c)
    Rayfield:Notify({ Title = t, Content = c, Duration = 6.5, Image = 4483362458 })
end

local function trackPlayer(model)
    local player = Players:GetPlayerFromCharacter(model)
    if not player then return end
    local function setup(c00l)
        if not c00l then return end
        if lastTrigger[player] and (tick() - lastTrigger[player]) < cooldownTime then return end
        lastTrigger[player] = tick()
        notify("c00lgui Tracker", "@" .. player.Name .. " is using c00lgui.")
        activeC00lParts[player] = c00l
    end
    local existing = model:FindFirstChild("c00lgui")
    if existing then setup(existing) end
    model.ChildAdded:Connect(function(ch)
        if ch.Name == "c00lgui" then setup(ch) end
    end)
end

RunService.Heartbeat:Connect(function()
    for player, c00l in pairs(activeC00lParts) do
        local model = player.Character
        if not model or not c00l or not c00l:IsDescendantOf(model) then
            local hrp = model and model:FindFirstChild("HumanoidRootPart")
            local teleported = false
            if hrp then
                local spawns = getMap() and Workspace.Map.Ingame.Map.SpawnPoints.Survivors:GetChildren() or {}
                for _, s in ipairs(spawns) do
                    if s.Name == "SurvivorSpawn" and (hrp.Position - s.Position).Magnitude <= 25 then
                        teleported = true
                        break
                    end
                end
            end
            if teleported then
                notify("c00lgui Tracker", "@" .. player.Name .. " teleported.")
            else
                notify("c00lgui Tracker", "@" .. player.Name .. "'s c00lgui cancelled.")
            end
            activeC00lParts[player] = nil
        end
    end
end)

MiscTab:CreateToggle({
    Name = "c00lgui Tracker",
    CurrentValue = false,
    Callback = function(s)
        trackerEnabled = s
        if trackerEnabled then
            local surv = Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Survivors")
            if surv then
                for _, m in ipairs(surv:GetChildren()) do
                    if m.Name == "007n7" then trackPlayer(m) end
                end
                surv.ChildAdded:Connect(function(m)
                    if m.Name == "007n7" then trackPlayer(m) end
                end)
            end
        end
    end
})

--// =====[ End of Script ]===== //--
