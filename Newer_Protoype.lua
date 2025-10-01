local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({Name="Just Yet Another Forsaken Script",LoadingTitle="Loading...",LoadingSubtitle="🌌 ✨",ConfigurationSaving={Enabled=false},Discord={Enabled=false}})
local GenTab = Window:CreateTab("Generator")
local Players, LocalPlayer = game:GetService("Players"), game:GetService("Players").LocalPlayer

-- Map & Generator
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

-- Auto Repair State
local autoRepair, repairCooldown, lastRepair, lastManual = false, 6.2, 0, 0
local _REPAIR_ANIMS = {["rbxassetid://82691533602949"]=true,["rbxassetid://122604262087779"]=true,["rbxassetid://130355934640695"]=true}

local function isRepairing()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
        if t.Animation and _REPAIR_ANIMS[tostring(t.Animation.AnimationId)] then return true end
    end
end

-- UI
GenTab:CreateToggle({Name="Auto-Repair Generators",CurrentValue=false,Callback=function(v) autoRepair=v end})
GenTab:CreateInput({
    Name="Repair Cooldown (2.4 - 15)",
    PlaceholderText=tostring(repairCooldown),
    Callback=function(v)
        local n=tonumber(v)
        if n then repairCooldown=math.clamp(n,2.4,15) Rayfield:Notify({Title="Generator",Content="Cooldown set to "..repairCooldown,Duration=1.4}) end
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
            if re then pcall(function() re:FireServer() end) lastManual=now end
        end
    end
})

-- Auto Repair Loop
local entryDelay, inRange = 0, false
task.spawn(function()
    while task.wait(0.2) do
        if autoRepair and isRepairing() then
            local now=tick()
            local g=getClosestGenerator(10)
            if g then
                if not inRange then entryDelay=now inRange=true end
                if now-entryDelay>=1 and now-lastRepair>=repairCooldown then
                    local re=g:FindFirstChild("Remotes") and g.Remotes:FindFirstChild("RE")
                    if re then pcall(function() re:FireServer() end) lastRepair=now end
                end
            else
                inRange=false -- reset delay when leaving generator
            end
        end
    end
end)

