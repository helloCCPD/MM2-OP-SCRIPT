-- MM2 Ultimate Script - By HelloCCPD

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Variables
local ESPenabled = false
local ItemESPenabled = false
local FlyEnabled = false
local NoclipEnabled = false
local AutoFarmEnabled = false
local FullbrightEnabled = false
local SpeedEnabled = false
local JumpEnabled = false
local AutoCollectEnabled = false
local InvisibilityEnabled = false
local AutoGrabGunEnabled = false
local XRayEnabled = false

-- Combat Variables
local KillAuraEnabled = false
local KillAuraRange = 1000

-- Aimbot Variables
local AimbotEnabled = false
local AimbotAutoFire = false
local AimbotLockCamera = true
local AimbotTargetMode = "Murderer"
local AimbotKeybind = Enum.KeyCode.E
local AimbotRange = 500
local AimbotCooldown = 0.35
local AimbotConnection = nil
local AimbotLastShot = 0

-- Target Variables
local SelectedPlayerName = ""
local SpectateConnection = nil

local ESPfolder = Instance.new("Folder")
ESPfolder.Name = "MM2_ESP"
ESPfolder.Parent = game.CoreGui

local FlySpeed = 50
local WalkSpeed = 100
local JumpPower = 100
local AutoFarmSpeed = 0.5

-- Fly Variables
local FlyConnection
local FlyBodyGyro, FlyBodyVelocity

-- Role Detection
local Roles = {
    Murderer = nil,
    Sheriff = nil,
    Hero = nil
}

-- ==================== ANTI-KICK ====================
local function SetupAntiKick()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and self == LocalPlayer then
            warn("[Anti-Kick] Blocked kick attempt")
            Rayfield:Notify({
                Title = "Anti-Kick",
                Content = "Blocked kick attempt!",
                Duration = 3,
                Image = "shield",
            })
            return nil
        end
        return oldNamecall(self, ...)
    end)
    
    if LocalPlayer.Kick then
        local oldKick = LocalPlayer.Kick
        LocalPlayer.Kick = function(self, ...)
            if self == LocalPlayer then
                warn("[Anti-Kick] Blocked kick attempt (direct)")
                return nil
            end
            return oldKick(self, ...)
        end
    end
end

pcall(SetupAntiKick)

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "🔪 MM2 Ultimate Hub",
    Icon = "skull",
    LoadingTitle = "MM2 Ultimate Hub",
    LoadingSubtitle = "By HelloCCPD",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MM2_Ultimate",
        FileName = "Config"
    },
    KeySystem = false,
})

-- Tabs
local MainTab = Window:CreateTab("🏠 Main", "home")
local VisualTab = Window:CreateTab("👁️ Visuals", "eye")
local CombatTab = Window:CreateTab("⚔️ Combat", "sword")
local TeleportTab = Window:CreateTab("🚀 Teleport", "move")
local MiscTab = Window:CreateTab("⚙️ Misc", "settings")

-- Notification
Rayfield:Notify({
    Title = "MM2 Ultimate Loaded!",
    Content = "Invisibility toggle updated!",
    Duration = 6.5,
    Image = "check",
})

-- ==================== UTILITY FUNCTIONS ====================

local function GetCharacter()
    if not LocalPlayer then return nil end
    local char = LocalPlayer.Character
    if char and char:IsA("Model") then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if hrp and hum then
            return char, hrp, hum
        end
    end
    return nil, nil, nil
end

local function GetDistance(position)
    local char, hrp = GetCharacter()
    if hrp and position then
        return math.floor((hrp.Position - position).Magnitude)
    end
    return 0
end

-- Safe Teleport
local function SafeTeleport(targetCFrame)
    local char, hrp, hum = GetCharacter()
    if not char or not hrp then
        Rayfield:Notify({ Title = "Error", Content = "Character not ready!", Duration = 3, Image = "x" })
        return false
    end
    
    if not targetCFrame or typeof(targetCFrame) ~= "CFrame" then
        Rayfield:Notify({ Title = "Error", Content = "Invalid teleport location!", Duration = 3, Image = "x" })
        return false
    end
    
    local success = pcall(function()
        hrp.CFrame = targetCFrame + Vector3.new(0, 3, 0)
    end)
    
    return success
end

-- ==================== INVISIBILITY (SERVER-SIDE) ====================
local InvisibleConnection = nil
local InvisibleRenderLoop = nil

