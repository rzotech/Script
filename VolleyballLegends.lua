-- =============================================================================
-- RZO HUB - Volleyball Legends
-- UI Framework: Obsidian UI Library (github.com/deividcomsono/Obsidian)
-- Key Authentication: rzo-key-auth API integration
-- =============================================================================

local AUTH_CONFIG = {
    Domain = getgenv().RZO_AUTH_DOMAIN or "https://rzohub.vercel.app",
    Discord = "https://discord.gg/vNExQNRK3",
    KeyFile = "rzo_key.txt"
}

local isKeyAuthenticated = false
local currentLicenseData = nil

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
            local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
            hwid = RbxAnalyticsService:GetClientId()
        end)
    end
    if not hwid or #tostring(hwid) < 5 then
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        hwid = "FALLBACK_" .. (lp and lp.UserId or "0")
    end
    return tostring(hwid)
end

local function copyToClipboard(str)
    pcall(function()
        if setclipboard then
            setclipboard(str)
        elseif toclipboard then
            toclipboard(str)
        elseif syn and syn.write_clipboard then
            syn.write_clipboard(str)
        end
    end)
end

local function makeHttpRequest(url, method, body)
    local fn = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    local HttpService = game:GetService("HttpService")
    if fn then
        local ok, res = pcall(function()
            return fn({
                Url = url,
                Method = method or "GET",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "RZO-HUB-VBL-Client/2.0"
                },
                Body = body and HttpService:JSONEncode(body) or nil
            })
        end)
        if ok and res and res.Body then
            return res.Body
        end
    end

    if method == "GET" or not method then
        local ok, res = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and res then
            return res
        end
    end

    return nil
end

local function verifyLicenseKey(key)
    if not key or key:gsub("%s+", "") == "" then
        return false, "MISSING_KEY", "Please enter a valid license key."
    end

    local cleanKey = key:gsub("%s+", "")
    local hwid = getHwid()
    local HttpService = game:GetService("HttpService")
    local url = string.format(
        "%s/api/verify.php?key=%s&hwid=%s",
        AUTH_CONFIG.Domain,
        cleanKey,
        hwid
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

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua", true))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua", true))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua", true))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "RZO HUB",
    Footer = "Volleyball Legends",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local function notify(title, content, duration)
    Library:Notify({
        Title = title or "RZO HUB",
        Description = content or "",
        Time = duration or 3
    })
end

Window.Notify = function(self, data)
    if type(data) == "table" then
        notify(data.Title, data.Content or data.Description, data.Duration or data.Time)
    else
        notify("RZO HUB", tostring(data), 3)
    end
end

local DraggableWatermark = Library:AddDraggableLabel("RZO HUB | Volleyball Legends")
task.spawn(function()
    local frameCount = 0
    local lastTime = tick()
    local fps = 60
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTime >= 1 then
            fps = frameCount
            frameCount = 0
            lastTime = now
            local timeStr = os.date("%H:%M:%S")
            local pName = lp and lp.Name or "Player"
            DraggableWatermark:SetText("RZO HUB | " .. pName .. " | " .. timeStr .. " | " .. tostring(fps) .. " FPS")
        end
    end)
end)

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
local silentSpikeEnabled = false
local redirectSpikeEnabled = false
local sanjuTiltEnabled = false
local maxChargeEnabled = false
local newSilentSpikeEnabled = false
local newSpikeButton = nil
local airMovement = false
local airMovementSpeed = 16
local bodyVelocity = nil
local desyncEnabled = false
local desyncConnection = nil
local autoReceiveEnabled = false
local autoReceiveConnection = nil
local akariDashEnabled = false
local dashButton = nil
local espEnabled = false
local espPlayers = {}
local espJumpEnabled = false
local espHighlights = {}
local espConnections = {}
local autoLucky = false
local autoYen = false
local autoAbility = false
local autoNormal = false
local autoSpin = false
local autoSpinDelay = 0.1
local autoAbilitySpin = false
local desiredStyles = {}
local desiredAbilities = {}
local spinType = "Normal"
local abilitySpinType = "Normal"
local spikeButton = nil
local stopBallButton = nil
local aimButton = nil
local stopBallVisible = false
local aimVisible = false
local hitEffectEnabled = false
local selectedEffect = "SupernovaScoreEffect"
local hasFired = false
local isLocalHit = false
local hitConnection = nil
local hitConnection2 = nil
local hitRemovedConnection = nil
local effectList = {}
local playerCardEnabled = false
local selectedCard = "BrainrotBallerPlayerCard"
local hasFiredCard = false
local cardConnection = nil
local cardConnection2 = nil
local cardList = {}
local luckySpinConnection = nil
local yenConnection = nil
local abilityConnection = nil
local normalConnection = nil
local notifConn = nil
local notifConn2 = nil
local leadFeetEnabled = false
local leadFeetConnection = nil
local maxServeEnabled = false
local maxServeHookActive = false
local oldNamecallMaxServe = nil
local mtMaxServe = nil
local infiniteLuckyEnabled = false
local infiniteLuckyConnection = nil
local autoShiftLock = false
local leadFeetButton = nil

local BallService = getKnitService("BallService")
local GameService = getKnitService("GameService")
local Serve = GameService and GameService:FindFirstChild("RF") and GameService.RF:FindFirstChild("Serve") or nil

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local ScoreEffect = Assets and Assets:FindFirstChild("ScoreEffect")
if ScoreEffect then
    for _, child in ipairs(ScoreEffect:GetChildren()) do
        if child:IsA("ModuleScript") then
            table.insert(effectList, child.Name)
        end
    end
end

local Content = ReplicatedStorage:FindFirstChild("Content")
local ItemContent = Content and Content:FindFirstChild("Item")
local ItemEntities = ItemContent and ItemContent:FindFirstChild("Entities")
if ItemEntities then
    for _, child in ipairs(ItemEntities:GetChildren()) do
        if child:IsA("ModuleScript") then
            local cardName = child.Name
            if string.match(cardName, "PlayerCard") or string.match(cardName, "Card") then
                table.insert(cardList, cardName)
            end
        end
    end
end

local function updateNametag()
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local nameTag = player.Character:FindFirstChild("Nametag")
        if nameTag then
            local label = nameTag:FindFirstChild("PlayerName")
            if label and label:IsA("TextLabel") then
                label.Text = "RZO Protect"
            end
        end
    end
end

local function updateTitle()
    local player = game.Players.LocalPlayer
    if player then
        player:SetAttribute("User_Title", "<font color='#FF0000'><b>Pro</b></font>")
    end
end

local function processNotification(notification)
    if not notification then return end
    local player = game.Players.LocalPlayer
    if not player then return end
    task.wait(0.2)
    local textLabel = notification:FindFirstChild("TextLabel")
    if not textLabel then
        for _, child in ipairs(notification:GetDescendants()) do
            if child:IsA("TextLabel") then
                textLabel = child
                break
            end
        end
    end
    if not textLabel then return end
    local text = textLabel.Text or ""
    if string.find(text, player.Name) then
        textLabel.Text = string.gsub(text, player.Name, "RZO Protected")
    end
end

