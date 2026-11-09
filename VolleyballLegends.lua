-- =============================================================================
-- RZO HUB - Volleyball Legends
-- Cross-Platform Architecture: Android (Delta, Fluxus, Codex, Arceus X, Hydrogen)
--                              & Windows (Wave, Synapse Z, Solara, Celery, Swift, etc.)
-- UI Framework: WindUI Library
-- Key Authentication: rzo-key-auth API integration
-- =============================================================================

-- Global Task Polyfill for legacy / Lua 5.1 environments
local task = task or {
    spawn = function(f, ...) return coroutine.resume(coroutine.create(f), ...) end,
    wait = function(n) return wait(n) end,
    cancel = function(t) end,
    delay = function(n, f) return delay(n, f) end
}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local AUTH_CONFIG = {
    Domain = (type(getgenv) == "function" and getgenv().RZO_AUTH_DOMAIN) or "https://rzohub.vercel.app",
    Discord = "https://discord.gg/vNExQNRK3",
    KeyFile = "rzo_key.txt"
}

local isKeyAuthenticated = false
local currentLicenseData = nil

-- Executor Identification Polyfill
local function getExecutorName()
    local name = nil
    pcall(function()
        if type(identifyexecutor) == "function" then
            name = identifyexecutor()
        elseif type(getexecutorname) == "function" then
            name = getexecutorname()
        end
    end)
    if name and #tostring(name) > 0 then
        return tostring(name)
    end
    if syn and syn.toast_notification then return "Synapse" end
    if SENTINEL_LOADED then return "Sentinel" end
    if KRNL_LOADED then return "Krnl" end
    if is_sirhurt_closure then return "Sirhurt" end
    if fluxus then return "Fluxus" end
    if delta then return "Delta" end
    if arceus then return "Arceus X" end
    if codex then return "Codex" end
    return isMobile and "Android Executor" or "Windows Executor"
end

-- Universal HWID Resolver (Cross-Platform Android & Windows)
local function getHwid()
    local hwid = nil
    pcall(function()
        if type(gethwid) == "function" then
            hwid = gethwid()
        elseif type(get_hwid) == "function" then
            hwid = get_hwid()
        end
    end)
    if not hwid or #tostring(hwid) < 5 then
        pcall(function()
            local rbx = game:GetService("RbxAnalyticsService")
            if rbx and rbx.GetClientId then
                hwid = rbx:GetClientId()
            end
        end)
    end
    if not hwid or #tostring(hwid) < 5 then
        pcall(function()
            if UserInputService and UserInputService.GetDeviceId then
                hwid = UserInputService:GetDeviceId()
            end
        end)
    end
    if not hwid or #tostring(hwid) < 5 then
        local lp = Players.LocalPlayer
        hwid = "FALLBACK_" .. (lp and tostring(lp.UserId) or "0")
    end
    return tostring(hwid)
end

-- Universal Clipboard Layer (Cross-Platform Android & Windows with memory fallback)
local function copyToClipboard(str)
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv then
        genv.RZO_CLIPBOARD = str
    end
    pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(str)
        elseif type(toclipboard) == "function" then
            toclipboard(str)
        elseif type(set_clipboard) == "function" then
            set_clipboard(str)
        elseif syn and type(syn.write_clipboard) == "function" then
            syn.write_clipboard(str)
        elseif Clipboard and type(Clipboard.set) == "function" then
            Clipboard.set(str)
        end
    end)
end

local function getFromClipboard()
    local clip = nil
    pcall(function()
        if type(getclipboard) == "function" then
            clip = getclipboard()
        elseif type(get_clipboard) == "function" then
            clip = get_clipboard()
        elseif syn and type(syn.read_clipboard) == "function" then
            clip = syn.read_clipboard()
        elseif Clipboard and type(Clipboard.get) == "function" then
            clip = Clipboard.get()
        end
    end)
    if not clip then
        local genv = (type(getgenv) == "function" and getgenv()) or _G
        if genv and genv.RZO_CLIPBOARD then
            clip = genv.RZO_CLIPBOARD
        end
    end
    return clip
end

-- Universal Resilient Filesystem Layer (File IO with Session Memory Fallback)
local function safeIsFile(path)
    local ok, res = pcall(function()
        if type(isfile) == "function" then
            return isfile(path)
        end
        return false
    end)
    if ok and res == true then return true end
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    return (genv and genv.RZO_FILE_CACHE and genv.RZO_FILE_CACHE[path] ~= nil) or false
end

local function safeReadFile(path)
    local ok, res = pcall(function()
        if type(readfile) == "function" then
            return readfile(path)
        end
        return nil
    end)
    if ok and res and type(res) == "string" and #res > 0 then
        return res
    end
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv and genv.RZO_FILE_CACHE and genv.RZO_FILE_CACHE[path] then
        return genv.RZO_FILE_CACHE[path]
    end
    return nil
end

local function safeWriteFile(path, content)
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv then
        genv.RZO_FILE_CACHE = genv.RZO_FILE_CACHE or {}
        genv.RZO_FILE_CACHE[path] = content
        genv.RZO_KEY = content
    end
    pcall(function()
        if type(writefile) == "function" then
            writefile(path, content)
        end
    end)
end

local function safeDelFile(path)
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv then
        if genv.RZO_FILE_CACHE then
            genv.RZO_FILE_CACHE[path] = nil
        end
        genv.RZO_KEY = nil
    end
    pcall(function()
        if type(delfile) == "function" then
            delfile(path)
        end
    end)
end

-- Universal UI Hierarchy Resolver (gethui -> CoreGui -> PlayerGui)
local function getSafeGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    local lp = Players.LocalPlayer
    return lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui"))
end

-- Signal Fire Polyfill (firesignal -> fire_signal -> getconnections)
local function safeFireSignal(signal, ...)
    if type(firesignal) == "function" then
        pcall(firesignal, signal, ...)
    elseif type(fire_signal) == "function" then
        pcall(fire_signal, signal, ...)
    elseif type(getconnections) == "function" then
        pcall(function(...)
            for _, conn in ipairs(getconnections(signal)) do
                if conn.Fire then
                    conn:Fire(...)
                elseif conn.Function then
                    task.spawn(conn.Function, ...)
                end
            end
        end, ...)
    end
end

-- Universal URI Encoder for Query Strings & HWID
local function urlEncode(str)
    if not str then return "" end
    str = tostring(str)
    return (str:gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

-- Universal HTTP Request Dispatcher (Cross-Executor & Android Case Normalization)
local function getHttpRequestFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    if krnl and type(krnl.request) == "function" then return krnl.request end
    if delta and type(delta.request) == "function" then return delta.request end
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if genv and type(genv.request) == "function" then return genv.request end
    return nil
end

local function makeHttpRequest(url, method, body)
    local fn = getHttpRequestFunction()
    if fn then
        local headersMap = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "RZO-HUB-VBL-Client/2.0 (" .. tostring(getExecutorName()) .. ")"
        }
        -- Both casing conventions for Android & PC executors
        local payload = {
            Url = url,
            url = url,
            Method = method or "GET",
            method = method or "GET",
            Headers = headersMap,
            headers = headersMap
        }
        if body then
            payload.Body = HttpService:JSONEncode(body)
            payload.body = payload.Body
        end

        local ok, res = pcall(fn, payload)
        if ok and res then
            if type(res) == "table" then
                if res.Body then return res.Body
                elseif res.body then return res.body
                elseif res.Response then return res.Response
                elseif res.Content then return res.Content
                end
            elseif type(res) == "string" then
                return res
            end
        end
    end

    if method == "GET" or not method then
        local ok, res = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and res and type(res) == "string" and #res > 0 then
            return res
        end
    end

    return nil
end

local function verifyLicenseKey(key)
    if not key or tostring(key):gsub("%s+", "") == "" then
        return false, "MISSING_KEY", "Please enter a valid license key."
    end

    local cleanKey = tostring(key):gsub("%s+", ""):gsub("[\"']", ""):upper()
    if not cleanKey:find("^VBL%-") and #cleanKey >= 16 then
        cleanKey = "VBL-" .. cleanKey:gsub("^%-+", "")
    end

    local hwid = getHwid()
    local url = string.format(
        "%s/api/verify.php?key=%s&hwid=%s",
        AUTH_CONFIG.Domain,
        urlEncode(cleanKey),
        urlEncode(hwid)
    )

    local body = makeHttpRequest(url, "GET")
    if not body then
        return false, "NETWORK_ERROR", "Failed to connect to RZO HUB server. Check your connection or domain."
    end

    local ok, parsed = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not ok or type(parsed) ~= "table" then
        return false, "SERVER_ERROR", "Invalid response received from authentication server."
    end

    if parsed.valid == true and parsed.status == "success" then
        return true, "SUCCESS", parsed
    else
        local code = parsed.code or "INVALID_KEY"
        local message = parsed.message or "License validation failed."
        return false, code, message
    end
end

-- =============================================================================
-- WINDUI FRAMEWORK INITIALIZATION
-- =============================================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "RZO HUB",
    Icon = "swords",
    Author = "Volleyball Legends",
    Folder = "rzohub",
    NewElements = true,
    OpenButton = {
        Title = "Open RZO HUB",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.6,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#257AF7")
        ),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Default",
    },
})

local function notify(title, content, duration)
    pcall(function()
        WindUI:Notify({
            Title = title or "RZO HUB",
            Content = content or "",
            Duration = duration or 3,
        })
    end)
end

Window.Notify = function(self, data)
    if type(data) == "table" then
        notify(data.Title, data.Content or data.Description, data.Duration or data.Time)
    else
        notify("RZO HUB", tostring(data), 3)
    end
