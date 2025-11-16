local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

WindUI:AddTheme({
    Name = "E-vil Royal",
    Accent = WindUI:Gradient({
        ["0"] = { Color = Color3.fromHex("#360273"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#004d57"), Transparency = 0 }
    }, { Rotation = 45 }),
    Background = WindUI:Gradient({
        ["0"] = { Color = Color3.fromHex("#360273"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#004d57"), Transparency = 0 }
    }, { Rotation = 45 }),
    Dialog = Color3.fromHex("#1a1a1d"),
    Outline = Color3.fromHex("#FFD700"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#c0a763"),
    Button = Color3.fromHex("#411b65"),
    Icon = Color3.fromHex("#FFD700")
})

WindUI:SetTheme("E-vil Royal")

local Window = WindUI:CreateWindow({
    Title = "Chronos x Da7muHUB",
    Icon = "moon-star",
    Author = "by @wtfchronic & @da7mu",
    Folder = "ChronosHUB",
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = "E-vil Royal",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.3,
    HideSearchBar = false,
    ScrollBarEnabled = true
})

Window:EditOpenButton({
    Title = "ChromuHUB",
    Icon = "moon",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("#574094"), Color3.fromHex("#FFD700")),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true
})

Window:DisableTopbarButtons({"Fullscreen"})
Window:Tag({Title = "DEV", Color = Color3.fromHex("#FFD700"), Radius = 13})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local matchActive = false
local CurrentRoles = {}
local lastRolesUpdate = 0
local ROLES_UPDATE_INTERVAL = 0.25
local sharedUpdaterConn = nil

local function UpdateRoles()
    if tick() - lastRolesUpdate < ROLES_UPDATE_INTERVAL then return end
    lastRolesUpdate = tick()
    local remote = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    if not remote then return end
    local ok, data = pcall(remote.InvokeServer, remote)
    if ok and typeof(data) == "table" then
        CurrentRoles = data
    end
end

local function StartSharedUpdater()
    if sharedUpdaterConn then return end
    sharedUpdaterConn = RunService.Heartbeat:Connect(UpdateRoles)
end

local function StopSharedUpdater()
    if sharedUpdaterConn then
        sharedUpdaterConn:Disconnect()
        sharedUpdaterConn = nil
    end
end

local function findMapModel()
    for _, obj in pairs(Workspace:GetChildren()) do
        if (obj:IsA("Model") or obj:IsA("Folder")) and obj:GetAttribute("MapID") ~= nil then
            return obj
        end
    end
    return nil
end

local lastMapCheck = 0
local matchMonitorConn = nil

local function SetMatchActive(state)
    matchActive = state
    if not state then
        CurrentRoles = {}
        StopSharedUpdater()
    else
        StartSharedUpdater()
    end
end

local function StartMatchMonitor()
    if matchMonitorConn then return end
    matchMonitorConn = RunService.Heartbeat:Connect(function()
        if tick() - lastMapCheck < 1 then return end
        lastMapCheck = tick()
        local map = findMapModel()
        if map and not matchActive then
            SetMatchActive(true)
        elseif not map and matchActive then
            SetMatchActive(false)
        end
    end)
end

StartMatchMonitor()

local function IsCharacterAlive()
    local char = LocalPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

local MainTab = Window:Tab({Title = "Main", Icon = "book"})
local MainSection = MainTab:Section({Title = "Main", Icon = "user", Box = true, Opened = true})

-- ==================== AUTO GUN COLLECT ====================

local autoGunEnabled = false
local autoGunConnection = nil
local lastGunObject = nil
local lastGrabTime = 0
local GRAB_INTERVAL = 0.25
local autoGunInitialized = false

local function findGunDrop()
    local map = findMapModel()
    if map then return map:FindFirstChild("GunDrop") end
    return nil
end

local function triggerTouchInterest(gun)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    firetouchinterest(hrp, gun, 0)
    task.wait(0.05)
    firetouchinterest(hrp, gun, 1)

    for i = 1, 10 do
        firetouchinterest(hrp, gun, 0)
        task.wait(0.03)
        firetouchinterest(hrp, gun, 1)
        task.wait(0.03)
    end
    return true
end

local function CanCollectGun()
    if not matchActive or not IsCharacterAlive() then return false end
    local info = CurrentRoles[LocalPlayer.Name]
    if not info or info.Dead then return false end
    local role = info.Role
    if role == "Murderer" or role == "Sheriff" or role == "Hero" then return false end
    return true
end

local function collectGun(notify)
    local gun = findGunDrop()
    if not gun then
        lastGunObject = nil
        if notify then
            WindUI:Notify({Title = "Can't Collect", Content = "Gun not found...", Duration = 3, Icon = "circle-x"})
        end
        return
    end

    if not CanCollectGun() then
        lastGunObject = nil
        if notify then
            local reason = "You are not in the match"
            local info = CurrentRoles[LocalPlayer.Name]
            if matchActive and info then
                if info.Dead then reason = "You are dead"
                elseif info.Role == "Murderer" then reason = "You are the Murderer"
                elseif info.Role == "Sheriff" then reason = "You have already collected the gun."
                elseif info.Role == "Hero" then reason = "You have already collected the gun."
                end
            end
            WindUI:Notify({Title = "Can't Collect", Content = reason, Duration = 3, Icon = "circle-x"})
        end
        return
    end

    local now = tick()
    if gun ~= lastGunObject then
        lastGunObject = gun
        lastGrabTime = 0
    end
    if now - lastGrabTime < GRAB_INTERVAL then return end

    if triggerTouchInterest(gun) then
        lastGrabTime = now
        if notify then
            WindUI:Notify({Title = "Gun Collected", Content = "Gun collected successfully!", Duration = 2, Icon = "hand-grab"})
        end
    end
end

MainSection:Toggle({
    Title = "Auto-Collect Gun",
    Desc = "Automatically collects gun upon drop.",
    Icon = "circle-check",
    Type = "Checkbox",
    Default = false,
    Callback = function(state)
        if not autoGunInitialized then autoGunInitialized = true return end
        autoGunEnabled = state
        if state then
            if autoGunConnection then autoGunConnection:Disconnect() end
            autoGunConnection = RunService.Heartbeat:Connect(function()
                if autoGunEnabled then collectGun(false) end
            end)
            WindUI:Notify({Title = "Auto-Collect Gun", Content = "Enabled", Duration = 2, Icon = "hand-grab"})
        else
            if autoGunConnection then autoGunConnection:Disconnect() autoGunConnection = nil end
            lastGunObject = nil
            lastGrabTime = 0
            WindUI:Notify({Title = "Auto-Collect Gun", Content = "Disabled", Duration = 2, Icon = "circle-x"})
        end
    end
})

MainSection:Button({
    Title = "Self-Collect Gun",
    Justify = "Center",
    IconAlign = "Right",
    Icon = "hand-grab",
    Callback = function()
        lastGunObject = nil
        lastGrabTime = 0
        collectGun(true)
    end
})

MainSection:Divider()

-- ==================== SHOOT ASSIST ====================

local autoShootEnabled = false
local autoShootConnection = nil
local autoShootInitialized = false
local lastShootTime = 0
local SHOOT_INTERVAL = 0.25
local smoothedTargetPos = nil
local SMOOTH_FACTOR = 0.3
local aimDot = nil
local aimDotConnection = nil
local lastStableTime = 0
local STABILITY_THRESHOLD = 0.3
local lastAimPos = nil
local AIM_STABILITY_DISTANCE = 3

local function CanShoot()
    if not matchActive or not IsCharacterAlive() then return false end
    local info = CurrentRoles[LocalPlayer.Name]
    if not info or info.Dead then return false end
    return info.Role == "Sheriff" or info.Role == "Hero"
end

local function EquipGun()
    local char = LocalPlayer.Character
    if not char or char:FindFirstChild("Gun") then return char and true or false end
    local backpackGun = LocalPlayer.Backpack:FindFirstChild("Gun")
    if backpackGun then
        backpackGun.Parent = char
        task.wait(0.1)
        return true
    end
    return false
end

local function GetGunRemote()
    local gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
    if not gun then return nil end
    return gun:FindFirstChild("KnifeLocal", true):FindFirstChild("CreateBeam"):FindFirstChild("RemoteFunction")
end

local function ShootAt(pos)
    local remote = GetGunRemote()
    if not remote then return false end
    local success = pcall(remote.InvokeServer, remote, 1, Vector3.new(pos.X, pos.Y, pos.Z), "AH2")
    return success
end

local function FindMurderer()
    for _, plr in Players:GetPlayers() do
        if plr ~= LocalPlayer then
            local info = CurrentRoles[plr.Name]
            if info and info.Role == "Murderer" and not info.Dead then
                return plr
            end
        end
    end
    return nil
end

local function HasClearLineOfSight(target)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local targetChar = target.Character
    if not targetChar then return false end
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return false end

    local blacklist = { char, targetChar }
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer and p ~= target and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            table.insert(blacklist, p.Character)
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = blacklist

    local offsets = { Vector3.new(0,0,0), Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,1,0), Vector3.new(0,-1,0) }

    for _, o in offsets do
        local start = hrp.Position + o
        local targetPos = targetHrp.Position + o
        local dir = (targetPos - start).Unit * (targetPos - start).Magnitude
        local result = Workspace:Raycast(start, dir, params)
        if not result or (result.Position - targetPos).Magnitude <= 3 then
            return true
        end
    end
    return false
end

local function GetPredictedPosition(plr)
    local char = plr.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local vel = hrp.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local strength = speed > 30 and 0.12 or speed > 15 and 0.09 or 0.04
    local pred = hrp.Position + vel * strength
    pred = Vector3.new(pred.X, math.max(pred.Y, hrp.Position.Y - 2), pred.Z)
    smoothedTargetPos = smoothedTargetPos and smoothedTargetPos:Lerp(pred, SMOOTH_FACTOR) or pred
    return smoothedTargetPos
end

local function CreateAimDot()
    if aimDot then aimDot:Destroy() end
    aimDot = Instance.new("Part")
    aimDot.Name = "AutoShootAimDot"
    aimDot.Size = Vector3.new(0.5, 0.5, 0.5)
    aimDot.Material = Enum.Material.Neon
    aimDot.Color = Color3.fromRGB(147, 0, 255)
    aimDot.Shape = Enum.PartType.Ball
    aimDot.CanCollide = false
    aimDot.Anchored = true
    aimDot.Parent = Workspace

    local hl = Instance.new("Highlight")
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 0
    hl.FillColor = Color3.fromRGB(147, 0, 255)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.Parent = aimDot

    if aimDotConnection then aimDotConnection:Disconnect() end
    aimDotConnection = RunService.RenderStepped:Connect(function()
        if aimDot and aimDot.Parent then
            local pulse = 0.5 + math.sin(tick() * 8) * 0.2
            aimDot.Size = Vector3.new(pulse, pulse, pulse)
        end
    end)
end

local function UpdateAimDot(pos, blocked, stable)
    if not aimDot then CreateAimDot() end
    aimDot.Position = pos
    aimDot.Transparency = blocked and 0.8 or (stable and 0.1 or 0.3)
    aimDot.Color = stable and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(147, 0, 255)
end

local function RemoveAimDot()
    if aimDotConnection then aimDotConnection:Disconnect() aimDotConnection = nil end
    if aimDot then aimDot:Destroy() aimDot = nil end
    smoothedTargetPos = nil
end

local function AutoShootLoop()
    if not CanShoot() then RemoveAimDot() lastStableTime = 0 return end
    local murderer = FindMurderer()
    if not murderer or not murderer.Character then RemoveAimDot() lastStableTime = 0 return end

    local pos = GetPredictedPosition(murderer)
    if not pos then RemoveAimDot() lastStableTime = 0 return end

    local blocked = not HasClearLineOfSight(murderer)
    local stable = false

    if lastAimPos and (pos - lastAimPos).Magnitude <= AIM_STABILITY_DISTANCE then
        if tick() - lastStableTime >= STABILITY_THRESHOLD then
            stable = true
        end
    else
        lastStableTime = tick()
    end
    lastAimPos = pos

    UpdateAimDot(pos, blocked, stable)

    if blocked or not stable then return end
    if not LocalPlayer.Character:FindFirstChild("Gun") then EquipGun() return end

    local now = tick()
    if now - lastShootTime >= SHOOT_INTERVAL and ShootAt(pos) then
        lastShootTime = now
        lastStableTime = 0
    end
end

MainSection:Toggle({
    Title = "Shoot Assist (Locked)",
    Desc = "Waits 0.3s of perfect aim before shooting.",
    Icon = "circle-check",
    Type = "Checkbox",
    Default = false,
    Callback = function(state)
        if not autoShootInitialized then autoShootInitialized = true return end
        autoShootEnabled = state
        if state then
            if autoShootConnection then autoShootConnection:Disconnect() end
            autoShootConnection = RunService.Heartbeat:Connect(function() pcall(AutoShootLoop) end)
            WindUI:Notify({Title = "Shoot Assist", Content = "Enabled - 0.3s Lock", Duration = 3, Icon = "target"})
        else
            if autoShootConnection then autoShootConnection:Disconnect() autoShootConnection = nil end
            RemoveAimDot()
            lastShootTime = 0
            lastStableTime = 0
            lastAimPos = nil
            WindUI:Notify({Title = "Shoot Assist", Content = "Disabled", Duration = 2, Icon = "circle-x"})
        end
    end
})

local NotifyHighlightSection = MainTab:Section({Title = "Notify & Highlight", Icon = "eye", Box = true, Opened = true})

-- ==================== NOTIFY SYSTEM ====================

local LastGunDrop = nil
local notifyEnabled = false
local notifyConnection = nil
local notifyInitialized = false
local NotifyRolesSnapshot = {}
local SelectedNotifyElements = {}
local NotifyHardLock = false

local function CheckGunDrop()
    if not notifyEnabled or NotifyHardLock then return end
    local map = findMapModel()
    if not map then return end
    local gun = map:FindFirstChild("GunDrop")
    if gun and gun ~= LastGunDrop then
        LastGunDrop = gun
        if not autoGunEnabled then
            WindUI:Notify({Title = "Gun Drop", Content = "The gun has dropped!", Duration = 4, Icon = "circle-chevron-down"})
        end
    elseif not gun then
        LastGunDrop = nil
    end
end

local function CheckRoleChanges()
    if not notifyEnabled or NotifyHardLock then return end
    for name, info in pairs(CurrentRoles) do
        local plr = Players:FindFirstChild(name)
        if plr and info.Role and not info.Dead then
            local last = NotifyRolesSnapshot[name]
            if last ~= info.Role then
                local icon = info.Role == "Murderer" and "skull" or info.Role == "Sheriff" and "shield-check" or info.Role == "Hero" and "star"
                if icon then
                    WindUI:Notify({
                        Title = info.Role,
                        Content = plr.DisplayName .. " is the " .. info.Role,
                        Duration = 5,
                        Icon = icon
                    })
                end
            end
        end
    end
    table.clear(NotifyRolesSnapshot)
    for name, info in pairs(CurrentRoles) do
        if info.Role then NotifyRolesSnapshot[name] = info.Role end
    end
end

local function EnableNotify()
    if notifyConnection then return end
    notifyEnabled = true
    NotifyHardLock = false
    notifyConnection = RunService.RenderStepped:Connect(function()
        if not notifyEnabled or NotifyHardLock then return end
        if table.find(SelectedNotifyElements, "Notify Gun Drop") then CheckGunDrop() end
        if table.find(SelectedNotifyElements, "Notify Role Changes") then CheckRoleChanges() end
    end)
    StartSharedUpdater()
end

local function DisableNotify()
    NotifyHardLock = true
    notifyEnabled = false
    if notifyConnection then notifyConnection:Disconnect() notifyConnection = nil end
    task.defer(function() NotifyRolesSnapshot = {} LastGunDrop = nil end)
    StopSharedUpdater()
end

NotifyHighlightSection:Toggle({
    Title = "Notify Events",
    Desc = "Notifies when the selected events occur.",
    Icon = "circle-check",
    Type = "Checkbox",
    Default = false,
    Callback = function(state)
        if not notifyInitialized then notifyInitialized = true return end
        if state then EnableNotify() WindUI:Notify({Title = "Notify", Content = "Enabled", Duration = 2, Icon = "bell"})
        else DisableNotify() WindUI:Notify({Title = "Notify", Content = "Disabled", Duration = 2, Icon = "bell-off"}) end
    end
})

NotifyHighlightSection:Dropdown({
    Title = "Events",
    Values = {"Notify Gun Drop", "Notify Role Changes"},
    Value = {"Notify Gun Drop", "Notify Role Changes"},
    Multi = true,
    AllowNone = true,
    Callback = function(v) SelectedNotifyElements = v end
})

NotifyHighlightSection:Button({
    Title = "Notify Once",
    Justify = "Center",
    IconAlign = "Right",
    Icon = "bell",
    Callback = function()
        if not matchActive then
            WindUI:Notify({Title = "Notify Once", Content = "Not in match", Duration = 3, Icon = "circle-x"})
            return
        end
        UpdateRoles()
        if table.find(SelectedNotifyElements, "Notify Gun Drop") then
            local map = findMapModel()
            if map and map:FindFirstChild("GunDrop") then
                WindUI:Notify({Title = "Gun Drop", Content = "The gun has dropped!", Duration = 4, Icon = "circle-chevron-down"})
            end
        end
        if table.find(SelectedNotifyElements, "Notify Role Changes") then
            for name, info in pairs(CurrentRoles) do
                local plr = Players:FindFirstChild(name)
                if plr and info.Role and not info.Dead then
                    local icon = info.Role == "Murderer" and "skull" or info.Role == "Sheriff" and "shield-check" or info.Role == "Hero" and "star"
                    if icon then
                        WindUI:Notify({Title = info.Role, Content = plr.DisplayName.." is the "..info.Role, Duration = 5, Icon = icon})
                    end
                end
            end
        end
    end
})

NotifyHighlightSection:Divider()

-- ==================== HIGHLIGHT SYSTEM ====================

local highlightActive = false
local quickHighlight = false
local renderConn = nil
local highlightInitialized = false
local ESPHighlights = {}
local MapGunHighlight = nil
local MapCoinHighlights = {}
local SelectedElements = {}
local gunRGBConn = nil

local ROLE_COLORS = {
    Innocent = Color3.fromRGB(180,180,180),
    Murderer = Color3.fromRGB(225,0,0),
    Sheriff = Color3.fromRGB(0,0,225),
    Hero = Color3.fromRGB(255,215,0),
    Zombie = Color3.fromRGB(255,170,0),
    Survivor = Color3.fromRGB(0,180,225),
    Freezer = Color3.fromRGB(100,255,252),
    Runner = Color3.fromRGB(195,48,255)
}
local DEFAULT_COLOR = ROLE_COLORS.Innocent

local function ShouldShow(plr)
    return plr ~= LocalPlayer and matchActive and CurrentRoles[plr.Name] and not CurrentRoles[plr.Name].Dead
end

local function ApplyHighlight(plr)
    if ESPHighlights[plr] then return end
    local char = plr.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hl = Instance.new("Highlight")
    hl.Name = "PlayerESP"
    hl.Adornee = char
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillColor = DEFAULT_COLOR
    hl.Parent = char
    ESPHighlights[plr] = hl
end

local function RemoveHighlight(plr)
    if ESPHighlights[plr] then
        ESPHighlights[plr]:Destroy()
        ESPHighlights[plr] = nil
    end
end

local function UpdatePlayerColor(plr)
    local hl = ESPHighlights[plr]
    if not hl then return end
    local info = CurrentRoles[plr.Name]
    if not info or not info.Role then hl.FillColor = DEFAULT_COLOR return end
    if info.Role == "Hero" then
        local sheriff = Players:FindFirstChild(info.Sheriff or "")
        hl.FillColor = (not sheriff or not IsAlive(sheriff)) and ROLE_COLORS.Hero or (ROLE_COLORS[info.Role] or DEFAULT_COLOR)
    else
        hl.FillColor = ROLE_COLORS[info.Role] or DEFAULT_COLOR
    end
end

local function UpdateVisuals()
    if not matchActive or (not highlightActive and not quickHighlight) then
        for plr in pairs(ESPHighlights) do RemoveHighlight(plr) end
        ESPHighlights = {}
        if MapGunHighlight then MapGunHighlight:Destroy() MapGunHighlight = nil end
        if gunRGBConn then gunRGBConn:Disconnect() gunRGBConn = nil end
        for _, hl in pairs(MapCoinHighlights) do if hl and hl.Parent then hl:Destroy() end end
        MapCoinHighlights = {}
        return
    end

    if table.find(SelectedElements, "Highlight Players") then
        for _, plr in Players:GetPlayers() do
            if ShouldShow(plr) then
                if plr.Character and not plr.Character:FindFirstChild("PlayerESP") then ApplyHighlight(plr) end
                UpdatePlayerColor(plr)
            else
                RemoveHighlight(plr)
            end
        end
    else
        for plr in pairs(ESPHighlights) do RemoveHighlight(plr) end
    end

    if table.find(SelectedElements, "Highlight Gun") then
        local map = findMapModel()
        if map then
            local gun = map:FindFirstChild("GunDrop")
            if gun and gun ~= MapGunHighlight then
                if MapGunHighlight then MapGunHighlight:Destroy() end
                local hl = Instance.new("Highlight")
                hl.Name = "MapGunESP"
                hl.Adornee = gun
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.FillTransparency = 0.3
                hl.FillColor = Color3.fromRGB(255,255,255)
                hl.OutlineTransparency = 0
                hl.OutlineColor = Color3.fromRGB(255,0,255)
                hl.Parent = gun
                MapGunHighlight = hl
                if gunRGBConn then gunRGBConn:Disconnect() end
                local hue = 0
                gunRGBConn = RunService.RenderStepped:Connect(function()
                    if not MapGunHighlight or not MapGunHighlight.Parent then
                        if gunRGBConn then gunRGBConn:Disconnect() gunRGBConn = nil end
                        return
                    end
                    hue = (hue - 0.02) % 1
                    MapGunHighlight.OutlineColor = Color3.fromHSV(hue, 1, 1)
                end)
            end
        end
    else
        if MapGunHighlight then MapGunHighlight:Destroy() MapGunHighlight = nil end
        if gunRGBConn then gunRGBConn:Disconnect() gunRGBConn = nil end
    end

    if table.find(SelectedElements, "Highlight Coins") then
        local map = findMapModel()
        if map and map:FindFirstChild("CoinContainer") then
            for _, child in map.CoinContainer:GetChildren() do
                local visual = child:FindFirstChild("CoinVisual")
                if visual and visual:IsA("BasePart") and not MapCoinHighlights[visual] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "CoinESP"
                    hl.Adornee = visual
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillTransparency = 0.85
                    hl.OutlineTransparency = 0.85
                    hl.OutlineColor = Color3.fromRGB(255,255,255)
                    hl.FillColor = Color3.fromHex("#8B00FF")
                    hl.Parent = visual
                    MapCoinHighlights[visual] = hl
                end
            end
        end
    else
        for _, hl in pairs(MapCoinHighlights) do if hl and hl.Parent then hl:Destroy() end end
        MapCoinHighlights = {}
    end
end

local function EnableESP()
    if highlightActive then return end
    highlightActive = true
    if not renderConn then
        renderConn = RunService.RenderStepped:Connect(UpdateVisuals)
    end
    StartSharedUpdater()
end

local function DisableESP()
    highlightActive = false
    quickHighlight = false
    if renderConn then renderConn:Disconnect() renderConn = nil end
    for plr in pairs(ESPHighlights) do RemoveHighlight(plr) end
    ESPHighlights = {}
    if MapGunHighlight then MapGunHighlight:Destroy() MapGunHighlight = nil end
    if gunRGBConn then gunRGBConn:Disconnect() gunRGBConn = nil end
    for _, hl in pairs(MapCoinHighlights) do if hl and hl.Parent then hl:Destroy() end end
    MapCoinHighlights = {}
    StopSharedUpdater()
end

Players.PlayerRemoving:Connect(RemoveHighlight)

NotifyHighlightSection:Toggle({
    Title = "Highlight Elements",
    Desc = "Highlights the selected elements in-match.",
    Icon = "circle-check",
    Type = "Checkbox",
    Default = false,
    Callback = function(state)
        if not highlightInitialized then highlightInitialized = true return end
        if state then
            EnableESP()
            WindUI:Notify({Title = "Highlights", Content = "Enabled", Duration = 3, Icon = "highlighter"})
        else
            DisableESP()
            WindUI:Notify({Title = "Highlights", Content = "Disabled", Duration = 3, Icon = "circle-x"})
        end
    end
})

NotifyHighlightSection:Dropdown({
    Title = "Elements",
    Values = {"Highlight Players", "Highlight Gun", "Highlight Coins"},
    Value = {"Highlight Players"},
    Multi = true,
    AllowNone = true,
    Callback = function(v)
        SelectedElements = v
        if (highlightActive or quickHighlight) and matchActive then UpdateVisuals() end
    end
})

-- QUICK HIGHLIGHT BUTTON
NotifyHighlightSection:Button({
    Title = "Quick Highlight",
    Justify = "Center",
    IconAlign = "Right",
    Icon = "zap",
    Callback = function()
        if highlightActive then
            WindUI:Notify({Title = "Quick Highlight", Content = "Highlights is already on!", Duration = 3, Icon = "highlighter"})
            return
        end

        if not matchActive then
            WindUI:Notify({Title = "Quick Highlight", Content = "Not in a match!", Duration = 3, Icon = "circle-x"})
            return
        end

        quickHighlight = true

        if not renderConn then
            renderConn = RunService.RenderStepped:Connect(UpdateVisuals)
        end
        StartSharedUpdater()
        UpdateVisuals()

        WindUI:Notify({Title = "Quick Highlight", Content = "Activated for 5 seconds!", Duration = 5, Icon = "zap"})

        task.delay(5, function()
            quickHighlight = false
            UpdateVisuals()
            if not highlightActive and renderConn then
                renderConn:Disconnect()
                renderConn = nil
            end
            WindUI:Notify({Title = "Quick Highlight", Content = "Expired", Duration = 2, Icon = "circle-x"})
        end)
    end
})

-- ==================== SETTINGS TAB ====================

local SettingsTab = Window:Tab({Title = "Settings", Icon = "settings"})
local UISettingsSection = SettingsTab:Section({Title = "UI Settings", Box = true, Opened = true})

UISettingsSection:Keybind({
    Title = "UI Toggle Key",
    Desc = "Key to open/close the UI",
    Value = "L",
    Callback = function(v) Window:SetToggleKey(Enum.KeyCode[v]) end
})

MainTab:Select()