local function setupNotifications()
    if notifConn then notifConn:Disconnect() notifConn = nil end
    if notifConn2 then notifConn2:Disconnect() notifConn2 = nil end
    local player = game.Players.LocalPlayer
    if not player then return end
    local gui = player.PlayerGui:FindFirstChild("Interface")
    if gui then
        gui = gui:FindFirstChild("Persistent")
        if gui then
            gui = gui:FindFirstChild("Notifications")
        end
    end
    if not gui then return end
    for _, child in ipairs(gui:GetChildren()) do
        processNotification(child)
    end
    notifConn = gui.ChildAdded:Connect(function(child)
        task.wait(0.2)
        processNotification(child)
    end)
    notifConn2 = gui.DescendantAdded:Connect(function(child)
        if child:IsA("TextLabel") then
            task.wait(0.1)
            local player = game.Players.LocalPlayer
            if not player then return end
            local text = child.Text or ""
            if string.find(text, player.Name) then
                child.Text = string.gsub(text, player.Name, "RZO Protected")
            end
        end
    end)
end

local function protectPlayerCard()
    local playerName = string.upper(LocalPlayer.Name)
    local flashFrame = LocalPlayer.PlayerGui:FindFirstChild("Interface")
    if flashFrame then
        flashFrame = flashFrame:FindFirstChild("Persistent")
        if flashFrame then
            flashFrame = flashFrame:FindFirstChild("FlashPlayerCardFrame")
        end
    end
    if not flashFrame then return end
    local username = flashFrame:FindFirstChild("Username", true)
    if username and username:IsA("TextLabel") then
        local currentText = string.upper(username.Text or "")
        if string.find(currentText, playerName) then
            username.Text = "RZO Protect"
        end
    end
end

updateNametag()
updateTitle()
setupNotifications()
protectPlayerCard()

local persistent = LocalPlayer.PlayerGui:FindFirstChild("Interface")
if persistent then
    persistent = persistent:FindFirstChild("Persistent")
    if persistent then
        persistent.ChildAdded:Connect(function(child)
            if child.Name == "FlashPlayerCardFrame" then
                task.wait(0.5)
                protectPlayerCard()
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    updateNametag()
    updateTitle()
    setupNotifications()
end)

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

local function spikeBall()
    if not silentSpikeEnabled then return end
    local ballId = getBallId()
    if not ballId then return end
    if not BallService then return end
    local cam = getCurrentCamera()
    if not cam then return end
    local lookVector = cam.CFrame.LookVector
    local Interact = BallService.RF.Interact
    if Interact then
        Interact:InvokeServer({
            ["Charge"] = 1,
            ["Move"] = "Spike",
            ["SpecialCharge"] = 0,
            ["TiltDirection"] = Vector3.new(0, 1, 0),
            ["LookVector"] = lookVector,
            ["MoveDirection"] = Vector3.new(0, 0, 0),
            ["ClientCanRunSpecial"] = false,
            ["From"] = "Client",
            ["Timestamp"] = tick(),
            ["BallId"] = ballId,
            ["CustomClient"] = {},
        })
    end
end

local function createSpikeButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SilentSpikeGUI"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    spikeButton = Instance.new("TextButton")
    spikeButton.Size = UDim2.new(0, 50, 0, 50)
    spikeButton.Position = UDim2.new(0.5, -25, 0.8, -25)
    spikeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    spikeButton.Text = "Spike"
    spikeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    spikeButton.TextScaled = true
    spikeButton.Font = Enum.Font.GothamBold
    spikeButton.Parent = screenGui
    spikeButton.BackgroundTransparency = 0.2
    spikeButton.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = spikeButton
    local dragging = false
    local dragStart = nil
    local startPos = nil
    spikeButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = spikeButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    spikeButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            spikeButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    spikeButton.MouseButton1Click:Connect(function()
        spikeBall()
    end)
    spikeButton.Visible = false
    return spikeButton
end

spikeButton = createSpikeButton()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        spikeBall()
    end
end)

local globalNamecallHooked = false
local oldGlobalNamecall = nil

local function setupUnifiedNamecallHook()
    if globalNamecallHooked then return end
    if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function" or type(getnamecallmethod) ~= "function" then
        warn("[RZO HUB] Metatable hook support is unavailable on this executor.")
        return
    end

    local mt = getrawmetatable(game)
    oldGlobalNamecall = mt.__namecall
    setreadonly(mt, false)

    local handler = function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer" then
            if BallService and BallService:FindFirstChild("RF") and self == BallService.RF:FindFirstChild("Interact") then
                local args = {...}
                local data = args[1]
                if type(data) == "table" and data.Move == "Spike" then
                    if redirectSpikeEnabled then
                        local cam = getCurrentCamera()
                        if cam then
                            local dir = cam.CFrame.LookVector
                            data.LookVector = dir
                            data.Direction = dir
                            if data.MoveDirection then
                                data.MoveDirection = dir
                            end
                        end
                    end

                    if sanjuTiltEnabled and data.TiltDirection and data.LookVector then
                        local tiltDir = data.TiltDirection
                        if math.abs(tiltDir.X) > 0.01 or math.abs(tiltDir.Z) > 0.01 then
                            local lookVec = data.LookVector
                            data.LookVector = Vector3.new(
                                lookVec.X + tiltDir.X * 0.3,
                                lookVec.Y,
                                lookVec.Z + tiltDir.Z * 0.3
                            ).Unit
                            data.TiltDirection = Vector3.new(
                                tiltDir.X * 1.35,
                                tiltDir.Y,
                                tiltDir.Z * 1.35
                            )
                        end
                    end

                    if maxChargeEnabled then
                        data.Charge = 1.0
                        data.SpecialCharge = 1.0
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

    if type(newcclosure) == "function" then
        mt.__namecall = newcclosure(handler)
    else
        mt.__namecall = handler
    end

    setreadonly(mt, true)
    globalNamecallHooked = true
end

local function enableRedirectSpike()
    setupUnifiedNamecallHook()
    redirectSpikeEnabled = true
end

local function disableRedirectSpike()
    redirectSpikeEnabled = false
end

local function enableSanjuTilt()
    setupUnifiedNamecallHook()
    sanjuTiltEnabled = true
end

local function disableSanjuTilt()
    sanjuTiltEnabled = false
end

local function enableMaxCharge()
    setupUnifiedNamecallHook()
    maxChargeEnabled = true
end

local function disableMaxCharge()
    maxChargeEnabled = false
end

local function fireNewSpike()
    if not newSilentSpikeEnabled then return end
    if not firesignal then return end
    local newRemote = getKnitService("BallService").RE.DoMove
    updateHitboxes(300.0)
    local cam = getCurrentCamera()
    if not cam then return end
    local dir = cam.CFrame.LookVector
    firesignal(newRemote.OnClientEvent, "Spike", false, false, dir)
    task.spawn(function()
        task.wait(0.3)
        removeHitboxes()
    end)
end

local function createNewSpikeButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NewSilentSpikeGUI"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    newSpikeButton = Instance.new("TextButton")
    newSpikeButton.Size = UDim2.new(0, 50, 0, 50)
    newSpikeButton.Position = UDim2.new(0.5, -25, 0.85, -25)
    newSpikeButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
    newSpikeButton.Text = "Spike"
    newSpikeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    newSpikeButton.TextScaled = true
    newSpikeButton.Font = Enum.Font.GothamBold
    newSpikeButton.Parent = screenGui
    newSpikeButton.BackgroundTransparency = 0.2
    newSpikeButton.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = newSpikeButton
    local dragging = false
    local dragStart = nil
    local startPos = nil
    newSpikeButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = newSpikeButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    newSpikeButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            newSpikeButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    newSpikeButton.MouseButton1Click:Connect(function()
        fireNewSpike()
    end)
    newSpikeButton.Visible = false
    return newSpikeButton
end

newSpikeButton = createNewSpikeButton()