end

-- Compatibility containers for external script calls
local Options = {}
local Toggles = {}
local Library = {
    Options = Options,
    Toggles = Toggles,
    Toggle = function(self)
        pcall(function() Window:Toggle() end)
    end,
    Unload = function(self)
        pcall(function() Window:Destroy() end)
    end,
    Notify = function(self, data)
        Window:Notify(data)
    end
}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local _originalGlobalShadows = Lighting.GlobalShadows
local _originalShadowSoftness = Lighting.ShadowSoftness
local _originalQualityLevel
local _originalShadowQuality
pcall(function()
    _originalQualityLevel = settings().Rendering.QualityLevel
    _originalShadowQuality = settings().Rendering.ShadowQuality
end)

local function getKnitService(name)
    local ok, service = pcall(function()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        if not packages then return nil end
        local index = packages:FindFirstChild("_Index")
        if not index then return nil end
        local knitPkg = index:FindFirstChild("sleitnick_knit@1.7.0")
        if not knitPkg then return nil end
        local knit = knitPkg:FindFirstChild("knit")
        if not knit then return nil end
        local services = knit:FindFirstChild("Services")
        if not services then return nil end
        return services:FindFirstChild(name)
    end)
    return ok and service or nil
end

local function getRemoteFolder(service)
    if not service then return nil end
    return service:FindFirstChild("RF")
end

local function getRemote(service, remoteName)
    local rf = getRemoteFolder(service)
    return rf and rf:FindFirstChild(remoteName) or nil
end

local function safeInvoke(remote, ...)
    if not remote or not remote:IsA("RemoteFunction") then
        return false, "RemoteFunction not found"
    end
    local ok, result = pcall(function(...)
        return remote:InvokeServer(...)
    end, ...)
    if not ok then
        warn("[RZO HUB] Invoke failed:", result)
    end
    return ok, result
end

local function hasExecutorFunction(name)
    return type(_G[name]) == "function" or type(getfenv()[name]) == "function"
end

local function getCurrentCamera()
    return Workspace.CurrentCamera or Camera
end

local function getGuiText(path)
    local node = LocalPlayer:FindFirstChild("PlayerGui")
    for part in string.gmatch(path, "[^%.]+") do
        if not node then return nil end
        node = node:FindFirstChild(part)
    end
    if node and (node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox")) then
        return node.Text
    end
    return nil
end

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local hitboxScale = 5.0
local hitboxColor = Color3.fromRGB(0, 255, 0)
local hitboxColorName = "Green"
-- Spike Settings
local sanjuTiltEnabled = false
local maxChargeEnabled = false
local maxChargeRoninEnabled = false
local maxChargeTSHEnabled = false
local inlineSpikeEnabled = false
local customSpikePower = 1.0

-- Movement & Controls
local autoShiftLockJumpEnabled = false
local isJumpingShiftLock = false
local lockedJumpLookVector = nil
local airMovement = false
local airMovementSpeed = 16
local bodyVelocity = nil
local desyncEnabled = false
local desyncConnection = nil
local autoReceiveEnabled = false
local autoReceiveConnection = nil
local akariDashEnabled = false
local dashButton = nil
local stopBallButton = nil
local aimButton = nil
local stopBallVisible = false
local aimVisible = false
local leadFeetEnabled = false
local leadFeetConnection = nil
local maxServeEnabled = false
local leadFeetButton = nil

-- Spin Settings
local autoSpin = false
local autoSpinDelay = 0.1
local autoAbilitySpin = false
local sessionSpins = 0
local desiredStyles = {}
local desiredAbilities = {}
local spinType = "Normal"
local abilitySpinType = "Normal"

local BallService = getKnitService("BallService")
local GameService = getKnitService("GameService")
local Serve = GameService and GameService:FindFirstChild("RF") and GameService.RF:FindFirstChild("Serve") or nil

local function getBallId()
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:match("^CLIENT_BALL_%d+$") then
            local id = model.Name:match("%d+")
            if id then
                return tonumber(id)
            end
        end
    end
    return nil
end

local function findFirstPart(model)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end
    return nil
end

local function updateHitboxes(scale)
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:match("^CLIENT_BALL_%d+$") then
            local ball = model:FindFirstChild("Ball.001")
            if not ball then
                local basePart = findFirstPart(model)
                if basePart then
                    ball = Instance.new("Part")
                    ball.Name = "Ball.001"
                    ball.Shape = Enum.PartType.Ball
                    ball.Size = Vector3.new(2, 2, 2) * scale
                    ball.CFrame = basePart.CFrame
                    ball.Anchored = true
                    ball.CanCollide = false
                    ball.Transparency = 0.7
                    ball.Material = Enum.Material.ForceField
                    ball.Color = hitboxColor
                    ball.Parent = model
                end
            else
                ball.Size = Vector3.new(2, 2, 2) * scale
                ball.Color = hitboxColor
            end
        end
    end
end

local function removeHitboxes()
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name:match("^CLIENT_BALL_%d+$") then
            local ball = model:FindFirstChild("Ball.001")
            if ball then
                ball:Destroy()
            end
        end
    end
end

workspace.ChildAdded:Connect(function(child)
    if child and child:IsA("Model") and child.Name:match("^CLIENT_BALL_%d+$") then
        task.wait(0.1)
        updateHitboxes(hitboxScale)
    end
end)

updateHitboxes(5.0)

local function getPlayerAnalogInput()
    local rawMove = Vector3.zero
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local controls = require(pm):GetControls()
            if controls and controls.GetMoveVector then
                rawMove = controls:GetMoveVector()
            end
        end
    end)
    return rawMove
end

local function applyInCourtSpikePhysics(data, isInline, isSanjuTilt)
    local character = LocalPlayer.Character
    local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChild("Humanoid")
    if not playerRoot then return end

    local cam = getCurrentCamera()
    local baseLook = (cam and cam.CFrame.LookVector) or playerRoot.CFrame.LookVector
    local flatLook = Vector3.new(baseLook.X, 0, baseLook.Z)
    if flatLook.Magnitude < 0.05 then
        flatLook = Vector3.new(playerRoot.CFrame.LookVector.X, 0, playerRoot.CFrame.LookVector.Z)
    end
    if flatLook.Magnitude > 0.001 then
        flatLook = flatLook.Unit
    else
        flatLook = Vector3.new(0, 0, -1)
    end
    local flatRight = Vector3.new(-flatLook.Z, 0, flatLook.X).Unit

    -- 1. Precision Raycast Floor Detection & Jump Altitude Calculation
    local myPos = playerRoot.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local floorHit = workspace:Raycast(myPos, Vector3.new(0, -60, 0), rayParams)
    local floorY = (floorHit and floorHit.Position.Y) or (myPos.Y - 3.0)
    local jumpAltitude = math.max(0.5, myPos.Y - floorY)

    -- 2. Power & Altitude Dynamics for Anti-Overhit Pitch (Guarantees In-Court Landing)
    local currentPower = tonumber(data.Power) or customSpikePower or 1.0
    local chargeVal = tonumber(data.Charge) or 1.0
    local totalPower = currentPower * chargeVal

    -- Steeper downward angle when high in the air or high power so the ball dips cleanly inside the line
    local downwardPitch = -math.clamp(0.42 + (0.025 * jumpAltitude) + (0.05 * totalPower), 0.45, 0.88)

    -- 3. Analog / Thumbstick Steering Direction (Kanan vs Kiri vs Center)
    local rawInput = getPlayerAnalogInput()
    local analogSide = 0 -- -1: Left (Kiri), 0: Center, 1: Right (Kanan)

    if math.abs(rawInput.X) > 0.15 then
        analogSide = (rawInput.X > 0) and 1 or -1
    elseif humanoid and humanoid.MoveDirection.Magnitude > 0.15 then
        local lateralDot = flatRight:Dot(humanoid.MoveDirection)
        if math.abs(lateralDot) > 0.20 then
            analogSide = (lateralDot > 0) and 1 or -1
        end
    end

    -- 4. Inline Spike Direction: Steered strictly by player's analog
    local lineAngle = flatLook
    if isInline then
        if analogSide == 1 then
            -- Analog Kanan: Angle down the Right Line
            lineAngle = (flatLook * 0.90 + flatRight * 0.35).Unit
        elseif analogSide == -1 then
            -- Analog Kiri: Angle down the Left Line
            lineAngle = (flatLook * 0.90 - flatRight * 0.35).Unit
        else
            -- Analog Center: Straight forward down-the-line
            lineAngle = flatLook
        end
    end

    local targetDirection = Vector3.new(lineAngle.X, downwardPitch, lineAngle.Z).Unit
    local targetLookVector = Vector3.new(lineAngle.X, downwardPitch * 0.55, lineAngle.Z).Unit

    if isInline then
        data.Direction = targetDirection
        data.LookVector = targetLookVector
        if data.MoveDirection then
            data.MoveDirection = targetDirection
        end
    end

    -- 5. Sanju Tilt [Universal Can Be Used All Style]: Steered strictly by player's analog
    if isSanjuTilt then
        local sliceFactor = 0.22 -- Calibrated sharp Sanju slice curve
        if analogSide ~= 0 then
            -- Analog Kanan (1) -> Cut slice sharply to the Right
            -- Analog Kiri (-1) -> Cut slice sharply to the Left
            local tiltX = flatRight.X * (sliceFactor * analogSide)
            local tiltZ = flatRight.Z * (sliceFactor * analogSide)
            data.TiltDirection = Vector3.new(tiltX, downwardPitch, tiltZ)
            data.LookVector = Vector3.new(
                targetLookVector.X + tiltX * 0.40,
                downwardPitch * 0.55,
                targetLookVector.Z + tiltZ * 0.40
            ).Unit
            data.Direction = Vector3.new(
                targetDirection.X + tiltX * 0.50,
                downwardPitch,
                targetDirection.Z + tiltZ * 0.50
            ).Unit
        elseif data.TiltDirection and (math.abs(data.TiltDirection.X) > 0.01 or math.abs(data.TiltDirection.Z) > 0.01) then
            -- Native Sanju style with centered analog: maintain and balance native curve
            local clampedX = math.clamp(data.TiltDirection.X * 1.15, -0.25, 0.25)
            local clampedZ = math.clamp(data.TiltDirection.Z * 1.15, -0.25, 0.25)
            data.TiltDirection = Vector3.new(clampedX, downwardPitch, clampedZ)
            data.LookVector = Vector3.new(
                targetLookVector.X + clampedX * 0.30,
                downwardPitch * 0.55,
                targetLookVector.Z + clampedZ * 0.30
            ).Unit
            data.Direction = Vector3.new(
                targetDirection.X + clampedX * 0.40,
                downwardPitch,
                targetDirection.Z + clampedZ * 0.40
            ).Unit
        else
            -- Center/Neutral analog: Clean downward tilt
            local tiltX = flatRight.X * 0.10
            local tiltZ = flatRight.Z * 0.10
            data.TiltDirection = Vector3.new(tiltX, downwardPitch, tiltZ)
            data.LookVector = Vector3.new(
                targetLookVector.X + tiltX * 0.20,
                downwardPitch * 0.55,
                targetLookVector.Z + tiltZ * 0.20
            ).Unit
            data.Direction = Vector3.new(
                targetDirection.X + tiltX * 0.25,
                downwardPitch,
                targetDirection.Z + tiltZ * 0.25
            ).Unit
        end
    end
