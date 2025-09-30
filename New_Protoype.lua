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
-- ESP Tab (Event-driven, efficient)
--========================================
local ESPTab = Window:CreateTab("ESP", 114055269167425)
local Workspace = workspace
local RunService = game:GetService("RunService")

-- Colors (as requested)
local COLORS = {
    Survivor = Color3.fromRGB(152,255,152),    -- mint green
    Killer   = Color3.fromRGB(255,102,102),    -- soft red
    ItemMedkit = Color3.fromRGB(0,200,0),      -- green
    ItemBloxy  = Color3.fromRGB(0,200,200),    -- teal
    Generator  = Color3.fromRGB(255,255,255),  -- white
    FakeGen    = Color3.fromRGB(200,150,255),  -- soft violet
    Deployable = Color3.fromRGB(255,182,193),  -- soft pink
    Minion     = Color3.fromRGB(255,102,102),  -- soft red
    Shadow     = Color3.fromRGB(255,102,102),  -- soft red
}

-- toggle state
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

-- tracked table holds one entry per Instance we touched
-- tracked[target] = {
--   owners = { playerHighlight=true, generator=true, ... },
--   ownerOpts = { playerHighlight = {highlight=true,billboard=false,color=Color3,...}, ... },
--   conns = { playerHighlight = {...connections...}, playerESP = {...} },
--   highlight = Instance or nil,
--   billboard = Instance or nil,
--   originalTransparency = number or nil
-- }
local tracked = setmetatable({}, { __mode = "k" }) -- weak keys so removed instances can GC

local function ensureTracked(inst)
    if tracked[inst] == nil then
        tracked[inst] = { owners = {}, ownerOpts = {}, conns = {}, highlight = nil, billboard = nil, originalTransparency = nil }
    end
    return tracked[inst]
end

