-- Wait for game to be fully loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat
        task.wait()
        LocalPlayer = Players.LocalPlayer
    until LocalPlayer
end

local Camera = Workspace.CurrentCamera
if not Camera then
    repeat
        task.wait()
        Camera = Workspace.CurrentCamera
    until Camera
end


-- ==============================================================================
-- RZO HUB - Volleyball Legends (VBL)
-- CHANGELOG:
-- ADDING VOLLEYBALLLEGENDS
-- Option A: VBL License Key Gateway System (+24h Key & HWID Validation)
-- Option C: Universal Executor Shims (Delta, Codex, Wave, Solara, Arceus, Fluxus)
-- ==============================================================================

local AUTH_API = "https://rzohub.vercel.app/api/verify.php"
local DISCORD_URL = "https://discord.gg/vNExQNRK3"
local GET_KEY_URL = "https://rzohub.vercel.app"
local KEY_FOLDER = "RzoHub"
local KEY_FILE = "RzoHub/vbl_key.txt"

-- Universal Executor Compatibility Helpers
local function safeClosure(fn)
    if newcclosure and type(newcclosure) == "function" then
        local ok, res = pcall(newcclosure, fn)
        if ok and res then return res end
    end
    return fn
end

local function getSafeGuiParent()
    -- 1. Try executor gethui() container first
    if gethui and type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h and typeof(h) == "Instance" then
            return h
        end
    end

    -- 2. PlayerGui is GUARANTEED to render on screen on all platforms & executors
    local lp = LocalPlayer or Players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
        if pg then return pg end
    end

    -- 3. Last fallback: CoreGui
    local ok, cg = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and cg then return cg end

    return nil
end

local function getClipboardSafe()
    local fn = getclipboard or (Clipboard and Clipboard.get) or (syn and syn.read_clipboard)
    if fn and type(fn) == "function" then
        local ok, res = pcall(fn)
        if ok and res and tostring(res) ~= "" then
            return tostring(res)
        end
    end
    return nil
end

local function setClipboardSafe(text)
    local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set) or (syn and syn.write_clipboard)
    if fn then
        pcall(fn, text)
        return true
    end
    return false
end

local function isFolderSafe(path)
    if isfolder and type(isfolder) == "function" then
        local ok, res = pcall(isfolder, path)
        return ok and res
    end
    return false
end

local function makeFolderSafe(path)
    if makefolder and type(makefolder) == "function" then
        pcall(makefolder, path)
    end
end

local function isFileSafe(path)
    if isfile and type(isfile) == "function" then
        local ok, res = pcall(isfile, path)
        return ok and res
    end
    return false
end

local function readFileSafe(path)
    if isfile and readfile and type(readfile) == "function" then
        local ok, res = pcall(readfile, path)
        if ok and res then return res end
    end
    return nil
end

local function writeFileSafe(path, text)
    if writefile and type(writefile) == "function" then
        pcall(writefile, path, text)
    end
end

local function getHWID()
    local hwidFn = gethwid or get_hwid or rbx_gethwid or (syn and syn.get_hwid)
    if hwidFn and type(hwidFn) == "function" then
        local ok, id = pcall(hwidFn)
        if ok and id and tostring(id) ~= "" then
            return tostring(id)
        end
    end
    local ok, clientId = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and clientId and tostring(clientId) ~= "" then
        return tostring(clientId)
    end
    local lp = game:GetService("Players").LocalPlayer
    return tostring(lp and lp.UserId or "FALLBACK_HWID")
end

local function requestHttp(url)
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    if req and type(req) == "function" then
        local ok, res = pcall(req, {
            Url = url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "RzoHub-VBL-Client/1.0"
            }
        })
        if ok and res then
            local body = res.Body or res.body
            if body and #body > 0 then
                return body
            end
        end
    end
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and res and #res > 0 then
        return res
    end
    return nil
end