end

local globalNamecallHooked = false
local oldGlobalNamecall = nil

local function setupUnifiedNamecallHook()
    if globalNamecallHooked then return end

    local handler = function(self, ...)
        if not isKeyAuthenticated then
            return oldGlobalNamecall(self, ...)
        end
        local method = (type(getnamecallmethod) == "function" and getnamecallmethod()) or ""
        if method == "InvokeServer" then
            if BallService and BallService:FindFirstChild("RF") and self == BallService.RF:FindFirstChild("Interact") then
                local args = {...}
                local data = args[1]
                if type(data) == "table" and data.Move == "Spike" then
                    -- Apply Spike Power attribute & payload
                    if customSpikePower and customSpikePower > 0 then
                        data.Power = customSpikePower
                    end

                    -- Smart In-Line Spike & Balanced Sanju Tilt Synchronization
                    if inlineSpikeEnabled or sanjuTiltEnabled then
                        applyInCourtSpikePhysics(data, inlineSpikeEnabled, sanjuTiltEnabled)
                    end

                    -- Max Charge: Ronin & TSH Tuning
                    if maxChargeRoninEnabled or maxChargeTSHEnabled or maxChargeEnabled then
                        data.Charge = 1.0
                        data.SpecialCharge = 1.0
                        if maxChargeRoninEnabled then
                            data.Power = customSpikePower or 1.0
                            data.StyleBoost = "Ronin"
                        end
                        if maxChargeTSHEnabled then
                            data.Boost = true
                            data.SuperCharge = true
                            data.StyleBoost = "TSH"
                        end
                    end
                end
                return oldGlobalNamecall(self, data)
            end

            if maxServeEnabled and Serve and self == Serve then
                local args = {...}
                args[2] = 5
                return oldGlobalNamecall(self, unpack(args))
            end
        end

        return oldGlobalNamecall(self, ...)
    end

    local hooked = false
    local cHandler = (type(newcclosure) == "function" and newcclosure(handler)) or handler

    -- Method 1: hookmetamethod (Standard for Delta, Codex, Arceus, Wave, Synapse)
    if type(hookmetamethod) == "function" then
        local ok, hookResult = pcall(function()
            return hookmetamethod(game, "__namecall", cHandler)
        end)
        if ok and hookResult then
            oldGlobalNamecall = hookResult
            hooked = true
        end
    end

    -- Method 2: Raw metatable hook fallback (Fluxus, Solara, older engines)
    if not hooked and type(getrawmetatable) == "function" then
        local ok, mt = pcall(getrawmetatable, game)
        if ok and mt then
            oldGlobalNamecall = mt.__namecall
            local writeable = false
            if type(setreadonly) == "function" then
                pcall(setreadonly, mt, false)
                writeable = true
            elseif type(make_writeable) == "function" then
                pcall(make_writeable, mt)
                writeable = true
            end

            local setOk = pcall(function()
                mt.__namecall = cHandler
            end)

            if setOk then
                hooked = true
            end

            if writeable then
                if type(setreadonly) == "function" then
                    pcall(setreadonly, mt, true)
                elseif type(make_readonly) == "function" then
                    pcall(make_readonly, mt)
                end
            end
        end
    end

    if hooked then
        globalNamecallHooked = true
    else
        warn("[RZO HUB] Namecall hook could not be established on this executor (" .. getExecutorName() .. ").")
    end
end

local function enableSanjuTilt()
    setupUnifiedNamecallHook()
    sanjuTiltEnabled = true
end

local function disableSanjuTilt()
    sanjuTiltEnabled = false
end

local function enableMaxChargeRonin()
    setupUnifiedNamecallHook()
    maxChargeRoninEnabled = true
end

local function disableMaxChargeRonin()
    maxChargeRoninEnabled = false
end

local function enableMaxChargeTSH()
    setupUnifiedNamecallHook()
    maxChargeTSHEnabled = true
end

local function disableMaxChargeTSH()
    maxChargeTSHEnabled = false
end

local function enableInlineSpike()
    setupUnifiedNamecallHook()
    inlineSpikeEnabled = true
end

local function disableInlineSpike()
    inlineSpikeEnabled = false
end

local function enableDesync()
    if desyncConnection then return end
    local doMove = getKnitService("BallService").RE.DoMove
    desyncConnection = UserInputService.JumpRequest:Connect(function()
        if desyncEnabled then
            task.wait(0.03)
            safeFireSignal(doMove.OnClientEvent, "Spike", false, false)
        end
    end)
    desyncEnabled = true
end

local function disableDesync()
    if desyncConnection then
        desyncConnection:Disconnect()
        desyncConnection = nil
    end
    desyncEnabled = false
end

local function enableAutoReceive()
    if autoReceiveConnection then return end
    local doMove = getKnitService("BallService").RE.DoMove
    autoReceiveConnection = RunService.Heartbeat:Connect(function()
        if not autoReceiveEnabled then return end
        local ball = nil
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") and model.Name:match("^CLIENT_BALL_%d+$") then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        ball = part
                        break
                    end
                end
            end
        end
        if not ball then return end
        local character = LocalPlayer.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        local distance = (ball.Position - rootPart.Position).Magnitude
        if distance <= 10 then
            if firesignal then
                firesignal(doMove.OnClientEvent, "Dive", false, false)
            end
        end
    end)
    autoReceiveEnabled = true
end

local function disableAutoReceive()
    if autoReceiveConnection then
        autoReceiveConnection:Disconnect()
        autoReceiveConnection = nil
    end
    autoReceiveEnabled = false
end

local function createDashButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AkariDashGUI"
    screenGui.Parent = getSafeGuiParent()
    screenGui.ResetOnSpawn = false
    dashButton = Instance.new("TextButton")
    dashButton.Size = UDim2.new(0, 50, 0, 50)
    dashButton.Position = UDim2.new(0.15, -25, 0.8, -25)
    dashButton.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    dashButton.Text = "⚡"
    dashButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    dashButton.TextScaled = true
    dashButton.Font = Enum.Font.GothamBold
    dashButton.Parent = screenGui
    dashButton.BackgroundTransparency = 0.2
    dashButton.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dashButton
    local dragging = false
    local dragStart = nil
    local startPos = nil
    dashButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = dashButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    dashButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            dashButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    dashButton.MouseButton1Click:Connect(function()
        if akariDashEnabled then
            local cam = getCurrentCamera()
            if not cam then return end
            local forward = cam.CFrame.LookVector
            forward = Vector3.new(forward.X, 0, forward.Z).Unit
            local character = LocalPlayer.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local tween = game:GetService("TweenService"):Create(hrp, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
                CFrame = CFrame.new(hrp.Position + (forward * 10)) * CFrame.Angles(0, math.rad(hrp.Orientation.Y), 0)
            })
            tween:Play()
        end
    end)
    dashButton.Visible = false
    return dashButton
end

createDashButton()

local function stopBall()
    if not BallService then return end
    local ballId = getBallId()
    if not ballId then return end
    local lookVector = Vector3.new(0, -1, 0)
    local Interact = BallService.RF.Interact
    if Interact then
        Interact:InvokeServer({
            ["Charge"] = 1,
            ["Move"] = "Block",
            ["SpecialCharge"] = 0,
            ["TiltDirection"] = Vector3.new(-0.1260179579257965, 1, 0.992027997970581),
            ["LookVector"] = lookVector,
            ["MoveDirection"] = Vector3.new(0, 0, 0),
            ["ClientCanRunSpecial"] = false,
            ["From"] = "Client",
            ["BallId"] = ballId,
            ["Timestamp"] = tick(),
            ["CustomClient"] = {},
        })
    end
