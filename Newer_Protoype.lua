local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Just Yet Another Forsaken Script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "🌌 ✨",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false }
})

local GenTab = Window:CreateTab("Generator")
-- Helpers
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
    if not map then return nil end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest, dist = nil, maxDist or 30
    for _, obj in ipairs(map:GetChildren()) do
        if obj.Name == "Generator" and obj.PrimaryPart and obj:FindFirstChild("Remotes") and obj:FindFirstChild("Progress") then
            local d = (hrp.Position - obj.PrimaryPart.Position).Magnitude
            if d < dist then
                closest, dist = obj, d
            end
        end
    end
    return closest, dist
end
-- Generator Tab
local autoRepair = false
local repairCooldown = 6.2
local lastRepair, lastManual = 0, 0

local _REPAIR_ANIMS = {
    ["rbxassetid://82691533602949"]  = true,
    ["rbxassetid://122604262087779"] = true,
    ["rbxassetid://130355934640695"] = true,
}

local function isRepairing()
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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
            Rayfield:Notify({Title="Generator", Content="Cooldown set to "..num, Duration=1.4})
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
            Rayfield:Notify({Title="Generator", Content="Min 2.4s between manual fires!", Duration=1.5})
            return
        end
        local gen = getClosestGenerator(30)
        if not gen then
            Rayfield:Notify({Title="Generator", Content="No generator found nearby.", Duration=1.6})
            return
        end
        local re = gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")
        if re then
            local ok, err = pcall(function() re:FireServer() end)
            if ok then lastManual = now else
                Rayfield:Notify({Title="Generator", Content="Failed: "..tostring(err), Duration=2.2})
            end
        end
    end
})
-- Auto Repair Loop
task.spawn(function()
    while true do
        task.wait(0.2)
        if autoRepair and isRepairing() then
            local now = tick()
            if now - lastRepair >= repairCooldown then
                local gen = getClosestGenerator(30)
                if gen and gen:FindFirstChild("Remotes") then
                    local re = gen.Remotes:FindFirstChild("RE")
                    if re then
                        pcall(function() re:FireServer() end)
                        lastRepair = now
                    end
                end
            end
        end
    end
end)

-- ESP Tab

