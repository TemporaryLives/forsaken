local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({Name="Just Yet Another Forsaken Script",LoadingTitle="Loading...",LoadingSubtitle="🌌 ✨",ConfigurationSaving={Enabled=false},Discord={Enabled=false}})
local GenTab = Window:CreateTab("Generator")
local Players, LocalPlayer = game:GetService("Players"), game:GetService("Players").LocalPlayer

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

local autoRepair, repairCooldown, lastRepair, lastManual = false, 6.2, 0, 0
local _REPAIR_ANIMS = {["rbxassetid://82691533602949"]=true,["rbxassetid://122604262087779"]=true,["rbxassetid://130355934640695"]=true}

local function isRepairing()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
        if t.Animation and _REPAIR_ANIMS[tostring(t.Animation.AnimationId)] then return true end
    end
end

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

--ESP Tab (paste in this line not under it)

local PlayerTab = Window:CreateTab("Player", 4483362458)
local Player = game:GetService("Players").LocalPlayer
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

local InfiniteToggle
local CustomToggle

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
            -- Reset defaults
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

local preview={cons={},label=nil,stam=0}
local function EnablePreview()
    local ui,btn=Player.PlayerGui.MainUI,Player.PlayerGui.MainUI.SprintingButton
    local isKiller=workspace.Players.Killers:FindFirstChild(Player.Name)~=nil
    local staminaVal=isKiller and 115 or stamina.MaxStamina
    preview.stam=staminaVal

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.fromOffset(120,24)
    lbl.Position=UDim2.new(0,10,.5,-12)
    lbl.AnchorPoint=Vector2.new(0,.5)
    lbl.BackgroundTransparency=1
    lbl.TextColor3=Color3.new(1,1,1)
    lbl.TextSize=18
    lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Parent=ui
    preview.label=lbl

    local hum,root,shiftHeld,currRun=nil,nil,false,false
    local function charAdded(c) hum,root=c:WaitForChild("Humanoid"),c:WaitForChild("HumanoidRootPart") end
    if Player.Character then charAdded(Player.Character) end

    local function nearestSurvivor(pos)
        local d=math.huge
        for _,s in ipairs(workspace.Players.Survivors:GetChildren())do
            local hrp=s:FindFirstChild("HumanoidRootPart")
            if hrp then d=math.min(d,(hrp.Position-pos).Magnitude) end
        end
        return d
    end

    preview.cons={
        btn.MouseButton1Click:Connect(function() currRun=not currRun end),
        UIS.InputBegan:Connect(function(i,g) if not g and i.KeyCode==Enum.KeyCode.LeftShift then shiftHeld=true end end),
        UIS.InputEnded:Connect(function(i,g) if not g and i.KeyCode==Enum.KeyCode.LeftShift then shiftHeld=false end end),
        Player.CharacterAdded:Connect(charAdded),
        RS.RenderStepped:Connect(function(dt)
            if not (hum and root) then return end
            -- Pull current settings (use custom if on, else defaults)
            local gain = CustomToggle.CurrentValue and stamina.StaminaGain or DefaultStamina.Gain
            local loss = CustomToggle.CurrentValue and stamina.StaminaLoss or DefaultStamina.Loss
            local maxS = CustomToggle.CurrentValue and stamina.MaxStamina or DefaultStamina.Max
            local thresh = 0.5
            local range = 100

            local moving = hum.MoveDirection.Magnitude>0 and Vector3.new(root.Velocity.X,0,root.Velocity.Z).Magnitude>thresh
            local active = (UIS.KeyboardEnabled and shiftHeld) or (UIS.TouchEnabled and currRun)
            local draining = active and moving and (not isKiller or nearestSurvivor(root.Position)<=range)

            preview.stam += (draining and -loss or gain)*dt
            preview.stam = math.clamp(preview.stam,0,maxS)
            lbl.Text=string.format("%d/%d",preview.stam+.5,maxS)
        end)
    }
end

local function DisablePreview()
    if preview.label then preview.label:Destroy() end
    for _,c in ipairs(preview.cons)do c:Disconnect() end
    preview.cons,preview.label={},nil
end

PlayerTab:CreateToggle({
    Name="Show Expected Stamina",
    CurrentValue=false,
    Flag="ShowExpectedStamina",
    Callback=function(v) if v then EnablePreview() else DisablePreview() end end
})

local Ingame=workspace:WaitForChild("Map"):WaitForChild("Ingame")
Ingame.ChildAdded:Connect(function(c)
    if c.Name=="Map" then
        task.wait(1)
        if InfiniteToggle.CurrentValue then
            stamina.StaminaLossDisabled=true
        elseif CustomToggle.CurrentValue then
            -- Reapply custom values from Rayfield flags
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