local function verifyVblKey(key)
    if not key or #key < 8 then
        return false, "Please enter a valid VBL key format."
    end
    local cleanKey = string.gsub(key, "%s+", "")
    local hwid = getHWID()
    
    local HttpService = game:GetService("HttpService")
    local query = "?key=" .. HttpService:UrlEncode(cleanKey) .. "&hwid=" .. HttpService:UrlEncode(hwid)
    local body = requestHttp(AUTH_API .. query)
    
    if not body then
        return false, "Network error: Unable to reach verification server."
    end
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    
    if not ok or not data then
        return false, "Server response error: Could not parse validation response."
    end
    
    if data.valid == true or data.status == "success" then
        return true, data
    end
    
    return false, data.message or "Invalid or expired VBL license key."
end

-- ==============================================================================
-- RZO HUB - Volleyball Legends (VBL)
-- UI Framework: WindUI (https://footagesus.github.io/WindUI-Docs/docs/installation)
-- CHANGELOG: ADDING VOLLEYBALLLEGENDS (Migrated to WindUI v1.0)
-- ==============================================================================

local function loadWindUI()
    local urls = {
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
        "https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/dist/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
    }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and src and #src > 500 then
            local loadOk, fn = pcall(loadstring, src)
            if loadOk and type(fn) == "function" then
                local execOk, lib = pcall(fn)
                if execOk and lib then
                    return lib
                end
            end
        end
    end
    error("[RZO HUB] Failed to download WindUI library from all mirrors.")
end

-- Ensure legacy saved key is synced to WindUI key store
pcall(function()
    local hwid = getHWID()
    local windUiKeyDir = "RzoHub/VolleyballLegends"
    local windUiKeyFile = windUiKeyDir .. "/" .. hwid .. ".key"
    if not isFolderSafe("RzoHub") then makeFolderSafe("RzoHub") end
    if not isFolderSafe(windUiKeyDir) then makeFolderSafe(windUiKeyDir) end
    if not isFileSafe(windUiKeyFile) and isFileSafe(KEY_FILE) then
        local leg = readFileSafe(KEY_FILE)
        if leg and #leg > 5 then
            writeFileSafe(windUiKeyFile, leg)
        end
    end
end)

local WindUI = loadWindUI()

local Window = WindUI:CreateWindow({
    Title = "RZO HUB - Volleyball Legends",
    Icon = "zap",
    Author = "RZO HUB",
    Folder = "RzoHub/VolleyballLegends",
    Size = UDim2.fromOffset(600, 440),
    Transparent = true,
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightControl,
    Resizable = true,
    KeySystem = {
        Title = "RZO HUB - Key Verification",
        Note = "Selesaikan quest LootLabs di website untuk mendapatkan key 24 jam",
        URL = GET_KEY_URL,
        SaveKey = true,
        KeyValidator = function(enteredKey)
            if not enteredKey or #enteredKey < 5 then return false end
            local valid, data = verifyVblKey(enteredKey)
            if valid then
                writeFileSafe(KEY_FILE, enteredKey)
                return true
            end
            return false
        end,
    }
})

local function notify(titleOrTable, content, duration)
    if typeof(titleOrTable) == "table" then
        WindUI:Notify({
            Title = titleOrTable.Title or "Notification",
            Content = titleOrTable.Content or titleOrTable.Description or "",
            Duration = titleOrTable.Duration or titleOrTable.Time or 3,
        })
    else
        WindUI:Notify({
            Title = tostring(titleOrTable or "Notification"),
            Content = tostring(content or ""),
            Duration = tonumber(duration) or 3,
        })
    end
end
Window.Notify = function(self, info)
    notify(info)
end

-- ==============================================================================
-- RZO HUB - FLOATING TOGGLE BUTTON & REAL-TIME PERFORMANCE OVERLAY
-- ==============================================================================

local function createFloatingToggle()
    local parent = getSafeGuiParent()
    if not parent then return end

    local existing = parent:FindFirstChild("RzoHub_FloatingToggle")
    if existing then existing:Destroy() end

    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5))
    if pg and pg ~= parent then
        local old = pg:FindFirstChild("RzoHub_FloatingToggle")
        if old then old:Destroy() end
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RzoHub_FloatingToggle"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 999999
    
    local parentOk = pcall(function()
        screenGui.Parent = parent
    end)
    if not parentOk or not screenGui.Parent then
        pcall(function()
            screenGui.Parent = pg
        end)
    end

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.new(0, 56, 0, 56)
    toggleBtn.Position = UDim2.new(0, 18, 0.45, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 24)
    toggleBtn.BackgroundTransparency = 0.1
    toggleBtn.Text = "RZO"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Active = true
    toggleBtn.AutoButtonColor = true
    toggleBtn.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = toggleBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 90, 130)
    stroke.Thickness = 2
    stroke.Parent = toggleBtn

    local dragging = false
    local dragStart = nil
    local startPos = nil

    toggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = toggleBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    toggleBtn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            toggleBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if Window and Window.Toggle then
                Window:Toggle()
            elseif WindUI and WindUI.Toggle then
                WindUI:Toggle()
            end
        end)
    end)

    return toggleBtn
