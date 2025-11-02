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

local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")

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

-- Config
local ESPConfig = {
	Items = { "Medkit", "BloxyCola" },
	Minions = { "1x1x1x1Zombie", "PizzaDeliveryRig", "Mafia1", "Mafia2", "Mafia3", "Mafia4" },
	Generators = { "Generator", "Generators" },
	FakeGenerators = { "FakeGenerator", "FakeGenerators" },
	Deployables = { "BuildermanSentry", "BuildermanDispenser", "SubspaceTripmine", "TaphTripwire" }, -- change/add names
	Footprints = { "Shadow", "Shadows" }, -- matches names containing these substrings
}

-- ===== Defaults: colors per category (color pickers will override) =====
local PRESETS = {
	PlayersSurvivor = Color3.fromRGB(0, 119, 0),
	PlayersKiller = Color3.fromRGB(170, 0, 0),
	Items = Color3.fromRGB(187, 0, 187),
	Deployables = Color3.fromRGB(72, 145, 108),
	Generators = Color3.fromRGB(255,255,255),
	FakeGenerators = Color3.fromRGB(85,0,127),
	Minions = Color3.fromRGB(170,0,0),
	Footprints = Color3.fromRGB(170,0,0),
}

-- ===== TRACKERS =====
local TRACK = {
	highlights = {},   -- [instance] = { hl = HighlightInstance, tag = "Items" }
	playerEsps = {},   -- [model] = { billboard = BillboardGui, humConn = conn, ancConn = conn }
	genEsps = {},      -- [model] = BillboardGui (progress)
	folderConns = {},  -- for potential future event-based tracking (kept for cleanup)
	toggles = {
		Players = false,
		ESPPlayers = false,
		Items = false,
		Deployables = false,
		Generators = false,
		FakeGenerators = false,
		Minions = false,
		Footprints = false,
	},
}

-- ===== Helpers =====
local function isValid(obj)
	return obj and obj.Parent and obj:IsDescendantOf(Workspace)
end

local function safeDisconnect(conn)
	if conn and typeof(conn) == "RBXScriptConnection" then
		pcall(function() conn:Disconnect() end)
	end
end

local function createHighlight(obj, color, tag)
	if not isValid(obj) then return end
	if TRACK.highlights[obj] then return end
	local ok, hl = pcall(function()
		local h = Instance.new("Highlight")
		h.Name = "ray_ESP_HL"
		h.Adornee = obj
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillColor = color
		h.FillTransparency = 0.5
		h.OutlineColor = color
		h.OutlineTransparency = 0
		h.Parent = obj
		return h
	end)
	if ok and hl then
		TRACK.highlights[obj] = { hl = hl, tag = tag }
	end
end

local function removeHighlight(obj)
	local data = TRACK.highlights[obj]
	if data and data.hl and isValid(data.hl) then
		pcall(function() data.hl:Destroy() end)
	end
	TRACK.highlights[obj] = nil
end

local function recolorHighlightsForTag(tag, color)
	for obj,data in pairs(TRACK.highlights) do
		if data and data.tag == tag and data.hl and isValid(data.hl) then
			pcall(function()
				data.hl.FillColor = color
				data.hl.OutlineColor = color
			end)
		end
	end
end

local function clearTag(tag)
	-- Remove highlights
	for obj,data in pairs(TRACK.highlights) do
		if data and data.tag == tag then
			removeHighlight(obj)
		end
	end
	-- Remove player ESP billboards if tag is "Players" or "ESPPlayers"
	if tag == "Players" or tag == "ESPPlayers" then
		for model,data in pairs(TRACK.playerEsps) do
			if data and data.billboard then pcall(function() data.billboard:Destroy() end) end
			safeDisconnect(data.humConn); safeDisconnect(data.ancConn)
			TRACK.playerEsps[model] = nil
		end
	end
	-- Remove generator billboards
	if tag == "Generators" then
		for model,gui in pairs(TRACK.genEsps) do
			if gui then pcall(function() gui:Destroy() end) end
			TRACK.genEsps[model] = nil
		end
	end
end

-- ===== SCANNER FUNCTIONS =====
local function matchesNameList(obj, names)
	if not obj.Name then return false end
	for _, n in ipairs(names) do
		if obj.Name == n then return true end
	end
	return false
end

local function containsSubstring(obj, substrings)
	if not obj.Name then return false end
	for _, s in ipairs(substrings) do
		if string.find(obj.Name, s) then return true end
	end
	return false