local function enableDesync()
    if desyncConnection then return end
    local doMove = getKnitService("BallService").RE.DoMove
    desyncConnection = UserInputService.JumpRequest:Connect(function()
        if desyncEnabled then
            task.wait(0.03)
            if firesignal then
                firesignal(doMove.OnClientEvent, "Spike", false, false)
            end
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
    screenGui.Parent = LocalPlayer.PlayerGui
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
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
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
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
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

local function applyESP(player)
    if not player.Character or espHighlights[player] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "JumpESP"
    highlight.Adornee = player.Character
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = player.Character
    espHighlights[player] = highlight
end

local function removeESP(player)
    if espHighlights[player] then
        espHighlights[player]:Destroy()
        espHighlights[player] = nil
    end
end

local function cleanupConnections(player)
    if espConnections[player] then
        for _, connection in pairs(espConnections[player]) do
            connection:Disconnect()
        end
        espConnections[player] = nil
    end
    removeESP(player)
end

local function isEnemy(player)
    return player ~= LocalPlayer and player.Team and LocalPlayer.Team and player.Team ~= LocalPlayer.Team
end

local function setupESP(player)
    if player == LocalPlayer then return end
    local function onCharacterAdded(character)
        cleanupConnections(player)
        local humanoid = character:WaitForChild("Humanoid", 3)
        local head = character:FindFirstChild("Head")
        if not humanoid or not head then return end
        local stateConnection = humanoid.StateChanged:Connect(function(_, newState)
            if not espJumpEnabled then return end
            if isEnemy(player) then
                if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
                    applyESP(player)
                elseif newState == Enum.HumanoidStateType.Landed then
                    removeESP(player)
                end
            else
                removeESP(player)
            end
        end)
        local heartbeatConnection = RunService.Heartbeat:Connect(function()
            if not espJumpEnabled then
                removeESP(player)
                return
            end
            if not player.Character or not isEnemy(player) then
                removeESP(player)
            else
                local state = humanoid:GetState()
                if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then
                    removeESP(player)
                end
            end
        end)
        espConnections[player] = { stateConnection, heartbeatConnection }
    end
    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupESP(player)
end
Players.PlayerAdded:Connect(setupESP)

local function createESP(player)
    if player == LocalPlayer then return end
    if not espEnabled then return end
    if espPlayers[player] then return end
    local character = player.Character or player.CharacterAdded:Wait()
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    local gui = Instance.new("BillboardGui")
    gui.Name = "PlayerESP"
    gui.Adornee = head
    gui.Size = UDim2.new(0, 280, 0, 80)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.MaxDistance = 150
    gui.AlwaysOnTop = true
    gui.Parent = character
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.6
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local deviceLabel = Instance.new("TextLabel")
    deviceLabel.Size = UDim2.new(1, 0, 0, 18)
    deviceLabel.BackgroundTransparency = 1
    deviceLabel.Text = player:GetAttribute("User_InputType") or "N/A"
    deviceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    deviceLabel.TextScaled = true
    deviceLabel.Font = Enum.Font.GothamBold
    deviceLabel.Parent = frame
    local styleLabel = Instance.new("TextLabel")
    styleLabel.Size = UDim2.new(1, 0, 0, 18)
    styleLabel.BackgroundTransparency = 1
    styleLabel.Text = player:GetAttribute("Gameplay_Style") or "N/A"
    styleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    styleLabel.TextScaled = true
    styleLabel.Font = Enum.Font.GothamBold
    styleLabel.Parent = frame
    local abilityLabel = Instance.new("TextLabel")
    abilityLabel.Size = UDim2.new(1, 0, 0, 18)
    abilityLabel.BackgroundTransparency = 1
    abilityLabel.Text = player:GetAttribute("Gameplay_Ability") or "N/A"
    abilityLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    abilityLabel.TextScaled = true
    abilityLabel.Font = Enum.Font.GothamBold
    abilityLabel.Parent = frame
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Size = UDim2.new(1, 0, 0, 18)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = player:GetAttribute("User_Level") or "N/A"
    levelLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    levelLabel.TextScaled = true
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.Parent = frame
    local connection = player.AttributeChanged:Connect(function(attr)
        if attr == "User_InputType" then
            deviceLabel.Text = player:GetAttribute("User_InputType") or "N/A"
        elseif attr == "Gameplay_Style" then
            styleLabel.Text = player:GetAttribute("Gameplay_Style") or "N/A"
        elseif attr == "Gameplay_Ability" then
            abilityLabel.Text = player:GetAttribute("Gameplay_Ability") or "N/A"
        elseif attr == "User_Level" then
            levelLabel.Text = player:GetAttribute("User_Level") or "N/A"
        end
    end)
    espPlayers[player] = {
        GUI = gui,
        Connection = connection
    }
end

local function removeESP2(player)
    if espPlayers[player] then
        if espPlayers[player].GUI then
            espPlayers[player].GUI:Destroy()
        end
        if espPlayers[player].Connection then
            espPlayers[player].Connection:Disconnect()
        end
        espPlayers[player] = nil
    end
end

local function startAutoSpin()
    coroutine.wrap(function()
        while autoSpin do
            local currentStyle = getGuiText("Interface.Lobby.Styles.TopPanel.DisplayName") or ""
            for _, style in ipairs(desiredStyles) do
                if currentStyle == style then
                    autoSpin = false
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
                    end
                end
            end
            task.wait(0)
        end
    end)()
end

local function startAutoAbilitySpin()
    coroutine.wrap(function()
        while autoAbilitySpin do
            local currentAbility = getGuiText("Interface.Lobby.Abilities.TopPanel.DisplayName") or ""
            for _, ability in ipairs(desiredAbilities) do
                if currentAbility == ability then
                    autoAbilitySpin = false
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
                    end
                end
            end
            task.wait(0)
        end
    end)()
end

local function startInfiniteLucky()
    coroutine.wrap(function()
        while infiniteLuckyEnabled do
            local SeasonService = getKnitService("SeasonService")
            if SeasonService then
                local RF = SeasonService:FindFirstChild("RF")
                if RF then
                    local RequestRankedReward = RF:FindFirstChild("RequestRankedReward")
                    if RequestRankedReward then
                        safeInvoke(RequestRankedReward, 1)
                    end
                end
            end
            task.wait(autoSpinDelay)
        end
    end)()
end

local function enableHitEffect()
    if hitConnection then return end
    hasFired = false
    isLocalHit = false
    local Remote = getKnitService("BallService").RE.HitGround
    Remote.OnClientEvent:Connect(function(...)
        local args = {...}
        local myName = LocalPlayer.Name
        for _, val in pairs(args) do
            if tostring(val) == myName then
                isLocalHit = true
                break
            end
        end
    end)
    local function fireHitRemote(hitPos)
        if hasFired then return end
        if not isLocalHit then return end
        if not hitEffectEnabled then return end
        hasFired = true
        local myUsername = LocalPlayer.Name
        local targetObject = workspace:FindFirstChild(myUsername) or workspace:FindFirstChild("uwuwuwiiwuw6")
        if firesignal then
            firesignal(Remote.OnClientEvent, table.unpack({
                hitPos,
                true,
                false,
                5,
                selectedEffect,
                targetObject,
                Vector3.new(-0.000002088591600113432, 1, -0.000004710930170404026)
            }))
        end
        task.wait(0.5)
        hasFired = false
        isLocalHit = false
    end
    hitConnection = workspace.ChildAdded:Connect(function(child)
        if child.Name == "HitIndicator" then
            if child.Color == Color3.fromRGB(0, 255, 0) then
                fireHitRemote(child.Position)
            end
        end
    end)
    hitConnection2 = workspace.DescendantAdded:Connect(function(child)
        if child.Name == "HitIndicator" and child:IsA("BasePart") then
            if child.Color == Color3.fromRGB(0, 255, 0) then
                fireHitRemote(child.Position)
            end
        end
    end)
    hitRemovedConnection = workspace.DescendantRemoving:Connect(function(child)
        if child.Name == "HitIndicator" then
            hasFired = false
            isLocalHit = false
        end
    end)
end

local function disableHitEffect()
    if hitConnection then
        hitConnection:Disconnect()
        hitConnection = nil
    end
    if hitConnection2 then
        hitConnection2:Disconnect()
        hitConnection2 = nil
    end
    if hitRemovedConnection then
        hitRemovedConnection:Disconnect()
        hitRemovedConnection = nil
    end
    hasFired = false
    isLocalHit = false
end

local function fireCardRemote()
    if hasFiredCard then return end
    if not playerCardEnabled then return end
    local Remote = getKnitService("PlayerCardService").RE.OnFlashCard
    if not Remote then return end
    hasFiredCard = true
    if firesignal then
        firesignal(Remote.OnClientEvent, {
            ["PlayerCardItemId"] = selectedCard,
            ["Context"] = {
                ["Custom"] = {
                },
                ["PlacementId"] = "ScoredPoint",
            },
            ["Player"] = LocalPlayer,
        })
    end
end

local function resetCard()
    hasFiredCard = false
end

local function handleCardFrame(frame)
    if not frame then return end
    if hasFiredCard then return end
    if not playerCardEnabled then return end
    local playerName = string.upper(LocalPlayer.Name)
    local username = frame:FindFirstChild("Username", true)
    if username and username:IsA("TextLabel") then
        local currentText = string.upper(username.Text or "")
        if string.find(currentText, playerName) then
            frame:Destroy()
            task.wait(0.1)
            fireCardRemote()
            protectPlayerCard()
        end
    end
end

local function enablePlayerCard()
    if cardConnection then return end
    hasFiredCard = false
    local persistent = LocalPlayer.PlayerGui:FindFirstChild("Interface")
    if persistent then
        persistent = persistent:FindFirstChild("Persistent")
        if persistent then
            cardConnection = persistent.ChildAdded:Connect(function(child)
                if child.Name == "FlashPlayerCardFrame" then
                    task.wait(0.3)
                    protectPlayerCard()
                    handleCardFrame(child)
                end
            end)
            cardConnection2 = persistent.DescendantAdded:Connect(function(child)
                if child.Name == "Username" and child:IsA("TextLabel") then
                    task.wait(0.2)
                    local frame = child.Parent
                    while frame and frame.Name ~= "FlashPlayerCardFrame" do
                        frame = frame.Parent
                    end
                    if frame then
                        protectPlayerCard()
                        handleCardFrame(frame)
                    end
                end
            end)
        end
    end
    protectPlayerCard()
end

local function disablePlayerCard()
    if cardConnection then
        cardConnection:Disconnect()
        cardConnection = nil
    end
    if cardConnection2 then
        cardConnection2:Disconnect()
        cardConnection2 = nil
    end
    hasFiredCard = false
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
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
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

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if humanoid.Jump then
            if autoShiftLock then
                task.defer(function()
                    task.wait(0.03)
                    local lookVector = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
                    if lookVector.Magnitude > 0 then
                        rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookVector.Unit)
                        humanoid.AutoRotate = false
                    end
                end)
            else
                humanoid.AutoRotate = true
            end
        end
    end)