end

pcall(createFloatingToggle)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    pcall(createFloatingToggle)
end)

-- Explicitly purge all performance overlays & lock/keybind overlays (Keep ONLY RZO toggle button)
pcall(function()
    if safeParent then
        local oldPerf = safeParent:FindFirstChild("RzoHub_PerfOverlay")
        if oldPerf then oldPerf:Destroy() end
    end
end)

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
local notifConn = nil
local notifConn2 = nil
local leadFeetEnabled = false
local leadFeetConnection = nil
local maxServeEnabled = false
local maxServeHookActive = false
local oldNamecallMaxServe = nil
local mtMaxServe = nil
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
                label.Text = "Anony Protect"
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
        textLabel.Text = string.gsub(text, player.Name, "Anony Protected")
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
                child.Text = string.gsub(text, player.Name, "Anony Protected")
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
            username.Text = "Anony Protect"
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

-- spikeButton disabled (Free Edition)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        spikeBall()
    end
end)

local _unifiedHookInstalled = false
local _originalNamecall = nil

local function ensureUnifiedNamecall()
    if _unifiedHookInstalled then return true end

    local function namecallHandler(self, ...)
        local method = (getnamecallmethod and getnamecallmethod()) or ""

        if BallService and BallService.RF and self == BallService.RF.Interact and method == "InvokeServer" then
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

                if sanjuTiltEnabled then
                    if data.TiltDirection and data.LookVector then
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
                end

                if maxChargeEnabled then
                    data.Charge = 1.0
                    data.SpecialCharge = 1.0
                end
                args[1] = data
            end
            if _originalNamecall then
                return _originalNamecall(self, unpack(args))
            end
        end

        if maxServeEnabled and Serve and self == Serve and method == "InvokeServer" then
            local args = {...}
            args[2] = 5
            if _originalNamecall then
                return _originalNamecall(self, unpack(args))
            end
        end

        if _originalNamecall then
            return _originalNamecall(self, ...)
        end
    end

    local ok = pcall(function()
        local wrapped = safeClosure(namecallHandler)
        if hookmetamethod and type(hookmetamethod) == "function" then
            _originalNamecall = hookmetamethod(game, "__namecall", wrapped)
            _unifiedHookInstalled = true
        elseif getrawmetatable and setreadonly then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            _originalNamecall = mt.__namecall
            mt.__namecall = wrapped
            setreadonly(mt, true)
            _unifiedHookInstalled = true
        end
    end)

    return ok and _unifiedHookInstalled
end

local function enableRedirectSpike()
    ensureUnifiedNamecall()
    redirectSpikeEnabled = true
end

local function disableRedirectSpike()
    redirectSpikeEnabled = false
end

local function enableSanjuTilt()
    ensureUnifiedNamecall()
    sanjuTiltEnabled = true
end

local function disableSanjuTilt()
    sanjuTiltEnabled = false
end

local function enableMaxCharge()
    ensureUnifiedNamecall()
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

-- newSpikeButton disabled (Free Edition)

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
    if not Serve then
        warn("[RZO HUB] Serve RemoteFunction not found.")
        return
    end
    ensureUnifiedNamecall()
    maxServeHookActive = true
    maxServeEnabled = true
end

local function disableMaxServe()
    maxServeHookActive = false
    maxServeEnabled = false
end

local function -- createLeadFeetButton disabled (Free Edition)
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

-- createLeadFeetButton disabled (Free Edition)

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