end

-- find objects by category (returns array of Instances to highlight)
local function findCategoryObjects(category)
	local found = {}
	if category == "Players" then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character and p.Character.PrimaryPart then
				table.insert(found, p.Character)
			end
		end
		return found
	end

	-- For other categories, search workspace descendants (fast early checks)
	local list = ESPConfig[category]
	if not list then
		-- special-case footprints category using substrings:
		if category == "Footprints" then
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if (obj:IsA("Model") or obj:IsA("BasePart")) and containsSubstring(obj, ESPConfig.Footprints) then
					table.insert(found, obj)
				end
			end
		end
		return found
	end

	-- Normal name-matching categories
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Folder") then
			-- If model has a PrimaryPart or any BasePart, highlight the model (use model prefer)
			local consider = obj
			-- If descendant is part of a model, prefer model root
			if obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") then
				consider = obj.Parent
			end
			-- Avoid duplicates; rely on TRACK.highlights table to dedupe later
			if matchesNameList(consider, list) then
				table.insert(found, consider)
			end
		end
	end
	return found
end

-- ===== PLAYER ESP (Billboard) =====
local PLAYER_ESP_MAXDIST = 300
local function makePlayerBillboard(model, roleColor)
	if not isValid(model) or TRACK.playerEsps[model] then return end
	local head = model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
	if not head then return end

	local bg = Instance.new("BillboardGui")
	bg.Name = model.Name .. "_ray_ESP"
	bg.Adornee = head
	bg.AlwaysOnTop = true
	bg.Size = UDim2.new(0, 160, 0, 50)
	bg.StudsOffset = Vector3.new(0, 2.6, 0)
	bg.ZIndexBehavior = Enum.ZIndexBehavior.Global
	bg.MaxDistance = PLAYER_ESP_MAXDIST
	bg.Parent = PlayerGui

	local function mk(text, y, bold)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1,0,0,16)
		t.Position = UDim2.new(0, 0, 0, y)
		t.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
		t.TextScaled = true
		t.Text = text or ""
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = Color3.new(0,0,0)
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextYAlignment = Enum.TextYAlignment.Center
		t.Parent = bg
		return t
	end

	local nameLbl = mk(model.Name, 0, true)
	local ownerName = "@Model"
	for _,p in ipairs(Players:GetPlayers()) do if p.Character == model then ownerName = "@"..p.Name; break end end
	local userLbl = mk(ownerName, 16, false)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local healthLbl = mk("Health: " .. (hum and math.floor(hum.Health) or 0), 32, false)

	if roleColor then
		nameLbl.TextColor3 = roleColor
		userLbl.TextColor3 = roleColor
		healthLbl.TextColor3 = Color3.new(1,1,1)
	end

	local humConn
	if hum then
		humConn = hum.HealthChanged:Connect(function(h)
			if healthLbl and healthLbl.Parent then
				pcall(function() healthLbl.Text = "Health: "..math.floor(h) end)
			end
		end)
	end

	local ancConn = model.AncestryChanged:Connect(function(_,parent)
		if not parent then
			pcall(function() bg:Destroy() end)
			safeDisconnect(humConn); safeDisconnect(ancConn)
			TRACK.playerEsps[model] = nil
		end
	end)

	TRACK.playerEsps[model] = { billboard = bg, humConn = humConn, ancConn = ancConn }
	return TRACK.playerEsps[model]
end

local function removePlayerBillboard(model)
	local d = TRACK.playerEsps[model]
	if not d then return end
	safeDisconnect(d.humConn); safeDisconnect(d.ancConn)
	if d.billboard and d.billboard.Parent then pcall(function() d.billboard:Destroy() end) end
	TRACK.playerEsps[model] = nil
end