-- utility: find a BasePart to adornee on a model, or return part itself
local function findAdornee(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst:FindFirstChild("HumanoidRootPart") then return inst.HumanoidRootPart end
        if inst.PrimaryPart then return inst.PrimaryPart end
        for _, v in ipairs(inst:GetChildren()) do
            if v:IsA("BasePart") then return v end
        end
    end
    return nil
end

-- create/destroy helper (only one highlight/billboard per tracked entry)
local function createHighlightIfNeeded(inst, color)
    local t = ensureTracked(inst)
    if t.highlight then return end
    local adornee = findAdornee(inst)
    if not adornee then return end
    if inst:FindFirstChild("PlayerAura") then return end -- respect PlayerAura
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight"
    hl.FillColor = color
    hl.OutlineColor = color
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = adornee
    hl.Parent = inst  -- keep it grouped with the instance
    t.highlight = hl
end

local function destroyHighlightIfNoOwner(inst)
    local t = tracked[inst]
    if not t or not t.highlight then return end
    -- if any owner requires highlight, keep it
    for name, opts in pairs(t.ownerOpts) do
        if t.owners[name] and opts.highlight then
            return
        end
    end
    -- no owners need highlight -> remove
    t.highlight:Destroy()
    t.highlight = nil
end

local function createBillboardIfNeeded(inst, color, getText)
    local t = ensureTracked(inst)
    if t.billboard then
        -- update text/color if present
        local label = t.billboard:FindFirstChild("ESP_Label")
        if label and getText then
            local ok, txt = pcall(getText, inst)
            if ok and txt then
                label.Text = txt
            end
        end
        if label and color then label.TextColor3 = color end
        return
    end
    local adornee = findAdornee(inst)
    if not adornee then return end
    if inst:FindFirstChild("PlayerAura") then return end -- respect PlayerAura
    -- BillboardGui parented to the model (valid for world GUIs)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Billboard"
    bb.Size = UDim2.new(0,100,0,30)
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

    t.billboard = bb
end

local function destroyBillboardIfNoOwner(inst)
    local t = tracked[inst]
    if not t or not t.billboard then return end
    for name, opts in pairs(t.ownerOpts) do
        if t.owners[name] and opts.billboard then
            return
        end
    end
    t.billboard:Destroy()
    t.billboard = nil
end

local function addOwner(inst, ownerName, opts)
    local t = ensureTracked(inst)
    t.owners[ownerName] = true
    t.ownerOpts[ownerName] = opts

    -- create highlight if any owner wants it
    if opts.highlight then
        createHighlightIfNeeded(inst, opts.color)
    end

    -- create billboard if any owner wants it
    if opts.billboard and opts.getText then
        createBillboardIfNeeded(inst, opts.color, opts.getText)
    end

    -- setup connections specific for this owner (e.g. health change, progress change, aura detection)
    if opts.setupConns and not t.conns[ownerName] then
        local conns = {}
        local function addConn(c) table.insert(conns, c) end
        local ok, res = pcall(opts.setupConns, inst, addConn)
        -- opts.setupConns should call addConn(connection) for each connection it returns
        t.conns[ownerName] = conns
    end
end

local function removeOwner(inst, ownerName)
    local t = tracked[inst]
    if not t then return end
    t.owners[ownerName] = nil
    t.ownerOpts[ownerName] = nil
    -- disconnect owner-specific conns
    if t.conns[ownerName] then
        for _, c in ipairs(t.conns[ownerName]) do
            if c and typeof(c.Disconnect) == "function" then
                pcall(function() c:Disconnect() end)
            elseif c and typeof(c) == "RBXScriptConnection" then
                pcall(function() c:Disconnect() end)
            end
        end
        t.conns[ownerName] = nil
    end
    -- decide whether to remove highlight/billboard
    destroyHighlightIfNoOwner(inst)
    destroyBillboardIfNoOwner(inst)

    -- for shadows, restore transparency if we stored it and no owner needs the part
    if t.originalTransparency and next(t.ownerOpts) == nil then
        local adornee = findAdornee(inst)
        if adornee and adornee:IsA("BasePart") then
            pcall(function() adornee.Transparency = t.originalTransparency end)
        end
        t.originalTransparency = nil
    end
end

local function removeAllOwners(inst)
    local t = tracked[inst]
    if not t then return end
    for ownerName,_ in pairs(t.owners) do
        removeOwner(inst, ownerName)
    end
    tracked[inst] = nil
end

-- ========== specific owner setup helpers ==========

-- Player owner setup (health updates, aura and ragdoll detection)
local function playerSetupConns(rig, addConn)
    -- health changed connection
    local hum = rig:FindFirstChildOfClass("Humanoid")
    if hum then
        local c1 = hum.HealthChanged:Connect(function()
            local t = tracked[rig]
            if t and t.billboard and t.ownerOpts["PlayerESP"] then
                local ok, txt = pcall(t.ownerOpts["PlayerESP"].getText, rig)
                if ok and txt then
                    local lbl = t.billboard:FindFirstChild("ESP_Label")
                    if lbl then lbl.Text = txt end
                end
            end
            -- if health is 0, remove our visual if moved to ragdoll or dead
            if hum.Health <= 0 then
                -- do not outright destroy tracked entry, let ChildRemoved/Ancestry handle model disposal
                removeOwner(rig, "PlayerHighlight")
                removeOwner(rig, "PlayerESP")
            end
        end)
        addConn(c1)
    end

    -- detect PlayerAura addition/removal on the model and hide/reapply accordingly
    local c2 = rig.ChildAdded:Connect(function(child)
        if child.Name == "PlayerAura" then
            -- temporarily hide our ESP
            destroyHighlightIfNoOwner(rig)
            if tracked[rig] and tracked[rig].billboard then
                tracked[rig].billboard.Enabled = false
            end
        end
    end)
    addConn(c2)

    local c3 = rig.ChildRemoved:Connect(function(child)
        if child.Name == "PlayerAura" then
            -- reapply what owners want (if owners still exist)
            local t = tracked[rig]
            if t then
                -- highlight
                for name, opts in pairs(t.ownerOpts) do
                    if t.owners[name] and opts.highlight then
                        createHighlightIfNeeded(rig, opts.color)
                        break
                    end
                end
                -- billboard
                for name, opts in pairs(t.ownerOpts) do
                    if t.owners[name] and opts.billboard then
                        tracked[rig].billboard.Enabled = true
                        -- refresh text
                        local ok, txt = pcall(opts.getText, rig)
                        if ok and txt then
                            local lbl = tracked[rig].billboard:FindFirstChild("ESP_Label")
                            if lbl then lbl.Text = txt end
                        end
                        break
                    end
                end
            end
        end
    end)
    addConn(c3)

    -- Ancestry change to detect ragdoll folder movement
    local c4 = rig.AncestryChanged:Connect(function(_, parent)
        if parent == Workspace.Ragdolls then
            removeOwner(rig, "PlayerHighlight")
            removeOwner(rig, "PlayerESP")
        end
    end)
    addConn(c4)
end

-- Generator owner setup (watch Progress value)
local function generatorSetupConns(gen, addConn)
    local prog = gen:FindFirstChild("Progress")
    if prog and prog:IsA("NumberValue") then
        local c = prog.Changed:Connect(function(val)
            local t = tracked[gen]
            if not t then return end
            -- update billboard text if present
            if t.billboard then
                local lbl = t.billboard:FindFirstChild("ESP_Label")
                if lbl then lbl.Text = "Progress: "..math.floor(val).."%"
                end
            end
            -- remove highlight/billboard when complete
            if val >= 100 then
                removeOwner(gen, "Generator")
            end
        end)
        addConn(c)
    end
    -- if generator model removed from map, cleanup will happen through ChildRemoved/Ancestry later
end

-- Shadow owner setup (store original transparency)
local function shadowSetupConns(part, addConn)
    local adorn = findAdornee(part)
    if adorn and adorn:IsA("BasePart") then
        local t = ensureTracked(part)
        if t.originalTransparency == nil then
            t.originalTransparency = adorn.Transparency
        end
        -- force transparency to 0
        pcall(function() adorn.Transparency = 0 end)
    end
end

-- ========== folder listeners & initial sweep ==========

-- helper to add player owners depending on toggles
local function addPlayerOwnersForRig(rig, role)
    if not rig or not rig:IsA("Model") then return end
    local color = (role == "Survivor") and COLORS.Survivor or COLORS.Killer

    if ESPStates.PlayerHighlights then
        addOwner(rig, "PlayerHighlight", {
            highlight = true,
            billboard = false,
            color = color,
            getText = nil,
            setupConns = playerSetupConns,
        })
    end
    if ESPStates.PlayerESP then
        addOwner(rig, "PlayerESP", {
            highlight = false,
            billboard = true,
            color = color,
            getText = function(m)
                local hum = m:FindFirstChildOfClass("Humanoid")
                local hp = hum and math.floor(hum.Health) or 0
                return m.Name .. " | HP: "..hp
            end,
            setupConns = playerSetupConns,
        })
    end
end

-- helper to add map-based owners (items/gens/...)
local function addMapOwnersForInstance(inst)
    if not inst then return end

    -- Items
    if ESPStates.Items and (inst.Name == "Medkit" or inst.Name == "BloxyCola") then
        addOwner(inst, "Item", {
            highlight = true,
            billboard = false,
            color = (inst.Name == "Medkit") and COLORS.ItemMedkit or COLORS.ItemBloxy,
            getText = nil,
            setupConns = nil,
        })
    end
    
        -- Generators
    if ESPStates.Generators and inst.Name == "Generator" then
        addOwner(inst, "Generator", {
            highlight = true,
            billboard = true,
            color = COLORS.Generator,
            getText = function(g) local p = g:FindFirstChild("Progress") return p and ("Progress: "..math.floor(p.Value).."%") or "Gen" end,
            setupConns = generatorSetupConns,
        })
    end

    -- Fake Generators
    if ESPStates.FakeGenerators and inst.Name == "FakeGenerator" then
        addOwner(inst, "FakeGenerator", {
            highlight = true,
            billboard = false,
            color = COLORS.FakeGen,
            getText = nil,
            setupConns = nil,
        })
    end

    -- Survivor Deployables
    if ESPStates.SurvivorDeployables then
        if inst.Name == "BuildermanSentry" or inst.Name == "BuildermanDispenser"
           or inst.Name == "TaphTripmine" or string.find(inst.Name, "TaphTripwire") then
            addOwner(inst, "Deployable", {
                highlight = true,
                billboard = false,
                color = COLORS.Deployable,
                getText = nil,
                setupConns = nil,
            })
        end
    end

    -- Killer Minions
    if ESPStates.KillerMinions then
        if table.find({"Mafia1","Mafia2","Mafia3","Mafia4","PizzaDeliveryRig","Zombie"}, inst.Name) then
            addOwner(inst, "Minion", {
                highlight = true,
                billboard = false,
                color = COLORS.Minion,
                getText = nil,
                setupConns = nil,
            })
        end
    end

    -- Shadows & Digital Footprints (parts or models containing Shadows)
    if ESPStates.DigitalFootprints then
        if inst:IsA("BasePart") and (inst.Name == "Shadow" or string.find(inst.Name, "Shadows")) then
            addOwner(inst, "Shadow", {
                highlight = true,
                billboard = false,
                color = COLORS.Shadow,
                getText = nil,
                setupConns = shadowSetupConns,
            })
        elseif inst:IsA("Model") and (inst.Name == "Shadow" or string.find(inst.Name, "Shadows")) then
            addOwner(inst, "Shadow", {
                highlight = true,
                billboard = false,
                color = COLORS.Shadow,
                getText = nil,
                setupConns = shadowSetupConns,
            })
        end
    end
end

-- Now attach folder listeners (Survivors, Killers, Map)
local function safeFindPlayersFolder()
    return Workspace:FindFirstChild("Players")
end

local function safeFindMapFolder()
    local m = Workspace:FindFirstChild("Map")
    if not m then return nil end
    local ig = m:FindFirstChild("Ingame")
    if not ig then return nil end
    return ig:FindFirstChild("Map")
end

-- We keep folder connections so we can reuse/replace if needed
local folderConns = {}

-- set up players folder listeners
local function setupPlayersListeners()
    local playersFolder = safeFindPlayersFolder()
    if not playersFolder then return end

    local survFolder = playersFolder:FindFirstChild("Survivors")
    local killerFolder = playersFolder:FindFirstChild("Killers")

    -- survivors
    if survFolder then
        -- initial pass
        for _, rig in ipairs(survFolder:GetChildren()) do
            addPlayerOwnersForRig(rig, "Survivor")
        end
        -- ChildAdded
        folderConns.survAdded = survFolder.ChildAdded:Connect(function(child)
            addPlayerOwnersForRig(child, "Survivor")
        end)
        -- ChildRemoved -> cleanup tracked if any
        folderConns.survRemoved = survFolder.ChildRemoved:Connect(function(child)
            removeAllOwners(child)
        end)
    end

    -- killers
    if killerFolder then
        for _, rig in ipairs(killerFolder:GetChildren()) do
            addPlayerOwnersForRig(rig, "Killer")
        end
        folderConns.killerAdded = killerFolder.ChildAdded:Connect(function(child)
            addPlayerOwnersForRig(child, "Killer")
        end)
        folderConns.killerRemoved = killerFolder.ChildRemoved:Connect(function(child)
            removeAllOwners(child)
        end)
    end
end

-- set up map listeners
local function setupMapListeners()
    local mapFolder = safeFindMapFolder()
    if not mapFolder then return end

    -- initial pass: children and descendants where appropriate
    for _, inst in ipairs(mapFolder:GetChildren()) do
        addMapOwnersForInstance(inst)
        -- also check descendants for Shadows if DigitalFootprints on
        if ESPStates.DigitalFootprints then
            for _, d in ipairs(inst:GetDescendants()) do
                addMapOwnersForInstance(d)
            end
        end
    end

    -- child added/removed
    folderConns.mapAdded = mapFolder.ChildAdded:Connect(function(child)
        addMapOwnersForInstance(child)
    end)
    folderConns.mapRemoved = mapFolder.ChildRemoved:Connect(function(child)
        removeAllOwners(child)
    end)
    -- DescendantAdded specifically to catch newly created 'Shadow' parts deeper in models
    folderConns.mapDescAdded = mapFolder.DescendantAdded:Connect(function(desc)
        addMapOwnersForInstance(desc)
    end)
    folderConns.mapDescRemoved = mapFolder.DescendantRemoving and mapFolder.DescendantRemoving:Connect and mapFolder.DescendantRemoving:Connect(function(desc)
        -- DescendantRemoving fires before removal; ensure we cleanup tracked entry
        removeAllOwners(desc)
    end) or nil
end

-- initialize listeners once (safe to call even if folders are missing)
setupPlayersListeners()
setupMapListeners()

-- ========== UI toggles (callbacks add/remove owners on existing objects) ==========

local function enableOrDisablePlayerHighlights(enable)
    ESPStates.PlayerHighlights = enable
    local playersFolder = safeFindPlayersFolder()
    if playersFolder and playersFolder:FindFirstChild("Survivors") then
        for _, rig in ipairs(playersFolder.Survivors:GetChildren()) do
            if enable then
                addOwner(rig, "PlayerHighlight", { highlight = true, billboard = false, color = COLORS.Survivor, setupConns = playerSetupConns })
            else
                removeOwner(rig, "PlayerHighlight")
            end
        end
    end
    if playersFolder and playersFolder:FindFirstChild("Killers") then
        for _, rig in ipairs(playersFolder.Killers:GetChildren()) do
            if enable then
                addOwner(rig, "PlayerHighlight", { highlight = true, billboard = false, color = COLORS.Killer, setupConns = playerSetupConns })
            else
                removeOwner(rig, "PlayerHighlight")
            end
        end
    end
end

local function enableOrDisablePlayerESP(enable)
    ESPStates.PlayerESP = enable
    local playersFolder = safeFindPlayersFolder()
    if playersFolder and playersFolder:FindFirstChild("Survivors") then
        for _, rig in ipairs(playersFolder.Survivors:GetChildren()) do
            if enable then
                addOwner(rig, "PlayerESP", {
                    highlight = false,
                    billboard = true,
                    color = COLORS.Survivor,
                    getText = function(m) local hum = m:FindFirstChildOfClass("Humanoid"); return m.Name.." | HP: "..(hum and math.floor(hum.Health) or 0) end,
                    setupConns = playerSetupConns
                })
            else
                removeOwner(rig, "PlayerESP")
            end
        end
    end
    if playersFolder and playersFolder:FindFirstChild("Killers") then
        for _, rig in ipairs(playersFolder.Killers:GetChildren()) do
            if enable then
                addOwner(rig, "PlayerESP", {
                    highlight = false,
                    billboard = true,
                    color = COLORS.Killer,
                    getText = function(m) local hum = m:FindFirstChildOfClass("Humanoid"); return m.Name.." | HP: "..(hum and math.floor(hum.Health) or 0) end,
                    setupConns = playerSetupConns
                })
            else
                removeOwner(rig, "PlayerESP")
            end
        end
    end
end

local function enableOrDisableItems(enable)
    ESPStates.Items = enable
    local map = safeFindMapFolder()
    if not map then return end
    if enable then
        for _, inst in ipairs(map:GetChildren()) do
            if inst.Name == "Medkit" or inst.Name == "BloxyCola" then
                addOwner(inst, "Item", { highlight = true, billboard = false, color = (inst.Name=="Medkit" and COLORS.ItemMedkit or COLORS.ItemBloxy) })
            end
        end
    else
        cleanupHighlights(map, {"Medkit","BloxyCola"})
    end
end

local function enableOrDisableGenerators(enable)
    ESPStates.Generators = enable
    local map = safeFindMapFolder()
    if not map then return end
    if enable then
        for _, inst in ipairs(map:GetChildren()) do
            if inst.Name == "Generator" then
                addOwner(inst, "Generator", { highlight = true, billboard = true, color = COLORS.Generator, getText = function(g) local p = g:FindFirstChild("Progress"); return p and ("Progress: "..math.floor(p.Value).."%") or "Generator" end, setupConns = generatorSetupConns })
            end
        end
    else
        cleanupHighlights(map, {"Generator"})
    end
end

local function enableOrDisableFakeGenerators(enable)
    ESPStates.FakeGenerators = enable
    local map = safeFindMapFolder()
    if not map then return end
    if enable then
        for _, inst in ipairs(map:GetChildren()) do
            if inst.Name == "FakeGenerator" then
                addOwner(inst, "FakeGenerator", { highlight = true, color = COLORS.FakeGen })
            end
        end
    else
        cleanupHighlights(map, {"FakeGenerator"})
    end
end

local function enableOrDisableDeployables(enable)
    ESPStates.SurvivorDeployables = enable
    local map = safeFindMapFolder()
    if not map then return end
    if enable then
        for _, inst in ipairs(map:GetChildren()) do
            if inst.Name == "BuildermanSentry" or inst.Name == "BuildermanDispenser" or inst.Name == "TaphTripmine" or string.find(inst.Name,"TaphTripwire") then
                addOwner(inst, "Deployable", { highlight = true, color = COLORS.Deployable })
            end
        end
    else
        cleanupHighlights(map, {"BuildermanSentry","BuildermanDispenser","TaphTripmine"})
    end
end

local function enableOrDisableMinions(enable)
    ESPStates.KillerMinions = enable
    local map = safeFindMapFolder()
    if not map then return end
    if enable then
        for _, inst in ipairs(map:GetChildren()) do
            if table.find({"Mafia1","Mafia2","Mafia3","Mafia4","PizzaDeliveryRig","Zombie"}, inst.Name) then
                addOwner(inst, "Minion", { highlight = true, color = COLORS.Minion })
            end
        end
    else
        cleanupHighlights(map, {"Mafia1","Mafia2","Mafia3","Mafia4","PizzaDeliveryRig","Zombie"})
    end
end

local function enableOrDisableShadows(enable)
    ESPStates.DigitalFootprints = enable
    local map = safeFindMapFolder()
    if not map then return end
    if enable then
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("BasePart") and (d.Name == "Shadow" or string.find(d.Name,"Shadows")) then
                addOwner(d, "Shadow", { highlight = true, color = COLORS.Shadow, setupConns = shadowSetupConns })
            end
        end
    else
        cleanupHighlights(map, {"Shadow"})
    end
end

-- ========== UI Creation (Rayfield toggles) ==========
ESPTab:CreateToggle({ Name = "Show Player Highlights", CurrentValue = false, Callback = function(v) enableOrDisablePlayerHighlights(v) end })
ESPTab:CreateToggle({ Name = "Show Player ESP", CurrentValue = false, Callback = function(v) enableOrDisablePlayerESP(v) end })
ESPTab:CreateToggle({ Name = "Show Items (Medkit / BloxyCola)", CurrentValue = false, Callback = function(v) enableOrDisableItems(v) end })
ESPTab:CreateToggle({ Name = "Show Generators", CurrentValue = false, Callback = function(v) enableOrDisableGenerators(v) end })
ESPTab:CreateToggle({ Name = "Show Fake Generators", CurrentValue = false, Callback = function(v) enableOrDisableFakeGenerators(v) end })
ESPTab:CreateToggle({ Name = "Show Survivor Deployables", CurrentValue = false, Callback = function(v) enableOrDisableDeployables(v) end })
ESPTab:CreateToggle({ Name = "Show Killer Minions", CurrentValue = false, Callback = function(v) enableOrDisableMinions(v) end })
ESPTab:CreateToggle({ Name = "Show Digital Footprints (Shadows)", CurrentValue = false, Callback = function(v) enableOrDisableShadows(v) end })

-- done