local function ApplyTransparency(container, t)
    if not container then return end
    for _, obj in pairs(container:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = t
        end
    end
end

local function SetPlayerTransparency(char, t)
    if not char then return end
    for _, obj in pairs(char:GetDescendants()) do
        if (obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart") or obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = t
        end
    end
    -- weapons in the Backpack (knife on back / gun on waist)
    ApplyTransparency(LocalPlayer:FindFirstChild("Backpack"), t)
    -- weapons welded into the character's assembly but parented elsewhere
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, part in pairs(root:GetConnectedParts(true)) do
            if part:IsA("BasePart") and not part:IsDescendantOf(char) then
                part.Transparency = t
            end
        end
    end
end

-- Force the server to re-replicate the character (the actual server-side trick)
local function ForceServerReplication()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local pos = hrp.Position

    -- shove the character far away so the server drops/rebuilds its replication
    char:MoveTo(pos + Vector3.new(0, 1000000, 0))
    task.wait(0.1)

    -- destroy + replace the root so the server re-reads the character's state
    local newRoot = hrp:Clone()
    hrp:Destroy()
    newRoot.Parent = char

    -- re-link the rig to the new root (keeps the character from falling apart)
    for _, d in pairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and (d.Part1 == nil or d.Part1 == hrp) then
            d.Part1 = newRoot
        end
    end

    char:MoveTo(pos)
    task.wait(0.1)
end

local function EnableInvisibility()
    if not LocalPlayer.Character then return end

    -- 1) force the server to re-replicate the character
    ForceServerReplication()

    -- 2) hide locally (this now carries to the server)
    SetPlayerTransparency(LocalPlayer.Character, 1)

    if InvisibleConnection then InvisibleConnection:Disconnect() end
    if InvisibleRenderLoop then InvisibleRenderLoop:Disconnect() end

    InvisibleRenderLoop = RunService.Heartbeat:Connect(function()
        if not InvisibilityEnabled then return end
        local c = LocalPlayer.Character
        if c then
            SetPlayerTransparency(c, 1)
        end
    end)
    
    InvisibleConnection = RunService.Stepped:Connect(function()
        if not InvisibilityEnabled then return end
        local c, hRoot, hHum = GetCharacter()
        if hHum then
            hHum.MaxHealth = 9e9
            hHum.Health = 9e9
            hHum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            hHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end
        if c then
            for _, part in pairs(c:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanTouch = false
                end
            end
        end
    end)
end

local function DisableInvisibility()
    if InvisibleConnection then InvisibleConnection:Disconnect() InvisibleConnection = nil end
    if InvisibleRenderLoop then InvisibleRenderLoop:Disconnect() InvisibleRenderLoop = nil end

    local char, hrp, hum = GetCharacter()
    if char then
        SetPlayerTransparency(char, 0)
    end

    -- refresh so the "visible again" state also replicates
    ForceServerReplication()

    hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum.MaxHealth = 100
        hum.Health = 100
    end
end

-- ==================== MAP & LOBBY DETECTION ====================

local function TeleportToLobby()
    local lobbyObj = Workspace:FindFirstChild("Lobby") or Workspace:FindFirstChild("LOBBY")
    if lobbyObj then
        local spawnPart = lobbyObj:FindFirstChildWhichIsA("SpawnLocation", true) or lobbyObj:FindFirstChildWhichIsA("BasePart", true)
        if spawnPart then
            return SafeTeleport(spawnPart.CFrame)
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") and not obj:FindFirstAncestor("Map") then
            return SafeTeleport(obj.CFrame)
        end
    end

    return SafeTeleport(CFrame.new(0, 50, 0))
end

local function TeleportToMap()
    local mapObj = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("CurrentMap")
    if mapObj then
        local spawnPart = mapObj:FindFirstChildWhichIsA("SpawnLocation", true) or mapObj:FindFirstChildWhichIsA("BasePart", true)
        if spawnPart then
            return SafeTeleport(spawnPart.CFrame)
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj.Name == "Coin" or obj.Name == "Coin_Server") and obj:IsA("BasePart") then
            return SafeTeleport(obj.CFrame + Vector3.new(0, 3, 0))
        end
    end

    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name ~= "Lobby" and obj ~= LocalPlayer.Character then
            local spawns = {}
            for _, child in pairs(obj:GetDescendants()) do
                if child:IsA("SpawnLocation") or child.Name:lower():find("spawn") then
                    table.insert(spawns, child)
                end
            end
            if #spawns > 0 then
                local chosen = spawns[math.random(1, #spawns)]
                return SafeTeleport(chosen.CFrame)
            end
        end
    end

    Rayfield:Notify({ Title = "Error", Content = "No active map detected! Wait for round start.", Duration = 3, Image = "x" })
    return false
end

-- ==================== ROLES ====================
local function UpdateRoles()
    Roles.Murderer = nil
    Roles.Sheriff = nil
    Roles.Hero = nil
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local backpack = player:FindFirstChild("Backpack")
            local character = player.Character
            
            if backpack then
                if backpack:FindFirstChild("Knife") or (character and character:FindFirstChild("Knife")) then
                    Roles.Murderer = player
                elseif backpack:FindFirstChild("Gun") or (character and character:FindFirstChild("Gun")) then
                    Roles.Sheriff = player
                elseif backpack:FindFirstChild("Hero") or (character and character:FindFirstChild("Hero")) then
                    Roles.Hero = player
                end
            end
        end
    end
end

-- ==================== GUN DETECTION & GRAB ====================

local function FindDroppedGun()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "GunDrop" or obj.Name == "DroppedGun" or obj.Name == "Gun") then
            return obj
        end
    end
    return nil
end

local function GrabGun()
    local gun = FindDroppedGun()
    if gun then
        local success = SafeTeleport(gun.CFrame)
        if success then
            Rayfield:Notify({ Title = "Gun Teleport", Content = "Teleported to dropped gun!", Duration = 3, Image = "crosshair" })
        end
        return success
    else
        Rayfield:Notify({ Title = "Error", Content = "No dropped gun found on the map!", Duration = 3, Image = "x" })
        return false
    end
end

local AutoGrabConnection = nil
local function StartAutoGrabGun()
    if AutoGrabConnection then AutoGrabConnection:Disconnect() AutoGrabConnection = nil end
    
    AutoGrabConnection = RunService.Heartbeat:Connect(function()
        if not AutoGrabGunEnabled then return end
        local gun = FindDroppedGun()
        if gun then
            local char, hrp = GetCharacter()
            if hrp then
                hrp.CFrame = gun.CFrame
            end
        end
    end)
end

local function StopAutoGrabGun()
    if AutoGrabConnection then
        AutoGrabConnection:Disconnect()
        AutoGrabConnection = nil
    end
end

-- ==================== COMBAT: KNIFE KILL AURA & FLING KILLING ====================

local function TriggerKnifeAttack(targetChar)
    local char, hrp = GetCharacter()
    if not char then return end
    
    local knife = char:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
    if knife then
        if knife.Parent == LocalPlayer.Backpack then
            knife.Parent = char
        end
        
        knife:Activate()
        
        local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
        if targetHrp then
            local knifeServer = knife:FindFirstChild("Stab") or knife:FindFirstChild("KnifeServer") or knife:FindFirstChild("Server")
            if knifeServer and knifeServer:IsA("RemoteEvent") then
                knifeServer:FireServer(targetHrp)
            end
            local handle = knife:FindFirstChild("Handle")
            if handle and typeof(firetouchinterest) == "function" then
                pcall(function()
                    firetouchinterest(handle, targetHrp, 0)
                    firetouchinterest(handle, targetHrp, 1)
                end)
            end
        end
    end
end

local function FlingTargetModel(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local char, hrp, hum = GetCharacter()
    if not char or not hrp or not hum then return false end

    local targetHrp = targetPlayer.Character.HumanoidRootPart
    local oldCFrame = hrp.CFrame

    local knife = char:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
    if knife and knife.Parent == LocalPlayer.Backpack then
        knife.Parent = char
    end

    local noclipLoop = RunService.Stepped:Connect(function()
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)

    local flingLoop
    local startTime = tick()

    flingLoop = RunService.Heartbeat:Connect(function()
        if not targetHrp or not targetHrp.Parent or not hrp or not hrp.Parent or (tick() - startTime > 1.8) then
            if flingLoop then flingLoop:Disconnect() end
            return
        end

        if knife then
            knife:Activate()
        end

        hrp.CFrame = targetHrp.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
        hrp.RotVelocity = Vector3.new(0, 100000, 0)
        hrp.Velocity = Vector3.new(100000, 100000, 100000)
    end)

    task.wait(1.8)

    if flingLoop then flingLoop:Disconnect() end
    if noclipLoop then noclipLoop:Disconnect() end

    hrp.RotVelocity = Vector3.new(0, 0, 0)
    hrp.Velocity = Vector3.new(0, 0, 0)
    hrp.CFrame = oldCFrame

    return true
end

local function KillMurdererAnywhere()
    UpdateRoles()
    if not Roles.Murderer or not Roles.Murderer.Character then
        Rayfield:Notify({ Title = "Error", Content = "No Murderer found in server!", Duration = 3, Image = "x" })
        return
    end

    local success = FlingTargetModel(Roles.Murderer)
    if success then
        Rayfield:Notify({ Title = "Murderer Eliminated", Content = "Fling-killed Murderer from distance!", Duration = 3, Image = "skull" })
    end
end

local function KillSheriffAnywhere()
    UpdateRoles()
    local targetSheriff = Roles.Sheriff or Roles.Hero
    if not targetSheriff or not targetSheriff.Character then
        Rayfield:Notify({ Title = "Error", Content = "No Sheriff/Hero found in server!", Duration = 3, Image = "x" })
        return
    end

    local success = FlingTargetModel(targetSheriff)
    if success then
        Rayfield:Notify({ Title = "Sheriff Eliminated", Content = "Fling-killed Sheriff from distance!", Duration = 3, Image = "skull" })
    end
end

RunService.Heartbeat:Connect(function()
    if not KillAuraEnabled then return end
    local char, hrp = GetCharacter()
    if not char or not hrp then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = player.Character:FindFirstChild("Humanoid")
            
            if targetHrp and targetHum and targetHum.Health > 0 then
                local dist = (hrp.Position - targetHrp.Position).Magnitude
                if dist <= KillAuraRange then
                    TriggerKnifeAttack(player.Character)
                end
            end
        end
    end
end)

-- ==================== AIMBOT (REBUILT) ====================

local function GetGunTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    local gun = char:FindFirstChild("Gun")
    if not gun then
        gun = LocalPlayer.Backpack:FindFirstChild("Gun")
        if gun then gun.Parent = char end
    end
    return gun
end

local function GetAimbotTarget()
    UpdateRoles()
    local _, hrp = GetCharacter()
    if not hrp then return nil end

    local candidates = {}
    if AimbotTargetMode == "Murderer" then
        if Roles.Murderer then table.insert(candidates, Roles.Murderer) end
    elseif AimbotTargetMode == "Sheriff" then
        local s = Roles.Sheriff or Roles.Hero
        if s then table.insert(candidates, s) end
    else
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then table.insert(candidates, plr) end
        end
    end

    local best, bestDist = nil, AimbotRange
    for _, plr in pairs(candidates) do
        if plr ~= LocalPlayer and plr.Character then
            local th = plr.Character:FindFirstChild("HumanoidRootPart")
            local hh = plr.Character:FindFirstChild("Humanoid")
            if th and hh and hh.Health > 0 then
                local d = (th.Position - hrp.Position).Magnitude
                if d <= bestDist then
                    best, bestDist = plr, d
                end
            end
        end
    end
    return best
end

local function GetAimPosition()
    local _, hrp = GetCharacter()
    if not hrp then return nil end
    local target = GetAimbotTarget()
    if not target or not target.Character then return nil end
    local th = target.Character:FindFirstChild("HumanoidRootPart")
    local hh = target.Character:FindFirstChild("Humanoid")
    if not th or not hh or hh.Health <= 0 then return nil end

    local bulletSpeed = 250
    local timeToHit = (th.Position - hrp.Position).Magnitude / bulletSpeed
    return th.Position + (th.Velocity * timeToHit)
end

local function AimbotAim()
    local aimPos = GetAimPosition()
    if not aimPos then return nil end
    local _, hrp = GetCharacter()
    if not hrp then return nil end

    if AimbotLockCamera then
        Workspace.CurrentCamera.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position, aimPos)
    end
    hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(aimPos.X, hrp.Position.Y, aimPos.Z))
    return aimPos