end

local function getNearestTeammate()
    local nearest = nil
    local shortestDistance = math.huge
    local playerRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not playerRoot then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team == LocalPlayer.Team then
            local character = player.Character
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local distance = (rootPart.Position - playerRoot.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        nearest = player
                    end
                end
            end
        end
    end
    return nearest
end

local function aim()
    if not BallService then return end
    local ballId = getBallId()
    if not ballId then return end
    local nearestTeammate = getNearestTeammate()
    if not nearestTeammate then return end
    local targetRoot = nearestTeammate.Character:FindFirstChild("HumanoidRootPart")
    local playerRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not playerRoot then return end
    local direction = (targetRoot.Position - playerRoot.Position).Unit
    local tiltDir = Vector3.new(direction.X, 1, direction.Z)
    local lookVec = Vector3.new(direction.X, 0, direction.Z)
    if lookVec.Magnitude > 0 then
        lookVec = lookVec.Unit
    else
        lookVec = Vector3.new(0.17569558322429657, 9.214759444375886e-08, -0.9844445586204529)
    end
    local Interact = BallService.RF.Interact
    if Interact then
        Interact:InvokeServer({
            ["Charge"] = 1,
            ["Move"] = "JumpSet",
            ["SpecialCharge"] = 0.9999996364706223,
            ["TiltDirection"] = tiltDir,
            ["LookVector"] = lookVec,
            ["MoveDirection"] = Vector3.new(0, 0, 0),
            ["ClientCanRunSpecial"] = false,
            ["From"] = "Client",
            ["Timestamp"] = tick(),
            ["BallId"] = ballId,
            ["CustomClient"] = {},
        })
    end
end

local function createStopBallButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StopBallGUI"
    screenGui.Parent = getSafeGuiParent()
    stopBallButton = Instance.new("TextButton")
    stopBallButton.Size = UDim2.new(0, 50, 0, 50)
    stopBallButton.Position = UDim2.new(0.35, -25, 0.8, -25)
    stopBallButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    stopBallButton.Text = "Stop"
    stopBallButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBallButton.TextScaled = true
    stopBallButton.Font = Enum.Font.GothamBold
    stopBallButton.Parent = screenGui
    stopBallButton.BackgroundTransparency = 0.2
    stopBallButton.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = stopBallButton
    local dragging = false
    local dragStart = nil
    local startPos = nil
    stopBallButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = stopBallButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    stopBallButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            stopBallButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    stopBallButton.MouseButton1Click:Connect(function()
        stopBall()
    end)
    stopBallButton.Visible = stopBallVisible
    return stopBallButton
end

local function createAimButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimGUI"
    screenGui.Parent = getSafeGuiParent()
    aimButton = Instance.new("TextButton")
    aimButton.Size = UDim2.new(0, 50, 0, 50)
    aimButton.Position = UDim2.new(0.65, -25, 0.8, -25)
    aimButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    aimButton.Text = "Aim"
    aimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimButton.TextScaled = true
    aimButton.Font = Enum.Font.GothamBold
    aimButton.Parent = screenGui
    aimButton.BackgroundTransparency = 0.2
    aimButton.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = aimButton
    local dragging = false
    local dragStart = nil
    local startPos = nil
    aimButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = aimButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    aimButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            aimButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    aimButton.MouseButton1Click:Connect(function()
        aim()
    end)
    aimButton.Visible = aimVisible
    return aimButton
end

RunService.RenderStepped:Connect(function()
    if airMovement and bodyVelocity and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            bodyVelocity.Velocity = humanoid.MoveDirection * airMovementSpeed
        end
    end
end)

local function startAutoSpin()
    coroutine.wrap(function()
        while autoSpin do
            if sessionSpins >= 10 then
                autoSpin = false
                if Toggles and Toggles.AutoStyleSpin then
                    Toggles.AutoStyleSpin:SetValue(false)
                end
                Window:Notify({
                    Title = "Spin Safety Limit",
                    Content = "Maximum 10 spins reached! Execute Data Rollback now to avoid ban.",
                    Duration = 6
                })
                return
            end
            local currentStyle = getGuiText("Interface.Lobby.Styles.TopPanel.DisplayName") or ""
            for _, style in ipairs(desiredStyles) do
                if currentStyle == style then
                    autoSpin = false
                    if Toggles and Toggles.AutoStyleSpin then
                        Toggles.AutoStyleSpin:SetValue(false)
                    end
                    Window:Notify({ Title = "Style Obtained", Content = currentStyle, Duration = 4 })
                    return
                end
            end
            local args = { [1] = (spinType == "Lucky") }
            local StyleService = getKnitService("StyleService")
            if StyleService then
                local RF = StyleService:FindFirstChild("RF")
                if RF then
                    local Roll = RF:FindFirstChild("Roll")
                    if Roll then
                        safeInvoke(Roll, unpack(args))
                        sessionSpins = sessionSpins + 1
                    end
                end
            end
            task.wait(autoSpinDelay)
        end
    end)()
end

local function startAutoAbilitySpin()
    coroutine.wrap(function()
        while autoAbilitySpin do
            if sessionSpins >= 10 then
                autoAbilitySpin = false
                if Toggles and Toggles.AutoAbilitySpin then
                    Toggles.AutoAbilitySpin:SetValue(false)
                end
                Window:Notify({
                    Title = "Spin Safety Limit",
                    Content = "Maximum 10 spins reached! Execute Data Rollback now to avoid ban.",
                    Duration = 6
                })
                return
            end
            local currentAbility = getGuiText("Interface.Lobby.Abilities.TopPanel.DisplayName") or ""
            for _, ability in ipairs(desiredAbilities) do
                if currentAbility == ability then
                    autoAbilitySpin = false
                    if Toggles and Toggles.AutoAbilitySpin then
                        Toggles.AutoAbilitySpin:SetValue(false)
                    end
                    Window:Notify({ Title = "Ability Obtained", Content = currentAbility, Duration = 4 })
                    return
                end
            end
            local args = { [1] = (abilitySpinType == "Lucky") }
            local AbilityService = getKnitService("AbilityService")
            if AbilityService then
                local RF = AbilityService:FindFirstChild("RF")
                if RF then
                    local Roll = RF:FindFirstChild("Roll")
                    if Roll then
                        safeInvoke(Roll, unpack(args))
                        sessionSpins = sessionSpins + 1
                    end
                end
            end
            task.wait(autoSpinDelay)
        end
    end)()
end

local function enableMaxServe()
    setupUnifiedNamecallHook()
    maxServeEnabled = true
end

local function disableMaxServe()
    maxServeEnabled = false
end

local function createLeadFeetButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LeadFeetGUI"
    screenGui.Parent = getSafeGuiParent()
    leadFeetButton = Instance.new("TextButton")
    leadFeetButton.Size = UDim2.new(0, 50, 0, 50)
    leadFeetButton.Position = UDim2.new(0.25, -25, 0.8, -25)
    leadFeetButton.BackgroundColor3 = Color3.fromRGB(0, 255, 200)
    leadFeetButton.Text = "LF"
    leadFeetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    leadFeetButton.TextScaled = true
    leadFeetButton.Font = Enum.Font.GothamBold
    leadFeetButton.Parent = screenGui
    leadFeetButton.BackgroundTransparency = 0.2
    leadFeetButton.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = leadFeetButton
    local dragging = false
    local dragStart = nil
    local startPos = nil
    leadFeetButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = leadFeetButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    leadFeetButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            leadFeetButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    leadFeetButton.MouseButton1Click:Connect(function()
        if leadFeetEnabled then
            local character = LocalPlayer.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid or humanoid.Health <= 0 then return end
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {character}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            local result = workspace:Raycast(hrp.Position, Vector3.new(0, -1000, 0), params)
            if result then
                local altura = humanoid.HipHeight + 0.2
                local newPos = Vector3.new(hrp.Position.X, result.Position.Y + altura, hrp.Position.Z)
                hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                humanoid:ChangeState(Enum.HumanoidStateType.Landing)
            end
        end
    end)
    leadFeetButton.Visible = false
    return leadFeetButton
end

createLeadFeetButton()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        if leadFeetEnabled then
            local character = LocalPlayer.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid or humanoid.Health <= 0 then return end
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {character}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            local result = workspace:Raycast(hrp.Position, Vector3.new(0, -1000, 0), params)
            if result then
                local altura = humanoid.HipHeight + 0.2
                local newPos = Vector3.new(hrp.Position.X, result.Position.Y + altura, hrp.Position.Z)
                hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                humanoid:ChangeState(Enum.HumanoidStateType.Landing)
            end
        end
    end
end)

local lockJumpDirection, unlockJumpDirection

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")

    -- Apply current custom character attributes upon character spawn
    if customSpikePower then
        LocalPlayer:SetAttribute("Multiplier_SpikePower", customSpikePower)
        LocalPlayer:SetAttribute("GameSpikePowerMultiplier", customSpikePower)
        character:SetAttribute("Multiplier_SpikePower", customSpikePower)
        character:SetAttribute("GameSpikePowerMultiplier", customSpikePower)
    end

    -- Shift Lock: Instantly snaps and locks facing direction on jump, preventing all mid-air rotation
    humanoid.StateChanged:Connect(function(oldState, newState)
        if autoShiftLockJumpEnabled then
            if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
                lockJumpDirection()
            elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.None then
                unlockJumpDirection()
            end
        else
            if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
                humanoid.AutoRotate = false
            elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
                humanoid.AutoRotate = true
            end
        end
    end)

    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if autoShiftLockJumpEnabled and humanoid.Jump then
            lockJumpDirection()
        end
    end)