end

if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

local function stableCleanup()
    pcall(disableRedirectSpike)
    pcall(disableSanjuTilt)
    pcall(disableMaxCharge)
    pcall(disableMaxServe)
    pcall(disableDesync)
    pcall(disableAutoReceive)
    pcall(disableHitEffect)
    pcall(disablePlayerCard)
    if bodyVelocity then
        pcall(function() bodyVelocity:Destroy() end)
        bodyVelocity = nil
    end
    if infiniteLuckyConnection then pcall(task.cancel, infiniteLuckyConnection) infiniteLuckyConnection = nil end
    if luckySpinConnection then pcall(task.cancel, luckySpinConnection) luckySpinConnection = nil end
    if yenConnection then pcall(task.cancel, yenConnection) yenConnection = nil end
    if abilityConnection then pcall(task.cancel, abilityConnection) abilityConnection = nil end
    if normalConnection then pcall(task.cancel, normalConnection) normalConnection = nil end
    removeHitboxes()
    for player in pairs(espHighlights) do pcall(removeESP, player) end
    for player in pairs(espPlayers) do pcall(removeESP2, player) end
end

-- =============================================================================
-- OBSIDIAN TABS DECLARATION & KEY AUTH GATE
-- =============================================================================
local Tabs = {
    Key = Window:AddTab("Key System", "key"),
    Main = Window:AddTab("Main", "swords"),
    Character = Window:AddTab("Character", "user"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "sparkles"),
    GameJoin = Window:AddTab("Game Join", "gamepad-2"),
    ["UI Settings"] = Window:AddTab("UI Settings", "wrench"),
}

local function lockFeatureTabs()
    Tabs.Main:SetVisible(false)
    Tabs.Character:SetVisible(false)
    Tabs.Visuals:SetVisible(false)
    Tabs.Misc:SetVisible(false)
    Tabs.GameJoin:SetVisible(false)
    Tabs["UI Settings"]:SetVisible(false)
    Tabs.Key:SetVisible(true)
    Tabs.Key:Show()
end

local function unlockFeatureTabs(licenseData)
    isKeyAuthenticated = true
    currentLicenseData = licenseData
    Tabs.Main:SetVisible(true)
    Tabs.Character:SetVisible(true)
    Tabs.Visuals:SetVisible(true)
    Tabs.Misc:SetVisible(true)
    Tabs.GameJoin:SetVisible(true)
    Tabs["UI Settings"]:SetVisible(true)
    Tabs.Key:SetVisible(false)
    Tabs.Main:Show()
end

-- -----------------------------------------------------------------------------
-- TAB 0: KEY SYSTEM (rzo-key-auth)
-- -----------------------------------------------------------------------------
local KeyAuthGroup = Tabs.Key:AddLeftGroupbox("VBL License Checkpoint")
local KeyInfoGroup = Tabs.Key:AddRightGroupbox("How to Get Key")

local inputKeyBoxValue = ""

KeyAuthGroup:AddInput("LicenseKeyInput", {
    Text = "License Key",
    Default = "",
    Placeholder = "VBL-XXXX-XXXX-XXXX-XXXX",
    Callback = function(v)
        inputKeyBoxValue = v
    end
})

KeyAuthGroup:AddButton({
    Text = "Verify Key",
    Func = function()
        local keyToTest = inputKeyBoxValue
        if not keyToTest or keyToTest:gsub("%s+", "") == "" then
            notify("Key System", "Please type or paste your key into the box above.", 3)
            return
        end

        notify("Key System", "Contacting authentication server...", 2)
        local valid, code, result = verifyLicenseKey(keyToTest)
        if valid then
            pcall(function()
                if writefile then
                    writefile(AUTH_CONFIG.KeyFile, keyToTest:gsub("%s+", ""))
                end
            end)
            notify("Access Granted", "Key verified! Welcome, " .. tostring(result.user) .. "!\nExpires: " .. tostring(result.expires_at), 4)
            unlockFeatureTabs(result)
        else
            notify("Verification Failed", tostring(result or code), 4)
        end
    end
})