-- [[ UI INITIALIZATION - WINDUI ]]
local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "crosshair", Desc = "Gameplay & Spikes" }),
    Character = Window:Tab({ Title = "Character", Icon = "user", Desc = "Attributes & Movement" }),
    Misc = Window:Tab({ Title = "Misc", Icon = "settings", Desc = "Shop, Rollback & Spins" }),
    GameJoin = Window:Tab({ Title = "Game Join", Icon = "gamepad-2", Desc = "Game Modes Teleport" }),
    Changelogs = Window:Tab({ Title = "Changelogs", Icon = "file-text", Desc = "Version & Changes" }),
    Settings = Window:Tab({ Title = "UI Settings", Icon = "sliders", Desc = "Themes & Controls" }),
}

-- Main Tab Sections
local MainLeft = Tabs.Main:Section({ Title = "Spike Settings", Opened = true })
local MainRight = Tabs.Main:Section({ Title = "Hitbox Settings", Opened = true })
local MainPerf = Tabs.Main:Section({ Title = "Performance & Movement", Opened = true })
local MainServe = Tabs.Main:Section({ Title = "Serve Settings", Opened = true })

-- Spike Settings (Free Edition)
MainLeft:Toggle({
    Title = "Sanju Tilt",
    Desc = "Spike tilt trajectory modification",
    Value = false,
    Callback = function(v)
        if v then
            enableSanjuTilt()
        else
            disableSanjuTilt()
        end
    end,
})

MainLeft:Toggle({
    Title = "Max Charge Special (Ronin)",
    Desc = "Charge max power on Ronin spike",
    Value = false,
    Callback = function(v)
        if v then
            enableMaxCharge()
        else
            disableMaxCharge()
        end
    end,
})

-- Hitbox Settings
MainRight:Slider({
    Title = "Hitbox Size",
    Desc = "Ball interaction radius scale",
    Step = 0.5,
    Value = {
        Min = 0,
        Max = 20,
        Default = 5,
    },
    Callback = function(v)
        hitboxScale = tonumber(v) or 5
        updateHitboxes(hitboxScale)
    end,
})

MainRight:Dropdown({
    Title = "Hitbox Color",
    Desc = "Highlight bounding box color",
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
            White = Color3.fromRGB(255, 255, 255),
        }
        hitboxColor = colors[v] or Color3.fromRGB(0, 255, 0)
        hitboxColorName = v
        updateHitboxes(hitboxScale)
    end,
})

MainRight:Button({
    Title = "Remove Hitboxes",
    Desc = "Clear all active hitboxes",
    Callback = function()
        removeHitboxes()
        notify("Hitboxes Removed", "All hitboxes cleared", 2)
    end,
})

MainRight:Button({
    Title = "Show / Hide Stop Ball",
    Desc = "Toggle mobile stop-ball button",
    Callback = function()
        stopBallVisible = not stopBallVisible
        if stopBallButton then
            stopBallButton.Visible = stopBallVisible
        else
            stopBallButton = createStopBallButton()
        end
        notify("Stop Ball", stopBallVisible and "SHOWN" or "HIDDEN", 2)
    end,
})

MainRight:Button({
    Title = "Show / Hide Aim",
    Desc = "Toggle mobile aim button",
    Callback = function()
        aimVisible = not aimVisible
        if aimButton then
            aimButton.Visible = aimVisible
        else
            aimButton = createAimButton()
        end
        notify("Aim", aimVisible and "SHOWN" or "HIDDEN", 2)
    end,
})

-- Performance & Movement
MainPerf:Toggle({
    Title = "Anti-Lag (FPS Boost)",
    Desc = "Disable heavy shadows and bloom effects",
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
    end,
})

MainPerf:Toggle({
    Title = "Desync",
    Desc = "Network packet desynchronization",
    Value = false,
    Callback = function(v)
        if v then
            enableDesync()
            notify("Desync", "ENABLED", 2)
        else
            disableDesync()
            notify("Desync", "DISABLED", 2)
        end
    end,
})

MainPerf:Toggle({
    Title = "Auto Receive",
    Desc = "Automatic ball receive positioning",
    Value = false,
    Callback = function(v)
        if v then
            enableAutoReceive()
            notify("Auto Receive", "ENABLED", 2)
        else
            disableAutoReceive()
            notify("Auto Receive", "DISABLED", 2)
        end
    end,
})

