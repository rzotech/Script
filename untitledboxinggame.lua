-- language: Lua, file: Script/untitledboxinggame.lua, runtime: Luau, target: Untitled Boxing Game (Roblox)
-- =============================================================================
-- RZO HUB - Untitled Boxing Game (UBG)
-- UI Framework: WindUI (https://github.com/Footagesus/WindUI)
-- Systems: Packet Interception, Directional Auto-Dodge, Anti-Feint, Auto-Counter
-- Distance Calibration: Real-Time Stud Range Gatekeeper
-- =============================================================================

if getgenv().LOADED_RZOUBG then
    pcall(function()
        if getgenv().UNLOAD_RZOUBG then
            getgenv().UNLOAD_RZOUBG()
        end
    end)
end
getgenv().LOADED_RZOUBG = true

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

-- External UI Framework
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Window Initialization
local Window = WindUI:CreateWindow({
    Title = "RZO HUB",
    SubTitle = "Untitled Boxing Game",
    Author = "RZO",
    Icon = "swords",
    Folder = "RZOHub_UBG",
    Size = UDim2.fromOffset(580, 480),
    Transparent = true,
    Theme = "Dark",
    Acrylic = true,
    Resizable = true,
    SideBarWidth = 190,
    ToggleKey = Enum.KeyCode.RightControl,
})

-- Tabs Declaration: Main and Blatant Only
local Tabs = {
    Main = Window:Tab({
        Title = "Main",
        Icon = "shield-check",
    }),
    Blatant = Window:Tab({
        Title = "Blatant",
        Icon = "flame",
    }),
}

-- Remotes & Replication References
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local MobileEvents = ReplicatedStorage:WaitForChild("MobileEvents")
local ReplicateTryAttack = RemoteEvents:WaitForChild("ReplicateTryAttack")

local TryPunch = MobileEvents:WaitForChild("TryPunch")
local TryDash = MobileEvents:WaitForChild("TryDash")
local UseSpecial = MobileEvents:WaitForChild("UseSpecial")

-- State References
local States = Workspace:WaitForChild("States")
local myState = States:WaitForChild(LocalPlayer.Name, 10)
if not myState then
    WindUI:Notify({
        Title = "RZO HUB",
        Content = "Failed to locate local player combat state.",
        Icon = "alert-triangle",
        Duration = 4,
    })
    return
end

local Occupied = myState:WaitForChild("Occupied", 10)
local PlayerData = myState:WaitForChild("PlayerData", 10)
local CharacterData = myState:WaitForChild("CharacterData", 10)

-- Styles Module
local StylesModule = require(ReplicatedStorage.Modules.Styles)

-- Connection Storage for Clean Lifecycle
local Connections = {}
local PropertyLocks = {}

-- Feature Configuration Flags & Distances
local Config = {
    AutoDodge = false,
    EnforceDistance = true,
    AutoDodgeDistance = 8.5,
    DirectionalDodge = true,
    AntiFeint = true,
    AntiFeintDistance = 8.0,
    AutoCounter = true,
    AutoCounterDistance = 7.5,
    M1Delay = 0.30,
    M2Delay = 0.45,
    UltDelay = 0.38,
    NoReverseInputs = false,
    InfiniteAbility = false,
    GhostAbilityCounter = false,
}

-- Movement Direction Vectors for Slip Evasion
local MoveDirections = {
    Forward = Vector3.new(0, 0, -1),
    Backward = Vector3.new(0, 0, 1),
    Left = Vector3.new(-1, 0, 0),
    Right = Vector3.new(1, 0, 0),
}

-- PlayerModule Movement Vector Hook
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()
local activeSpoofVector = nil

local rawGetMoveVector = Controls.GetMoveVector
function Controls:GetMoveVector()
    if activeSpoofVector then
        return MoveDirections[activeSpoofVector] or Vector3.zero
    end
    if self.activeController then
        return self.activeController:GetMoveVector()
    end
    return Vector3.zero
end

-- Helper: Compute Live Distance to Enemy
local function getLiveEnemyDistance()
    local lockedOpponent = Occupied and Occupied:FindFirstChild("LockedOn") and Occupied.LockedOn.Value
    if not lockedOpponent then return nil end

    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local oppHrp = lockedOpponent:FindFirstChild("HumanoidRootPart")

    if myHrp and oppHrp then
        return (oppHrp.Position - myHrp.Position).Magnitude
    end
    return nil
end

-- Fast Binary Buffer Parser
local function createBufferReader(rawPayload)
    local bufLen = buffer.len(rawPayload)
    local stream = {
        _buffer = buffer.create(bufLen),
        _cursor = 0,
    }
    buffer.copy(stream._buffer, 0, rawPayload)

    function stream:readu16()
        local val = buffer.readu16(self._buffer, self._cursor)
        self._cursor = self._cursor + 2
        return val
    end

    function stream:readf32()
        local val = buffer.readf32(self._buffer, self._cursor)
        self._cursor = self._cursor + 4
        return val
    end

    function stream:readString()
        local len = buffer.readu32(self._buffer, self._cursor)
        local str = buffer.readstring(self._buffer, self._cursor + 4, len)
        self._cursor = self._cursor + (len + 4)
        return str
    end

    return stream
end

-- Attack Packet Deserializer
local function parseAttackString(rawStr, victimInstance)
    local chars = string.split(rawStr, "")
    if #chars < 20 then
        return nil
    end

    return {
        CurrentCombo = tonumber(chars[1] .. chars[2]) or 1,
        CurrentPunch = tonumber(chars[3] .. chars[4]) or 1,
        IsHeavy = (tonumber(chars[5]) == 1),
        IsUltimate = (tonumber(chars[6]) == 1),
        IsCharge = (tonumber(chars[7]) == 1),
        IsStart = (tonumber(chars[8]) == 1),
        IsLocked = (tonumber(chars[9]) == 1),
        Ping = tonumber("0." .. chars[10] .. chars[11] .. chars[12] .. chars[13] .. chars[14]) or 0.05,
        Id = tonumber(chars[15] .. chars[16] .. chars[17] .. chars[18] .. chars[19]) or 0,
        IsFeint = (tonumber(chars[20]) == 1),
        Victim = victimInstance,
    }
end

-- Dodge Execution Routine
local activeDodgeThread = nil

local function executeSlipDash(targetDirection)
    activeSpoofVector = targetDirection
    pcall(function()
        TryDash:Fire()
    end)
    task.defer(function()
        activeSpoofVector = nil
    end)
end

local function performDirectionalDodge(opponentCharacter)
    local attackingHand = opponentCharacter and opponentCharacter:GetAttribute("AttackingHand") or "Right"
    local slipDir = "Right"

    if Config.DirectionalDodge then
        if string.find(tostring(attackingHand), "Left") then
            slipDir = "Right"
        else
            slipDir = "Left"
        end

        if Occupied and Occupied:FindFirstChild("ReverseInputs") and Occupied.ReverseInputs.Value then
            if slipDir == "Right" then
                slipDir = "Left"
            else
                slipDir = "Right"
            end
        end
    end

    executeSlipDash(slipDir)
end

-- Property Lock Helper
local function setPropertyLock(instance, value)
    if PropertyLocks[instance] then
        PropertyLocks[instance]:Disconnect()
        PropertyLocks[instance] = nil
    end
    if value == nil then return end

    PropertyLocks[instance] = instance.Changed:Connect(function(newVal)
        if newVal ~= value then
            instance.Value = value
        end
    end)
    instance.Value = value
end

-- =============================================================================
-- UI CONFIGURATION: TAB 1 (MAIN)
-- =============================================================================

Tabs.Main:Section({ Title = "Match Telemetry & Live Range" })

local TelemetryParagraph = Tabs.Main:Paragraph({
    Title = "Combat Status",
    Desc = "Opponent: None\nDistance: Out of Range\nYour Style: N/A\nOpponent Style: N/A",
})

local function updateTelemetryUI()
    local lockedOpponent = Occupied and Occupied:FindFirstChild("LockedOn") and Occupied.LockedOn.Value
    local oppName = lockedOpponent and lockedOpponent.Name or "None"

    local liveDist = getLiveEnemyDistance()
    local distText = liveDist and string.format("%.1f studs", liveDist) or "Out of Range / None"

    local myStyleName = PlayerData and PlayerData:FindFirstChild("Style") and PlayerData.Style.Value or "N/A"
    local myShort = (StylesModule[myStyleName] and StylesModule[myStyleName].ShortName) or myStyleName

    local oppStyleName = "N/A"
    if lockedOpponent then
        local oppState = States:FindFirstChild(lockedOpponent.Name)
        if oppState and oppState:FindFirstChild("PlayerData") and oppState.PlayerData:FindFirstChild("Style") then
            oppStyleName = oppState.PlayerData.Style.Value
        end
    end
    local oppShort = (StylesModule[oppStyleName] and StylesModule[oppStyleName].ShortName) or oppStyleName

    TelemetryParagraph:SetDesc(string.format(
        "Opponent: %s\nDistance to Enemy: %s\nYour Style: %s (%s)\nOpponent Style: %s (%s)",
        oppName,
        distText,
        myStyleName,
        myShort,
        oppStyleName,
        oppShort
    ))
end

-- Periodic Telemetry Poller (keeps live distance accurate)
task.spawn(function()
    while getgenv().LOADED_RZOUBG do
        pcall(updateTelemetryUI)
        task.wait(0.25)
    end
end)

if Occupied and Occupied:FindFirstChild("LockedOn") then
    Connections.LockedOn = Occupied.LockedOn:GetPropertyChangedSignal("Value"):Connect(function()
        updateTelemetryUI()
        local lockedOpponent = Occupied.LockedOn.Value
        if lockedOpponent then
            local oppState = States:FindFirstChild(lockedOpponent.Name)
            if oppState and oppState:FindFirstChild("CharacterData") then
                local ultEnergy = oppState.CharacterData:FindFirstChild("UltimateEnergy")
                if ultEnergy then
                    if Connections.OppUlt then Connections.OppUlt:Disconnect() end
                    Connections.OppUlt = ultEnergy.Changed:Connect(function(v)
                        if v == 100 then
                            WindUI:Notify({
                                Title = "Opponent Ultimate Ready",
                                Content = lockedOpponent.Name .. " has full Ultimate energy!",
                                Icon = "zap",
                                Duration = 3,
                            })
                        end
                    end)
                end
            end
        end
    end)
    updateTelemetryUI()
end

Tabs.Main:Section({ Title = "Combat Feature Switches" })

Tabs.Main:Toggle({
    Title = "Auto Dodge",
    Desc = "Automatically dodges incoming light, heavy, and ultimate attacks",
    Value = Config.AutoDodge,
    Callback = function(v)
        Config.AutoDodge = v
        WindUI:Notify({
            Title = "Auto Dodge",
            Content = v and "ENABLED" or "DISABLED",
            Icon = v and "check" or "x",
            Duration = 2,
        })
    end,
})

Tabs.Main:Toggle({
    Title = "Directional Dodge",
    Desc = "Slips in the optimal direction based on opponent's attacking fist",
    Value = Config.DirectionalDodge,
    Callback = function(v)
        Config.DirectionalDodge = v
    end,
})

Tabs.Main:Toggle({
    Title = "Anti-Feint",
    Desc = "Prevents dodging feinted punches and punishes heavy feints instantly",
    Value = Config.AntiFeint,
    Callback = function(v)
        Config.AntiFeint = v
    end,
})

Tabs.Main:Toggle({
    Title = "Auto Counter M2",
    Desc = "Instantly punches on incoming heavy attack startup frames",
    Value = Config.AutoCounter,
    Callback = function(v)
        Config.AutoCounter = v
    end,
})

-- =============================================================================
-- ENEMY DISTANCE SETTINGS (PENGATURAN JARAK AKTIVASI MUSUH)
-- =============================================================================
Tabs.Main:Section({ Title = "Enemy Distance Settings (Jarak Musuh)" })

Tabs.Main:Toggle({
    Title = "Enforce Distance Gate",
    Desc = "When enabled, features only trigger if enemy is within set range",
    Value = Config.EnforceDistance,
    Callback = function(v)
        Config.EnforceDistance = v
        WindUI:Notify({
            Title = "Distance Gating",
            Content = v and "ACTIVE (Checking Range)" or "OFF (Trigger Anywhere)",
            Icon = v and "shield" or "alert-circle",
            Duration = 2,
        })
    end,
})

local SliderAutoDodgeDist = Tabs.Main:Slider({
    Title = "Auto Dodge Max Range",
    Desc = "Jarak maksimal musuh agar Auto Dodge aktif (1.0 - 15.0 studs)",
    Step = 0.1,
    Value = {
        Min = 1.0,
        Max = 15.0,
        Default = Config.AutoDodgeDistance,
    },
    Callback = function(v)
        Config.AutoDodgeDistance = tonumber(string.format("%.1f", v)) or v
    end,
})

local SliderAntiFeintDist = Tabs.Main:Slider({
    Title = "Anti-Feint Max Range",
    Desc = "Jarak maksimal musuh agar Anti-Feint aktif (1.0 - 15.0 studs)",
    Step = 0.1,
    Value = {
        Min = 1.0,
        Max = 15.0,
        Default = Config.AntiFeintDistance,
    },
    Callback = function(v)
        Config.AntiFeintDistance = tonumber(string.format("%.1f", v)) or v
    end,
})

local SliderAutoCounterDist = Tabs.Main:Slider({
    Title = "Auto Counter Max Range",
    Desc = "Jarak maksimal musuh agar Auto Counter M2 aktif (1.0 - 15.0 studs)",
    Step = 0.1,
    Value = {
        Min = 1.0,
        Max = 15.0,
        Default = Config.AutoCounterDistance,
    },
    Callback = function(v)
        Config.AutoCounterDistance = tonumber(string.format("%.1f", v)) or v
    end,
})

Tabs.Main:Section({ Title = "Timing Calibration (Seconds)" })

local SliderM1 = Tabs.Main:Slider({
    Title = "M1 Dodge Delay",
    Desc = "Latency compensation for standard light attacks",
    Step = 0.01,
    Value = {
        Min = 0.05,
        Max = 0.60,
        Default = Config.M1Delay,
    },
    Callback = function(v)
        Config.M1Delay = v
    end,
})

local SliderM2 = Tabs.Main:Slider({
    Title = "M2 Dodge Delay",
    Desc = "Latency compensation for heavy windup attacks",
    Step = 0.01,
    Value = {
        Min = 0.05,
        Max = 0.60,
        Default = Config.M2Delay,
    },
    Callback = function(v)
        Config.M2Delay = v
    end,
})

local SliderUlt = Tabs.Main:Slider({
    Title = "Ultimate Dodge Delay",
    Desc = "Latency compensation for ultimate attacks",
    Step = 0.01,
    Value = {
        Min = 0.05,
        Max = 0.60,
        Default = Config.UltDelay,
    },
    Callback = function(v)
        Config.UltDelay = v
    end,
})

Tabs.Main:Button({
    Title = "Restore Default Timings & Distances",
    Desc = "Resets timings (0.30s, 0.45s, 0.38s) and distances (8.5s, 8.0s, 7.5s)",
    Callback = function()
        Config.M1Delay = 0.30
        Config.M2Delay = 0.45
        Config.UltDelay = 0.38
        Config.AutoDodgeDistance = 8.5
        Config.AntiFeintDistance = 8.0
        Config.AutoCounterDistance = 7.5
        Config.EnforceDistance = true
        pcall(function()
            SliderM1:SetValue(0.30)
            SliderM2:SetValue(0.45)
            SliderUlt:SetValue(0.38)
            SliderAutoDodgeDist:SetValue(8.5)
            SliderAntiFeintDist:SetValue(8.0)
            SliderAutoCounterDist:SetValue(7.5)
        end)
        WindUI:Notify({
            Title = "Defaults Restored",
            Content = "Timings and enemy activation distances reset to default values.",
            Icon = "refresh-cw",
            Duration = 2,
        })
    end,
})

-- =============================================================================
-- UI CONFIGURATION: TAB 2 (BLATANT)
-- =============================================================================

Tabs.Blatant:Section({ Title = "Combat Overrides" })

Tabs.Blatant:Toggle({
    Title = "No Reverse Inputs",
    Desc = "Locks ReverseInputs to false to eliminate Trickster confusion",
    Value = Config.NoReverseInputs,
    Callback = function(v)
        Config.NoReverseInputs = v
        if Occupied and Occupied:FindFirstChild("ReverseInputs") then
            setPropertyLock(Occupied.ReverseInputs, v and false or nil)
        end
        WindUI:Notify({
            Title = "No Reverse Inputs",
            Content = v and "ENABLED" or "DISABLED",
            Icon = v and "shield" or "x",
            Duration = 2,
        })
    end,
})

Tabs.Blatant:Toggle({
    Title = "Ghost Ability Counter",
    Desc = "Automatically fires Ghost style special push during attacks",
    Value = Config.GhostAbilityCounter,
    Callback = function(v)
        if v then
            local myStyle = PlayerData and PlayerData:FindFirstChild("Style") and PlayerData.Style.Value or ""
            if myStyle:lower() ~= "ghost" then
                WindUI:Notify({
                    Title = "Ghost Ability Counter",
                    Content = "You must be using Ghost style to utilize this override.",
                    Icon = "alert-triangle",
                    Duration = 3,
                })
            end
        end
        Config.GhostAbilityCounter = v
    end,
})

Tabs.Blatant:Toggle({
    Title = "Infinite Ability Energy (Client)",
    Desc = "Freezes local AbilityEnergy value to 100%",
    Value = Config.InfiniteAbility,
    Callback = function(v)
        Config.InfiniteAbility = v
        if CharacterData and CharacterData:FindFirstChild("AbilityEnergy") then
            setPropertyLock(CharacterData.AbilityEnergy, v and 100 or nil)
        end
    end,
})

-- =============================================================================
-- ATTACK REPLICATION INTERCEPTION (CORE ENGINE)
-- =============================================================================

Connections.ReplicateAttack = ReplicateTryAttack.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" or not payload[1] or not payload[2] then return end

    local attackerCharacter = payload[2]
    local lockedOpponent = Occupied and Occupied:FindFirstChild("LockedOn") and Occupied.LockedOn.Value
    if not lockedOpponent or attackerCharacter.Name ~= lockedOpponent.Name then
        return
    end

    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local oppHrp = attackerCharacter:FindFirstChild("HumanoidRootPart")
    if not myHrp or not oppHrp then return end

    local currentDistance = (oppHrp.Position - myHrp.Position).Magnitude
    -- Immediate exit if opponent is beyond general arena proximity (15.0 studs)
    if Config.EnforceDistance and currentDistance > 15.0 then
        return
    end

    -- Binary Buffer Deserialization
    local reader = createBufferReader(payload[1])
    reader:readu16()
    local attackStr = reader:readString()
    reader:readf32()

    local attackData = parseAttackString(attackStr, attackerCharacter)
    if not attackData then return end

    -- Ghost Style Counter Pulse
    if Config.GhostAbilityCounter then
        pcall(function()
            UseSpecial:Fire({ PushDirection = "Down" })
            UseSpecial:Fire({ PushDirection = "Up" })
        end)
    end

    -- Feint Interception: Checks independent AntiFeintDistance
    if attackData.IsFeint then
        if activeDodgeThread then
            task.cancel(activeDodgeThread)
            activeDodgeThread = nil
        end

        local inFeintRange = (not Config.EnforceDistance) or (currentDistance <= Config.AntiFeintDistance)
        if Config.AntiFeint and inFeintRange then
            if attackData.IsHeavy then
                -- Punish recovery with immediate counter-punch
                pcall(function()
                    TryPunch:Fire()
                end)
            else
                -- Delayed slip dash for light feint
                activeDodgeThread = task.delay(Config.M1Delay, function()
                    activeDodgeThread = nil
                    performDirectionalDodge(attackerCharacter)
                end)
            end
        end
        return
    end

    -- Auto Counter on Heavy Attack Startup: Checks independent AutoCounterDistance
    local inCounterRange = (not Config.EnforceDistance) or (currentDistance <= Config.AutoCounterDistance)
    if attackData.IsHeavy and Config.AutoCounter and inCounterRange then
        pcall(function()
            local isReversed = Occupied and Occupied:FindFirstChild("ReverseInputs") and Occupied.ReverseInputs.Value
            TryPunch:Fire(isReversed and { IsHeavy = true } or nil)
        end)
    end

    -- Auto Dodge: Checks independent AutoDodgeDistance
    local inDodgeRange = (not Config.EnforceDistance) or (currentDistance <= Config.AutoDodgeDistance)
    if not Config.AutoDodge or not inDodgeRange then
        return
    end

    -- Calculate Delay Based on Attack Class
    local targetDelay = Config.M1Delay
    if attackData.IsUltimate then
        targetDelay = Config.UltDelay
    elseif attackData.IsHeavy then
        targetDelay = Config.M2Delay
    else
        targetDelay = Config.M1Delay
    end

    -- Cancel stale dodge threads
    if activeDodgeThread then
        task.cancel(activeDodgeThread)
        activeDodgeThread = nil
    end

    -- Schedule frame-calibrated directional slip
    activeDodgeThread = task.delay(targetDelay, function()
        activeDodgeThread = nil
        performDirectionalDodge(attackerCharacter)
    end)
end)

-- Unload & Cleanup Handler
getgenv().UNLOAD_RZOUBG = function()
    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    for inst, conn in pairs(PropertyLocks) do
        pcall(function() conn:Disconnect() end)
    end
    if activeDodgeThread then
        pcall(task.cancel, activeDodgeThread)
        activeDodgeThread = nil
    end
    Controls.GetMoveVector = rawGetMoveVector
    getgenv().LOADED_RZOUBG = nil
end

WindUI:Notify({
    Title = "RZO HUB",
    Content = "Untitled Boxing Game script initialized successfully.",
    Icon = "shield-check",
    Duration = 3,
})