KeyAuthGroup:AddButton({
    Text = "Paste From Clipboard",
    Func = function()
        local clip = nil
        pcall(function()
            if getclipboard then
                clip = getclipboard()
            end
        end)
        if clip and #clip > 3 then
            inputKeyBoxValue = clip
            if Options.LicenseKeyInput then
                Options.LicenseKeyInput:SetValue(clip)
            end
            notify("Clipboard", "Key pasted! Click 'Verify Key' to activate.", 2)
        else
            notify("Clipboard", "Clipboard is empty or unsupported on your executor.", 2)
        end
    end
})

KeyAuthGroup:AddButton({
    Text = "Check Saved Key",
    Func = function()
        local saved = nil
        pcall(function()
            if isfile and isfile(AUTH_CONFIG.KeyFile) then
                saved = readfile(AUTH_CONFIG.KeyFile)
            end
        end)
        if saved and saved:gsub("%s+", "") ~= "" then
            notify("Key System", "Validating saved key...", 2)
            local valid, code, result = verifyLicenseKey(saved)
            if valid then
                notify("Access Granted", "Saved key verified! Welcome, " .. tostring(result.user), 4)
                unlockFeatureTabs(result)
            else
                notify("Key Expired", tostring(result or code), 4)
            end
        else
            notify("Key System", "No saved key found on device.", 2)
        end
    end
})

-- Right side: Get Key via LootLabs and community links
KeyInfoGroup:AddButton({
    Text = "Get 24h Key (Copy Link)",
    Func = function()
        local url = AUTH_CONFIG.Domain .. "/get_key.php"
        copyToClipboard(url)
        notify("Link Copied!", "Open browser, complete LootLabs, and claim your key.", 4)
    end
})

KeyInfoGroup:AddButton({
    Text = "Web Dashboard (Copy Link)",
    Func = function()
        local url = AUTH_CONFIG.Domain .. "/dashboard.php"
        copyToClipboard(url)
        notify("Dashboard Copied!", "Manage HWID resets or view your active key.", 3)
    end
})

KeyInfoGroup:AddButton({
    Text = "Join Discord Community",
    Func = function()
        copyToClipboard(AUTH_CONFIG.Discord)
        notify("Discord Copied!", "Invite copied to clipboard: " .. AUTH_CONFIG.Discord, 3)
    end
})

KeyInfoGroup:AddLabel("1. Click 'Get 24h Key (Copy Link)'.")
KeyInfoGroup:AddLabel("2. Open browser, login / register.")
KeyInfoGroup:AddLabel("3. Complete LootLabs tasks.")
KeyInfoGroup:AddLabel("4. Copy key from Dashboard & paste here.")

-- -----------------------------------------------------------------------------
-- TAB 1: MAIN
-- -----------------------------------------------------------------------------
local SpikeGroup = Tabs.Main:AddLeftGroupbox("Spike Settings")

SpikeGroup:AddToggle("SilentSpike", {
    Text = "Silent Spike",
    Default = false,
    Tooltip = "Show quick Spike button",
    Callback = function(v)
        silentSpikeEnabled = v
        if spikeButton then
            spikeButton.Visible = v
        end
    end
})

SpikeGroup:AddToggle("RedirectSpike", {
    Text = "Redirect Spike",
    Default = false,
    Tooltip = "Redirect spike trajectory to camera direction",
    Callback = function(v)
        if v then
            enableRedirectSpike()
        else
            disableRedirectSpike()
        end
    end
})

SpikeGroup:AddToggle("NewSilentSpike", {
    Text = "New Silent Spike",
    Default = false,
    Tooltip = "Display new spike overlay button",
    Callback = function(v)
        newSilentSpikeEnabled = v
        if newSpikeButton then
            newSpikeButton.Visible = v
        end
    end
})

SpikeGroup:AddToggle("SanjuTilt", {
    Text = "Sanju Tilt",
    Default = false,
    Tooltip = "Angle-boosted spike tilt physics",
    Callback = function(v)
        if v then
            enableSanjuTilt()
        else
            disableSanjuTilt()
        end
    end
})

SpikeGroup:AddToggle("MaxCharge", {
    Text = "Max Charge Special",
    Default = false,
    Tooltip = "Forces maximum special charge on every spike",
    Callback = function(v)
        if v then
            enableMaxCharge()
        else
            disableMaxCharge()
        end
    end
})

local ServeGroup = Tabs.Main:AddLeftGroupbox("Max Serve & Data")

ServeGroup:AddToggle("MaxServe", {
    Text = "Max Serve",
    Default = false,
    Tooltip = "Forces maximum serve power level 5",
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

ServeGroup:AddToggle("LeadFeet", {
    Text = "Lead Feet",
    Default = false,
    Tooltip = "Snap instantly to floor when pressing R",
    Callback = function(v)
        leadFeetEnabled = v
        if leadFeetButton then
            leadFeetButton.Visible = v
        end
        notify("Lead Feet", v and "ENABLED" or "DISABLED", 2)
    end
})

ServeGroup:AddButton({
    Text = "Data Rollback",
    Func = function()
        local remote = getKnitService("SettingsService")
        local rf = remote and remote:FindFirstChild("RF") and remote.RF:FindFirstChild("UpdateKeybind")
        if rf then
            rf:InvokeServer("MouseButton1", true, "Spike\xE2\x80\x8B\x8F")
        end
        notify("Data Rollback", "Executed! Rejoining...", 2)
        TeleportService:Teleport(game.PlaceId)
    end
})

local HitboxGroup = Tabs.Main:AddRightGroupbox("Hitbox Settings")

HitboxGroup:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 5,
    Min = 0,
    Max = 20,
    Rounding = 1,
    Callback = function(v)
        hitboxScale = v
        updateHitboxes(v)
    end
})