end

lockJumpDirection = function()
    if not autoShiftLockJumpEnabled then return end
    if isJumpingShiftLock and lockedJumpLookVector then return end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local cam = getCurrentCamera()
    if not humanoid or not hrp or not cam or humanoid.Health <= 0 then return end

    -- Determine target: camera center look vector (flattened to horizon)
    local camLook = cam.CFrame.LookVector
    local flatTarget = Vector3.new(camLook.X, 0, camLook.Z)
    if flatTarget.Magnitude < 0.05 then
        flatTarget = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
    end
    if flatTarget.Magnitude > 0.001 then
        flatTarget = flatTarget.Unit
    else
        flatTarget = Vector3.new(0, 0, -1)
    end

    -- Instantly snap character to face the camera center direction
    lockedJumpLookVector = flatTarget
    isJumpingShiftLock = true
    humanoid.AutoRotate = false
    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatTarget)

    -- Trigger Shift Lock orientation mode
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local pMod = require(pm)
            local cameras = pMod and pMod:GetCameras()
            local mouseLock = cameras and cameras.mouseLockController
            if mouseLock and not mouseLock:GetIsMouseLocked() then
                mouseLock:OnMouseLockToggled()
            end
        end
    end)
    pcall(function()
        UserSettings():GetService("UserGameSettings").RotationType = Enum.RotationType.CameraRelative
    end)
end

unlockJumpDirection = function()
    isJumpingShiftLock = false
    lockedJumpLookVector = nil
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.AutoRotate = true
        end
    end
    pcall(function()
        UserSettings():GetService("UserGameSettings").RotationType = Enum.RotationType.MovementRelative
    end)
end

UserInputService.JumpRequest:Connect(function()
    if autoShiftLockJumpEnabled then
        lockJumpDirection()
    end
end)

if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

-- Auto Shift Lock: Strictly keeps character locked to the initial jump direction throughout the airborne arc
RunService.RenderStepped:Connect(function()
    if autoShiftLockJumpEnabled and isJumpingShiftLock and lockedJumpLookVector and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and hrp and humanoid.Health > 0 then
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                -- Held fixed to the locked jump direction; character cannot rotate mid-air
                humanoid.AutoRotate = false
                hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + lockedJumpLookVector)
            end
        end
    end
end)

local function stableCleanup()
    pcall(disableInlineSpike)
    pcall(disableSanjuTilt)
    pcall(disableMaxChargeRonin)
    pcall(disableMaxChargeTSH)
    pcall(disableMaxServe)
    pcall(disableDesync)
    pcall(disableAutoReceive)
    if autoShiftLockJumpEnabled then
        autoShiftLockJumpEnabled = false
        pcall(unlockJumpDirection)
    end
    if bodyVelocity then
        pcall(function() bodyVelocity:Destroy() end)
        bodyVelocity = nil
    end
    removeHitboxes()
end

-- =============================================================================
-- WINDUI TABS DECLARATION (STRICT KEY PIPELINE)
-- =============================================================================
local Tabs = {
    Key = Window:Tab({ Title = "Key System", Icon = "key", Desc = "License verification checkpoint" }),
    Main = Window:Tab({ Title = "Main", Icon = "swords", Desc = "Game mechanics & enhancements" }),
    Character = Window:Tab({ Title = "Character", Icon = "user", Desc = "Attributes & movement modifications" }),
    Spin = Window:Tab({ Title = "Spin", Icon = "sparkles", Desc = "Rollback safeguard & spins" }),
    GameJoin = Window:Tab({ Title = "Game Join", Icon = "gamepad-2", Desc = "Matchmaking & modes" }),
    Settings = Window:Tab({ Title = "Settings", Icon = "wrench", Desc = "Hub configuration & safety" }),
}

local function setTabVisible(tabObj, visible)
    if not tabObj then return end
    pcall(function()
        if tabObj.UIElements and tabObj.UIElements.Main then
            tabObj.UIElements.Main.Visible = visible
        end
        if tabObj.Button then
            tabObj.Button.Visible = visible
        end
        if tabObj.Container then
            tabObj.Container.Visible = visible
        end
        if tabObj.UIElements and tabObj.UIElements.ContainerFrame then
            tabObj.UIElements.ContainerFrame.Visible = visible
        end
    end)
end

local function lockFeatureTabs()
    isKeyAuthenticated = false
    currentLicenseData = nil

    setTabVisible(Tabs.Main, false)
    setTabVisible(Tabs.Character, false)
    setTabVisible(Tabs.Spin, false)
    setTabVisible(Tabs.GameJoin, false)
    setTabVisible(Tabs.Settings, false)

    setTabVisible(Tabs.Key, true)
    pcall(function()
        if Tabs.Key and Tabs.Key.Select then
            Tabs.Key:Select()
        elseif Window and Window.SelectTab then
            Window:SelectTab(Tabs.Key.Index or 1)
        end
    end)
end

local function unlockFeatureTabs(licenseData)
    isKeyAuthenticated = true
    currentLicenseData = licenseData

    setTabVisible(Tabs.Key, false)

    setTabVisible(Tabs.Main, true)
    setTabVisible(Tabs.Character, true)
    setTabVisible(Tabs.Spin, true)
    setTabVisible(Tabs.GameJoin, true)
    setTabVisible(Tabs.Settings, true)

    pcall(function()
        if Tabs.Main and Tabs.Main.Select then
            Tabs.Main:Select()
        elseif Window and Window.SelectTab then
            Window:SelectTab(Tabs.Main.Index or 2)
        end
    end)
end

-- Strictly gate features initially
lockFeatureTabs()

-- -----------------------------------------------------------------------------
-- TAB 0: KEY SYSTEM (rzo-key-auth)
-- -----------------------------------------------------------------------------
local KeyAuthSection = Tabs.Key:Section({ Title = "VBL License Checkpoint", Box = true, Opened = true })
local KeyInfoSection = Tabs.Key:Section({ Title = "How to Get Key", Box = true, Opened = true })

local inputKeyBoxValue = ""

local keyInput = KeyAuthSection:Input({
    Title = "License Key",
    Desc = "Enter your 24h key",
    Value = "",
    Placeholder = "VBL-XXXX-XXXX-XXXX-XXXX",
    Callback = function(v)
        inputKeyBoxValue = v
        if Options.LicenseKeyInput then
            Options.LicenseKeyInput.Value = v
        end
    end
})

Options.LicenseKeyInput = {
    Value = "",
    Set = function(self, val)
        self.Value = val
        inputKeyBoxValue = val
        pcall(function() keyInput:Set(val) end)
    end,
    SetValue = function(self, val)
        self:Set(val)
    end
}

