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

local function launchKeyGateway(onSuccess)
    if not isFolderSafe(KEY_FOLDER) then
        makeFolderSafe(KEY_FOLDER)
    end

    if isFileSafe(KEY_FILE) then
        local saved = readFileSafe(KEY_FILE)
        if saved and #saved > 6 then
            local valid, data = verifyVblKey(saved)
            if valid then
                onSuccess(saved, data)
                return
            end
        end
    end

    local parent = getSafeGuiParent()
    if not parent then
        warn("[RZO HUB] Cannot find valid GUI parent.")
        onSuccess(nil, nil)
        return
    end

    local existing = parent:FindFirstChild("RzoHub_VBL_KeyGate")
    if existing then existing:Destroy() end

    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5))
    if pg and pg ~= parent then
        local old = pg:FindFirstChild("RzoHub_VBL_KeyGate")
        if old then old:Destroy() end
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RzoHub_VBL_KeyGate"
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

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 420, 0, 260)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Thickness = 1.6
    stroke.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -30, 0, 28)
    titleLabel.Position = UDim2.new(0, 16, 0, 14)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "RZO HUB"
    titleLabel.TextColor3 = Color3.fromRGB(250, 250, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = mainFrame

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 95, 0, 20)
    badge.Position = UDim2.new(1, -110, 0, 16)
    badge.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    badge.TextColor3 = Color3.fromRGB(10, 10, 15)
    badge.Text = "VBL GATEWAY"
    badge.Font = Enum.Font.Code
    badge.TextSize = 10
    badge.Parent = mainFrame

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 4)
    badgeCorner.Parent = badge

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, -32, 0, 18)
    subLabel.Position = UDim2.new(0, 16, 0, 44)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = "Masukkan key VBL 24-jam Anda untuk otentikasi"
    subLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 12
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = mainFrame

    local inputContainer = Instance.new("Frame")
    inputContainer.Size = UDim2.new(1, -32, 0, 40)
    inputContainer.Position = UDim2.new(0, 16, 0, 72)
    inputContainer.BackgroundTransparency = 1
    inputContainer.Parent = mainFrame

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -76, 1, 0)
    inputBox.Position = UDim2.new(0, 0, 0, 0)
    inputBox.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
    inputBox.TextColor3 = Color3.fromRGB(245, 245, 255)
    inputBox.Text = ""
    inputBox.PlaceholderText = "" -- KOSONG BERSIH TANPA TEKS
    inputBox.ClearTextOnFocus = true
    inputBox.Font = Enum.Font.Code
    inputBox.TextSize = 13
    inputBox.Parent = inputContainer

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(50, 50, 70)
    inputStroke.Thickness = 1.2
    inputStroke.Parent = inputBox

    inputBox.Focused:Connect(function()
        inputBox.Text = ""
    end)

    local pasteBtn = Instance.new("TextButton")
    pasteBtn.Size = UDim2.new(0, 68, 1, 0)
    pasteBtn.Position = UDim2.new(1, -68, 0, 0)
    pasteBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
    pasteBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
    pasteBtn.Text = "PASTE"
    pasteBtn.Font = Enum.Font.GothamBold
    pasteBtn.TextSize = 12
    pasteBtn.Parent = inputContainer

    local pasteCorner = Instance.new("UICorner")
    pasteCorner.CornerRadius = UDim.new(0, 8)
    pasteCorner.Parent = pasteBtn

    local pasteStroke = Instance.new("UIStroke")
    pasteStroke.Color = Color3.fromRGB(70, 70, 100)
    pasteStroke.Thickness = 1
    pasteStroke.Parent = pasteBtn

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -32, 0, 20)
    statusLabel.Position = UDim2.new(0, 16, 0, 120)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Siap memasukkan key"
    statusLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame

    pasteBtn.MouseButton1Click:Connect(function()
        local clip = getClipboardSafe()
        if clip and #clip > 4 then
            inputBox.Text = string.gsub(clip, "%s+", "")
            statusLabel.Text = "Key berhasil di-paste dari clipboard!"
            statusLabel.TextColor3 = Color3.fromRGB(130, 220, 255)
        else
            inputBox.Text = ""
            statusLabel.Text = "Clipboard kosong atau tidak didukung executor."
            statusLabel.TextColor3 = Color3.fromRGB(240, 180, 80)
        end
    end)

    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(1, -32, 0, 38)
    submitBtn.Position = UDim2.new(0, 16, 0, 150)
    submitBtn.BackgroundColor3 = Color3.fromRGB(245, 245, 255)
    submitBtn.TextColor3 = Color3.fromRGB(10, 10, 15)
    submitBtn.Text = "Verify & Engage"
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 13
    submitBtn.Parent = mainFrame

    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 8)
    submitCorner.Parent = submitBtn

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(0.48, -20, 0, 30)
    getKeyBtn.Position = UDim2.new(0, 16, 0, 200)
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    getKeyBtn.TextColor3 = Color3.fromRGB(220, 220, 235)
    getKeyBtn.Text = "Get Key (Copy Link)"
    getKeyBtn.Font = Enum.Font.GothamMedium
    getKeyBtn.TextSize = 11
    getKeyBtn.Parent = mainFrame

    local getKeyCorner = Instance.new("UICorner")
    getKeyCorner.CornerRadius = UDim.new(0, 6)
    getKeyCorner.Parent = getKeyBtn

    local discordBtn = Instance.new("TextButton")
    discordBtn.Size = UDim2.new(0.48, -12, 0, 30)
    discordBtn.Position = UDim2.new(0.52, 0, 0, 200)
    discordBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    discordBtn.TextColor3 = Color3.fromRGB(150, 170, 255)
    discordBtn.Text = "Join Discord"
    discordBtn.Font = Enum.Font.GothamMedium
    discordBtn.TextSize = 11
    discordBtn.Parent = mainFrame

    local discordCorner = Instance.new("UICorner")
    discordCorner.CornerRadius = UDim.new(0, 6)
    discordCorner.Parent = discordBtn

    getKeyBtn.MouseButton1Click:Connect(function()
        setClipboardSafe(GET_KEY_URL)
        statusLabel.Text = "Link copied! Selesaikan LootLabs untuk claim key."
        statusLabel.TextColor3 = Color3.fromRGB(130, 200, 255)
    end)

    discordBtn.MouseButton1Click:Connect(function()
        setClipboardSafe(DISCORD_URL)
        statusLabel.Text = "Discord invite copied to clipboard!"
        statusLabel.TextColor3 = Color3.fromRGB(150, 170, 255)
    end)

    local function handleKeySubmission()
        local inputKey = string.gsub(inputBox.Text, "%s+", "")
        if #inputKey < 6 then
            statusLabel.Text = "Silakan masukkan atau paste key VBL Anda."
            statusLabel.TextColor3 = Color3.fromRGB(255, 90, 100)
            return
        end

        statusLabel.Text = "Authenticating with RZO HUB..."
        statusLabel.TextColor3 = Color3.fromRGB(220, 220, 240)

        task.spawn(function()
            local valid, res = verifyVblKey(inputKey)
            if valid then
                statusLabel.Text = "Key Valid! (+24h Active) Loading RZO HUB..."
                statusLabel.TextColor3 = Color3.fromRGB(50, 220, 130)
                writeFileSafe(KEY_FILE, inputKey)
                task.wait(0.4)
                screenGui:Destroy()
                onSuccess(inputKey, res)
            else
                local msg = (type(res) == "table" and res.message) or tostring(res)
                statusLabel.Text = msg
                statusLabel.TextColor3 = Color3.fromRGB(255, 80, 90)
            end
        end)
    end

    submitBtn.MouseButton1Click:Connect(handleKeySubmission)
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            handleKeySubmission()
        end
    end)
