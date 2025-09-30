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
-- Medium-level ESP Tab (efficient, event-driven)
--========================================
local ESPTab = Window:CreateTab("ESP")
local Workspace = workspace
local RunService = game:GetService("RunService")

-- Colors
local COLORS = {
    Survivor = Color3.fromRGB(152,255,152), -- mint green
    Killer   = Color3.fromRGB(255,102,102), -- soft red
    Medkit   = Color3.fromRGB(0,200,0),     -- green
    Bloxy    = Color3.fromRGB(0,200,200),   -- teal
    Generator= Color3.fromRGB(255,255,255), -- white
    FakeGen  = Color3.fromRGB(200,160,255), -- soft violet
    Deploy   = Color3.fromRGB(255,182,193), -- soft pink
    Minion   = Color3.fromRGB(255,102,102), -- soft red
    Shadow   = Color3.fromRGB(255,102,102), -- soft red
}

-- Toggle state (UI + logic)
local ESPStates = {
    PlayerHighlights = false,
    PlayerESP = false,
    Items = false,
    Generators = false,
    FakeGenerators = false,
    SurvivorDeployables = false,
    KillerMinions = false,
    DigitalFootprints = false,
}

-- tracked table: weak keys (Instance -> metadata)
local tracked = setmetatable({}, { __mode = "k" })
local function ensureTracked(inst)
    if tracked[inst] == nil then
        tracked[inst] = {
            owners = {},        -- ownerName -> true
            opts = {},          -- ownerName -> opts (highlight/billboard/color/getText)
            conns = {},         -- ownerName -> {connections...}
            highlight = nil,    -- Highlight instance
            billboard = nil,    -- BillboardGui instance
            savedTransparency = nil -- for shadows
        }
    end
    return tracked[inst]
end

-- find adornee basepart for an instance (model or part)
local function findAdornee(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst:FindFirstChild("HumanoidRootPart") then return inst.HumanoidRootPart end
        if inst.PrimaryPart then return inst.PrimaryPart end
        for _, c in ipairs(inst:GetChildren()) do
            if c:IsA("BasePart") then return c end
        end
    end
    return nil
end

-- respects PlayerAura
local function hasPlayerAura(inst)
    if not inst then return false end
    return inst:FindFirstChild("PlayerAura") ~= nil
end

-- highlight create/destroy
local function createHighlight(inst, color)
    if not inst or hasPlayerAura(inst) then return end
    local meta = ensureTracked(inst)
    if meta.highlight then return end
    local adornee = findAdornee(inst)
    if not adornee then return end
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight"
    hl.FillColor = color
    hl.OutlineColor = color
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = adornee
    hl.Parent = inst
    meta.highlight = hl
end

local function destroyHighlightIfNoOwners(inst)
    local meta = tracked[inst]
    if not meta or not meta.highlight then return end
    for owner, _ in pairs(meta.owners) do
        local o = meta.opts[owner]
        if o and o.highlight then
            return -- some owner still needs it
        end
    end
    pcall(function() meta.highlight:Destroy() end)
    meta.highlight = nil
end

-- billboard create/destroy
local function createBillboard(inst, color, getText)
    if not inst or hasPlayerAura(inst) then return end
    local meta = ensureTracked(inst)
    if meta.billboard then
        -- update text/color if necessary (only when text changed)
        local lbl = meta.billboard:FindFirstChild("ESP_Label")
        if lbl and getText then
            local ok, txt = pcall(getText, inst)
            if ok and txt and lbl.Text ~= txt then lbl.Text = txt end
        end
        if lbl and color then lbl.TextColor3 = color end
        return
    end
    local adornee = findAdornee(inst)
    if not adornee then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Billboard"
    bb.Size = UDim2.new(0,100,0,28)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0,3.5,0)
    bb.Adornee = adornee
    bb.Parent = inst

    local label = Instance.new("TextLabel")
    label.Name = "ESP_Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1,0,1,0)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextColor3 = color or Color3.new(1,1,1)
    label.Text = (getText and pcall(getText, inst) and getText(inst)) or ""
    label.Parent = bb

    meta.billboard = bb
end

local function destroyBillboardIfNoOwners(inst)
    local meta = tracked[inst]
    if not meta or not meta.billboard then return end
    for owner, _ in pairs(meta.owners) do
        local o = meta.opts[owner]
        if o and o.billboard then
            return -- some owner still needs it
        end
    end
    pcall(function() meta.billboard:Destroy() end)
    meta.billboard = nil
end

