-- Just Another Forsaken Script - Rayfield UI Setup

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Just Another Forsaken Script",
	LoadingTitle = "Just Another Forsaken Script",
	LoadingSubtitle = "Loading...",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "ForsakenConfig",
		FileName = "Settings"
	},
	Discord = {
		Enabled = false
	},
	KeySystem = false,
})

-- Tabs
local generatorTab = Window:CreateTab("Generator", 4483362458)
local espTab = Window:CreateTab("ESP", 4483362458)
local playerTab = Window:CreateTab("Player", 4483362458)
local miscTab = Window:CreateTab("Misc", 4483362458)

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tables
local espTable = {}
local highlightTable = {}

-- Stamina Values
local staminaModule = ReplicatedStorage:WaitForChild("Systems")
	:WaitForChild("Character")
	:WaitForChild("Game")
	:WaitForChild("Sprinting")

local defaultStamina = require(staminaModule)
local customStamina = {
	Gain = defaultStamina.StaminaGain,
	Loss = defaultStamina.StaminaLoss
}


-- Generator Logic
_G.autoSolveEnabled = false
_G.generatorCooldown = 2.5

generatorTab:CreateToggle({
	Name = "Auto Complete Generators",
	CurrentValue = false,
	Callback = function(v)
		_G.autoSolveEnabled = v
	end,
})

generatorTab:CreateInput({
	Name = "Cooldown (min 2.5)",
	PlaceholderText = "e.g. 3",
	RemoveTextAfterFocusLost = false,
	Callback = function(input)
		local val = tonumber(input)
		if val and val >= 2.5 then
			_G.generatorCooldown = val
		end
	end,
})

task.spawn(function()
	local lastUsed = 0
	while task.wait(0.25) do
		if _G.autoSolveEnabled then
			local now = tick()
			if now - lastUsed >= _G.generatorCooldown then
				local closestGen
				local shortestDist = math.huge
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("Model") and obj:FindFirstChild("Remotes") and obj.Remotes:FindFirstChild("RE") then
						local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						if hrp then
							local dist = (obj:GetModelCFrame().Position - hrp.Position).Magnitude
							if dist < shortestDist then
								shortestDist = dist
								closestGen = obj
							end
						end
					end
				end
				if closestGen then
					closestGen.Remotes.RE:FireServer()
					lastUsed = now
				end
			end
		end
	end
end)


-- ESP Settings
local espEnabled = false
local chamsEnabled = false
local espTextColor = Color3.fromRGB(255, 255, 255)
local espKillerTextColor = Color3.fromRGB(255, 0, 0)

espTab:CreateToggle({
	Name = "Enable Text ESP",
	CurrentValue = false,
	Callback = function(v)
		espEnabled = v
	end,
})

espTab:CreateToggle({
	Name = "Enable Chams",
	CurrentValue = false,
	Callback = function(v)
		chamsEnabled = v
		for _, highlight in pairs(highlightTable) do
			highlight.Enabled = v
		end
	end,
})

espTab:CreateColorPicker({
	Name = "Survivor ESP Text Color",
	Color = espTextColor,
	Callback = function(color)
		espTextColor = color
	end,
})

espTab:CreateColorPicker({
	Name = "Killer ESP Text Color",
	Color = espKillerTextColor,
	Callback = function(color)
		espKillerTextColor = color
	end,
})

-- ESP Loop
RunService.RenderStepped:Connect(function()
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
			local model = player.Character
			local nameTag = espTable[player]

			if espEnabled then
				if not nameTag then
					local billboard = Instance.new("BillboardGui")
					billboard.Size = UDim2.new(0, 100, 0, 20)
					billboard.StudsOffset = Vector3.new(0, 2.5, 0)
					billboard.AlwaysOnTop = true
					billboard.Adornee = model:FindFirstChild("Head")
					billboard.Parent = model

					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.Size = UDim2.new(1, 0, 1, 0)
					label.Font = Enum.Font.GothamMedium
					label.TextScaled = true
					label.TextStrokeTransparency = 0
					label.Text = model.Name
					label.TextColor3 = espKillerTextColor
					label.Parent = billboard

					espTable[player] = billboard
				else
					nameTag.Enabled = true
					local label = nameTag:FindFirstChildOfClass("TextLabel")
					if label then
						local isSurvivor = tostring(model.Parent) == "Survivors"
						label.TextColor3 = isSurvivor and espTextColor or espKillerTextColor
					end
				end
			elseif nameTag then
				nameTag.Enabled = false
			end

			if chamsEnabled and not highlightTable[player] then
				local highlight = Instance.new("Highlight")
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.FillTransparency = 0.5
				highlight.OutlineTransparency = 0
				highlight.Adornee = model

				local isSurvivor = tostring(model.Parent) == "Survivors"
				if isSurvivor then
					highlight.FillColor = Color3.fromRGB(255, 191, 0)
					highlight.OutlineColor = Color3.fromRGB(255, 191, 0)
				else
					highlight.FillColor = Color3.fromRGB(255, 0, 0)
					highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
				end

				highlight.Parent = model
				highlightTable[player] = highlight
			end
		end
	end
end)