KeyAuthSection:Button({
    Title = "Submit Key",
    Color = Color3.fromHex("#30FF6A"),
    Callback = function()
        local keyToTest = inputKeyBoxValue
        if (not keyToTest or keyToTest:gsub("%s+", "") == "") and Options.LicenseKeyInput and Options.LicenseKeyInput.Value then
            keyToTest = Options.LicenseKeyInput.Value
        end

        if (not keyToTest or keyToTest:gsub("%s+", "") == "") then
            local saved = safeReadFile(AUTH_CONFIG.KeyFile)
            if saved and saved:gsub("%s+", "") ~= "" then
                keyToTest = saved
            end
        end

        if (not keyToTest or keyToTest:gsub("%s+", "") == "") then
            local clip = getFromClipboard()
            if clip and #clip > 3 then
                keyToTest = clip
            end
        end

        if not keyToTest or keyToTest:gsub("%s+", "") == "" then
            notify("Key System", "Please enter or paste your license key first.", 3)
            return
        end

        local cleanKey = keyToTest:gsub("%s+", ""):gsub("["']", ""):upper()
        if not cleanKey:find("^VBL%-") and #cleanKey >= 16 then
            cleanKey = "VBL-" .. cleanKey:gsub("^%-+", "")
        end

        inputKeyBoxValue = cleanKey
        if Options.LicenseKeyInput then
            Options.LicenseKeyInput:SetValue(cleanKey)
        end

        notify("Key System", "Contacting authentication server...", 2)
        local valid, code, result = verifyLicenseKey(cleanKey)
        if valid then
            safeWriteFile(AUTH_CONFIG.KeyFile, cleanKey)
            local welcomeUser = (type(result) == "table" and result.user) or "User"
            local expiryStr = (type(result) == "table" and result.expires_at) or "24 Hours"
            notify("Access Granted", "Key verified! Welcome, " .. tostring(welcomeUser) .. "!
Expires: " .. tostring(expiryStr), 4)
            unlockFeatureTabs(result)
        else
            local errMsg = (type(result) == "table" and (result.message or result.code)) or result or code or "Verification failed."
            notify("Verification Failed", tostring(errMsg), 4)
        end
    end
})

KeyAuthSection:Button({
    Title = "Paste From Clipboard",
    Callback = function()
        local clip = getFromClipboard()
        if clip and #clip > 3 then
            local cleanClip = clip:gsub("%s+", ""):gsub("["']", ""):upper()
            if not cleanClip:find("^VBL%-") and #cleanClip >= 16 then
                cleanClip = "VBL-" .. cleanClip:gsub("^%-+", "")
            end
            inputKeyBoxValue = cleanClip
            if Options.LicenseKeyInput then
                Options.LicenseKeyInput:SetValue(cleanClip)
            end
            notify("Clipboard", "Key loaded into input! Click 'Submit Key' to activate.", 3)
        else
            notify("Clipboard", "Clipboard is empty or unsupported on your executor.", 2)
        end
    end
})

KeyAuthSection:Button({
    Title = "Check Saved Key",
    Callback = function()
        local saved = safeReadFile(AUTH_CONFIG.KeyFile)
        if saved and saved:gsub("%s+", "") ~= "" then
            local clean = saved:gsub("%s+", "")
            inputKeyBoxValue = clean
            if Options.LicenseKeyInput then
                Options.LicenseKeyInput:SetValue(clean)
            end
            notify("Key System", "Saved key loaded into input! Click 'Submit Key' to activate.", 3)
        else
            notify("Key System", "No saved key found on device.", 2)
        end
    end
})

KeyInfoSection:Button({
    Title = "Get Key via LootLabs (Copy)",
    Callback = function()
        local url = AUTH_CONFIG.Domain .. "/get_key.php?provider=lootlabs"
        copyToClipboard(url)
        notify("Link Copied!", "LootLabs URL copied! Complete tasks in browser.", 4)
    end
})

KeyInfoSection:Button({
    Title = "Get Key via Linkvertise (Copy)",
    Callback = function()
        local url = AUTH_CONFIG.Domain .. "/get_key.php?provider=linkvertise"
        copyToClipboard(url)
        notify("Link Copied!", "Linkvertise URL copied! Complete tasks in browser.", 4)
    end
})

KeyInfoSection:Button({
    Title = "Web Dashboard (Copy Link)",
    Callback = function()
        local url = AUTH_CONFIG.Domain .. "/dashboard.php"
        copyToClipboard(url)
        notify("Dashboard Copied!", "Manage HWID resets or view active key.", 3)
    end
})

KeyInfoSection:Button({
    Title = "Join Discord Community",
    Callback = function()
        copyToClipboard(AUTH_CONFIG.Discord)
        notify("Discord Copied!", "Invite copied to clipboard: " .. AUTH_CONFIG.Discord, 3)
    end
})

KeyInfoSection:Section({
    Title = "Instructions",
    Desc = "1. Choose LootLabs or Linkvertise link.
2. Complete tasks in browser to get +24h key.
3. Paste key here and press Submit Key.",
    TextSize = 14,
    TextTransparency = 0.35
})

-- -----------------------------------------------------------------------------
-- TAB 1: MAIN
-- -----------------------------------------------------------------------------
local SpikeSection = Tabs.Main:Section({ Title = "Spike Settings", Box = true, Opened = true })

SpikeSection:Toggle({
    Title = "Inline Spike",
    Desc = "Guarantees in-court spike calculated dynamically with analog steering",
    Value = false,
    Callback = function(v)
        if v then
            enableInlineSpike()
            notify("Inline Spike", "ENABLED (In-Court Guaranteed)", 2)
        else
            disableInlineSpike()
            notify("Inline Spike", "DISABLED", 2)
        end
    end
})

SpikeSection:Toggle({
    Title = "Sanju Tilt [universal can be use all style]",
    Desc = "Smart empty-space cut tilt adapted for all styles steered by analog thumbstick",
    Value = false,
    Callback = function(v)
        if v then
            enableSanjuTilt()
            notify("Sanju Tilt", "ENABLED (Universal All Styles)", 2)
        else
            disableSanjuTilt()
            notify("Sanju Tilt", "DISABLED", 2)
        end
    end
})

SpikeSection:Toggle({
    Title = "Max Charge (Ronin)",
    Desc = "Forces maximum special charge and power tuned for Ronin",
    Value = false,
    Callback = function(v)
        if v then
            enableMaxChargeRonin()
            notify("Ronin Charge", "MAX CHARGE ENABLED", 2)
        else
            disableMaxChargeRonin()
            notify("Ronin Charge", "DISABLED", 2)
        end
    end
})

SpikeSection:Toggle({
    Title = "Max Charge (TSH)",
    Desc = "Forces maximum special charge, boost, and power for The Strongest Hero",
    Value = false,
    Callback = function(v)
        if v then
            enableMaxChargeTSH()
            notify("TSH Charge", "MAX CHARGE ENABLED", 2)
        else
            disableMaxChargeTSH()
            notify("TSH Charge", "DISABLED", 2)
        end
    end
})

local ServeSection = Tabs.Main:Section({ Title = "Serve Settings", Box = true, Opened = true })

ServeSection:Toggle({
    Title = "Max Serve",
    Desc = "Forces maximum serve power level 5",
    Value = false,
    Callback = function(v)
        if v then
            enableMaxServe()
            notify("Max Serve", "ENABLED", 2)
        else
            disableMaxServe()
            notify("Max Serve", "DISABLED", 2)
        end
    end
})

ServeSection:Toggle({
    Title = "Lead Feet",
    Desc = "Snap instantly to floor when pressing R",
    Value = false,
    Callback = function(v)
        leadFeetEnabled = v
        if leadFeetButton then
            leadFeetButton.Visible = v
        end
        notify("Lead Feet", v and "ENABLED" or "DISABLED", 2)
    end
})

local HitboxSection = Tabs.Main:Section({ Title = "Hitbox Settings", Box = true, Opened = true })

HitboxSection:Slider({
    Title = "Hitbox Size",
    Desc = "Adjust ball interaction hitbox radius",
    Step = 0.5,
    Value = {
        Min = 0,
        Max = 20,
        Default = 5,
    },
    Callback = function(v)
        hitboxScale = v
        updateHitboxes(v)
    end
})

HitboxSection:Dropdown({
    Title = "Hitbox Color",
    Desc = "Choose visual indicator tint",
    Values = {"Green", "Blue", "Red", "Yellow", "Purple", "Orange", "Pink", "White"},
    Value = "Green",
    Callback = function(v)
        local colors = {
            Green = Color3.fromRGB(0, 255, 0),
            Blue = Color3.fromRGB(0, 0, 255),
            Red = Color3.fromRGB(255, 0, 0),
            Yellow = Color3.fromRGB(255, 255, 0),
            Purple = Color3.fromRGB(128, 0, 128),
            Orange = Color3.fromRGB(255, 165, 0),
            Pink = Color3.fromRGB(255, 105, 180),
            White = Color3.fromRGB(255, 255, 255)
        }
        hitboxColor = colors[v] or Color3.fromRGB(0, 255, 0)
        hitboxColorName = v
        updateHitboxes(hitboxScale)
    end
})

HitboxSection:Button({
    Title = "Remove Hitboxes",
    Callback = function()
        removeHitboxes()
        notify("Hitboxes Removed", "All hitboxes cleared", 2)
    end
})

HitboxSection:Button({
    Title = "Show Stop Ball",
    Callback = function()
        stopBallVisible = not stopBallVisible
        if stopBallButton then
            stopBallButton.Visible = stopBallVisible
        else
            stopBallButton = createStopBallButton()
        end
        notify("Stop Ball", stopBallVisible and "SHOWN" or "HIDDEN", 2)
    end
})

HitboxSection:Button({
    Title = "Show Aim",
    Callback = function()
        aimVisible = not aimVisible
        if aimButton then
            aimButton.Visible = aimVisible
        else
            aimButton = createAimButton()
        end
        notify("Aim", aimVisible and "SHOWN" or "HIDDEN", 2)
    end
})

local MovePerfSection = Tabs.Main:Section({ Title = "Movement & Performance", Box = true, Opened = true })

MovePerfSection:Toggle({
    Title = "Auto Shift Lock (Jump)",
    Desc = "Centers facing to camera on jump and strictly locks mid-air orientation",
    Value = false,
    Callback = function(v)
        autoShiftLockJumpEnabled = v
        if not v then
            pcall(unlockJumpDirection)
        end
        notify("Shift Lock", v and "Auto Shift Lock (Jump Lock) ENABLED" or "DISABLED", 2)
    end
})

MovePerfSection:Toggle({
    Title = "Anti-Lag",
    Desc = "Optimizes shadows and lighting for maximum FPS",
    Value = false,
    Callback = function(v)
        if v then
            pcall(function()
                local GraphicsQuality = tonumber(game:GetEngineStats().GraphicsQuality)
                if GraphicsQuality and GraphicsQuality > 3 then
                    game:SetGraphicsQuality(3)
                end
                if Lighting:FindFirstChild("BloomEffect") then Lighting.BloomEffect.Enabled = false end
                if Lighting:FindFirstChild("BlurEffect") then Lighting.BlurEffect.Enabled = false end
                if Lighting:FindFirstChild("SunRaysEffect") then Lighting.SunRaysEffect.Enabled = false end
                Lighting.ShadowSoftness = 1.5
                Lighting.ShadowsEnabled = false
                Lighting.GlobalShadows = false
                settings().Rendering.QualityLevel = 1
                settings().Rendering.ShadowQuality = 0
            end)
            notify("Anti-Lag", "ENABLED", 2)
        else
            pcall(function()
                if _originalQualityLevel then settings().Rendering.QualityLevel = _originalQualityLevel end
                if _originalShadowQuality then settings().Rendering.ShadowQuality = _originalShadowQuality end
                Lighting.GlobalShadows = _originalGlobalShadows
                Lighting.ShadowSoftness = _originalShadowSoftness
                if Lighting:FindFirstChild("BloomEffect") then Lighting.BloomEffect.Enabled = true end
                if Lighting:FindFirstChild("BlurEffect") then Lighting.BlurEffect.Enabled = true end
                if Lighting:FindFirstChild("SunRaysEffect") then Lighting.SunRaysEffect.Enabled = true end
            end)
            notify("Anti-Lag", "DISABLED", 2)
        end
    end
})

MovePerfSection:Toggle({
    Title = "Desync",
    Desc = "Desynchronizes character jump state via spoofed Dive event",
    Value = false,
    Callback = function(v)
        if v then
            enableDesync()
            notify("Desync", "ENABLED", 2)
        else
            disableDesync()
            notify("Desync", "DISABLED", 2)
        end
    end
})

MovePerfSection:Toggle({
    Title = "Auto Receive",
    Desc = "Automatically dives when ball is within 10 studs",
    Value = false,
    Callback = function(v)
        if v then
            enableAutoReceive()
            notify("Auto Receive", "ENABLED", 2)
        else
            disableAutoReceive()
            notify("Auto Receive", "DISABLED", 2)
        end
    end
})

MovePerfSection:Toggle({
    Title = "Akari Dash",
    Desc = "On-screen button for Akari dash action",
    Value = false,
    Callback = function(v)
        akariDashEnabled = v
        if dashButton then
            dashButton.Visible = v
        end
        notify("Akari Dash", v and "ENABLED" or "DISABLED", 2)
    end
})

-- -----------------------------------------------------------------------------
-- TAB 2: CHARACTER
-- -----------------------------------------------------------------------------
local AttrSection = Tabs.Character:Section({ Title = "Attributes", Box = true, Opened = true })

AttrSection:Input({
    Title = "Spike Power",
    Desc = "Multiplier for spike velocity",
    Value = "1.0",
    Placeholder = "1.0",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            customSpikePower = num
            LocalPlayer:SetAttribute("Multiplier_SpikePower", num)
            LocalPlayer:SetAttribute("GameSpikePowerMultiplier", num)
            if LocalPlayer.Character then
                LocalPlayer.Character:SetAttribute("Multiplier_SpikePower", num)
                LocalPlayer.Character:SetAttribute("GameSpikePowerMultiplier", num)
            end
        end
    end
})

AttrSection:Input({
    Title = "Dive Speed",
    Desc = "Multiplier for diving speed",
    Value = "0.95",
    Placeholder = "0.95",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_DiveSpeed", num)
        end
    end
})

AttrSection:Input({
    Title = "Jump Power",
    Desc = "Multiplier for jump altitude",
    Value = "1.1",
    Placeholder = "1.1",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_JumpPower", num)
        end
    end
})

AttrSection:Input({
    Title = "Speed",
    Desc = "Multiplier for run velocity",
    Value = "0.85",
    Placeholder = "0.85",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_Speed", num)
        end
    end
})

local CharMoveSection = Tabs.Character:Section({ Title = "Movement", Box = true, Opened = true })

CharMoveSection:Toggle({
    Title = "Air Movement",
    Desc = "Directional velocity while airborne",
    Value = false,
    Callback = function(v)
        airMovement = v
        if not v and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end
})

CharMoveSection:Slider({
    Title = "Air Movement Speed",
    Desc = "Flight velocity speed value",
    Step = 1,
    Value = {
        Min = 0,
        Max = 100,
        Default = 16,
    },
    Callback = function(v)
        airMovementSpeed = v
    end
})

-- -----------------------------------------------------------------------------
-- TAB 3: SPIN & AUTOMATION
-- -----------------------------------------------------------------------------
local RollbackSection = Tabs.Spin:Section({ Title = "Data Rollback Warning", Box = true, Opened = true })

RollbackSection:Section({
    Title = "[CRITICAL NOTICE] READ BEFORE USING SPINS",
    Desc = "• Spin Limit: Strict maximum of 10 spins per session.
• Auto-Save Risk: Exceeding 10 spins triggers permanent server auto-save.
• Ban Prevention: Never roll more than 10 times in one session or you risk an immediate ban.
• Rollback Function: Reverts unwanted spin results before server commits data.
• Instructions: If you do not roll your desired item within 10 spins, press Execute Data Rollback immediately to rejoin safely.",
    TextSize = 14,
    TextTransparency = 0.25
})

RollbackSection:Button({
    Title = "Execute Data Rollback (Rejoin)",
    Color = Color3.fromHex("#EF4F1D"),
    Callback = function()
        local remote = getKnitService("SettingsService")
        local rf = remote and remote:FindFirstChild("RF") and remote.RF:FindFirstChild("UpdateKeybind")
        if rf then
            rf:InvokeServer("MouseButton1", true, "Spikeâ")
        end
        notify("Data Rollback", "Executed! Rejoining server...", 2)
        TeleportService:Teleport(game.PlaceId)
    end
})

local RewardsSection = Tabs.Spin:Section({ Title = "Claim Rewards & Codes", Box = true, Opened = true })

RewardsSection:Button({
    Title = "Claim Level Rewards",
    Callback = function()
        local LevelService = getKnitService("LevelService")
        if LevelService then
            local RF = LevelService:FindFirstChild("RF")
            if RF then
                local ClaimLevelRewards = RF:FindFirstChild("ClaimLevelRewards")
                if ClaimLevelRewards then
                    safeInvoke(ClaimLevelRewards)
                    notify("Claimed", "Level rewards claimed!", 2)
                end
            end
        end
    end
})

RewardsSection:Button({
    Title = "Claim Quest Rewards",
    Callback = function()
        local QuestService = getKnitService("QuestService")
        if QuestService then
            local RF = QuestService:FindFirstChild("RF")
            if RF then
                local ClaimAll = RF:FindFirstChild("ClaimAll")
                if ClaimAll then
                    safeInvoke(ClaimAll, true)
                    notify("Claimed", "Quest rewards claimed!", 2)
                end
            end
        end
    end
})

RewardsSection:Button({
    Title = "Redeem All Codes",
    Callback = function()
        local function fetchNewCodes()
            local success, data = pcall(function()
                return game:HttpGet("https://beebom.com/haikyuu-legends-codes/")
            end)
            if not success or not data then
                return {}
            end
            local newCodes = {}
            local processed = {}
            for line in string.gmatch(data, "[^
]+") do
                if string.find(line, "(NEW)") then
                    local code = string.match(line, "(%u+[%u%d_]+)")
                    if code and not processed[code] then
                        processed[code] = true
                        table.insert(newCodes, code)
                    end
                end
                if #newCodes >= 5 then
                    break
                end
            end
            return newCodes
        end
        local newCodes = fetchNewCodes()
        if #newCodes > 0 then
            for _, code in pairs(newCodes) do
                local CodeService = getKnitService("CodeService")
                if CodeService then
                    local RF = CodeService:FindFirstChild("RF")
                    if RF then
                        local Redeem = RF:FindFirstChild("Redeem")
                        if Redeem then
                            pcall(function()
                                Redeem:InvokeServer(code)
                            end)
                        end
                    end
                end
                task.wait(0.01)
            end
            notify("Codes Redeemed", "Codes process completed!", 3)
        else
            notify("No Codes", "No new codes found from web!", 3)
        end
    end
})

local StyleSpinSection = Tabs.Spin:Section({ Title = "Auto Style Spin", Box = true, Opened = true })

local autoStyleSpinToggle = StyleSpinSection:Toggle({
    Title = "Auto Style Spin",
    Desc = "Continuously rolls style until desired style is reached [Max 10 spins!]",
    Value = false,
    Callback = function(v)
        autoSpin = v
        if v then
            startAutoSpin()
        end
    end
})

Toggles.AutoStyleSpin = {
    Value = false,
    Set = function(self, val)
        self.Value = val
        pcall(function() autoStyleSpinToggle:Set(val) end)
    end,
    SetValue = function(self, val)
        self:Set(val)
    end
}

StyleSpinSection:Dropdown({
    Title = "Style Spin Type",
    Values = {"Normal", "Lucky"},
    Value = "Normal",
    Callback = function(v)
        spinType = v
    end
})

StyleSpinSection:Input({
    Title = "Target Style",
    Value = "Sanju",
    Placeholder = "Sanju",
    Callback = function(v)
        desiredStyles = {v}
        notify("Target Set", "Target style: " .. tostring(v), 2)
    end
})

StyleSpinSection:Button({
    Title = "Instant Spin",
    Callback = function()
        if sessionSpins >= 10 then
            Window:Notify({
                Title = "Spin Limit Warning",
                Content = "10 spins reached! Execute Data Rollback to prevent ban.",
                Duration = 5
            })
            return
        end
        local args = { [1] = (spinType == "Lucky") }
        local StyleService = getKnitService("StyleService")
        if StyleService then
            local RF = StyleService:FindFirstChild("RF")
            if RF then
                local Roll = RF:FindFirstChild("Roll")
                if Roll then
                    safeInvoke(Roll, unpack(args))
                    sessionSpins = sessionSpins + 1
                    notify("Instant Spin", "Style spin executed! (" .. spinType .. ") [" .. tostring(sessionSpins) .. "/10]", 2)
                end
            end
        end
    end
})

local AbilitySpinSection = Tabs.Spin:Section({ Title = "Auto Ability Spin", Box = true, Opened = true })

local autoAbilitySpinToggle = AbilitySpinSection:Toggle({
    Title = "Auto Ability Spin",
    Desc = "Continuously rolls ability until desired ability is reached [Max 10 spins!]",
    Value = false,
    Callback = function(v)
        autoAbilitySpin = v
        if v then
            startAutoAbilitySpin()
        end
    end
})

Toggles.AutoAbilitySpin = {
    Value = false,
    Set = function(self, val)
        self.Value = val
        pcall(function() autoAbilitySpinToggle:Set(val) end)
    end,
    SetValue = function(self, val)
        self:Set(val)
    end
}

AbilitySpinSection:Dropdown({
    Title = "Ability Spin Type",
    Values = {"Normal", "Lucky"},
    Value = "Normal",
    Callback = function(v)
        abilitySpinType = v
    end
})

AbilitySpinSection:Input({
    Title = "Target Ability",
    Value = "Shield Breaker",
    Placeholder = "Shield Breaker",
    Callback = function(v)
        desiredAbilities = {v}
        notify("Target Set", "Target ability: " .. tostring(v), 2)
    end
})

AbilitySpinSection:Button({
    Title = "Instant Spin",
    Callback = function()
        if sessionSpins >= 10 then
            Window:Notify({
                Title = "Spin Limit Warning",
                Content = "10 spins reached! Execute Data Rollback to prevent ban.",
                Duration = 5
            })
            return
        end
        local args = { [1] = (abilitySpinType == "Lucky") }
        local AbilityService = getKnitService("AbilityService")
        if AbilityService then
            local RF = AbilityService:FindFirstChild("RF")
            if RF then
                local Roll = RF:FindFirstChild("Roll")
                if Roll then
                    safeInvoke(Roll, unpack(args))
                    sessionSpins = sessionSpins + 1
                    notify("Instant Spin", "Ability spin executed! (" .. abilitySpinType .. ") [" .. tostring(sessionSpins) .. "/10]", 2)
                end
            end
        end
    end
})

local ShopSection = Tabs.Spin:Section({ Title = "Shop Purchases", Box = true, Opened = true })

ShopSection:Button({
    Title = "Buy Emote",
    Callback = function()
        local PackService = getKnitService("PackService")
        local RF = PackService and PackService:FindFirstChild("RF")
        if RF then
            local Open = RF:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Emote1")
                notify("Shop", "Emote purchased!", 2)
            end
        end
    end
})

ShopSection:Button({
    Title = "Buy Basic Ball",
    Callback = function()
        local PackService = getKnitService("PackService")
        local RF = PackService and PackService:FindFirstChild("RF")
        if RF then
            local Open = RF:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Ball1")
                notify("Shop", "Basic ball purchased!", 2)
            end
        end
    end
})

ShopSection:Button({
    Title = "Buy Extreme Ball",
    Callback = function()
        local PackService = getKnitService("PackService")
        local RF = PackService and PackService:FindFirstChild("RF")
        if RF then
            local Open = RF:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Extreme")
                notify("Shop", "Extreme ball purchased!", 2)
            end
        end
    end
})

ShopSection:Button({
    Title = "Buy Medium Ball",
    Callback = function()
        local PackService = getKnitService("PackService")
        local RF = PackService and PackService:FindFirstChild("RF")
        if RF then
            local Open = RF:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Medium")
                notify("Shop", "Medium ball purchased!", 2)
            end
        end
    end
})

ShopSection:Button({
    Title = "Buy Basic Ball",
    Callback = function()
        local PackService = getKnitService("PackService")
        local RF = PackService and PackService:FindFirstChild("RF")
        if RF then
            local Open = RF:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Basic")
                notify("Shop", "Basic ball purchased!", 2)
            end
        end
    end
})

-- -----------------------------------------------------------------------------
-- TAB 4: GAME JOIN
-- -----------------------------------------------------------------------------
local GameModesSection = Tabs.GameJoin:Section({ Title = "Game Modes", Box = true, Opened = true })

GameModesSection:Button({
    Title = "Chaos Mode",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "ChaosMode")
                notify("Joining", "Chaos Mode...", 2)
            end
        end
    end
})

GameModesSection:Button({
    Title = "1v1 Mini Map",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "OnesMini")
                notify("Joining", "1v1 Mini Map...", 2)
            end
        end
    end
})

GameModesSection:Button({
    Title = "2v2 Ranked",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "Twos")
                notify("Joining", "2v2 Ranked...", 2)
            end
        end
    end
})