-- ===== GENERATOR PROGRESS BILLBOARD =====
local function makeGeneratorBillboard(genModel, color)
	if not isValid(genModel) or TRACK.genEsps[genModel] then return end
	local prog = genModel:FindFirstChild("Progress")
	if not (prog and prog:IsA("NumberValue")) then
		-- try to find a NumberValue descendant named Progress
		for _,d in ipairs(genModel:GetDescendants()) do
			if d:IsA("NumberValue") and d.Name == "Progress" then prog = d; break end
		end
	end
	if not prog then return end

	local head = genModel:FindFirstChildWhichIsA("BasePart") or genModel:FindFirstChild("PrimaryPart")
	if not head then head = genModel:FindFirstChildWhichIsA("BasePart") end
	if not head then return end

	local bg = Instance.new("BillboardGui")
	bg.Name = genModel.Name .. "_ray_GEN"
	bg.Adornee = head
	bg.AlwaysOnTop = true
	bg.Size = UDim2.new(0,120,0,30)
	bg.StudsOffset = Vector3.new(0,3,0)
	bg.ZIndexBehavior = Enum.ZIndexBehavior.Global
	bg.MaxDistance = 300
	bg.Parent = PlayerGui

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1,0,1,0)
	lbl.Font = Enum.Font.SourceSansBold
	lbl.TextScaled = true
	lbl.Text = tostring(math.floor(prog.Value)) .. "%"
	lbl.TextColor3 = color or Color3.new(1,1,1)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.Parent = bg

	local con
	con = prog.Changed:Connect(function()
		local v = tonumber(prog.Value) or 0
		if not lbl or not lbl.Parent then
			safeDisconnect(con)
			TRACK.genEsps[genModel] = nil
			return
		end
		lbl.Text = tostring(math.clamp(math.floor(v),0,100)) .. "%"
		if v >= 100 then
			pcall(function() bg:Destroy() end)
			safeDisconnect(con)
			TRACK.genEsps[genModel] = nil
		end
	end)
	TRACK.genEsps[genModel] = bg
	return bg
end

local function removeGeneratorBillboard(genModel)
	if TRACK.genEsps[genModel] then
		pcall(function() TRACK.genEsps[genModel]:Destroy() end)
		TRACK.genEsps[genModel] = nil
	end
end

-- ===== HIGH-LEVEL CATEGORY HANDLERS =====
local function handlePlayersToggle(enabled)
	TRACK.toggles.Players = enabled
	if not enabled then
		clearTag("Players")
		clearTag("ESPPlayers")
		return
	end
	-- immediate pass: create highlights for players (survivor/killer)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character.PrimaryPart then
			-- You may have team names "Survivors"/"Killers" or rely on names; adjust if needed
			local role = (p.Team and p.Team.Name) or "Unknown"
			if role == "Survivors" then createHighlight(p.Character, PRESETS.PlayersSurvivor, "Players")
			elseif role == "Killers" then createHighlight(p.Character, PRESETS.PlayersKiller, "Players")
			else createHighlight(p.Character, PRESETS.PlayersSurvivor, "Players") end
		end
	end
end

local function handleESPPlayersToggle(enabled)
	TRACK.toggles.ESPPlayers = enabled
	if not enabled then
		clearTag("ESPPlayers")
		return
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character.PrimaryPart then
			-- choose color based on team if available
			local role = (p.Team and p.Team.Name) or "Survivors"
			local color = (role == "Survivors") and PRESETS.PlayersSurvivor or PRESETS.PlayersKiller
			makePlayerBillboard(p.Character, color)
		end
	end
end

local function handleGenericCategoryToggle(catName, tagName, color)
	TRACK.toggles[tagName] = true
	-- find objects and add highlights + special handlers
	local arr = findCategoryObjects(catName)
	for _, obj in ipairs(arr) do
		createHighlight(obj, color, tagName)
		-- generator special: also create progress billboard
		if tagName == "Generators" and obj:IsA("Model") then
			makeGeneratorBillboard(obj, PRESETS.Generators)
		end
	end
end