-- disconnect owner conns
local function disconnectOwnerConns(inst, owner)
    local meta = tracked[inst]
    if not meta or not meta.conns[owner] then return end
    for _, c in ipairs(meta.conns[owner]) do
        if c and type(c.Disconnect) == "function" then
            pcall(function() c:Disconnect() end)
        elseif c and type(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
    meta.conns[owner] = nil
end

-- add owner: opts = { highlight = bool, billboard = bool, color = Color3, getText = fn or nil, setup = fn(inst,addConn) or nil }
local function addOwner(inst, ownerName, opts)
    if not inst then return end
    local meta = ensureTracked(inst)
    meta.owners[ownerName] = true
    meta.opts[ownerName] = opts

    if opts.highlight then createHighlight(inst, opts.color) end
    if opts.billboard then createBillboard(inst, opts.color, opts.getText) end

    -- setup owner-specific connections (health/progress/aura)
    if opts.setup and not meta.conns[ownerName] then
        local conns = {}
        local function addConn(c) table.insert(conns, c) end
        pcall(function() opts.setup(inst, addConn) end)
        meta.conns[ownerName] = conns
    end
end

local function removeOwner(inst, ownerName)
    if not inst then return end
    local meta = tracked[inst]
    if not meta then return end
    meta.owners[ownerName] = nil
    meta.opts[ownerName] = nil
    disconnectOwnerConns(inst, ownerName)
    destroyHighlightIfNoOwners(inst)
    destroyBillboardIfNoOwners(inst)

    -- shadow transparency restore if no more owners
    if meta.savedTransparency and next(meta.owners) == nil then
        local adornee = findAdornee(inst)
        if adornee and adornee:IsA("BasePart") then
            pcall(function() adornee.Transparency = meta.savedTransparency end)
        end
        meta.savedTransparency = nil
    end
end

local function removeAllOwners(inst)
    if not inst then return end
    local meta = tracked[inst]
    if not meta then return end
    for owner,_ in pairs(meta.owners) do
        removeOwner(inst, owner)
    end
    tracked[inst] = nil
end

-- ========== owner-specific setup functions ==========

-- player: watch HealthChanged, PlayerAura add/remove and AncestryChanged (ragdoll)
local function setupPlayerConns(rig, addConn)
    local hum = rig:FindFirstChildOfClass("Humanoid")
    if hum then
        addConn(hum.HealthChanged:Connect(function(hp)
            local meta = tracked[rig]
            if meta and meta.billboard and meta.opts["PlayerESP"] and meta.opts["PlayerESP"].getText then
                local ok, txt = pcall(meta.opts["PlayerESP"].getText, rig)
                if ok and txt then
                    local lbl = meta.billboard:FindFirstChild("ESP_Label")
                    if lbl then lbl.Text = txt end
                end
            end
            if hp <= 0 then
                -- remove player visuals when dead; model removal might follow
                removeOwner(rig, "PlayerHighlight")
                removeOwner(rig, "PlayerESP")
            end
        end))
    end

    addConn(rig.ChildAdded:Connect(function(child)
        if child.Name == "PlayerAura" then
            -- hide visuals while aura exists
            local meta = tracked[rig]
            if meta and meta.highlight then
                pcall(function() meta.highlight:Destroy() end)
                meta.highlight = nil
            end
            if meta and meta.billboard then meta.billboard.Enabled = false end
        end
    end))
    addConn(rig.ChildRemoved:Connect(function(child)
        if child.Name == "PlayerAura" then
            -- restore what owners want
            local meta = tracked[rig]
            if meta then
                for owner, o in pairs(meta.opts) do
                    if meta.owners[owner] then
                        if o.highlight then createHighlight(rig, o.color) end
                        if o.billboard and meta.billboard then
                            meta.billboard.Enabled = true
                            if o.getText then
                                local ok, txt = pcall(o.getText, rig)
                                if ok and txt then
                                    local lbl = meta.billboard:FindFirstChild("ESP_Label")
                                    if lbl then lbl.Text = txt end
                                end
                            end
                        end
                    end
                end
            end
        end
    end))
    addConn(rig.AncestryChanged:Connect(function(_, parent)
        if parent == Workspace:FindFirstChild("Ragdolls") then
            removeOwner(rig, "PlayerHighlight")
            removeOwner(rig, "PlayerESP")
        end
    end))
end

-- generator: watch Progress.Value
local function setupGeneratorConns(gen, addConn)
    local prog = gen:FindFirstChild("Progress")
    if prog and prog:IsA("NumberValue") then
        addConn(prog.Changed:Connect(function(val)
            local meta = tracked[gen]
            if meta and meta.billboard and meta.opts["Generator"] and meta.opts["Generator"].getText then
                local lbl = meta.billboard:FindFirstChild("ESP_Label")
                if lbl then lbl.Text = "Progress: "..math.floor(val).."%" end
            end
            if val >= 100 then
                -- auto-remove visuals when complete
                removeOwner(gen, "Generator")
            end
        end))
    end
end

-- shadow: store transparency then force 0
local function setupShadowConns(part, addConn)
    local adornee = findAdornee(part)
    if adornee and adornee:IsA("BasePart") then
        local meta = ensureTracked(part)
        if meta.savedTransparency == nil then meta.savedTransparency = adornee.Transparency end
        pcall(function() adornee.Transparency = 0 end)
    end
end

-- ========== utilities: initial sweep & listeners ==========

local function safePlayersFolder()
    return Workspace:FindFirstChild("Players")
end

local function safeMapFolder()
    local m = Workspace:FindFirstChild("Map")
    if not m then return nil end
    local ig = m:FindFirstChild("Ingame")
    if not ig then return nil end
    return ig:FindFirstChild("Map")
end

-- add owners for existing players in folder depending on toggles
local function applyPlayerTogglesToRig(rig, role)
    if not rig or not rig:IsA("Model") then return end
    if ESPStates.PlayerHighlights then
        addOwner(rig, "PlayerHighlight", { highlight = true, billboard = false, color = (role=="Survivor" and COLORS.Survivor or COLORS.Killer), setup = setupPlayerConns })
    end
    if ESPStates.PlayerESP then
        addOwner(rig, "PlayerESP", {
            highlight = false,
            billboard = true,
            color = (role=="Survivor" and COLORS.Survivor or COLORS.Killer),
            getText = function(m) local h = m:FindFirstChildOfClass("Humanoid"); return m.Name.." | HP: "..(h and math.floor(h.Health) or 0) end,
            setup = setupPlayerConns
        })
    end
end

-- add owners for map instances depending on toggles
local function applyMapTogglesToInstance(inst)
    if not inst then return end
    -- Items
    if ESPStates.Items and (inst.Name == "Medkit" or inst.Name == "BloxyCola") then
        addOwner(inst, "Item", { highlight = true, billboard = false, color = (inst.Name=="Medkit" and COLORS.Medkit or COLORS.Bloxy) })
    end
    -- Generators
    if ESPStates.Generators and inst.Name == "Generator" then
        addOwner(inst, "Generator", {
            highlight = true,
            billboard = true,
            color = COLORS.Generator,
            getText = function(g) local p = g:FindFirstChild("Progress"); return p and ("Progress: "..math.floor(p.Value).."%") or "Generator" end,
            setup = setupGeneratorConns
        })
    end
    -- FakeGenerators
    if ESPStates.FakeGenerators and inst.Name == "FakeGenerator" then
        addOwner(inst, "FakeGenerator", { highlight = true, billboard = false, color = COLORS.FakeGen })
    end
    -- Deployables
    if ESPStates.SurvivorDeployables and (inst.Name == "BuildermanSentry" or inst.Name == "BuildermanDispenser" or inst.Name == "TaphTripmine" or string.find(inst.Name,"TaphTripwire")) then
        addOwner(inst, "Deployable", { highlight = true, billboard = false, color = COLORS.Deploy })
    end
    -- Minions
    if ESPStates.KillerMinions and table.find({"Mafia1","Mafia2","Mafia3","Mafia4","PizzaDeliveryRig","Zombie"}, inst.Name) then
        addOwner(inst, "Minion", { highlight = true, billboard = false, color = COLORS.Minion })
    end
    -- Shadows (descendants often)
    if ESPStates.DigitalFootprints then
        if inst:IsA("BasePart") and (inst.Name == "Shadow" or string.find(inst.Name,"Shadows")) then
            addOwner(inst, "Shadow", { highlight = true, billboard = false, color = COLORS.Shadow, setup = setupShadowConns })
        elseif inst:IsA("Model") and (inst.Name == "Shadow" or string.find(inst.Name,"Shadows")) then
            addOwner(inst, "Shadow", { highlight = true, billboard = false, color = COLORS.Shadow, setup = setupShadowConns })
        end
    end
end

-- initial and event listeners for players folder
local playerFolderConns = {}
local function watchPlayersFolder()
    local players = safePlayersFolder()
    if not players then return end
    local surv = players:FindFirstChild("Survivors")
    local kills = players:FindFirstChild("Killers")
    if surv then
        for _, r in ipairs(surv:GetChildren()) do applyPlayerTogglesToRig(r, "Survivor") end
        playerFolderConns.survAdded = surv.ChildAdded:Connect(function(child) applyPlayerTogglesToRig(child, "Survivor") end)
        playerFolderConns.survRemoved = surv.ChildRemoved:Connect(function(child) removeAllOwners(child) end)
    end
    if kills then
        for _, r in ipairs(kills:GetChildren()) do applyPlayerTogglesToRig(r, "Killer") end
        playerFolderConns.killAdded = kills.ChildAdded:Connect(function(child) applyPlayerTogglesToRig(child, "Killer") end)
        playerFolderConns.killRemoved = kills.ChildRemoved:Connect(function(child) removeAllOwners(child) end)
    end
end

-- initial and event listeners for map folder
local mapFolderConns = {}
local function watchMapFolder()
    local map = safeMapFolder()
    if not map then return end
    for _, inst in ipairs(map:GetChildren()) do
        applyMapTogglesToInstance(inst)
        -- also check descendants for shadows if footprint enabled
        if ESPStates.DigitalFootprints then
            for _, d in ipairs(inst:GetDescendants()) do applyMapTogglesToInstance(d) end
        end
    end
    mapFolderConns.add = map.ChildAdded:Connect(function(c) applyMapTogglesToInstance(c) end)
    mapFolderConns.rem = map.ChildRemoved:Connect(function(c) removeAllOwners(c) end)
    mapFolderConns.descAdd = map.DescendantAdded:Connect(function(d) applyMapTogglesToInstance(d) end)
    mapFolderConns.descRem = map.DescendantRemoving and map.DescendantRemoving:Connect and map.DescendantRemoving:Connect(function(d) removeAllOwners(d) end) or nil
end

-- initial watch (safe: will do nothing if folders not present)
watchPlayersFolder()
watchMapFolder()

-- ========== UI Toggles (Rayfield) ==========
-- When toggles are pressed we add/remove owners for existing objects (and future objects handled by folder listeners)
ESPTab:CreateToggle({ Name = "Show Player Highlights", CurrentValue = false, Callback = function(v)
    ESPStates.PlayerHighlights = v
    local players = safePlayersFolder()
    if players and players:FindFirstChild("Survivors") then
        for _, r in ipairs(players.Survivors:GetChildren()) do
            if v then addOwner(r, "PlayerHighlight", { highlight = true, billboard = false, color = COLORS.Survivor, setup = setupPlayerConns })
            else removeOwner(r, "PlayerHighlight") end
        end
    end
    if players and players:FindFirstChild("Killers") then
        for _, r in ipairs(players.Killers:GetChildren()) do
            if v then addOwner(r, "PlayerHighlight", { highlight = true, billboard = false, color = COLORS.Killer, setup = setupPlayerConns })
            else removeOwner(r, "PlayerHighlight") end
        end
    end
end })

ESPTab:CreateToggle({ Name = "Show Player ESP", CurrentValue = false, Callback = function(v)
    ESPStates.PlayerESP = v
    local players = safePlayersFolder()
    if players and players:FindFirstChild("Survivors") then
        for _, r in ipairs(players.Survivors:GetChildren()) do
            if v then addOwner(r, "PlayerESP", { highlight = false, billboard = true, color = COLORS.Survivor, getText = function(m) local h = m:FindFirstChildOfClass("Humanoid"); return m.Name.." | HP: "..(h and math.floor(h.Health) or 0) end, setup = setupPlayerConns })
            else removeOwner(r, "PlayerESP") end
        end
    end
    if players and players:FindFirstChild("Killers") then
        for _, r in ipairs(players.Killers:GetChildren()) do
            if v then addOwner(r, "PlayerESP", { highlight = false, billboard = true, color = COLORS.Killer, getText = function(m) local h = m:FindFirstChildOfClass("Humanoid"); return m.Name.." | HP: "..(h and math.floor(h.Health) or 0) end, setup = setupPlayerConns })
            else removeOwner(r, "PlayerESP") end
        end
    end
end })

ESPTab:CreateToggle({ Name = "Show Items (Medkit / BloxyCola)", CurrentValue = false, Callback = function(v)
    ESPStates.Items = v
    local map = safeMapFolder()
    if not map then return end
    if v then
        for _, inst in ipairs(map:GetChildren()) do
            if inst.Name == "Medkit" or inst.Name == "BloxyCola" then
                addOwner(inst, "Item", { highlight = true, billboard = false, color = (inst.Name=="Medkit" and COLORS.Medkit or COLORS.Bloxy) })
            end
        end
    else
        -- remove all items visuals from map
        for _, inst in ipairs(map:GetDescendants()) do
            if inst.Name == "Medkit" or inst.Name == "BloxyCola" then removeOwner(inst, "Item") end
        end
    end
end })

ESPTab:CreateToggle({ Name = "Show Generators", CurrentValue = false, Callback = function(v)
    ESPStates.Generators = v
    local map = safeMapFolder()
    if not map then return end
    if v then
        for _, inst in ipairs(map:GetChildren()) do
            if inst.Name == "Generator" then
                addOwner(inst, "Generator", { highlight = true, billboard = true, color = COLORS.Generator, getText = function(g) local p = g:FindFirstChild("Progress"); return p and ("Progress: "..math.floor(p.Value).."%") or "Generator" end, setup = setupGeneratorConns })
            end
        end
    else
        for _, inst in ipairs(map:GetDescendants()) do if inst.Name == "Generator" then removeOwner(inst, "Generator") end end
    end
end })

ESPTab:CreateToggle({ Name = "Show Fake Generators", CurrentValue = false, Callback = function(v)
    ESPStates.FakeGenerators = v
    local map = safeMapFolder()
    if not map then return end
    if v then
        for _, inst in ipairs(map:GetChildren()) do if inst.Name == "FakeGenerator" then addOwner(inst, "FakeGenerator", { highlight = true, billboard = false, color = COLORS.FakeGen }) end end
    else
        for _, inst in ipairs(map:GetDescendants()) do if inst.Name == "FakeGenerator" then removeOwner(inst, "FakeGenerator") end end
    end
end })

ESPTab:CreateToggle({ Name = "Show Survivor Deployables", CurrentValue = false, Callback = function(v)
    ESPStates.SurvivorDeployables = v
    local map = safeMapFolder()
    if not map then return end
    local names = {"BuildermanSentry","BuildermanDispenser","TaphTripmine"}
    if v then
        for _, inst in ipairs(map:GetChildren()) do
            if table.find(names, inst.Name) or string.find(inst.Name,"TaphTripwire") then
                addOwner(inst, "Deployable", { highlight = true, billboard = false, color = COLORS.Deploy })
            end
        end
    else
        for _, inst in ipairs(map:GetDescendants()) do
            if table.find(names, inst.Name) or string.find(inst.Name,"TaphTripwire") then removeOwner(inst, "Deployable") end
        end
    end
end })

ESPTab:CreateToggle({ Name = "Show Killer Minions", CurrentValue = false, Callback = function(v)
    ESPStates.KillerMinions = v
    local map = safeMapFolder()
    if not map then return end
    local names = {"Mafia1","Mafia2","Mafia3","Mafia4","PizzaDeliveryRig","Zombie"}
    if v then
        for _, inst in ipairs(map:GetChildren()) do if table.find(names, inst.Name) then addOwner(inst, "Minion", { highlight = true, billboard = false, color = COLORS.Minion }) end end
    else
        for _, inst in ipairs(map:GetDescendants()) do if table.find(names, inst.Name) then removeOwner(inst, "Minion") end end
    end
end })

ESPTab:CreateToggle({ Name = "Show Digital Footprints (Shadows)", CurrentValue = false, Callback = function(v)
    ESPStates.DigitalFootprints = v
    local map = safeMapFolder()
    if not map then return end
    if v then
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("BasePart") and (d.Name == "Shadow" or string.find(d.Name,"Shadows")) then
                addOwner(d, "Shadow", { highlight = true, billboard = false, color = COLORS.Shadow, setup = setupShadowConns })
            end
        end
    else
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("BasePart") and (d.Name == "Shadow" or string.find(d.Name,"Shadows")) then
                removeOwner(d, "Shadow")
            end
        end
    end
end })

-- If players/map get created later, re-run watchers (simple safety)
-- small watcher: listen for Players and Map creation, then attach
local function safeAttach()
    -- players
    local p = safePlayersFolder()
    if p and not (playerFolderConns and next(playerFolderConns)) then
        -- create local copies of the watcher functions above
        watchPlayersFolder()
    end
    -- map
    local m = safeMapFolder()
    if m and not (mapFolderConns and next(mapFolderConns)) then
        watchMapFolder()
    end
end

-- call safeAttach when Workspace child added that might be Players or Map
Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Players" or child.Name == "Map" then
        pcall(safeAttach)
    end
end)

-- done