GameModesSection:Button({
    Title = "3v3 Ranked",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "Threes")
                notify("Joining", "3v3 Ranked...", 2)
            end
        end
    end
})

GameModesSection:Button({
    Title = "4v4 Ranked",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "Fours")
                notify("Joining", "4v4 Ranked...", 2)
            end
        end
    end
})

GameModesSection:Button({
    Title = "6v6 Ranked",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "Sixes")
                notify("Joining", "6v6 Ranked...", 2)
            end
        end
    end
})

GameModesSection:Button({
    Title = "Training",
    Callback = function()
        local PartyService = getKnitService("PartyService")
        local RF = PartyService and PartyService:FindFirstChild("RF")
        if RF then
            local RequestTeleport = RF:FindFirstChild("RequestTeleport")
            if RequestTeleport then
                safeInvoke(RequestTeleport, "Training")
                notify("Joining", "Training...", 2)
            end
        end
    end
})

-- -----------------------------------------------------------------------------
-- TAB 5: SETTINGS
-- -----------------------------------------------------------------------------
local LicenseStatusSection = Tabs.Settings:Section({ Title = "License Management", Box = true, Opened = true })

LicenseStatusSection:Button({
    Title = "Copy My Key",
    Callback = function()
        local key = currentLicenseData and currentLicenseData.license_key
        if not key then
            pcall(function()
                if isfile and isfile(AUTH_CONFIG.KeyFile) then
                    key = readfile(AUTH_CONFIG.KeyFile)
                end
            end)
        end
        if key then
            copyToClipboard(key)
            notify("Copied", "License key copied to clipboard!", 2)
        else
            notify("Error", "No active license key found.", 2)
        end
    end
})