MainPerf:Toggle({
    Title = "Akari Dash",
    Desc = "Fast directional dash button",
    Value = false,
    Callback = function(v)
        akariDashEnabled = v
        if dashButton then
            dashButton.Visible = v
        end
        notify("Akari Dash", v and "ENABLED" or "DISABLED", 2)
    end,
})

-- Serve Settings
MainServe:Toggle({
    Title = "Max Serve",
    Desc = "Force power value 5 on server remote",
    Value = false,
    Callback = function(v)
        if v then
            enableMaxServe()
            notify("Max Serve", "ENABLED", 2)
        else
            disableMaxServe()
            notify("Max Serve", "DISABLED", 2)
        end
    end,
})

-- Character Tab Sections
local CharLeft = Tabs.Character:Section({ Title = "Attributes", Opened = true })
local CharRight = Tabs.Character:Section({ Title = "Movement", Opened = true })

CharLeft:Input({
    Title = "Dive Speed",
    Placeholder = "0.95",
    Value = "",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_DiveSpeed", num)
        end
    end,
})

CharLeft:Input({
    Title = "Jump Power",
    Placeholder = "1.1",
    Value = "",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_JumpPower", num)
        end
    end,
})

CharLeft:Input({
    Title = "Speed",
    Placeholder = "0.85",
    Value = "",
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_Speed", num)
        end
    end,
})

CharRight:Toggle({
    Title = "Air Movement",
    Desc = "Glide in mid-air",
    Value = false,
    Callback = function(v)
        airMovement = v
        if not v and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end,
})

CharRight:Slider({
    Title = "Air Movement Speed",
    Desc = "Air glide velocity intensity",
    Step = 1,
    Value = {
        Min = 0,
        Max = 100,
        Default = 16,
    },
    Callback = function(v)
        airMovementSpeed = tonumber(v) or 16
    end,
})

local autoShiftLock = false

CharRight:Toggle({
    Title = "Auto Shift Lock",
    Desc = "Lock facing direction prior to jumping",
    Value = false,
    Callback = function(v)
        autoShiftLock = v
        notify("Auto Shift Lock", v and "ENABLED" or "DISABLED", 2)
    end,
})

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
                    end
                end)
            end
        end
    end)
end

if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

-- Misc Tab Sections
local MiscRollback = Tabs.Misc:Section({ Title = "Data Rollback", Opened = true })
local MiscShop = Tabs.Misc:Section({ Title = "Shop", Opened = true })
local MiscStyleSpin = Tabs.Misc:Section({ Title = "Auto Style Spin", Opened = true })
local MiscAbilitySpin = Tabs.Misc:Section({ Title = "Auto Ability Spin", Opened = true })
local MiscRewards = Tabs.Misc:Section({ Title = "Claim Rewards", Opened = true })

MiscRollback:Paragraph({
    Title = "Peringatan Data Rollback",
    Desc = "- Minimal gunakan 10 spin (jangan lebih!)\n- Use at your own risk!\n- Crash server untuk revert inventory",
})

MiscRollback:Button({
    Title = "Execute Data Rollback",
    Desc = "Revert inventory by disconnecting session",
    Callback = function()
        local Remote = game:GetService("ReplicatedStorage")
            :WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_knit@1.7.0")
            :WaitForChild("knit")
            :WaitForChild("Services")
            :WaitForChild("SettingsService")
            :WaitForChild("RF")
            :WaitForChild("UpdateKeybind")
        Remote:InvokeServer("MouseButton1", true, "Spike\xE2\x80\x8B\x8F")
        notify("Data Rollback", "Executed! Rejoining...", 2)
        TeleportService:Teleport(game.PlaceId)
    end,
})

MiscStyleSpin:Toggle({
    Title = "Auto Style Spin",
    Desc = "Continuously spin for target style",
    Value = false,
    Callback = function(v)
        autoSpin = v
        if v then
            startAutoSpin()
        end
    end,
})

MiscStyleSpin:Dropdown({
    Title = "Spin Type",
    Desc = "Select spin tier",
    Values = {"Normal", "Lucky"},
    Value = "Normal",
    Callback = function(v)
        spinType = v
    end,
})

MiscStyleSpin:Input({
    Title = "Target Style",
    Placeholder = "Sanju",
    Value = "",
    Callback = function(v)
        desiredStyles = {v}
        notify("Target Set", "Target style: " .. tostring(v), 2)
    end,
})