end

local function loadObsidianComponent(path)
    local urls = {
        "https://cdn.jsdelivr.net/gh/deividcomsono/Obsidian@main/" .. path,
        "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/" .. path
    }
    for _, url in ipairs(urls) do
        local ok, src = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and src and #src > 100 then
            local loadOk, fn = pcall(loadstring, src)
            if loadOk and type(fn) == "function" then
                local execOk, res = pcall(fn)
                if execOk and res then
                    return res
                end
            end
        end
    end
    error("[RZO HUB] Failed to download Obsidian component: " .. tostring(path))
end

local function LoadMainHub()
local Library = loadObsidianComponent("Library.lua")
local ThemeManager = loadObsidianComponent("addons/ThemeManager.lua")
local SaveManager = loadObsidianComponent("addons/SaveManager.lua")

local Options = Library.Options
local Toggles = Library.Toggles

local function notify(titleOrTable, content, duration)
    if typeof(titleOrTable) == "table" then
        Library:Notify({
            Title = titleOrTable.Title or "Notification",
            Description = titleOrTable.Content or titleOrTable.Description or "",
            Time = titleOrTable.Duration or titleOrTable.Time or 3,
        })
    else
        Library:Notify({
            Title = tostring(titleOrTable or "Notification"),
            Description = tostring(content or ""),
            Time = tonumber(duration) or 3,
        })
    end