LicenseStatusSection:Button({
    Title = "Open Web Dashboard (Copy)",
    Callback = function()
        copyToClipboard(AUTH_CONFIG.Domain .. "/dashboard.php")
        notify("Dashboard", "URL copied to clipboard!", 2)
    end
})

LicenseStatusSection:Button({
    Title = "Clear Saved Key (Logout)",
    Color = Color3.fromHex("#EF4F1D"),
    Callback = function()
        safeDelFile(AUTH_CONFIG.KeyFile)
        notify("License Cleared", "Saved key deleted! Locking hub...", 2)
        task.wait(0.5)
        lockFeatureTabs()
    end
})

local SafetySection = Tabs.Settings:Section({ Title = "Safety & Lifecycle", Box = true, Opened = true })

SafetySection:Button({
    Title = "Panic (Disable All)",
    Color = Color3.fromHex("#EF4F1D"),
    Callback = function()
        removeHitboxes()
        inlineSpikeEnabled = false
        sanjuTiltEnabled = false
        autoShiftLockJumpEnabled = false
        pcall(unlockJumpDirection)
        maxChargeRoninEnabled = false
        maxChargeTSHEnabled = false
        airMovement = false
        desyncEnabled = false
        autoReceiveEnabled = false
        akariDashEnabled = false
        autoSpin = false
        autoAbilitySpin = false
        stopBallVisible = false
        aimVisible = false
        maxServeEnabled = false
        leadFeetEnabled = false
        if spinConnection then task.cancel(spinConnection) spinConnection = nil end
        if abilitySpinConnection then task.cancel(abilitySpinConnection) abilitySpinConnection = nil end
        if dashButton then dashButton.Visible = false end
        if stopBallButton then stopBallButton.Visible = false end
        if aimButton then aimButton.Visible = false end
        if leadFeetButton then leadFeetButton.Visible = false end
        if desyncConnection then desyncConnection:Disconnect() desyncConnection = nil end
        if autoReceiveConnection then autoReceiveConnection:Disconnect() autoReceiveConnection = nil end
        if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
        if leadFeetConnection then leadFeetConnection:Disconnect() leadFeetConnection = nil end
        disableMaxServe()
        notify("Panic Mode", "All features disabled", 3)
    end
})

SafetySection:Button({
    Title = "Unload UI",
    Color = Color3.fromHex("#EF4F1D"),
    Callback = function()
        stableCleanup()
        pcall(function() Window:Destroy() end)
    end
})

local MenuConfigSection = Tabs.Settings:Section({ Title = "Menu Configuration", Box = true, Opened = true })

MenuConfigSection:Slider({
    Title = "UI Scale",
    Desc = "Adjust overall interface scaling percentage",
    Step = 5,
    Value = {
        Min = 50,
        Max = 125,
        Default = 100,
    },
    Callback = function(v)
        pcall(function()
            Window:SetUIScale(v / 100)
        end)
    end
})

MenuConfigSection:Button({
    Title = "Toggle Menu Visibility",
    Callback = function()
        pcall(function()
            Window:Toggle()
        end)
    end
})

-- =============================================================================
-- STARTUP LICENSE VERIFICATION (AUTO-FILL OR GATE)
-- =============================================================================
task.spawn(function()
    -- Strict gate: feature tabs remain locked and hidden until verified
    lockFeatureTabs()

    local savedKey = safeReadFile(AUTH_CONFIG.KeyFile)
    local genv = (type(getgenv) == "function" and getgenv()) or _G
    if not savedKey and genv and genv.RZO_KEY then
        savedKey = genv.RZO_KEY
    end

    if savedKey and savedKey:gsub("%s+", "") ~= "" then
        local cleanSaved = savedKey:gsub("%s+", "")
        inputKeyBoxValue = cleanSaved
        task.wait(0.2)
        if Options.LicenseKeyInput then
            Options.LicenseKeyInput:SetValue(cleanSaved)
        end
        notify("RZO HUB", "Saved license detected in input. Click 'Submit Key' to activate.", 4)
    else
        notify("License Checkpoint", "Please enter or paste your 24h key and click 'Submit Key'.", 4)
    end
end)
