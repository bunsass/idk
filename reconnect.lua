-- ========================================
-- MOBILE-OPTIMIZED AUTO-RECONNECT DASHBOARD
-- ========================================
-- Put this in your Delta autoexec folder!
-- Make sure "Verify Teleports" is OFF in Delta settings
-- ========================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- CONFIGURATION (saved between sessions)
-- ========================================
local Config = {
    webhookUrl = "",
    placeId = "12886143095",
    maxTimeInServer = 60,
    autoReconnect = true,
    guiVisible = true,
    verboseLogging = false,
    enableMaxTime = false
}

-- ========================================
-- PERSISTENT STORAGE FUNCTIONS
-- ========================================
local configFileName = "reconnect_config.json"
local hasWriteFile = writefile ~= nil
local hasReadFile = readfile ~= nil

local Logs = {}
local Stats = {
    timeInServer = 0,
    totalReconnects = 0,
    lastReconnect = nil,
    status = "Active"
}

local isTeleporting = false
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function addLog(type, message)
    table.insert(Logs, 1, {
        time = os.time(),
        type = type,
        message = message
    })
    
    if #Logs > 50 then
        table.remove(Logs, #Logs)
    end
    
    print("[" .. type:upper() .. "] " .. message)
end

local function saveConfig()
    if not hasWriteFile then
        addLog("warning", "writefile() not available in this executor")
        return
    end
    
    local success, err = pcall(function()
        local configData = HttpService:JSONEncode(Config)
        writefile(configFileName, configData)
    end)
    
    if success then
        addLog("success", "Settings saved!")
    else
        addLog("error", "Failed to save: " .. tostring(err))
    end
end

local function loadConfig()
    if not hasReadFile then
        addLog("info", "readfile() not available, using defaults")
        return
    end
    
    local success, result = pcall(function()
        local configData = readfile(configFileName)
        local loaded = HttpService:JSONDecode(configData)
        
        for key, value in pairs(loaded) do
            Config[key] = value
        end
        
        return true
    end)
    
    if success and result then
        addLog("success", "Settings loaded from file!")
    else
        addLog("info", "No saved settings found, using defaults")
    end
end

local function sendWebhook(message, color)
    if Config.webhookUrl == "" or Config.webhookUrl == "YOUR_WEBHOOK_URL_HERE" then
        return
    end
    
    pcall(function()
        local embed = {
            ["embeds"] = {{
                ["description"] = message,
                ["color"] = color or 3447003,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                ["footer"] = {
                    ["text"] = "Auto-Reconnect Dashboard"
                }
            }}
        }
        
        request({
            Url = Config.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(embed)
        })
    end)
end

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

local function reconnect(reason)
    if isTeleporting then
        addLog("warning", "Reconnect already in progress!")
        return
    end
    
    isTeleporting = true
    Stats.status = "Reconnecting"
    Stats.totalReconnects = Stats.totalReconnects + 1
    Stats.lastReconnect = os.time()
    
    addLog("warning", "Reconnecting: " .. reason)
    sendWebhook("🔄 Reconnecting - " .. reason, 16776960)
    
    task.wait(0.5)
    
    local success, err = pcall(function()
        TeleportService:Teleport(tonumber(Config.placeId))
    end)
    
    if not success then
        addLog("error", "Reconnect failed: " .. tostring(err))
        sendWebhook("❌ Reconnect failed: " .. tostring(err), 15158332)
        isTeleporting = false
        Stats.status = "Error"
    else
        addLog("success", "Reconnect initiated!")
        sendWebhook("✅ Reconnect successful!", 3066993)
    end
end

-- ========================================
-- MOBILE-OPTIMIZED UI CREATION
-- ========================================
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoReconnectDashboard"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    
    -- Detect screen size for responsive design
    local ViewportSize = workspace.CurrentCamera.ViewportSize
    local isSmallScreen = ViewportSize.X < 600 or ViewportSize.Y < 600
    
    -- Adjusted sizes for mobile
    local guiWidth = isMobile and math.min(ViewportSize.X - 20, 380) or 450
    local guiHeight = isMobile and math.min(ViewportSize.Y - 100, 550) or 500
    
    -- Main Container
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.Size = UDim2.new(0, guiWidth, 0, guiHeight)
    MainFrame.Active = true
    MainFrame.ClipsDescendants = true
    
    -- Make draggable only on PC
    if not isMobile then
        MainFrame.Draggable = true
    end
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, isMobile and 12 or 10)
    MainCorner.Parent = MainFrame
    
    -- Gradient Background
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 40))
    }
    Gradient.Rotation = 90
    Gradient.Parent = MainFrame
    
    -- Header
    local headerHeight = isMobile and 55 or 50
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = MainFrame
    Header.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    Header.BorderSizePixel = 0
    Header.Size = UDim2.new(1, 0, 0, headerHeight)
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, isMobile and 12 or 10)
    HeaderCorner.Parent = Header
    
    -- Accent line
    local AccentLine = Instance.new("Frame")
    AccentLine.Name = "AccentLine"
    AccentLine.Parent = Header
    AccentLine.BackgroundColor3 = Color3.fromRGB(120, 100, 255)
    AccentLine.BorderSizePixel = 0
    AccentLine.Position = UDim2.new(0, 0, 1, -3)
    AccentLine.Size = UDim2.new(1, 0, 0, 3)
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = Header
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.Size = UDim2.new(1, -120, 1, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🔄 Auto-Reconnect"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = isMobile and 16 or 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextScaled = isMobile
    
    -- Minimize Button (larger on mobile)
    local buttonSize = isMobile and 38 or 30
    local MinButton = Instance.new("TextButton")
    MinButton.Name = "MinButton"
    MinButton.Parent = Header
    MinButton.AnchorPoint = Vector2.new(1, 0.5)
    MinButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    MinButton.Position = UDim2.new(1, -(buttonSize + 15), 0.5, 0)
    MinButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
    MinButton.Font = Enum.Font.GothamBold
    MinButton.Text = "−"
    MinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinButton.TextSize = isMobile and 20 : 18
    MinButton.AutoButtonColor = false
    
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 8)
    MinCorner.Parent = MinButton
    
    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Parent = Header
    CloseButton.AnchorPoint = Vector2.new(1, 0.5)
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseButton.Position = UDim2.new(1, -10, 0.5, 0)
    CloseButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "×"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = isMobile and 24 or 20
    CloseButton.AutoButtonColor = false
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    -- Mini Toggle Button (larger on mobile)
    local miniSize = isMobile and 70 or 60
    local MiniButton = Instance.new("ImageButton")
    MiniButton.Name = "MiniButton"
    MiniButton.Parent = ScreenGui
    MiniButton.AnchorPoint = Vector2.new(0, 0)
    MiniButton.BackgroundColor3 = Color3.fromRGB(120, 100, 255)
    MiniButton.Position = UDim2.new(0, 10, 0, 10)
    MiniButton.Size = UDim2.new(0, miniSize, 0, miniSize)
    MiniButton.Visible = false
    MiniButton.Active = true
    MiniButton.Image = ""
    
    -- Make mini button draggable on mobile
    if isMobile then
        MiniButton.Draggable = true
    end
    
    local MiniCorner = Instance.new("UICorner")
    MiniCorner.CornerRadius = UDim.new(0, 14)
    MiniCorner.Parent = MiniButton
    
    local MiniIcon = Instance.new("TextLabel")
    MiniIcon.Parent = MiniButton
    MiniIcon.BackgroundTransparency = 1
    MiniIcon.Size = UDim2.new(1, 0, 0.6, 0)
    MiniIcon.Position = UDim2.new(0, 0, 0, 5)
    MiniIcon.Font = Enum.Font.GothamBold
    MiniIcon.Text = "🔄"
    MiniIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    MiniIcon.TextSize = isMobile and 28 or 24
    
    local MiniLabel = Instance.new("TextLabel")
    MiniLabel.Parent = MiniButton
    MiniLabel.BackgroundTransparency = 1
    MiniLabel.Size = UDim2.new(1, 0, 0.35, 0)
    MiniLabel.Position = UDim2.new(0, 0, 0.65, 0)
    MiniLabel.Font = Enum.Font.GothamBold
    MiniLabel.Text = "Dashboard"
    MiniLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MiniLabel.TextSize = isMobile and 10 or 9
    
    MinButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniButton.Visible = true
    end)
    
    MiniButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        MiniButton.Visible = false
    end)
    
    -- Content Area
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Parent = MainFrame
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Position = UDim2.new(0, 0, 0, headerHeight)
    ContentFrame.Size = UDim2.new(1, 0, 1, -headerHeight)
    ContentFrame.ClipsDescendants = true
    
    -- Tab System (simplified for mobile)
    local tabHeight = isMobile and 48 or 40
    local TabBar = Instance.new("Frame")
    TabBar.Name = "TabBar"
    TabBar.Parent = ContentFrame
    TabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    TabBar.BorderSizePixel = 0
    TabBar.Size = UDim2.new(1, 0, 0, tabHeight)
    
    local TabBarLayout = Instance.new("UIListLayout")
    TabBarLayout.Parent = TabBar
    TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
    TabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabBarLayout.Padding = UDim.new(0, isMobile and 8 or 5)
    
    local TabPadding = Instance.new("UIPadding")
    TabPadding.Parent = TabBar
    TabPadding.PaddingLeft = UDim.new(0, 10)
    TabPadding.PaddingRight = UDim.new(0, 10)
    TabPadding.PaddingTop = UDim.new(0, isMobile and 8 or 5)
    
    -- Dashboard Tab
    local DashboardTab = Instance.new("Frame")
    DashboardTab.Name = "DashboardTab"
    DashboardTab.Parent = ContentFrame
    DashboardTab.BackgroundTransparency = 1
    DashboardTab.Position = UDim2.new(0, 0, 0, tabHeight + 5)
    DashboardTab.Size = UDim2.new(1, 0, 1, -(tabHeight + 5))
    DashboardTab.Visible = true
    
    local DashScroll = Instance.new("ScrollingFrame")
    DashScroll.Parent = DashboardTab
    DashScroll.BackgroundTransparency = 1
    DashScroll.BorderSizePixel = 0
    DashScroll.Size = UDim2.new(1, 0, 1, 0)
    DashScroll.ScrollBarThickness = isMobile and 6 or 4
    DashScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 100, 255)
    DashScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    DashScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    DashScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    
    local DashLayout = Instance.new("UIListLayout")
    DashLayout.Parent = DashScroll
    DashLayout.SortOrder = Enum.SortOrder.LayoutOrder
    DashLayout.Padding = UDim.new(0, isMobile and 12 or 10)
    
    local DashPadding = Instance.new("UIPadding")
    DashPadding.Parent = DashScroll
    DashPadding.PaddingTop = UDim.new(0, 10)
    DashPadding.PaddingBottom = UDim.new(0, 10)
    DashPadding.PaddingLeft = UDim.new(0, isMobile and 12 or 15)
    DashPadding.PaddingRight = UDim.new(0, isMobile and 12 or 15)
    
    -- Stats Container (adjusted for mobile)
    local StatsContainer = Instance.new("Frame")
    StatsContainer.Name = "StatsContainer"
    StatsContainer.Parent = DashScroll
    StatsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    StatsContainer.BorderSizePixel = 0
    StatsContainer.Size = UDim2.new(1, 0, 0, isMobile and 180 or 160)
    
    local StatsCorner = Instance.new("UICorner")
    StatsCorner.CornerRadius = UDim.new(0, 8)
    StatsCorner.Parent = StatsContainer
    
    local StatsLayout = Instance.new("UIGridLayout")
    StatsLayout.Parent = StatsContainer
    StatsLayout.CellSize = UDim2.new(0.5, -7.5, 0, isMobile and 80 or 70)
    StatsLayout.CellPadding = UDim2.new(0, 5, 0, 5)
    StatsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local StatsPadding = Instance.new("UIPadding")
    StatsPadding.Parent = StatsContainer
    StatsPadding.PaddingTop = UDim.new(0, 10)
    StatsPadding.PaddingBottom = UDim.new(0, 10)
    StatsPadding.PaddingLeft = UDim.new(0, 10)
    StatsPadding.PaddingRight = UDim.new(0, 10)
    
    -- Helper function to create stat cards
    local function createStatCard(icon, label, value, color, parent)
        local Card = Instance.new("Frame")
        Card.Parent = parent
        Card.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        Card.BorderSizePixel = 0
        
        local CardCorner = Instance.new("UICorner")
        CardCorner.CornerRadius = UDim.new(0, 6)
        CardCorner.Parent = Card
        
        local IconLabel = Instance.new("TextLabel")
        IconLabel.Parent = Card
        IconLabel.BackgroundTransparency = 1
        IconLabel.Position = UDim2.new(0, 10, 0, 8)
        IconLabel.Size = UDim2.new(0, 20, 0, 20)
        IconLabel.Font = Enum.Font.GothamBold
        IconLabel.Text = icon
        IconLabel.TextColor3 = color
        IconLabel.TextSize = isMobile and 18 or 16
        
        local LabelText = Instance.new("TextLabel")
        LabelText.Parent = Card
        LabelText.BackgroundTransparency = 1
        LabelText.Position = UDim2.new(0, 35, 0, 8)
        LabelText.Size = UDim2.new(1, -40, 0, 20)
        LabelText.Font = Enum.Font.Gotham
        LabelText.Text = label
        LabelText.TextColor3 = Color3.fromRGB(150, 150, 150)
        LabelText.TextSize = isMobile and 12 or 11
        LabelText.TextXAlignment = Enum.TextXAlignment.Left
        
        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Name = "Value"
        ValueLabel.Parent = Card
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Position = UDim2.new(0, 10, 0, isMobile and 38 or 32)
        ValueLabel.Size = UDim2.new(1, -20, 0, isMobile and 35 or 30)
        ValueLabel.Font = Enum.Font.GothamBold
        ValueLabel.Text = value
        ValueLabel.TextColor3 = color
        ValueLabel.TextSize = isMobile and 22 or 20
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Left
        ValueLabel.TextScaled = isMobile
        
        return ValueLabel
    end
    
    -- Create stat cards
    local TimeValue = createStatCard("⏱️", "Time in Server", "00:00:00", Color3.fromRGB(100, 220, 150), StatsContainer)
    local ReconnectsValue = createStatCard("🔄", "Total Reconnects", "0", Color3.fromRGB(100, 150, 255), StatsContainer)
    local StatusValue = createStatCard("📡", "Status", "Active", Color3.fromRGB(100, 220, 150), StatsContainer)
    
    -- Progress Bar
    local ProgressContainer = Instance.new("Frame")
    ProgressContainer.Name = "ProgressContainer"
    ProgressContainer.Parent = DashScroll
    ProgressContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    ProgressContainer.BorderSizePixel = 0
    ProgressContainer.Size = UDim2.new(1, 0, 0, isMobile and 70 or 60)
    
    local ProgressCorner = Instance.new("UICorner")
    ProgressCorner.CornerRadius = UDim.new(0, 8)
    ProgressCorner.Parent = ProgressContainer
    
    local ProgressLabel = Instance.new("TextLabel")
    ProgressLabel.Name = "ProgressLabel"
    ProgressLabel.Parent = ProgressContainer
    ProgressLabel.BackgroundTransparency = 1
    ProgressLabel.Position = UDim2.new(0, 15, 0, 10)
    ProgressLabel.Size = UDim2.new(1, -30, 0, 15)
    ProgressLabel.Font = Enum.Font.GothamBold
    ProgressLabel.Text = "Time Progress"
    ProgressLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    ProgressLabel.TextSize = isMobile and 13 or 12
    ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local ProgressBG = Instance.new("Frame")
    ProgressBG.Name = "ProgressBG"
    ProgressBG.Parent = ProgressContainer
    ProgressBG.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    ProgressBG.Position = UDim2.new(0, 15, 0, isMobile and 35 or 32)
    ProgressBG.Size = UDim2.new(1, -30, 0, isMobile and 8 or 6)
    
    local ProgressBGCorner = Instance.new("UICorner")
    ProgressBGCorner.CornerRadius = UDim.new(1, 0)
    ProgressBGCorner.Parent = ProgressBG
    
    local ProgressBar = Instance.new("Frame")
    ProgressBar.Name = "ProgressBar"
    ProgressBar.Parent = ProgressBG
    ProgressBar.BackgroundColor3 = Color3.fromRGB(120, 100, 255)
    ProgressBar.BorderSizePixel = 0
    ProgressBar.Size = UDim2.new(0, 0, 1, 0)
    
    local ProgressBarCorner = Instance.new("UICorner")
    ProgressBarCorner.CornerRadius = UDim.new(1, 0)
    ProgressBarCorner.Parent = ProgressBar
    
    local ProgressText = Instance.new("TextLabel")
    ProgressText.Name = "ProgressText"
    ProgressText.Parent = ProgressContainer
    ProgressText.BackgroundTransparency = 1
    ProgressText.Position = UDim2.new(0, 15, 0, isMobile and 48 or 42)
    ProgressText.Size = UDim2.new(1, -30, 0, 12)
    ProgressText.Font = Enum.Font.Gotham
    ProgressText.Text = "No time limit set"
    ProgressText.TextColor3 = Color3.fromRGB(120, 120, 120)
    ProgressText.TextSize = isMobile and 11 or 10
    ProgressText.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Action Button (larger on mobile)
    local ButtonsContainer = Instance.new("Frame")
    ButtonsContainer.Name = "ButtonsContainer"
    ButtonsContainer.Parent = DashScroll
    ButtonsContainer.BackgroundTransparency = 1
    ButtonsContainer.Size = UDim2.new(1, 0, 0, isMobile and 52 or 45)
    
    local ReconnectButton = Instance.new("TextButton")
    ReconnectButton.Name = "ReconnectButton"
    ReconnectButton.Parent = ButtonsContainer
    ReconnectButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    ReconnectButton.Size = UDim2.new(1, 0, 1, 0)
    ReconnectButton.Font = Enum.Font.GothamBold
    ReconnectButton.Text = "🔄 Reconnect Now"
    ReconnectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ReconnectButton.TextSize = isMobile and 16 or 14
    ReconnectButton.AutoButtonColor = false
    
    local ReconnectCorner = Instance.new("UICorner")
    ReconnectCorner.CornerRadius = UDim.new(0, 8)
    ReconnectCorner.Parent = ReconnectButton
    
    ReconnectButton.MouseButton1Click:Connect(function()
        reconnect("Manual reconnect")
    end)
    
    -- Logs Section
    local LogsHeader = Instance.new("TextLabel")
    LogsHeader.Name = "LogsHeader"
    LogsHeader.Parent = DashScroll
    LogsHeader.BackgroundTransparency = 1
    LogsHeader.Size = UDim2.new(1, 0, 0, isMobile and 28 or 25)
    LogsHeader.Font = Enum.Font.GothamBold
    LogsHeader.Text = "📋 Activity Logs"
    LogsHeader.TextColor3 = Color3.fromRGB(200, 200, 200)
    LogsHeader.TextSize = isMobile and 14 or 13
    LogsHeader.TextXAlignment = Enum.TextXAlignment.Left
    
    local LogsContainer = Instance.new("Frame")
    LogsContainer.Name = "LogsContainer"
    LogsContainer.Parent = DashScroll
    LogsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    LogsContainer.BorderSizePixel = 0
    LogsContainer.Size = UDim2.new(1, 0, 0, isMobile and 220 or 200)
    
    local LogsCorner = Instance.new("UICorner")
    LogsCorner.CornerRadius = UDim.new(0, 8)
    LogsCorner.Parent = LogsContainer
    
    local LogsScroll = Instance.new("ScrollingFrame")
    LogsScroll.Name = "LogsScroll"
    LogsScroll.Parent = LogsContainer
    LogsScroll.BackgroundTransparency = 1
    LogsScroll.Size = UDim2.new(1, 0, 1, 0)
    LogsScroll.ScrollBarThickness = isMobile and 6 or 4
    LogsScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 100, 255)
    LogsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    
    local LogsLayout = Instance.new("UIListLayout")
    LogsLayout.Parent = LogsScroll
    LogsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LogsLayout.Padding = UDim.new(0, isMobile and 6 or 5)
    
    local LogsPadding = Instance.new("UIPadding")
    LogsPadding.Parent = LogsScroll
    LogsPadding.PaddingTop = UDim.new(0, 10)
    LogsPadding.PaddingBottom = UDim.new(0, 10)
    LogsPadding.PaddingLeft = UDim.new(0, 10)
    LogsPadding.PaddingRight = UDim.new(0, 10)
    
    -- Settings Tab
    local SettingsTab = Instance.new("Frame")
    SettingsTab.Name = "SettingsTab"
    SettingsTab.Parent = ContentFrame
    SettingsTab.BackgroundTransparency = 1
    SettingsTab.Position = UDim2.new(0, 0, 0, tabHeight + 5)
    SettingsTab.Size = UDim2.new(1, 0, 1, -(tabHeight + 5))
    SettingsTab.Visible = false
    
    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Parent = SettingsTab
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.BorderSizePixel = 0
    SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
    SettingsScroll.ScrollBarThickness = isMobile and 6 or 4
    SettingsScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 100, 255)
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SettingsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    
    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Parent = SettingsScroll
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.Padding = UDim.new(0, isMobile and 12 or 10)
    
    local SettingsPadding = Instance.new("UIPadding")
    SettingsPadding.Parent = SettingsScroll
    SettingsPadding.PaddingTop = UDim.new(0, 15)
    SettingsPadding.PaddingBottom = UDim.new(0, 15)
    SettingsPadding.PaddingLeft = UDim.new(0, isMobile and 12 or 15)
    SettingsPadding.PaddingRight = UDim.new(0, isMobile and 12 or 15)
    
    -- Helper function to create settings
    local function createSetting(name, type, description, defaultValue)
        local settingHeight = isMobile and 85 or 75
        
        local Setting = Instance.new("Frame")
        Setting.Name = name
        Setting.Parent = SettingsScroll
        Setting.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        Setting.BorderSizePixel = 0
        Setting.Size = UDim2.new(1, 0, 0, settingHeight)
        
        local SettingCorner = Instance.new("UICorner")
        SettingCorner.CornerRadius = UDim.new(0, 8)
        SettingCorner.Parent = Setting
        
        local NameLabel = Instance.new("TextLabel")
        NameLabel.Parent = Setting
        NameLabel.BackgroundTransparency = 1
        NameLabel.Position = UDim2.new(0, 12, 0, 8)
        NameLabel.Size = UDim2.new(1, -24, 0, 18)
        NameLabel.Font = Enum.Font.GothamBold
        NameLabel.Text = name
        NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        NameLabel.TextSize = isMobile and 14 or 13
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local DescLabel = Instance.new("TextLabel")
        DescLabel.Parent = Setting
        DescLabel.BackgroundTransparency = 1
        DescLabel.Position = UDim2.new(0, 12, 0, 28)
        DescLabel.Size = UDim2.new(1, -24, 0, 14)
        DescLabel.Font = Enum.Font.Gotham
        DescLabel.Text = description
        DescLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
        DescLabel.TextSize = isMobile and 11 or 10
        DescLabel.TextXAlignment = Enum.TextXAlignment.Left
        DescLabel.TextWrapped = true
        
        if type == "text" then
            local TextBox = Instance.new("TextBox")
            TextBox.Parent = Setting
            TextBox.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
            TextBox.Position = UDim2.new(0, 12, 0, isMobile and 50 or 45)
            TextBox.Size = UDim2.new(1, -24, 0, isMobile and 30 or 25)
            TextBox.Font = Enum.Font.Gotham
            TextBox.PlaceholderText = defaultValue
            TextBox.Text = defaultValue
            TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            TextBox.TextSize = isMobile and 12 or 11
            TextBox.ClearTextOnFocus = false
            TextBox.TextXAlignment = Enum.TextXAlignment.Left
            
            local TextBoxCorner = Instance.new("UICorner")
            TextBoxCorner.CornerRadius = UDim.new(0, 5)
            TextBoxCorner.Parent = TextBox
            
            local TextBoxPadding = Instance.new("UIPadding")
            TextBoxPadding.Parent = TextBox
            TextBoxPadding.PaddingLeft = UDim.new(0, 8)
            TextBoxPadding.PaddingRight = UDim.new(0, 8)
            
            TextBox.FocusLost:Connect(function()
                if name == "Discord Webhook" then
                    Config.webhookUrl = TextBox.Text
                elseif name == "Place ID" then
                    Config.placeId = TextBox.Text
                end
                saveConfig()
            end)
            
            return TextBox
            
        elseif type == "number" then
            local TextBox = Instance.new("TextBox")
            TextBox.Parent = Setting
            TextBox.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
            TextBox.Position = UDim2.new(0, 12, 0, isMobile and 50 or 45)
            TextBox.Size = UDim2.new(1, -24, 0, isMobile and 30 or 25)
            TextBox.Font = Enum.Font.Gotham
            TextBox.PlaceholderText = tostring(defaultValue)
            TextBox.Text = tostring(defaultValue)
            TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            TextBox.TextSize = isMobile and 12 or 11
            TextBox.ClearTextOnFocus = false
            TextBox.TextXAlignment = Enum.TextXAlignment.Left
            
            local TextBoxCorner = Instance.new("UICorner")
            TextBoxCorner.CornerRadius = UDim.new(0, 5)
            TextBoxCorner.Parent = TextBox
            
            local TextBoxPadding = Instance.new("UIPadding")
            TextBoxPadding.Parent = TextBox
            TextBoxPadding.PaddingLeft = UDim.new(0, 8)
            TextBoxPadding.PaddingRight = UDim.new(0, 8)
            
            TextBox.FocusLost:Connect(function()
                if name == "Max Time (minutes)" then
                    Config.maxTimeInServer = tonumber(TextBox.Text) or 0
                end
                saveConfig()
            end)
            
            return TextBox
            
        elseif type == "toggle" then
            local toggleWidth = isMobile and 60 or 50
            local toggleHeight = isMobile and 32 or 25
            
            local Toggle = Instance.new("TextButton")
            Toggle.Parent = Setting
            Toggle.AnchorPoint = Vector2.new(1, 0)
            Toggle.BackgroundColor3 = defaultValue and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(60, 60, 70)
            Toggle.Position = UDim2.new(1, -12, 0, isMobile and 50 or 45)
            Toggle.Size = UDim2.new(0, toggleWidth, 0, toggleHeight)
            Toggle.Font = Enum.Font.GothamBold
            Toggle.Text = defaultValue and "ON" or "OFF"
            Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            Toggle.TextSize = isMobile and 13 or 11
            Toggle.AutoButtonColor = false
            
            local ToggleCorner = Instance.new("UICorner")
            ToggleCorner.CornerRadius = UDim.new(0, 6)
            ToggleCorner.Parent = Toggle
            
            local toggleState = defaultValue
            Toggle.MouseButton1Click:Connect(function()
                toggleState = not toggleState
                Toggle.Text = toggleState and "ON" or "OFF"
                Toggle.BackgroundColor3 = toggleState and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(60, 60, 70)
                
                if name == "Auto Reconnect" then
                    Config.autoReconnect = toggleState
                elseif name == "Verbose Logging" then
                    Config.verboseLogging = toggleState
                elseif name == "Enable Max Time" then
                    Config.enableMaxTime = toggleState
                end
                saveConfig()
            end)
            
            return Toggle
        end
    end
    
    -- Create settings
    createSetting("Discord Webhook", "text", "Send logs to Discord (optional)", Config.webhookUrl)
    createSetting("Place ID", "text", "Game to reconnect to", Config.placeId)
    createSetting("Auto Reconnect", "toggle", "Automatically reconnect on disconnect", Config.autoReconnect)
    createSetting("Enable Max Time", "toggle", "Enable time-based reconnection", Config.enableMaxTime)
    createSetting("Max Time (minutes)", "number", "Minutes before auto-reconnect (0 = unlimited)", Config.maxTimeInServer)
    createSetting("Verbose Logging", "toggle", "Show detailed connection logs", Config.verboseLogging)
    
    -- Tab buttons
    local function createTabButton(text, targetTab)
        local tabWidth = isMobile and 110 or 100
        
        local TabButton = Instance.new("TextButton")
        TabButton.Parent = TabBar
        TabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        TabButton.Size = UDim2.new(0, tabWidth, 0, isMobile and 35 or 30)
        TabButton.Font = Enum.Font.GothamBold
        TabButton.Text = text
        TabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        TabButton.TextSize = isMobile and 13 or 12
        TabButton.AutoButtonColor = false
        
        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 6)
        TabCorner.Parent = TabButton
        
        TabButton.MouseButton1Click:Connect(function()
            DashboardTab.Visible = (targetTab == "dashboard")
            SettingsTab.Visible = (targetTab == "settings")
            
            -- Update button colors
            for _, btn in ipairs(TabBar:GetChildren()) do
                if btn:IsA("TextButton") then
                    if btn == TabButton then
                        btn.BackgroundColor3 = Color3.fromRGB(120, 100, 255)
                        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    else
                        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    end
                end
            end
        end)
        
        return TabButton
    end
    
    local DashTab = createTabButton("📊 Dashboard", "dashboard")
    local SetTab = createTabButton("⚙️ Settings", "settings")
    
    -- Set initial active tab
    DashTab.BackgroundColor3 = Color3.fromRGB(120, 100, 255)
    DashTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    -- Update functions
    local function updateLogs()
        for _, child in ipairs(LogsScroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        for i, log in ipairs(Logs) do
            local logHeight = isMobile and 52 or 45
            
            local LogEntry = Instance.new("Frame")
            LogEntry.Name = "LogEntry" .. i
            LogEntry.Parent = LogsScroll
            LogEntry.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            LogEntry.BorderSizePixel = 0
            LogEntry.Size = UDim2.new(1, 0, 0, logHeight)
            
            local LogCorner = Instance.new("UICorner")
            LogCorner.CornerRadius = UDim.new(0, 6)
            LogCorner.Parent = LogEntry
            
            local Icon = Instance.new("TextLabel")
            Icon.Parent = LogEntry
            Icon.BackgroundTransparency = 1
            Icon.Position = UDim2.new(0, 8, 0, 0)
            Icon.Size = UDim2.new(0, 30, 1, 0)
            Icon.Font = Enum.Font.GothamBold
            Icon.TextSize = isMobile and 18 or 16
            Icon.TextXAlignment = Enum.TextXAlignment.Center
            
            if log.type == "success" then
                Icon.Text = "✅"
                Icon.TextColor3 = Color3.fromRGB(100, 220, 150)
            elseif log.type == "warning" then
                Icon.Text = "⚠️"
                Icon.TextColor3 = Color3.fromRGB(255, 200, 100)
            elseif log.type == "error" then
                Icon.Text = "❌"
                Icon.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                Icon.Text = "ℹ️"
                Icon.TextColor3 = Color3.fromRGB(100, 150, 255)
            end
            
            local Message = Instance.new("TextLabel")
            Message.Parent = LogEntry
            Message.BackgroundTransparency = 1
            Message.Position = UDim2.new(0, 38, 0, 5)
            Message.Size = UDim2.new(1, -75, 0, isMobile and 24 : 20)
            Message.Font = Enum.Font.Gotham
            Message.Text = log.message
            Message.TextColor3 = Color3.fromRGB(220, 220, 220)
            Message.TextSize = isMobile and 12 or 11
            Message.TextXAlignment = Enum.TextXAlignment.Left
            Message.TextTruncate = Enum.TextTruncate.AtEnd
            
            local Time = Instance.new("TextLabel")
            Time.Parent = LogEntry
            Time.BackgroundTransparency = 1
            Time.Position = UDim2.new(0, 38, 0, isMobile and 29 or 25)
            Time.Size = UDim2.new(1, -45, 0, 15)
            Time.Font = Enum.Font.Gotham
            Time.Text = os.date("%H:%M:%S", log.time)
            Time.TextColor3 = Color3.fromRGB(100, 100, 100)
            Time.TextSize = isMobile and 10 or 9
            Time.TextXAlignment = Enum.TextXAlignment.Left
        end
    end
    
    local function updateStats()
        TimeValue.Text = formatTime(Stats.timeInServer)
        ReconnectsValue.Text = tostring(Stats.totalReconnects)
        StatusValue.Text = Stats.status
        
        if Config.enableMaxTime and Config.maxTimeInServer > 0 then
            local percentage = (Stats.timeInServer / (Config.maxTimeInServer * 60)) * 100
            
            if percentage >= 90 then
                TimeValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            elseif percentage >= 70 then
                TimeValue.TextColor3 = Color3.fromRGB(255, 200, 100)
            else
                TimeValue.TextColor3 = Color3.fromRGB(100, 220, 150)
            end
            
            ProgressBar.Size = UDim2.new(math.min(1, percentage / 100), 0, 1, 0)
            ProgressText.Text = string.format("%.1f%% - %d min remaining", 
                percentage, 
                math.max(0, Config.maxTimeInServer - math.floor(Stats.timeInServer / 60))
            )
        else
            TimeValue.TextColor3 = Color3.fromRGB(100, 150, 255)
            ProgressBar.Size = UDim2.new(0, 0, 1, 0)
            ProgressText.Text = Config.enableMaxTime and "Set max time in settings" or "Max time disabled"
        end
        
        if Stats.status == "Active" then
            StatusValue.TextColor3 = Color3.fromRGB(100, 220, 150)
        elseif Stats.status == "Reconnecting" then
            StatusValue.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            StatusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
    
    -- Main update loop
    task.spawn(function()
        while true do
            updateStats()
            updateLogs()
            task.wait(0.5)
        end
    end)
    
    -- Parent to PlayerGui
    if LocalPlayer:FindFirstChild("PlayerGui") then
        ScreenGui.Parent = LocalPlayer.PlayerGui
    else
        LocalPlayer:WaitForChild("PlayerGui")
        ScreenGui.Parent = LocalPlayer.PlayerGui
    end
    
    return ScreenGui
end

-- ========================================
-- DISCONNECT DETECTION
-- ========================================
GuiService.ErrorMessageChanged:Connect(function()
    local errorMsg = GuiService:GetErrorMessage()
    addLog("warning", "Disconnect detected: " .. tostring(errorMsg))
    
    if Config.autoReconnect then
        reconnect("Error message displayed")
    end
end)

-- ========================================
-- TIME MONITORING
-- ========================================
task.spawn(function()
    while true do
        task.wait(1)
        Stats.timeInServer = Stats.timeInServer + 1
        
        if Config.autoReconnect and Config.enableMaxTime and Config.maxTimeInServer > 0 then
            if Stats.timeInServer >= Config.maxTimeInServer * 60 then
                reconnect("Max time limit reached")
            end
        end
    end
end)

-- ========================================
-- CONNECTION HEALTH MONITOR
-- ========================================
local lastHeartbeat = tick()
local connectionWarningIssued = false

RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    local timeSinceLastBeat = currentTime - lastHeartbeat
    
    if timeSinceLastBeat > 5 and not connectionWarningIssued then
        if Config.verboseLogging then
            addLog("warning", string.format("Connection unstable! No heartbeat for %.1fs", timeSinceLastBeat))
            sendWebhook("⚠️ Connection unstable!", 16776960)
        end
        connectionWarningIssued = true
    end
    
    if timeSinceLastBeat > 10 and Config.autoReconnect then
        addLog("error", "Critical connection failure!")
        reconnect("Connection timeout")
    end
    
    lastHeartbeat = currentTime
    connectionWarningIssued = false
end)

