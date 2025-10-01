-- // Load Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Just Yet Another Forsaken Script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "🌌 ✨",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false }
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

-- Generator finder with full fallback chain
local function getClosestGenerator(maxDist)
    local map = getMap()
    if not map then
        warn("[DEBUG] getMap() returned nil")
        return nil, math.huge
    end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        warn("[DEBUG] No HumanoidRootPart")
        return nil, math.huge
    end

    local closest, dist = nil, maxDist or 30
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" then
            local re = obj:FindFirstChild("Remotes")
            local prog = obj:FindFirstChild("Progress")
            if re and prog then
                local main = nil

                -- 1. Try PrimaryPart
                if obj:IsA("Model") and obj.PrimaryPart then
                    main = obj.PrimaryPart
                end

                -- 2. Try common names
                if not main then
                    main = obj:FindFirstChild("Generator") or obj:FindFirstChild("Root") or obj:FindFirstChild("Base")
                end

                -- 3. Fallback: first BasePart inside model
                if not main then
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("BasePart") then
                            main = child
                            break
                        end
                    end
                end

                if main then
                    local d = (hrp.Position - main.Position).Magnitude
                    warn("[DEBUG] Generator usable:", obj:GetFullName(), "Dist:", d, "Using part:", main.Name)
                    if d < dist then
                        closest, dist = obj, d
                    end
                else
                    warn("[DEBUG] Generator has no BaseParts at all:", obj:GetFullName())
                end
            else
                warn("[DEBUG] Generator missing Remotes/Progress:", obj:GetFullName())
            end
        elseif obj.Name == "FakeGenerator" then
            warn("[DEBUG] Skipping FakeGenerator:", obj:GetFullName())
        end
    end

    if not closest then
        warn("[DEBUG] No valid generator within range")
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

        local gen, dist = getClosestGenerator(30)
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

--========================================
-- Auto Repair Loop
--========================================
task.spawn(function()
    while true do
        task.wait(0.2)

        if autoRepair and isRepairing() then
            local now = tick()
            if now - lastRepair >= repairCooldown then
                local gen, _ = getClosestGenerator(30)
                if gen and gen:FindFirstChild("Remotes") then
                    local re = gen.Remotes:FindFirstChild("RE")
                    if re then
                        local ok = pcall(function() re:FireServer() end)
                        if ok then
                            lastRepair = now
                        end
                    end
                end
            end
        end
    end
end)