-- ===== MAIN SCAN LOOP (keeps life of toggles updated) =====
task.spawn(function()
	while task.wait(0.9) do
		-- Players highlights
		if TRACK.toggles.Players then
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and p.Character.PrimaryPart and not TRACK.highlights[p.Character] then
					local role = (p.Team and p.Team.Name) or "Survivors"
					if role == "Survivors" then createHighlight(p.Character, PRESETS.PlayersSurvivor, "Players")
					else createHighlight(p.Character, PRESETS.PlayersKiller, "Players") end
				end
			end
		end

		-- ESP Players (billboards)
		if TRACK.toggles.ESPPlayers then
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and p.Character.PrimaryPart and not TRACK.playerEsps[p.Character] then
					local role = (p.Team and p.Team.Name) or "Survivors"
					local color = (role == "Survivors") and PRESETS.PlayersSurvivor or PRESETS.PlayersKiller
					makePlayerBillboard(p.Character, color)
				end
			end
		end

		-- Generic categories
		local mapping = {
			{ cfg = "Items", tag = "Items", color = PRESETS.Items },
			{ cfg = "Deployables", tag = "Deployables", color = PRESETS.Deployables },
			{ cfg = "Generators", tag = "Generators", color = PRESETS.Generators },
			{ cfg = "FakeGenerators", tag = "FakeGenerators", color = PRESETS.FakeGenerators },
			{ cfg = "Minions", tag = "Minions", color = PRESETS.Minions },
			{ cfg = "Footprints", tag = "Footprints", color = PRESETS.Footprints },
		}
		for _, m in ipairs(mapping) do
			if TRACK.toggles[m.tag] then
				local arr = findCategoryObjects(m.cfg)
				for _, obj in ipairs(arr) do
					if not TRACK.highlights[obj] then
						createHighlight(obj, m.color, m.tag)
					end
					-- generator billboard
					if m.tag == "Generators" and obj:IsA("Model") and not TRACK.genEsps[obj] then
						makeGeneratorBillboard(obj, PRESETS.Generators)
					end
				end
			end
		end
	end
end)

-- UI
--local ESPTab = Window:CreateTab("ESP", "eye")

-- Players highlight toggle
ESPTab:CreateToggle({
	Name = "Highlight Players",
	CurrentValue = false,
	Flag = "HighlightPlayers",
	Callback = function(val)
		TRACK.toggles.Players = val
		if not val then clearTag("Players") end
	end
})

-- ESP Players billboards toggle
ESPTab:CreateToggle({
	Name = "ESP Players",
	CurrentValue = false,
	Flag = "ESP_Players",
	Callback = function(val)
		TRACK.toggles.ESPPlayers = val
		if not val then clearTag("ESPPlayers") end
	end
})

-- Items
ESPTab:CreateToggle({
	Name = "Highlight Items",
	CurrentValue = false,
	Flag = "HighlightItems",
	Callback = function(val)
		TRACK.toggles.Items = val
		if not val then clearTag("Items") else
			for _, obj in ipairs(findCategoryObjects("Items")) do createHighlight(obj, PRESETS.Items, "Items") end
		end
	end
})

-- Deployables
ESPTab:CreateToggle({
	Name = "Highlight Survivor Deployables",
	CurrentValue = false,
	Flag = "HighlightDeployables",
	Callback = function(val)
		TRACK.toggles.Deployables = val
		if not val then clearTag("Deployables") else
			for _, obj in ipairs(findCategoryObjects("Deployables")) do createHighlight(obj, PRESETS.Deployables, "Deployables") end
		end
	end
})

-- Generators (and generator progress)
ESPTab:CreateToggle({
	Name = "Highlight Generators (includes Generator billboards)",
	CurrentValue = false,
	Flag = "HighlightGenerators",
	Callback = function(val)
		TRACK.toggles.Generators = val
		if not val then clearTag("Generators") else
			for _, obj in ipairs(findCategoryObjects("Generators")) do
				createHighlight(obj, PRESETS.Generators, "Generators")
				if obj:IsA("Model") then makeGeneratorBillboard(obj, PRESETS.Generators) end
			end
		end
	end
})

-- Fake Generators
ESPTab:CreateToggle({
	Name = "Highlight Fake Generators",
	CurrentValue = false,
	Flag = "HighlightFakeGenerators",
	Callback = function(val)
		TRACK.toggles.FakeGenerators = val
		if not val then clearTag("FakeGenerators") else
			for _, obj in ipairs(findCategoryObjects("FakeGenerators")) do createHighlight(obj, PRESETS.FakeGenerators, "FakeGenerators") end
		end
	end
})

-- Minions
ESPTab:CreateToggle({
	Name = "Highlight Killer Minions",
	CurrentValue = false,
	Flag = "HighlightMinions",
	Callback = function(val)
		TRACK.toggles.Minions = val
		if not val then clearTag("Minions") else
			for _, obj in ipairs(findCategoryObjects("Minions")) do createHighlight(obj, PRESETS.Minions, "Minions") end
		end
	end
})

-- Digital Footprints / Traps
ESPTab:CreateToggle({
	Name = "Highlight Digital Footprints",
	CurrentValue = false,
	Flag = "HighlightFootprints",
	Callback = function(val)
		TRACK.toggles.Footprints = val
		if not val then clearTag("Footprints") else
			for _, obj in ipairs(findCategoryObjects("Footprints")) do createHighlight(obj, PRESETS.Footprints, "Footprints") end
		end
	end
})