end

local function AimbotFire()
    local aimPos = AimbotAim()
    if not aimPos then
        Rayfield:Notify({ Title = "Aimbot", Content = "No target found!", Duration = 2.5, Image = "x" })
        return
    end

    local gun = GetGunTool()
    if not gun then
        Rayfield:Notify({ Title = "Aimbot", Content = "You do not have the Gun!", Duration = 2.5, Image = "x" })
        return
    end

    local shootRemote = gun:FindFirstChild("ShootGun") or ReplicatedStorage:FindFirstChild("ShootGun", true)
    if shootRemote and shootRemote:IsA("RemoteEvent") then
        pcall(function() shootRemote:FireServer(aimPos) end)
    end
    pcall(function() gun:Activate() end)

    AimbotLastShot = os.clock()
end

local function StartAimbotLoop()
    if AimbotConnection then AimbotConnection:Disconnect() end
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if not AimbotEnabled then return end
        if AimbotLockCamera then AimbotAim() end
        if AimbotAutoFire and (os.clock() - AimbotLastShot >= AimbotCooldown) then
            AimbotFire()
        end
    end)
end

local function StopAimbotLoop()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
end

-- ==================== SPECTATE ====================

local function FlingPlayer(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then
        Rayfield:Notify({ Title = "Error", Content = "Target player missing!", Duration = 3, Image = "x" })
        return
    end
    FlingTargetModel(target)
end

local function SpectatePlayer(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character or not target.Character:FindFirstChild("Humanoid") then
        Rayfield:Notify({ Title = "Error", Content = "Cannot spectate player!", Duration = 3, Image = "x" })
        return
    end

    if SpectateConnection then SpectateConnection:Disconnect() end

    local cam = Workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Custom

    SpectateConnection = RunService.RenderStepped:Connect(function()
        if target and target.Character and target.Character:FindFirstChild("Humanoid") then
            cam.CameraSubject = target.Character.Humanoid
        else
            if SpectateConnection then SpectateConnection:Disconnect() end
            local _, _, hum = GetCharacter()
            if hum then cam.CameraSubject = hum end
        end
    end)

    Rayfield:Notify({ Title = "Spectating", Content = "Now spectating " .. targetName, Duration = 3, Image = "eye" })
end

local function StopSpectating()
    if SpectateConnection then
        SpectateConnection:Disconnect()
        SpectateConnection = nil
    end
    local char, hrp, hum = GetCharacter()
    if hum then
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        Workspace.CurrentCamera.CameraSubject = hum
        Rayfield:Notify({ Title = "Spectate Stopped", Content = "Camera reset to local character.", Duration = 3, Image = "check" })
    end
end

-- ==================== ESP ====================
local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local roleText = "Innocent"
    local roleColor = Color3.fromRGB(0, 255, 0)
    
    if Roles.Murderer == player then
        roleText = "Murderer"
        roleColor = Color3.fromRGB(255, 0, 0)
    elseif Roles.Sheriff == player then
        roleText = "Sheriff"
        roleColor = Color3.fromRGB(0, 100, 255)
    elseif Roles.Hero == player then
        roleText = "Hero"
        roleColor = Color3.fromRGB(255, 215, 0)
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = player.Name .. "_ESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    
    local roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "RoleLabel"
    roleLabel.Parent = billboard
    roleLabel.BackgroundTransparency = 1
    roleLabel.Size = UDim2.new(1, 0, 0.5, 0)
    roleLabel.Text = roleText
    roleLabel.TextColor3 = roleColor
    roleLabel.TextStrokeTransparency = 0
    roleLabel.TextSize = 14
    roleLabel.Font = Enum.Font.GothamBold
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Parent = billboard
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
    nameLabel.Text = player.Name .. " [0m]"
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.Gotham
    
    local box = Instance.new("BoxHandleAdornment")
    box.Name = player.Name .. "_Box"
    box.Size = Vector3.new(4, 5, 4)
    box.Color3 = roleColor
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.6
    
    return billboard, box
end

local function UpdateESP()
    for _, v in pairs(ESPfolder:GetChildren()) do
        v:Destroy()
    end
    
    if not ESPenabled then return end
    
    UpdateRoles()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local billboard, box = CreateESP(player)
                if billboard and box then
                    billboard.Parent = ESPfolder
                    billboard.Adornee = hrp
                    box.Parent = ESPfolder
                    box.Adornee = hrp
                    
                    task.spawn(function()
                        while billboard.Parent and player.Character and player.Character:FindFirstChild("HumanoidRootPart") do
                            local dist = GetDistance(player.Character.HumanoidRootPart.Position)
                            local nameLabel = billboard:FindFirstChild("NameLabel")
                            if nameLabel then
                                nameLabel.Text = player.Name .. " [" .. dist .. "m]"
                            end
                            task.wait(0.2)
                        end
                    end)
                end
            end
        end
    end
end

local function UpdateItemESP()
    for _, v in pairs(ESPfolder:GetChildren()) do
        if v.Name:match("Item_") then
            v:Destroy()
        end
    end
    
    if not ItemESPenabled then return end
    
    for _, item in pairs(Workspace:GetDescendants()) do
        if item:IsA("BasePart") and (item.Name == "GunDrop" or item.Name == "DroppedGun" or item.Name == "Gun") then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "Item_Gun"
            billboard.AlwaysOnTop = true
            billboard.Size = UDim2.new(0, 120, 0, 35)
            billboard.StudsOffset = Vector3.new(0, 1.5, 0)
            billboard.Parent = ESPfolder
            billboard.Adornee = item
            
            local label = Instance.new("TextLabel")
            label.Parent = billboard
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 1, 0)
            label.Text = "🔫 GUN [0m]"
            label.TextColor3 = Color3.fromRGB(0, 255, 255)
            label.TextStrokeTransparency = 0
            label.TextSize = 12
            label.Font = Enum.Font.GothamBold
            
            task.spawn(function()
                while billboard.Parent and item.Parent do
                    local dist = GetDistance(item.Position)
                    label.Text = "🔫 GUN [" .. dist .. "m]"
                    task.wait(0.2)
                end
            end)
        end
    end
end

-- ==================== X-RAY ====================
local XRayTransparency = 0.8
local XRaySaved = {}
local XRayAddedConnection = nil
local XRayHighlightConnections = {}
local XRayHighlights = {}

local function XRayIsCharacterPart(part)
    local model = part:FindFirstAncestorOfClass("Model")
    return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local function XRayApplyPart(part)
    if not XRayEnabled then return end
    if not part:IsA("BasePart") then return end
    if XRayIsCharacterPart(part) then return end
    if XRaySaved[part] == nil then
        XRaySaved[part] = part.Transparency
    end
    part.Transparency = XRayTransparency
end

local function XRayAddHighlight(character)
    if not character or XRayHighlights[character] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "MM2_XRayHighlight"
    highlight.FillColor = Color3.fromRGB(0, 255, 130)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = character
    XRayHighlights[character] = highlight
end

local function XRayHookPlayer(player)
    if player == LocalPlayer then return end
    if XRayHighlightConnections[player] then return end
    local connection = player.CharacterAdded:Connect(function(character)
        if XRayEnabled then
            task.wait(0.2)
            XRayAddHighlight(character)
        end
    end)
    XRayHighlightConnections[player] = connection
end

local function EnableXRay()
    XRayEnabled = true
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            XRayApplyPart(obj)
        end
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            XRayAddHighlight(player.Character)
        end
        XRayHookPlayer(player)
    end
    if XRayAddedConnection then XRayAddedConnection:Disconnect() end
    XRayAddedConnection = Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then
            task.defer(function() XRayApplyPart(obj) end)
        end
    end)