MiscStyleSpin:Button({
    Title = "Instant Spin",
    Desc = "Spin style once immediately",
    Callback = function()
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
    end,
})

MiscAbilitySpin:Toggle({
    Title = "Auto Ability Spin",
    Desc = "Continuously spin for target ability",
    Value = false,
    Callback = function(v)
        autoAbilitySpin = v
        if v then
            startAutoAbilitySpin()
        end
    end,
})

MiscAbilitySpin:Dropdown({
    Title = "Ability Spin Type",
    Desc = "Select ability spin tier",
    Values = {"Normal", "Lucky"},
    Value = "Normal",
    Callback = function(v)
        abilitySpinType = v
    end,
})

MiscAbilitySpin:Input({
    Title = "Target Ability",
    Placeholder = "Shield Breaker",
    Value = "",
    Callback = function(v)
        desiredAbilities = {v}
        notify("Target Set", "Target ability: " .. tostring(v), 2)
    end,
})

MiscAbilitySpin:Button({
    Title = "Instant Ability Spin",
    Desc = "Spin ability once immediately",
    Callback = function()
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
    end,
})

MiscRewards:Button({
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
    end,
})

MiscRewards:Button({
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
    end,
})

MiscRewards:Button({
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
            for line in string.gmatch(data, "[^\n]+") do
                if string.find(line, "(NEW)") then
                    local code = string.match(line, "(%u+[%u%d_]+)")
                    if code and not processed[code] then
                        processed[code] = true
                        table.insert(newCodes, code)
                    end
                end
                if #newCodes >= 3 then
                    break
                end
            end
            return newCodes
        end
        local newCodes = fetchNewCodes()
        if #newCodes > 0 then
            for i, code in pairs(newCodes) do
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
            notify("Codes Redeemed", "All codes redeemed!", 3)
        else
            notify("No Codes", "No codes found!", 3)
        end
    end,
})

MiscShop:Button({
    Title = "Buy Emote",
    Callback = function()
        local PackService = getKnitService("PackService").RF
        if PackService then
            local Open = PackService:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Emote1")
                notify("Shop", "Emote purchased!", 2)
            end
        end
    end,
})

MiscShop:Button({
    Title = "Buy Effect",
    Callback = function()
        local PackService = getKnitService("PackService").RF
        if PackService then
            local Open = PackService:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "ScoreEffect1")
                notify("Shop", "Effect purchased!", 2)
            end
        end
    end,
})

MiscShop:Button({
    Title = "Buy Extreme Ball",
    Callback = function()
        local PackService = getKnitService("PackService").RF
        if PackService then
            local Open = PackService:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Extreme")
                notify("Shop", "Extreme ball purchased!", 2)
            end
        end
    end,
})

MiscShop:Button({
    Title = "Buy Medium Ball",
    Callback = function()
        local PackService = getKnitService("PackService").RF
        if PackService then
            local Open = PackService:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Medium")
                notify("Shop", "Medium ball purchased!", 2)
            end
        end
    end,
})

MiscShop:Button({
    Title = "Buy Basic Ball",
    Callback = function()
        local PackService = getKnitService("PackService").RF
        if PackService then
            local Open = PackService:FindFirstChild("Open")
            if Open then
                safeInvoke(Open, "Basic")
                notify("Shop", "Basic ball purchased!", 2)
            end
        end
    end,
})

MiscShop:Button({
    Title = "Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId)
    end,
})

-- Game Join Tab
local JoinGroup = Tabs.GameJoin:Section({ Title = "Game Modes", Opened = true })

local function requestGameMode(modeName, displayLabel)
    local PartyService = getKnitService("PartyService").RF
    if PartyService then
        local RequestTeleport = PartyService:FindFirstChild("RequestTeleport")
        if RequestTeleport then
            safeInvoke(RequestTeleport, modeName)
            notify("Joining", displayLabel .. "...", 2)
        end
    end
end