end

local Window = Library:CreateWindow({
    Title = "RZO HUB - Volleyball Legends",
    Footer = "RZO HUB | Volleyball Legends",
    NotifySide = "Right",
    ShowCustomCursor = true,
})
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
            if Library and Library.Toggle then
                Library:Toggle()
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
    if Library then
        if Library.SetWatermarkVisibility then
            Library:SetWatermarkVisibility(false)
        end
        if Library.KeybindFrame then
            Library.KeybindFrame.Visible = false
        end
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

-- [[ UI INITIALIZATION - OBSIDIAN ]]
local Tabs = {
    Main = Window:AddTab("Main", "crosshair"),
    Character = Window:AddTab("Character", "user"),
    Misc = Window:AddTab("Misc", "settings"),
    GameJoin = Window:AddTab("Game Join", "gamepad-2"),
    Changelogs = Window:AddTab("Changelogs", "file-text"),
    ["UI Settings"] = Window:AddTab("UI Settings", "sliders"),
}

-- Main Tab Groupboxes
local MainLeft = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Spike Settings", IconName = "zap" })
local MainRight = Tabs.Main:AddGroupbox({ Side = "Right", Name = "Hitbox Settings", IconName = "box" })
local MainPerf = Tabs.Main:AddGroupbox({ Side = "Left", Name = "Performance & Movement", IconName = "activity" })
local MainServe = Tabs.Main:AddGroupbox({ Side = "Right", Name = "Serve Settings", IconName = "sparkles" })

-- Spike Settings (Free Edition)
MainLeft:AddToggle("sanju", {
    Text = "Sanju Tilt",
    Default = false,
    Callback = function(v)
        if v then
            enableSanjuTilt()
        else
            disableSanjuTilt()
        end
    end,
})

MainLeft:AddToggle("maxcharge", {
    Text = "Max Charge Special (Ronin)",
    Default = false,
    Callback = function(v)
        if v then
            enableMaxCharge()
        else
            disableMaxCharge()
        end
    end,
})

-- Hitbox Settings
MainRight:AddSlider("hitboxsize", {
    Text = "Hitbox Size",
    Default = 5,
    Min = 0,
    Max = 20,
    Rounding = 1,
    Callback = function(v)
        hitboxScale = v
        updateHitboxes(v)
    end,
})