end

local function DisableXRay()
    XRayEnabled = false
    if XRayAddedConnection then XRayAddedConnection:Disconnect() XRayAddedConnection = nil end
    for _, connection in pairs(XRayHighlightConnections) do
        connection:Disconnect()
    end
    XRayHighlightConnections = {}
    for _, highlight in pairs(XRayHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    XRayHighlights = {}
    for part, transparency in pairs(XRaySaved) do
        if part and part.Parent then
            part.Transparency = transparency
        end
    end
    XRaySaved = {}
end

Players.PlayerAdded:Connect(function(player)
    if XRayEnabled then
        XRayHookPlayer(player)
    end
end)

-- ==================== FLY ====================
local function StopFly()
    FlyEnabled = false
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
end

local function StartFly()
    if FlyEnabled then return end
    local char, hrp = GetCharacter()
    if not hrp then
        Rayfield:Notify({ Title = "Error", Content = "Character not ready!", Duration = 3, Image = "x" })
        return
    end
    
    FlyEnabled = true
    
    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.P = 9e4
    FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyGyro.CFrame = hrp.CFrame
    FlyBodyGyro.Parent = hrp
    
    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    FlyBodyVelocity.Parent = hrp
    
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not FlyEnabled then return end
        local camera = Workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        FlyBodyVelocity.Velocity = moveDir * FlySpeed
        FlyBodyGyro.CFrame = camera.CFrame
    end)