-- Reload button
ESPTab:CreateButton({
	Name = "Reload ESP",
	Callback = function()
		-- destroy all highlights and billboards
		for obj, data in pairs(TRACK.highlights) do
			if data and data.hl then pcall(function() data.hl:Destroy() end) end
			TRACK.highlights[obj] = nil
		end
		for model,data in pairs(TRACK.playerEsps) do
			if data and data.billboard then pcall(function() data.billboard:Destroy() end) end
			safeDisconnect(data.humConn); safeDisconnect(data.ancConn)
			TRACK.playerEsps[model] = nil
		end
		for gen,gui in pairs(TRACK.genEsps) do
			if gui then pcall(function() gui:Destroy() end) end
			TRACK.genEsps[gen] = nil
		end
		Rayfield:Notify({ Title = "ESP", Content = "Reloaded.", Duration = 2 })
	end
})

-- Color Pickers
ESPTab:CreateColorPicker({
	Name = "Survivor Color",
	Color = PRESETS.PlayersSurvivor,
	Flag = "ESP_SurvivorColor",
	Callback = function(c)
		PRESETS.PlayersSurvivor = c
		recolorHighlightsForTag("Players", c)
		-- recolor existing player billboards' name labels
		for model,data in pairs(TRACK.playerEsps) do
			if data and data.billboard then
				local nameLbl = data.billboard:FindFirstChild(model.Name, true) -- no naming guarantee; keep simple
				-- simpler: recolor all textlabels in billboard except health
				for _,child in ipairs(data.billboard:GetChildren()) do
					if child:IsA("TextLabel") then
						pcall(function() child.TextColor3 = c end)
					end
				end
			end
		end
	end
})

ESPTab:CreateColorPicker({
	Name = "Killer Color",
	Color = PRESETS.PlayersKiller,
	Flag = "ESP_KillerColor",
	Callback = function(c)
		PRESETS.PlayersKiller = c
		recolorHighlightsForTag("Players", c)
	end
})

ESPTab:CreateColorPicker({
	Name = "Item Color",
	Color = PRESETS.Items,
	Flag = "ESP_ItemColor",
	Callback = function(c)
		PRESETS.Items = c
		recolorHighlightsForTag("Items", c)
	end
})

ESPTab:CreateColorPicker({
	Name = "Generator Color",
	Color = PRESETS.Generators,
	Flag = "ESP_GeneratorColor",
	Callback = function(c)
		PRESETS.Generators = c
		recolorHighlightsForTag("Generators", c)
		-- also recolor generator billboards' text
		for gen, gui in pairs(TRACK.genEsps) do
			local lbl = gui and gui:FindFirstChildOfClass("TextLabel")
			if lbl then pcall(function() lbl.TextColor3 = c end) end
		end
	end
})

ESPTab:CreateColorPicker({
	Name = "Fake Generator Color",
	Color = PRESETS.FakeGenerators,
	Flag = "ESP_FakeGenColor",
	Callback = function(c)
		PRESETS.FakeGenerators = c
		recolorHighlightsForTag("FakeGenerators", c)
	end
})

ESPTab:CreateColorPicker({
	Name = "Deployables Color",
	Color = PRESETS.Deployables,
	Flag = "ESP_DeployColor",
	Callback = function(c)
		PRESETS.Deployables = c
		recolorHighlightsForTag("Deployables", c)
	end
})

ESPTab:CreateColorPicker({
	Name = "Minion Color",
	Color = PRESETS.Minions,
	Flag = "ESP_MinionColor",
	Callback = function(c)
		PRESETS.Minions = c
		recolorHighlightsForTag("Minions", c)
	end
})

ESPTab:CreateColorPicker({
	Name = "Digital Footprint Color",
	Color = PRESETS.Footprints,
	Flag = "ESP_FootprintColor",
	Callback = function(c)
		PRESETS.Footprints = c
		recolorHighlightsForTag("Footprints", c)
	end
})

--Persistence
task.spawn(function()
	task.wait(0.12)
	if Window and Window.Flags then
		pcall(function()
			if Window.Flags.HighlightPlayers then ESPTab:SetValue("HighlightPlayers", Window.Flags.HighlightPlayers) end
		end)
	end
end)

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