HitboxGroup:AddDropdown("HitboxColor", {
    Values = {"Green", "Blue", "Red", "Yellow", "Purple", "Orange", "Pink", "White"},
    Default = 1,
    Multi = false,
    Text = "Hitbox Color",
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

HitboxGroup:AddButton({
    Text = "Remove Hitboxes",
    Func = function()
        removeHitboxes()
        notify("Hitboxes Removed", "All hitboxes cleared", 2)
    end
})

HitboxGroup:AddButton({
    Text = "Show Stop Ball",
    Func = function()
        stopBallVisible = not stopBallVisible
        if stopBallButton then
            stopBallButton.Visible = stopBallVisible
        else
            stopBallButton = createStopBallButton()
        end
        notify("Stop Ball", stopBallVisible and "SHOWN" or "HIDDEN", 2)
    end
})

HitboxGroup:AddButton({
    Text = "Show Aim",
    Func = function()
        aimVisible = not aimVisible
        if aimButton then
            aimButton.Visible = aimVisible
        else
            aimButton = createAimButton()
        end
        notify("Aim", aimVisible and "SHOWN" or "HIDDEN", 2)
    end
})

local MovePerfGroup = Tabs.Main:AddRightGroupbox("Movement & Performance")

MovePerfGroup:AddToggle("AntiLag", {
    Text = "Anti-Lag",
    Default = false,
    Tooltip = "Optimizes shadows and lighting for max FPS",
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

MovePerfGroup:AddToggle("Desync", {
    Text = "Desync",
    Default = false,
    Tooltip = "Desynchronizes character jump state via spoofed Dive event",
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

MovePerfGroup:AddToggle("AutoReceive", {
    Text = "Auto Receive",
    Default = false,
    Tooltip = "Automatically dives when ball is within 10 studs",
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

MovePerfGroup:AddToggle("AkariDash", {
    Text = "Akari Dash",
    Default = false,
    Tooltip = "On-screen button for Akari dash action",
    Callback = function(v)
        akariDashEnabled = v
        if dashButton then
            dashButton.Visible = v
        end
        notify("Akari Dash", v and "ENABLED" or "DISABLED", 2)
    end
})

local CosmeticGroup = Tabs.Main:AddRightGroupbox("Visual & Cosmetics")

CosmeticGroup:AddToggle("ScoreEffect", {
    Text = "ScoreEffect Changer",
    Default = false,
    Tooltip = "Overrides your score explosion effect",
    Callback = function(v)
        hitEffectEnabled = v
        if v then
            enableHitEffect()
            notify("ScoreEffect Changer", "ENABLED", 2)
        else
            disableHitEffect()
            notify("ScoreEffect Changer", "DISABLED", 2)
        end
    end
})

CosmeticGroup:AddDropdown("EffectSelect", {
    Values = #effectList > 0 and effectList or {"No Effects Found"},
    Default = 1,
    Multi = false,
    Text = "Effect Select",
    Callback = function(v)
        selectedEffect = v
        notify("Effect Changed", "Set to " .. tostring(v), 2)
    end
})

CosmeticGroup:AddToggle("PlayerCard", {
    Text = "PlayerCard Changer",
    Default = false,
    Tooltip = "Overrides your displayed player banner card",
    Callback = function(v)
        playerCardEnabled = v
        if v then
            enablePlayerCard()
            notify("PlayerCard Changer", "ENABLED", 2)
        else
            disablePlayerCard()
            notify("PlayerCard Changer", "DISABLED", 2)
        end
    end
})

CosmeticGroup:AddDropdown("CardSelect", {
    Values = #cardList > 0 and cardList or {"No Cards Found"},
    Default = 1,
    Multi = false,
    Text = "Card Select",
    Callback = function(v)
        selectedCard = v
        notify("Card Changed", "Set to " .. tostring(v), 2)
    end
})

CosmeticGroup:AddButton({
    Text = "Unlock All Ball",
    Func = function()
        if type(require) ~= "function" or type(hookfunction) ~= "function" or type(getgc) ~= "function" then
            notify("Unlock All Ball", "Executor hook support is unavailable.", 3)
            return
        end
        local RS = game:GetService("ReplicatedStorage")
        local Item = require(RS.Content.Item)
        local Knit = require(RS.Packages.Knit)
        local InventoryController = Knit.GetController("InventoryController")
        local InventoryService = Knit.GetService("InventoryService")
        local InventoryValue = InventoryController.Inventory
        local inv = InventoryValue:get()
        local isEquipped = require(game.ReplicatedFirst.Controllers.InventoryController.IsEquipped)
        local toggled = {}
        local Items = {}
        local allBalls = Item:GetAllFromType(Item.Type.Ball)
        for _, ball in pairs(allBalls) do
            Items[ball.Id] = true
            inv[ball.Id] = 1
        end
        InventoryValue:set(inv)
        local old3
        old3 = hookfunction(isEquipped, function(item, equippedTable, selected)
            if Items[selected] and toggled[selected] ~= nil then
                return toggled[selected]
            end
            return old3(item, equippedTable, selected)
        end)
        local old2
        old2 = hookfunction(InventoryService.Equip, function(self, id)
            local result = old2(self, id)
            if Items[id] then
                for k, _ in pairs(toggled) do
                    toggled[k] = nil
                end
                toggled[id] = true
                local eq = InventoryController.Equipped:get()
                InventoryController.Equipped:set(eq)
            end
            return result
        end)
        local fakeEntries = {}
        for _, ball in pairs(allBalls) do
            table.insert(fakeEntries, {Name = ball.Id, Item = ball, Count = 1, IsRandom = false})
        end
        for _, func in getgc() do
            if typeof(func) == "function" then
                local env = getfenv(func)
                local scr = env and tostring(env.script) or ""
                if scr == "buildEntries" then
                    local old
                    old = hookfunction(func, function(p1, p2)
                        if p1 and p1.ItemType == Item.Type.Ball then
                            return fakeEntries
                        end
                        return old(p1, p2)
                    end)
                end
                if scr == "BallController" then
                    local old4
                    old4 = hookfunction(func, function(p1)
                        if p1 and not workspace:FindFirstChild("CLIENT_BALL_" .. tostring(p1.ID)) and p1.Skin then
                            for name, isToggled in pairs(toggled) do
                                if isToggled then
                                    p1.Skin = name
                                    break
                                end
                            end
                        end
                        return old4(p1)
                    end)
                end
            end
        end
        notify("Unlock All Ball", "All balls unlocked!", 2)
    end
})

CosmeticGroup:AddToggle("ESP", {
    Text = "ESP",
    Default = false,
    Tooltip = "Box and Tracer ESP on other players",
    Callback = function(v)
        espEnabled = v
        if v then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(createESP, player)
                end
            end
            Players.PlayerAdded:Connect(function(player)
                task.spawn(createESP, player)
            end)
        else
            for player in pairs(espPlayers) do
                removeESP2(player)
            end
        end
    end
})

-- -----------------------------------------------------------------------------
-- TAB 2: CHARACTER
-- -----------------------------------------------------------------------------
local AttrGroup = Tabs.Character:AddLeftGroupbox("Attributes")

AttrGroup:AddInput("DiveSpeed", {
    Text = "Dive Speed",
    Default = "0.95",
    Numeric = true,
    Placeholder = "0.95",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_DiveSpeed", num)
        end
    end
})

AttrGroup:AddInput("JumpPower", {
    Text = "Jump Power",
    Default = "1.1",
    Numeric = true,
    Placeholder = "1.1",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_JumpPower", num)
        end
    end
})

AttrGroup:AddInput("Speed", {
    Text = "Speed",
    Default = "0.85",
    Numeric = true,
    Placeholder = "0.85",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_Speed", num)
        end
    end
})

local CharMoveGroup = Tabs.Character:AddRightGroupbox("Movement")

CharMoveGroup:AddToggle("AirMovement", {
    Text = "Air Movement",
    Default = false,
    Tooltip = "Fly / directional velocity while airborne",
    Callback = function(v)
        airMovement = v
        if not v and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end
})

CharMoveGroup:AddSlider("AirSpeed", {
    Text = "Air Movement Speed",
    Default = 16,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Callback = function(v)
        airMovementSpeed = v
    end
})

CharMoveGroup:AddToggle("AutoShiftLock", {
    Text = "Auto Shift Lock",
    Default = false,
    Tooltip = "Forces camera orientation lock on jump",
    Callback = function(v)
        autoShiftLock = v
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.AutoRotate = not v
            end
        end
        notify("Auto Shift Lock", v and "ENABLED" or "DISABLED", 2)
    end
})

-- -----------------------------------------------------------------------------
-- TAB 3: VISUALS
-- -----------------------------------------------------------------------------
local VisualESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP")

VisualESPGroup:AddToggle("ESPJump", {
    Text = "ESP (Jump)",
    Default = false,
    Tooltip = "Highlights players when they jump",
    Callback = function(v)
        espJumpEnabled = v
        if not v then
            for player in pairs(espHighlights) do
                removeESP(player)
            end
        end
    end
})

local CameraGroup = Tabs.Visuals:AddRightGroupbox("Camera & World")

CameraGroup:AddSlider("POV", {
    Text = "Field of View",
    Default = 70,
    Min = 1,
    Max = 120,
    Rounding = 0,
    Callback = function(v)
        workspace.CurrentCamera.FieldOfView = v
    end
})

CameraGroup:AddButton({
    Text = "Rejoin Server",
    Func = function()
        TeleportService:Teleport(game.PlaceId)
    end
})

-- -----------------------------------------------------------------------------
-- TAB 4: MISC
-- -----------------------------------------------------------------------------
local FarmGroup = Tabs.Misc:AddLeftGroupbox("Infinite Lucky & Currency")

FarmGroup:AddToggle("InfiniteLuckyStyle", {
    Text = "Style Spin Farm",
    Default = false,
    Tooltip = "Continuous loop claiming season style roll",
    Callback = function(v)
        infiniteLuckyEnabled = v
        if v then
            if infiniteLuckyConnection then return end
            infiniteLuckyConnection = task.spawn(function()
                local SeasonService = getKnitService("SeasonService")
                while infiniteLuckyEnabled do
                    if SeasonService then
                        local RF = SeasonService:FindFirstChild("RF")
                        if RF then
                            local RequestRankedReward = RF:FindFirstChild("RequestRankedReward")
                            if RequestRankedReward then
                                safeInvoke(RequestRankedReward, 1)
                            end
                        end
                    end
                    task.wait(autoSpinDelay)
                end
            end)
            notify("Infinite Lucky", "ENABLED", 2)
        else
            if infiniteLuckyConnection then
                task.cancel(infiniteLuckyConnection)
                infiniteLuckyConnection = nil
            end
            notify("Infinite Lucky", "DISABLED", 2)
        end
    end
})

FarmGroup:AddToggle("AutoYen", {
    Text = "Yen Farm",
    Default = false,
    Tooltip = "Continuous loop claiming season Yen rewards",
    Callback = function(v)
        autoYen = v
        if v then
            if yenConnection then return end
            yenConnection = task.spawn(function()
                local SeasonService = getKnitService("SeasonService")
                while autoYen do
                    if SeasonService then
                        local RF = SeasonService:FindFirstChild("RF")
                        if RF then
                            local RequestRankedReward = RF:FindFirstChild("RequestRankedReward")
                            if RequestRankedReward then
                                safeInvoke(RequestRankedReward, 2)
                            end
                        end
                    end
                    task.wait(autoSpinDelay)
                end
            end)
            notify("Yen", "ENABLED", 2)
        else
            if yenConnection then
                task.cancel(yenConnection)
                yenConnection = nil
            end
            notify("Yen", "DISABLED", 2)
        end
    end
})

FarmGroup:AddToggle("AutoAbility", {
    Text = "Ability Farm",
    Default = false,
    Tooltip = "Continuous loop claiming season Ability rewards",
    Callback = function(v)
        autoAbility = v
        if v then
            if abilityConnection then return end
            abilityConnection = task.spawn(function()
                local SeasonService = getKnitService("SeasonService")
                while autoAbility do
                    if SeasonService then
                        local RF = SeasonService:FindFirstChild("RF")
                        if RF then
                            local RequestRankedReward = RF:FindFirstChild("RequestRankedReward")
                            if RequestRankedReward then
                                safeInvoke(RequestRankedReward, 4)
                            end
                        end
                    end
                    task.wait(autoSpinDelay)
                end
            end)
            notify("Ability", "ENABLED", 2)
        else
            if abilityConnection then
                task.cancel(abilityConnection)
                abilityConnection = nil
            end
            notify("Ability", "DISABLED", 2)
        end
    end
})

FarmGroup:AddToggle("AutoNormalSpin", {
    Text = "Normal Spin Farm",
    Default = false,
    Tooltip = "Continuous loop claiming season normal rolls",
    Callback = function(v)
        autoNormal = v
        if v then
            if normalConnection then return end
            normalConnection = task.spawn(function()
                local SeasonService = getKnitService("SeasonService")
                while autoNormal do
                    if SeasonService then
                        local RF = SeasonService:FindFirstChild("RF")
                        if RF then
                            local RequestRankedReward = RF:FindFirstChild("RequestRankedReward")
                            if RequestRankedReward then
                                safeInvoke(RequestRankedReward, 5)
                            end
                        end
                    end
                    task.wait(autoSpinDelay)
                end
            end)
            notify("Normal Spin", "ENABLED", 2)
        else
            if normalConnection then
                task.cancel(normalConnection)
                normalConnection = nil
            end
            notify("Normal Spin", "DISABLED", 2)
        end
    end
})

local RewardsGroup = Tabs.Misc:AddLeftGroupbox("Claim Rewards & Codes")

RewardsGroup:AddButton({
    Text = "Claim Level Rewards",
    Func = function()
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

RewardsGroup:AddButton({
    Text = "Claim Quest Rewards",
    Func = function()
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

RewardsGroup:AddButton({
    Text = "Redeem All Codes",
    Func = function()
        local function fetchNewCodes()
            local success, data = pcall(function()
                return game:HttpGet("https://beebom.com/haikyuu-legends-codes/")
            end)
            if not success or not data then
                return {}
            end
            local newCodes = {}
            local processed = {}
            for line in string.gmatch(data, "[^\n]+") do
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

local StyleSpinGroup = Tabs.Misc:AddRightGroupbox("Auto Style Spin")

StyleSpinGroup:AddToggle("AutoStyleSpin", {
    Text = "Auto Style Spin",
    Default = false,
    Tooltip = "Loops rolling style until target style is hit",
    Callback = function(v)
        autoSpin = v
        if v then
            startAutoSpin()
        end
    end
})

StyleSpinGroup:AddDropdown("StyleSpinType", {
    Values = {"Normal", "Lucky"},
    Default = 1,
    Multi = false,
    Text = "Spin Type",
    Callback = function(v)
        spinType = v
    end
})

StyleSpinGroup:AddInput("TargetStyle", {
    Text = "Target Style",
    Default = "Sanju",
    Placeholder = "Sanju",
    Callback = function(v)
        desiredStyles = {v}
        notify("Target Set", "Target style: " .. tostring(v), 2)
    end
})

StyleSpinGroup:AddButton({
    Text = "Instant Spin",
    Func = function()
        local args = { [1] = (spinType == "Lucky") }
        local StyleService = getKnitService("StyleService")
        if StyleService then
            local RF = StyleService:FindFirstChild("RF")
            if RF then
                local Roll = RF:FindFirstChild("Roll")
                if Roll then
                    safeInvoke(Roll, unpack(args))
                    notify("Instant Spin", "Style spin executed! (" .. spinType .. ")", 2)
                end
            end
        end
    end
})

local AbilitySpinGroup = Tabs.Misc:AddRightGroupbox("Auto Ability Spin")

AbilitySpinGroup:AddToggle("AutoAbilitySpin", {
    Text = "Auto Ability Spin",
    Default = false,
    Tooltip = "Loops rolling ability until target ability is hit",
    Callback = function(v)
        autoAbilitySpin = v
        if v then
            startAutoAbilitySpin()
        end
    end
})

AbilitySpinGroup:AddDropdown("AbilitySpinType", {
    Values = {"Normal", "Lucky"},
    Default = 1,
    Multi = false,
    Text = "Ability Spin Type",
    Callback = function(v)
        abilitySpinType = v
    end
})

AbilitySpinGroup:AddInput("TargetAbility", {
    Text = "Target Ability",
    Default = "Shield Breaker",
    Placeholder = "Shield Breaker",
    Callback = function(v)
        desiredAbilities = {v}
        notify("Target Set", "Target ability: " .. tostring(v), 2)
    end
})

AbilitySpinGroup:AddButton({
    Text = "Instant Spin",
    Func = function()
        local args = { [1] = (abilitySpinType == "Lucky") }
        local AbilityService = getKnitService("AbilityService")
        if AbilityService then
            local RF = AbilityService:FindFirstChild("RF")
            if RF then
                local Roll = RF:FindFirstChild("Roll")
                if Roll then
                    safeInvoke(Roll, unpack(args))
                    notify("Instant Spin", "Ability spin executed! (" .. abilitySpinType .. ")", 2)
                end
            end
        end
    end
})

local ShopGroup = Tabs.Misc:AddRightGroupbox("Shop Purchases")

ShopGroup:AddButton({
    Text = "Buy Emote",
    Func = function()
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

ShopGroup:AddButton({
    Text = "Buy Effect",
    Func = function()
        local PackService = getKnitService("PackService")
        local RF = PackService and PackService:FindFirstChild("RF")
        if RF then
            local Open = RF:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "ScoreEffect1")
                notify("Shop", "Effect purchased!", 2)
            end
        end
    end
})

ShopGroup:AddButton({
    Text = "Buy Extreme Ball",
    Func = function()
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

ShopGroup:AddButton({
    Text = "Buy Medium Ball",
    Func = function()
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

ShopGroup:AddButton({
    Text = "Buy Basic Ball",
    Func = function()
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
-- TAB 5: GAME JOIN
-- -----------------------------------------------------------------------------
local GameModesLeft = Tabs.GameJoin:AddLeftGroupbox("Game Modes")

GameModesLeft:AddButton({
    Text = "Chaos Mode",
    Func = function()
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

GameModesLeft:AddButton({
    Text = "1v1 Mini Map",
    Func = function()
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

GameModesLeft:AddButton({
    Text = "2v2 Ranked",
    Func = function()
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

GameModesLeft:AddButton({
    Text = "3v3 Ranked",
    Func = function()
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

local GameModesRight = Tabs.GameJoin:AddRightGroupbox("More Modes")

GameModesRight:AddButton({
    Text = "4v4 Ranked",
    Func = function()
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

GameModesRight:AddButton({
    Text = "6v6 Ranked",
    Func = function()
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

GameModesRight:AddButton({
    Text = "Training",
    Func = function()
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
-- TAB 6: UI SETTINGS
-- -----------------------------------------------------------------------------
local LicenseStatusGroup = Tabs["UI Settings"]:AddLeftGroupbox("License Management")

LicenseStatusGroup:AddButton({
    Text = "Copy My Key",
    Func = function()
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

LicenseStatusGroup:AddButton({
    Text = "Open Web Dashboard (Copy)",
    Func = function()
        copyToClipboard(AUTH_CONFIG.Domain .. "/dashboard.php")
        notify("Dashboard", "URL copied to clipboard!", 2)
    end
})

LicenseStatusGroup:AddButton({
    Text = "Clear Saved Key (Logout)",
    Func = function()
        pcall(function()
            if delfile and isfile and isfile(AUTH_CONFIG.KeyFile) then
                delfile(AUTH_CONFIG.KeyFile)
            end
        end)
        notify("License Cleared", "Saved key deleted! Locking hub...", 2)
        task.wait(0.5)
        lockFeatureTabs()
    end
})

local SafetyGroup = Tabs["UI Settings"]:AddLeftGroupbox("Safety & Lifecycle")

SafetyGroup:AddButton({
    Text = "Panic (Disable All)",
    Func = function()
        removeHitboxes()
        silentSpikeEnabled = false
        redirectSpikeEnabled = false
        sanjuTiltEnabled = false
        maxChargeEnabled = false
        newSilentSpikeEnabled = false
        airMovement = false
        desyncEnabled = false
        autoReceiveEnabled = false
        akariDashEnabled = false
        espEnabled = false
        espJumpEnabled = false
        autoLucky = false
        autoYen = false
        autoAbility = false
        autoNormal = false
        autoSpin = false
        autoAbilitySpin = false
        infiniteLuckyEnabled = false
        hitEffectEnabled = false
        playerCardEnabled = false
        stopBallVisible = false
        aimVisible = false
        maxServeEnabled = false
        leadFeetEnabled = false
        if luckySpinConnection then task.cancel(luckySpinConnection) luckySpinConnection = nil end
        if yenConnection then task.cancel(yenConnection) yenConnection = nil end
        if abilityConnection then task.cancel(abilityConnection) abilityConnection = nil end
        if normalConnection then task.cancel(normalConnection) normalConnection = nil end
        if infiniteLuckyConnection then task.cancel(infiniteLuckyConnection) infiniteLuckyConnection = nil end
        if spikeButton then spikeButton.Visible = false end
        if newSpikeButton then newSpikeButton.Visible = false end
        if dashButton then dashButton.Visible = false end
        if stopBallButton then stopBallButton.Visible = false end
        if aimButton then aimButton.Visible = false end
        if leadFeetButton then leadFeetButton.Visible = false end
        if desyncConnection then desyncConnection:Disconnect() desyncConnection = nil end
        if autoReceiveConnection then autoReceiveConnection:Disconnect() autoReceiveConnection = nil end
        if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
        if hitConnection then hitConnection:Disconnect() hitConnection = nil end
        if hitConnection2 then hitConnection2:Disconnect() hitConnection2 = nil end
        if hitRemovedConnection then hitRemovedConnection:Disconnect() hitRemovedConnection = nil end
        if cardConnection then cardConnection:Disconnect() cardConnection = nil end
        if cardConnection2 then cardConnection2:Disconnect() cardConnection2 = nil end
        if notifConn then notifConn:Disconnect() notifConn = nil end
        if notifConn2 then notifConn2:Disconnect() notifConn2 = nil end
        if leadFeetConnection then leadFeetConnection:Disconnect() leadFeetConnection = nil end
        disableMaxServe()
        for player in pairs(espHighlights) do removeESP(player) end
        for player in pairs(espPlayers) do removeESP2(player) end
        notify("Panic Mode", "All features disabled", 3)
    end
})

SafetyGroup:AddButton({
    Text = "Unload UI",
    Func = function()
        stableCleanup()
        pcall(function() Library:Unload() end)
    end
})

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu Configuration")
MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("RZOHub")
SaveManager:SetFolder("RZOHub/volleyball-legends")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

-- =============================================================================
-- STARTUP LICENSE VERIFICATION (AUTO-LOGIN OR GATE)
-- =============================================================================
task.spawn(function()
    local savedKey = nil
    pcall(function()
        if isfile and isfile(AUTH_CONFIG.KeyFile) then
            savedKey = readfile(AUTH_CONFIG.KeyFile)
        end
    end)
    if not savedKey and getgenv().RZO_KEY then
        savedKey = getgenv().RZO_KEY
    end

    if savedKey and savedKey:gsub("%s+", "") ~= "" then
        notify("RZO HUB", "Checking saved VBL license...", 2)
        local valid, code, result = verifyLicenseKey(savedKey)
        if valid then
            notify("RZO HUB", "Welcome back, " .. tostring(result.user) .. "!\nExpires: " .. tostring(result.expires_at), 4)
            unlockFeatureTabs(result)
            return
        else
            pcall(function()
                if delfile and isfile and isfile(AUTH_CONFIG.KeyFile) then
                    delfile(AUTH_CONFIG.KeyFile)
                end
            end)
            notify("License Expired", tostring(result or code) .. "\nPlease enter a fresh 24h key.", 4)
        end
    end

    -- Default: Lock feature tabs until key is verified
    lockFeatureTabs()
end)