end

-- Noclip
local NoclipConnection
local function EnableNoclip()
    NoclipConnection = RunService.Stepped:Connect(function()
        if NoclipEnabled then
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

-- ==================== AUTO FEATURES ====================
local function GetCoins()
    local coins = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if (v.Name == "Coin" or v.Name == "Coin_Server") and v:IsA("BasePart") then
            table.insert(coins, v)
        end
    end
    return coins
end

local function AutoFarm()
    while AutoFarmEnabled do
        local coins = GetCoins()
        for _, coin in pairs(coins) do
            if not AutoFarmEnabled then break end
            if coin and coin.Parent then
                local char, hrp = GetCharacter()
                if hrp then
                    local tween = TweenService:Create(hrp, TweenInfo.new(AutoFarmSpeed), {CFrame = coin.CFrame + Vector3.new(0, 2, 0)})
                    tween:Play()
                    tween.Completed:Wait()
                    task.wait(0.1)
                end
            end
        end
        task.wait(0.5)
    end
end

local function AutoCollect()
    while AutoCollectEnabled do
        local char, hrp = GetCharacter()
        if hrp then
            for _, coin in pairs(GetCoins()) do
                if coin and coin.Parent then
                    if (hrp.Position - coin.Position).Magnitude < 15 then
                        hrp.CFrame = coin.CFrame
                    end
                end
            end
        end
        task.wait(0.1)
    end
end

local function SetFullbright(enabled)
    if enabled then
        Lighting.Brightness = 10
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    else
        Lighting.Brightness = 2
        Lighting.GlobalShadows = true
        Lighting.Ambient = Color3.fromRGB(127, 127, 127)
        Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
    end
end

-- ==================== UI ====================

-- MAIN TAB
MainTab:CreateSection("Character Mods")

MainTab:CreateToggle({
    Name = "Invisibility",
    CurrentValue = false,
    Flag = "InvisibilityToggle",
    Callback = function(Value)
        InvisibilityEnabled = Value
        if Value then
            EnableInvisibility()
            Rayfield:Notify({ Title = "Invisibility", Content = "Invisibility Active!", Duration = 3, Image = "eye-off" })
        else
            DisableInvisibility()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(Value)
        if Value then StartFly() else StopFly() end
    end,
})

MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = " studs/s",
    CurrentValue = 50,
    Flag = "FlySpeedSlider",
    Callback = function(Value) FlySpeed = Value end,
})

MainTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "NoclipToggle",
    Callback = function(Value)
        NoclipEnabled = Value
        if Value then EnableNoclip() elseif NoclipConnection then NoclipConnection:Disconnect() end
    end,
})

MainTab:CreateSection("Speed & Jump")

MainTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Flag = "SpeedToggle",
    Callback = function(Value)
        SpeedEnabled = Value
        local _, _, hum = GetCharacter()
        if hum then hum.WalkSpeed = Value and WalkSpeed or 16 end
    end,
})

MainTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 5,
    Suffix = " studs/s",
    CurrentValue = 100,
    Flag = "WalkSpeedSlider",
    Callback = function(Value)
        WalkSpeed = Value
        local _, _, hum = GetCharacter()
        if hum and SpeedEnabled then hum.WalkSpeed = Value end
    end,
})

MainTab:CreateToggle({
    Name = "Jump Power",
    CurrentValue = false,
    Flag = "JumpToggle",
    Callback = function(Value)
        JumpEnabled = Value
        local _, _, hum = GetCharacter()
        if hum then hum.JumpPower = Value and JumpPower or 50 end
    end,
})

MainTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 200},
    Increment = 5,
    Suffix = " power",
    CurrentValue = 100,
    Flag = "JumpPowerSlider",
    Callback = function(Value)
        JumpPower = Value
        local _, _, hum = GetCharacter()
        if hum and JumpEnabled then hum.JumpPower = Value end
    end,
})

-- VISUAL TAB
VisualTab:CreateSection("Player ESP")

VisualTab:CreateToggle({
    Name = "Player ESP + Distance",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(Value)
        ESPenabled = Value
        if Value then
            task.spawn(function()
                while ESPenabled do
                    UpdateESP()
                    task.wait(1)
                end
            end)
        else
            for _, v in pairs(ESPfolder:GetChildren()) do v:Destroy() end
        end
    end,
})

VisualTab:CreateParagraph({
    Title = "ESP Layout",
    Content = "🔴 Murderer\n🔵 Sheriff\n🟢 Innocent\n\nName + Distance below"
})

VisualTab:CreateToggle({
    Name = "Item ESP (Gun Drops)",
    CurrentValue = false,
    Flag = "ItemESPToggle",
    Callback = function(Value)
        ItemESPenabled = Value
        if Value then
            task.spawn(function()
                while ItemESPenabled do
                    UpdateItemESP()
                    task.wait(1)
                end
            end)
        else
            for _, v in pairs(ESPfolder:GetChildren()) do
                if v.Name:match("Item_") then v:Destroy() end
            end
        end
    end,
})

VisualTab:CreateSection("X-Ray")