JoinGroup:Button({ Title = "Chaos Mode", Callback = function() requestGameMode("ChaosMode", "Chaos Mode") end })
JoinGroup:Button({ Title = "1v1 Mini Map", Callback = function() requestGameMode("OnesMini", "1v1 Mini Map") end })
JoinGroup:Button({ Title = "2v2 Ranked", Callback = function() requestGameMode("Twos", "2v2 Ranked") end })
JoinGroup:Button({ Title = "3v3 Ranked", Callback = function() requestGameMode("Threes", "3v3 Ranked") end })
JoinGroup:Button({ Title = "4v4 Ranked", Callback = function() requestGameMode("Fours", "4v4 Ranked") end })
JoinGroup:Button({ Title = "6v6 Ranked", Callback = function() requestGameMode("Sixes", "6v6 Ranked") end })
JoinGroup:Button({ Title = "Training", Callback = function() requestGameMode("Training", "Training") end })

-- Changelogs Tab
local ChangeLogSec = Tabs.Changelogs:Section({ Title = "Changelogs", Opened = true })
local VersionSec = Tabs.Changelogs:Section({ Title = "Version Info", Opened = true })

ChangeLogSec:Paragraph({
    Title = "ADDING VOLLEYBALLLEGENDS",
    Desc = "[+] UI Migrated to WindUI (Modern, Ultra-Smooth)\n[+] VBL License Key Gateway (+24h HWID Auth)\n[+] Universal Executor Shims (Delta, Solara, Codex, Wave)\n[+] Unified Namecall Hook (Collision-Free Engine)\n[+] Shift Lock Jump Fix (Pre-Jump Direction Lock)\n[+] Max Charge Special (Ronin)\n[+] Sanju Tilt\n[+] Max Serve\n[-] Stripped Premium Spikes (Free Edition)\n[-] Cleaned Visual Clutter (ScoreEffect, ESP, PlayerCards)"
})

VersionSec:Paragraph({
    Title = "Hub Metadata",
    Desc = "Hub: RZO HUB\nTarget: Volleyball Legends\nBranch: Free Edition\nEngine: WindUI\nPlatform: Universal Luau"
})

VersionSec:Button({
    Title = "Copy Discord Link",
    Callback = function()
        setClipboardSafe("https://discord.gg/vNExQNRK3")
        notify("Discord", "Discord invite link copied to clipboard!", 2)
    end,
})

-- UI Settings Tab
local SettingsMenu = Tabs.Settings:Section({ Title = "Theme & Customization", Opened = true })
local SettingsActions = Tabs.Settings:Section({ Title = "Emergency & Controls", Opened = true })

SettingsMenu:Dropdown({
    Title = "Select Theme",
    Desc = "Change WindUI appearance theme",
    Values = { "Dark", "Midnight", "Indigo", "Sky", "Violet", "Rose", "Emerald", "Plant", "Red", "Crimson", "MonokaiPro", "CottonCandy" },
    Value = "Dark",
    Callback = function(themeName)
        pcall(function()
            WindUI:SetTheme(themeName)
        end)
    end,
})

SettingsMenu:Keybind({
    Title = "Menu Keybind",
    Desc = "Key to toggle WindUI menu",
    Value = Enum.KeyCode.RightControl,
    Callback = function(key)
        pcall(function()
            if Window and Window.SetToggleKey then
                Window:SetToggleKey(key)
            end
        end)
    end,
})

SettingsActions:Button({
    Title = "Panic Mode (Disable All)",
    Desc = "Immediately deactivate all features",
    Callback = function()
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
        autoSpin = false
        autoAbilitySpin = false
        hitEffectEnabled = false
        playerCardEnabled = false
        stopBallVisible = false
        aimVisible = false
        maxServeEnabled = false
        leadFeetEnabled = false
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
    end,
})

SettingsActions:Button({
    Title = "Toggle Window",
    Desc = "Open or close WindUI interface",
    Callback = function()
        if Window and Window.Toggle then
            Window:Toggle()
        end
    end,
})

SettingsActions:Button({
    Title = "Unload UI",
    Desc = "Safely close and destroy WindUI",
    Callback = function()
        if Window and Window.Destroy then
            Window:Destroy()
        end
    end,
})

-- Force open WindUI menu on load
task.defer(function()
    task.wait(0.25)
    pcall(function()
        if Window and Window.Open then
            Window:Open()
        end
    end)
end)

notify("RZO HUB", "ADDING VOLLEYBALLLEGENDS - Loaded successfully!", 3)