-- ========================================
-- PLAYER REMOVING DETECTION
-- ========================================
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        local sessionTime = formatTime(Stats.timeInServer)
        addLog("info", "Session ended after " .. sessionTime)
        sendWebhook("⏱️ Session ended - Duration: " .. sessionTime, 3447003)
        
        if Config.autoReconnect then
            reconnect("Session ended, reconnecting...")
        end
    end
end)

-- ========================================
-- INITIALIZE
-- ========================================
print("========================================")
print("AUTO-RECONNECT DASHBOARD STARTING...")
print("========================================")

pcall(loadConfig)
pcall(function() addLog("success", "Auto-Reconnect Dashboard initializing...") end)
pcall(function() sendWebhook("✅ Auto-Reconnect Dashboard loaded!", 3066993) end)

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

task.wait(2)

local success, err = pcall(createGUI)

if not success then
    warn("Failed to create GUI:", err)
    return
end

addLog("success", "Dashboard ready! " .. (isMobile and "Tap minimize to hide." or "Click minimize to hide."))
addLog("info", "Place ID: " .. Config.placeId)
addLog("info", "Max time: " .. (Config.maxTimeInServer == 0 and "Unlimited" or Config.maxTimeInServer .. " minutes"))
addLog("info", "Auto-reconnect: " .. (Config.autoReconnect and "Enabled" or "Disabled"))

Stats.status = "Active"

print("========================================")
print("AUTO-RECONNECT DASHBOARD LOADED!")
print("Device: " .. (isMobile and "MOBILE" or "PC"))
print("Make sure 'Verify Teleports' is OFF in Delta settings!")
print("========================================")