VisualTab:CreateToggle({
    Name = "X-Ray (See Through Walls)",
    CurrentValue = false,
    Flag = "XRayToggle",
    Callback = function(Value)
        if Value then
            EnableXRay()
            Rayfield:Notify({ Title = "X-Ray", Content = "X-Ray Enabled! Walls are see-through.", Duration = 3, Image = "eye" })
        else
            DisableXRay()
        end
    end,
})

VisualTab:CreateSlider({
    Name = "X-Ray Transparency",
    Range = {0.3, 0.95},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.8,
    Flag = "XRayTransparencySlider",
    Callback = function(Value)
        XRayTransparency = Value
        if XRayEnabled then
            for part in pairs(XRaySaved) do
                if part and part.Parent then
                    part.Transparency = Value
                end
            end
        end
    end,
})

VisualTab:CreateSection("World")

VisualTab:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "FullbrightToggle",
    Callback = function(Value)
        FullbrightEnabled = Value
        SetFullbright(Value)
    end,
})

-- COMBAT TAB
CombatTab:CreateSection("Auto Features")

CombatTab:CreateToggle({
    Name = "Auto Farm Coins",
    CurrentValue = false,
    Flag = "AutoFarmToggle",
    Callback = function(Value)
        AutoFarmEnabled = Value
        if Value then task.spawn(AutoFarm) end
    end,
})

CombatTab:CreateSlider({
    Name = "Auto Farm Speed",
    Range = {0.1, 2},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.5,
    Flag = "FarmSpeedSlider",
    Callback = function(Value) AutoFarmSpeed = Value end,
})

CombatTab:CreateToggle({
    Name = "Auto Collect",
    CurrentValue = false,
    Flag = "AutoCollectToggle",
    Callback = function(Value)
        AutoCollectEnabled = Value
        if Value then task.spawn(AutoCollect) end
    end,
})

CombatTab:CreateSection("Gun Features")

CombatTab:CreateToggle({
    Name = "Auto-Grab Dropped Gun",
    CurrentValue = false,
    Flag = "AutoGrabGunToggle",
    Callback = function(Value)
        AutoGrabGunEnabled = Value
        if Value then
            StartAutoGrabGun()
            Rayfield:Notify({ Title = "Auto Grab", Content = "Auto-grab dropped gun active!", Duration = 3, Image = "crosshair" })
        else
            StopAutoGrabGun()
        end
    end,
})

CombatTab:CreateButton({
    Name = "Instant Teleport to Dropped Gun",
    Callback = function()
        GrabGun()
    end,
})

CombatTab:CreateSection("Fling Combat")

CombatTab:CreateButton({
    Name = "Fling-Kill Murderer From Anywhere",
    Callback = function()
        KillMurdererAnywhere()
    end,
})

CombatTab:CreateButton({
    Name = "Fling-Kill Sheriff From Anywhere",
    Callback = function()
        KillSheriffAnywhere()
    end,
})

CombatTab:CreateToggle({
    Name = "Knife Kill Aura",
    CurrentValue = false,
    Flag = "KillAuraToggle",
    Callback = function(Value)
        KillAuraEnabled = Value
        if Value then
            Rayfield:Notify({ Title = "Kill Aura", Content = "Knife Kill Aura Active!", Duration = 3, Image = "sword" })
        end
    end,
})

CombatTab:CreateSlider({
    Name = "Kill Aura Range",
    Range = {5, 1000},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 1000,
    Flag = "KillAuraRangeSlider",
    Callback = function(Value)
        KillAuraRange = Value
    end,
})

CombatTab:CreateSection("Aimbot")

CombatTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        AimbotEnabled = Value
        if Value then
            StartAimbotLoop()
            Rayfield:Notify({ Title = "Aimbot", Content = "Aimbot Active! Targets: " .. AimbotTargetMode, Duration = 3, Image = "crosshair" })
        else
            StopAimbotLoop()
        end
    end,
})

CombatTab:CreateDropdown({
    Name = "Aimbot Target",
    Options = {"Murderer", "Sheriff", "Nearest"},
    CurrentOption = "Murderer",
    Flag = "AimbotTargetDropdown",
    Callback = function(Option)
        if typeof(Option) == "table" then
            AimbotTargetMode = Option[1] or "Murderer"
        else
            AimbotTargetMode = Option or "Murderer"
        end
    end,
})

CombatTab:CreateToggle({
    Name = "Aimbot Auto-Fire",
    CurrentValue = false,
    Flag = "AimbotAutoFireToggle",
    Callback = function(Value)
        AimbotAutoFire = Value
    end,
})

CombatTab:CreateToggle({
    Name = "Aimbot Lock Camera",
    CurrentValue = true,
    Flag = "AimbotLockCameraToggle",
    Callback = function(Value)
        AimbotLockCamera = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Aimbot Range",
    Range = {50, 1000},
    Increment = 25,
    Suffix = " studs",
    CurrentValue = 500,
    Flag = "AimbotRangeSlider",
    Callback = function(Value)
        AimbotRange = Value
    end,
})