MainRight:AddDropdown("hitboxcolor", {
    Text = "Hitbox Color",
    Values = {"Green", "Blue", "Red", "Yellow", "Purple", "Orange", "Pink", "White"},
    Default = "Green",
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

MainRight:AddButton({
    Text = "Remove Hitboxes",
    Func = function()
        removeHitboxes()
        notify("Hitboxes Removed", "All hitboxes cleared", 2)
    end,
})

MainRight:AddButton({
    Text = "Show / Hide Stop Ball",
    Func = function()
        stopBallVisible = not stopBallVisible
        if stopBallButton then
            stopBallButton.Visible = stopBallVisible
        else
            stopBallButton = createStopBallButton()
        end
        notify("Stop Ball", stopBallVisible and "SHOWN" or "HIDDEN", 2)
    end,
})

MainRight:AddButton({
    Text = "Show / Hide Aim",
    Func = function()
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
MainPerf:AddToggle("antilag", {
    Text = "Anti-Lag",
    Default = false,
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

MainPerf:AddToggle("desync", {
    Text = "Desync",
    Default = false,
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

MainPerf:AddToggle("autoreceive", {
    Text = "Auto Receive",
    Default = false,
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

MainPerf:AddToggle("akaridash", {
    Text = "Akari Dash",
    Default = false,
    Callback = function(v)
        akariDashEnabled = v
        if dashButton then
            dashButton.Visible = v
        end
        notify("Akari Dash", v and "ENABLED" or "DISABLED", 2)
    end,
})

-- Serve Settings (Free Edition)
MainServe:AddToggle("maxserve", {
    Text = "Max Serve",
    Default = false,
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

-- Character Tab Groupboxes
local CharLeft = Tabs.Character:AddGroupbox({ Side = "Left", Name = "Attributes", IconName = "sliders-horizontal" })
local CharRight = Tabs.Character:AddGroupbox({ Side = "Right", Name = "Movement", IconName = "move" })

CharLeft:AddInput("divespeed", {
    Text = "Dive Speed",
    Placeholder = "0.95",
    Finished = false,
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_DiveSpeed", num)
        end
    end,
})

CharLeft:AddInput("jumppower", {
    Text = "Jump Power",
    Placeholder = "1.1",
    Finished = false,
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_JumpPower", num)
        end
    end,
})

CharLeft:AddInput("speed", {
    Text = "Speed",
    Placeholder = "0.85",
    Finished = false,
    Callback = function(v)
        local num = tonumber(v)
        if num then
            LocalPlayer:SetAttribute("Multiplier_Speed", num)
        end
    end,
})

CharRight:AddToggle("airmove", {
    Text = "Air Movement",
    Default = false,
    Callback = function(v)
        airMovement = v
        if not v and bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end,
})

CharRight:AddSlider("airspeed", {
    Text = "Air Movement Speed",
    Default = 16,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        airMovementSpeed = v
    end,
})

-- Auto Shift Lock (Original Implementation - Zero AutoRotate)
local autoShiftLock = false

CharRight:AddToggle("autoshiftlock", {
    Text = "Auto Shift Lock",
    Default = false,
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

-- Visuals Tab removed for Free Edition

-- Misc Tab Groupboxes
Tabs.Misc:UpdateWarningBox({
    Visible = true,
    Title = "DATA ROLLBACK WARNING",
    Text = "Perhatian: Gunakan MINIMAL 10 spin saat melakukan rollback, jangan lebih! Use at your own risk.",
})

local MiscRollback = Tabs.Misc:AddGroupbox({ Side = "Left", Name = "Data Rollback", IconName = "database" })
local MiscShop = Tabs.Misc:AddGroupbox({ Side = "Right", Name = "Shop", IconName = "shopping-cart" })
local MiscStyleSpin = Tabs.Misc:AddGroupbox({ Side = "Left", Name = "Auto Style Spin", IconName = "rotate-cw" })
local MiscAbilitySpin = Tabs.Misc:AddGroupbox({ Side = "Right", Name = "Auto Ability Spin", IconName = "sparkle" })
local MiscRewards = Tabs.Misc:AddGroupbox({ Side = "Left", Name = "Claim Rewards", IconName = "gift" })

MiscRollback:AddLabel("Pemberitahuan:\n- Minimal gunakan 10 spin (jangan lebih!)\n- Use at your own risk!", true)

MiscRollback:AddButton({
    Text = "Execute Data Rollback",
    Func = function()
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
        game:GetService("TeleportService"):Teleport(game.PlaceId)
    end,
})

MiscStyleSpin:AddToggle("autostyle", {
    Text = "Auto Style Spin",
    Default = false,
    Callback = function(v)
        autoSpin = v
        if v then
            startAutoSpin()
        end
    end,
})

MiscStyleSpin:AddDropdown("spintype", {
    Text = "Spin Type",
    Values = {"Normal", "Lucky"},
    Default = "Normal",
    Callback = function(v)
        spinType = v
    end,
})

MiscStyleSpin:AddInput("targetstyle", {
    Text = "Target Style",
    Placeholder = "Sanju",
    Finished = false,
    Callback = function(v)
        desiredStyles = {v}
        notify("Target Set", "Target style: " .. tostring(v), 2)
    end,
})

MiscStyleSpin:AddButton({
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
    end,
})

MiscAbilitySpin:AddToggle("autoabilityspin", {
    Text = "Auto Ability Spin",
    Default = false,
    Callback = function(v)
        autoAbilitySpin = v
        if v then
            startAutoAbilitySpin()
        end
    end,
})

MiscAbilitySpin:AddDropdown("abilityspintype", {
    Text = "Ability Spin Type",
    Values = {"Normal", "Lucky"},
    Default = "Normal",
    Callback = function(v)
        abilitySpinType = v
    end,
})

MiscAbilitySpin:AddInput("targetability", {
    Text = "Target Ability",
    Placeholder = "Shield Breaker",
    Finished = false,
    Callback = function(v)
        desiredAbilities = {v}
        notify("Target Set", "Target ability: " .. tostring(v), 2)
    end,
})

MiscAbilitySpin:AddButton({
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
    end,
})

MiscRewards:AddButton({
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
    end,
})

MiscRewards:AddButton({
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
    end,
})

MiscRewards:AddButton({
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

MiscShop:AddButton({
    Text = "Buy Emote",
    Func = function()
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

MiscShop:AddButton({
    Text = "Buy Effect",
    Func = function()
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

MiscShop:AddButton({
    Text = "Buy Extreme Ball",
    Func = function()
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

MiscShop:AddButton({
    Text = "Buy Medium Ball",
    Func = function()
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

MiscShop:AddButton({
    Text = "Buy Basic Ball",
    Func = function()
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

MiscShop:AddButton({
    Text = "Rejoin Server",
    Func = function()
        TeleportService:Teleport(game.PlaceId)
    end,
})

-- Game Join Tab Groupboxes
local JoinGroup = Tabs.GameJoin:AddGroupbox({ Side = "Left", Name = "Game Modes", IconName = "swords" })

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

JoinGroup:AddButton({ Text = "Chaos Mode", Func = function() requestGameMode("ChaosMode", "Chaos Mode") end })
JoinGroup:AddButton({ Text = "1v1 Mini Map", Func = function() requestGameMode("OnesMini", "1v1 Mini Map") end })
JoinGroup:AddButton({ Text = "2v2 Ranked", Func = function() requestGameMode("Twos", "2v2 Ranked") end })
JoinGroup:AddButton({ Text = "3v3 Ranked", Func = function() requestGameMode("Threes", "3v3 Ranked") end })
JoinGroup:AddButton({ Text = "4v4 Ranked", Func = function() requestGameMode("Fours", "4v4 Ranked") end })
JoinGroup:AddButton({ Text = "6v6 Ranked", Func = function() requestGameMode("Sixes", "6v6 Ranked") end })
JoinGroup:AddButton({ Text = "Training", Func = function() requestGameMode("Training", "Training") end })

-- Changelogs Tab Groupboxes
local ChangeLogLeft = Tabs.Changelogs:AddGroupbox({ Side = "Left", Name = "Changelogs", IconName = "history" })
local ChangeLogRight = Tabs.Changelogs:AddGroupbox({ Side = "Right", Name = "Version Info", IconName = "info" })

ChangeLogLeft:AddLabel([[ADDING VOLLEYBALLLEGENDS

[+] VBL License Key Gateway (+24h HWID Auth)
[+] Universal Executor Shims (Delta, Solara, Codex, Wave)
[+] Unified Namecall Hook (Collision-Free Engine)
[+] Shift Lock Jump Fix (Pre-Jump Direction Lock)
[+] Max Charge Special (Ronin)
[+] Sanju Tilt
[+] Max Serve
[-] Stripped Premium Spikes (Free Edition)
[-] Cleaned Visual Clutter (ScoreEffect, ESP, PlayerCards)]], true)

ChangeLogRight:AddLabel("Hub: RZO HUB\nTarget: Volleyball Legends\nBranch: Free Edition\nEngine: Obsidian UI\nPlatform: Universal Luau", true)
ChangeLogRight:AddDivider()
ChangeLogRight:AddButton({
    Text = "Copy Discord Link",
    Func = function()
        setClipboardSafe("https://discord.gg/vNExQNRK3")
        notify("Discord", "Discord invite link copied to clipboard!", 2)
    end,
})

-- UI Settings Tab Groupboxes
local MenuGroup = Tabs["UI Settings"]:AddGroupbox({ Side = "Left", Name = "Menu Controls", IconName = "wrench" })
local ActionGroup = Tabs["UI Settings"]:AddGroupbox({ Side = "Right", Name = "Emergency & Actions", IconName = "alert-triangle" })

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
    removeHitboxes()
    for player in pairs(espHighlights) do pcall(removeESP, player) end
    for player in pairs(espPlayers) do pcall(removeESP2, player) end
end

ActionGroup:AddButton({
    Text = "Panic Mode (Disable All)",
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

        -- Sync UI toggles
        for _, toggleKey in ipairs({
            "sanju", "maxcharge",
            "antilag", "desync", "autoreceive", "akaridash",
            "maxserve", "airmove",
            "autoshiftlock", "autostyle", "autoabilityspin"
        }) do
            if Toggles[toggleKey] and Toggles[toggleKey].SetValue then
                Toggles[toggleKey]:SetValue(false)
            end
        end

        notify("Panic Mode", "All features disabled", 3)
    end,
})

ActionGroup:AddButton({
    Text = "Unload UI & Cleanup",
    Func = function()
        stableCleanup()
        Library:Unload()
    end,
})

ActionGroup:AddButton({
    Text = "Toggle Menu (Show/Hide)",
    Func = function()
        Library:Toggle()
    end,
})

ActionGroup:AddDivider()
ActionGroup:AddLabel("RZO HUB - Volleyball Legends\nUI migrated to Obsidian UI Library\nPress RightControl or custom bind to toggle UI", true)

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = false,
    Text = "Open Keybind Menu",
    Callback = function(value)
        if Library and Library.KeybindFrame then
            Library.KeybindFrame.Visible = value
        end
    end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = Library.ShowCustomCursor,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})

MenuGroup:AddToggle("AlwaysOnTop", {
    Text = "Always On Top",
    Default = Window.AlwaysOnTop,
    Callback = function(Value)
        Window:SetAlwaysOnTop(Value)
    end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        local DPI = tonumber(Value)
        if DPI then
            Library:SetDPIScale(DPI)
        end
    end,
})

MenuGroup:AddSlider("UICornerSlider", {
    Text = "Corner Radius",
    Default = Library.CornerRadius,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(value)
        Window:SetCornerRadius(value)
    end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

-- Theme & Config Managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("RzoHub")
SaveManager:SetFolder("RzoHub/VolleyballLegends")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"], "palette")

SaveManager:LoadAutoloadConfig()

pcall(function()
    if Library then
        if Library.KeybindFrame then
            Library.KeybindFrame.Visible = false
        end
        if Library.SetWatermarkVisibility then
            Library:SetWatermarkVisibility(false)
        end
    end
end)

-- Force open Obsidian menu on load
    task.defer(function()
        task.wait(0.25)
        pcall(function()
            if Library and Library.Toggle then
                Library:Toggle(true)
            end
        end)
    end)

    notify("RZO HUB", "ADDING VOLLEYBALLLEGENDS - Loaded successfully!", 3)
end

-- Launch VBL License Authentication Gateway asynchronously
task.spawn(function()
    print("[RZO HUB] Initializing VBL client gateway...")
    local ok, err = pcall(function()
        launchKeyGateway(function(key, data)
            local hubOk, hubErr = pcall(LoadMainHub)
            if not hubOk then
                warn("[RZO HUB ERROR] Failed to load main hub:", tostring(hubErr))
                local parent = getSafeGuiParent()
                if parent then
                    local fallbackGui = Instance.new("ScreenGui")
                    fallbackGui.Name = "RzoHub_ErrorNotice"
                    fallbackGui.DisplayOrder = 999999
                    fallbackGui.Parent = parent
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(0, 420, 0, 90)
                    label.Position = UDim2.new(0.5, -210, 0.2, 0)
                    label.BackgroundColor3 = Color3.fromRGB(35, 10, 15)
                    label.TextColor3 = Color3.fromRGB(255, 120, 120)
                    label.Text = "[RZO HUB LOAD ERROR]\n" .. tostring(hubErr)
                    label.TextWrapped = true
                    label.Font = Enum.Font.Code
                    label.TextSize = 12
                    label.Parent = fallbackGui
                end
            end
        end)
    end)
    if not ok then
        warn("[RZO HUB CRITICAL ERROR] Gateway failed to launch:", tostring(err))
    end
end)