-- Infinite Stamina Logic
local infiniteStaminaEnabled = false
playerTab:CreateToggle({
	Name = "Infinite Stamina",
	CurrentValue = false,
	Callback = function(v)
		infiniteStaminaEnabled = v
		if v then
			defaultStamina.StaminaLossDisabled = true
		else
			defaultStamina.StaminaLossDisabled = false
		end
	end,
})

playerTab:CreateToggle({
	Name = "Custom Stamina Settings",
	CurrentValue = false,
	Callback = function(v)
		if v then
			defaultStamina.StaminaGain = customStamina.Gain
			defaultStamina.StaminaLoss = customStamina.Loss
		else
			defaultStamina.StaminaGain = 20
			defaultStamina.StaminaLoss = 10
		end
	end,
})

playerTab:CreateInput({
	Name = "Stamina Gain",
	PlaceholderText = tostring(customStamina.Gain),
	RemoveTextAfterFocusLost = false,
	Callback = function(txt)
		local val = tonumber(txt)
		if val then
			customStamina.Gain = val
			defaultStamina.StaminaGain = val
		end
	end,
})

playerTab:CreateInput({
	Name = "Stamina Loss",
	PlaceholderText = tostring(customStamina.Loss),
	RemoveTextAfterFocusLost = false,
	Callback = function(txt)
		local val = tonumber(txt)
		if val then
			customStamina.Loss = val
			defaultStamina.StaminaLoss = val
		end
	end,
})


-- CoolGUI Animation Tracker
local animationId = "rbxassetid://123915228705093"
local trackCoolGUI = false

miscTab:CreateToggle({
	Name = "Track 007n7 CoolGUI",
	CurrentValue = false,
	Callback = function(v)
		trackCoolGUI = v
		task.spawn(function()
			while trackCoolGUI and task.wait(1) do
				for _, plr in pairs(Players:GetPlayers()) do
					-- if plr ~= LocalPlayer then
						local char = plr.Character
						if char then
							local hum = char:FindFirstChildOfClass("Humanoid")
							if hum and hum:FindFirstChild("Animator") then
								local animTracks = hum.Animator:GetPlayingAnimationTracks()
								for _, track in ipairs(animTracks) do
									if string.find(track.Animation.AnimationId, tostring(animationId)) then
										Rayfield:Notify({
											Title = "CoolGUI Detected",
											Content = "Someone is using CoolGUI..",
											Duration = 5
										})
										track.Stopped:Connect(function()
											Rayfield:Notify({
												Title = "CoolGUI",
												Content = "CoolGUI animation ended.",
												Duration = 5
											})
										end)
										return
									end
								end
							end
						end
					-- end
				end
			end
		end)
	end,
})

miscTab:CreateToggle({
	Name = "Delete Subspaced Effect",
	CurrentValue = false,
	Callback = function(v)
		if v then
			local survivorExclusive = ReplicatedStorage:WaitForChild("Modules")
				:WaitForChild("StatusEffects")
				:FindFirstChild("SurvivorExclusive")

			if survivorExclusive then
				local subspacedEffect = survivorExclusive:FindFirstChild("Subspaced")
				if subspacedEffect then
					subspacedEffect:Destroy()
					Rayfield:Notify({
						Title = "Effect Removed",
						Content = "Subspaced effect was successfully removed.",
						Duration = 5
					})
				else
					Rayfield:Notify({
						Title = "Missing",
						Content = "Subspaced effect was not found.",
						Duration = 5
					})
				end
			else
				Rayfield:Notify({
					Title = "Missing",
					Content = "SurvivorExclusive folder was not found.",
					Duration = 5
				})
			end
		end
	end,
})