CombatTab:CreateKeybind({
    Name = "Aimbot Fire Keybind",
    CurrentKeybind = "E",
    HoldToInteract = false,
    Flag = "AimbotKeybind",
    Callback = function(Keybind)
        if typeof(Keybind) == "table" then
            AimbotKeybind = Keybind[1] or Enum.KeyCode.E
        elseif typeof(Keybind) == "EnumItem" then
            AimbotKeybind = Keybind
        elseif typeof(Keybind) == "string" and Enum.KeyCode[Keybind] then
            AimbotKeybind = Enum.KeyCode[Keybind]
        end
        if AimbotEnabled then
            AimbotFire()
        end
    end,
})

CombatTab:CreateButton({
    Name = "Fire At Target (Manual)",
    Callback = function()
        AimbotFire()
    end,
})

-- TELEPORT TAB
TeleportTab:CreateSection("Location Teleports")

TeleportTab:CreateButton({
    Name = "Teleport to Lobby",
    Callback = function()
        local success = TeleportToLobby()
        if success then
            Rayfield:Notify({ Title = "Teleport", Content = "Teleported to Lobby!", Duration = 3, Image = "check" })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Map",
    Callback = function()
        local success = TeleportToMap()
        if success then
            Rayfield:Notify({ Title = "Teleport", Content = "Teleported to Active Map!", Duration = 3, Image = "check" })
        end
    end,
})

TeleportTab:CreateSection("Player Actions")

local PlayerDropdown = TeleportTab:CreateDropdown({
    Name = "Select Player",
    Options = {},
    CurrentOption = "",
    Flag = "PlayerDropdown",
    Callback = function(Option)
        if typeof(Option) == "table" then
            SelectedPlayerName = Option[1] or ""
        else
            SelectedPlayerName = Option or ""
        end
    end,
})

local function RefreshPlayerDropdown()
    local names = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    PlayerDropdown:Refresh(names)
end

task.spawn(function()
    while task.wait(2.5) do
        pcall(RefreshPlayerDropdown)
    end
end)

TeleportTab:CreateButton({
    Name = "Teleport to Selected Player",
    Callback = function()
        if SelectedPlayerName ~= "" then
            local target = Players:FindFirstChild(SelectedPlayerName)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                SafeTeleport(target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
                Rayfield:Notify({ Title = "Teleported", Content = "Teleported to " .. SelectedPlayerName, Duration = 3, Image = "check" })
            else
                Rayfield:Notify({ Title = "Error", Content = "Target player model not found!", Duration = 3, Image = "x" })
            end
        else
            Rayfield:Notify({ Title = "Error", Content = "Select a player from the dropdown first!", Duration = 3, Image = "x" })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Fling Selected Player",
    Callback = function()
        if SelectedPlayerName ~= "" then
            FlingPlayer(SelectedPlayerName)
        else
            Rayfield:Notify({ Title = "Error", Content = "Select a player from the dropdown first!", Duration = 3, Image = "x" })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Spectate Selected Player",
    Callback = function()
        if SelectedPlayerName ~= "" then
            SpectatePlayer(SelectedPlayerName)
        else
            Rayfield:Notify({ Title = "Error", Content = "Select a player from the dropdown first!", Duration = 3, Image = "x" })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Stop Spectating",
    Callback = function()
        StopSpectating()
    end,
})

TeleportTab:CreateSection("Role Teleports")

TeleportTab:CreateButton({
    Name = "Teleport to Murderer",
    Callback = function()
        UpdateRoles()
        if Roles.Murderer and Roles.Murderer.Character then
            SafeTeleport(Roles.Murderer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
        else
            Rayfield:Notify({ Title = "Error", Content = "No murderer found!", Duration = 3, Image = "x" })
        end
    end,
})

TeleportTab:CreateButton({
    Name = "Teleport to Sheriff",
    Callback = function()
        UpdateRoles()
        if Roles.Sheriff and Roles.Sheriff.Character then
            SafeTeleport(Roles.Sheriff.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
        else
            Rayfield:Notify({ Title = "Error", Content = "No sheriff found!", Duration = 3, Image = "x" })
        end
    end,
})

-- MISC TAB
MiscTab:CreateSection("Protection")

MiscTab:CreateParagraph({
    Title = "Anti-Kick",
    Content = "✅ Active - Blocks client kicks"
})

MiscTab:CreateParagraph({
    Title = "Invisibility",
    Content = "Toggle in Main tab"
})

MiscTab:CreateSection("Utilities")

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(Value)
        if Value then
            local vu = game:GetService("VirtualUser")
            LocalPlayer.Idled:Connect(function()
                vu:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                task.wait(1)
                vu:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
        end
    end,
})

MiscTab:CreateButton({
    Name = "Respawn",
    Callback = function()
        local char = LocalPlayer.Character
        if char then char:BreakJoints() end
    end,
})

MiscTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})

-- Character handler
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    
    if SpeedEnabled then hum.WalkSpeed = WalkSpeed end
    if JumpEnabled then hum.JumpPower = JumpPower end
    if InvisibilityEnabled then EnableInvisibility() end
    if FlyEnabled then task.wait(0.5) StartFly() end
    if AutoGrabGunEnabled then StartAutoGrabGun() end
end)

-- Role loop
task.spawn(function()
    while task.wait(2) do
        UpdateRoles()
    end
end)

-- Final notification
Rayfield:Notify({
    Title = "Ready!",
    Content = "Script Ready!",
    Duration = 5,
    Image = "check",
})
