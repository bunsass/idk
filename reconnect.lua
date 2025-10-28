-- ========================================
-- AUTO-RECONNECT DASHBOARD GUI FOR ROBLOX
-- ========================================
-- Put this in your Delta autoexec folder!
-- Make sure "Verify Teleports" is OFF in Delta settings
-- ========================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- CONFIGURATION (saved between sessions)
-- ========================================
local Config = {
    webhookUrl = "",
    placeId = "12886143095",
    maxTimeInServer = 60, -- minutes (0 = unlimited)
    autoReconnect = true,
    guiVisible = true
}

-- ========================================
-- PERSISTENT STORAGE FUNCTIONS
-- ========================================
local configFileName = "reconnect_config.json"

local function saveConfig()
    local success, err = pcall(function()
        local configData = HttpService:JSONEncode(Config)
        writefile(configFileName, configData)
        addLog("success", "Settings saved!")
    end)
    
    if not success then
        addLog("error", "Failed to save settings: " .. tostring(err))
    end
end

local function loadConfig()
    local success, err = pcall(function()
        if isfile(configFileName) then
            local configData = readfile(configFileName)
            local loaded = HttpService:JSONDecode(configData)
            for key, value in pairs(loaded) do
                Config[key] = value
            end
            addLog("success", "Settings loaded from file!")
        else
            addLog("info", "No saved settings found, using defaults")
        end
    end)
    
    if not success then
        addLog("warning", "Could not load settings: " .. tostring(err))
    end
end

-- ========================================
-- STATS TRACKING
-- ========================================
local Stats = {
    timeInServer = 0,
    totalReconnects = 0,
    lastReconnect = nil,
    status = "Active"
}

local Logs = {}
local isTeleporting = false

-- ========================================
-- LOGGING SYSTEM
-- ========================================
local function addLog(type, message)
    table.insert(Logs, 1, {
        time = os.time(),
        type = type,
        message = message
    })
    
    -- Keep only last 50 logs
    if #Logs > 50 then
        table.remove(Logs, #Logs)
    end
    
    print("[" .. type:upper() .. "] " .. message)
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

-- ========================================
-- TELEPORT FUNCTION
-- ========================================
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
-- CREATE GUI
-- ========================================
local function createGUI()
    -- Create ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoReconnectDashboard"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
    MainFrame.Size = UDim2.new(0, 600, 0, 500)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    -- Corner
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = MainFrame
    
    -- Gradient
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 40))
    }
    Gradient.Rotation = 45
    Gradient.Parent = MainFrame
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = MainFrame
    Header.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
    Header.BorderSizePixel = 0
    Header.Size = UDim2.new(1, 0, 0, 60)
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 12)
    HeaderCorner.Parent = Header
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = Header
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.Size = UDim2.new(1, -120, 1, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🔄 Auto-Reconnect Dashboard"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 20
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Parent = Header
    CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseButton.Position = UDim2.new(1, -45, 0.5, -15)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    -- Minimize Button
    local MinButton = Instance.new("TextButton")
    MinButton.Name = "MinButton"
    MinButton.Parent = Header
    MinButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    MinButton.Position = UDim2.new(1, -80, 0.5, -15)
    MinButton.Size = UDim2.new(0, 30, 0, 30)
    MinButton.Font = Enum.Font.GothamBold
    MinButton.Text = "_"
    MinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinButton.TextSize = 16
    
    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 8)
    MinCorner.Parent = MinButton
    
    MinButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)
    
    -- Content Frame
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Parent = MainFrame
    Content.BackgroundTransparency = 1
    Content.Position = UDim2.new(0, 10, 0, 70)
    Content.Size = UDim2.new(1, -20, 1, -80)
    
    -- Stats Frame
    local StatsFrame = Instance.new("Frame")
    StatsFrame.Name = "StatsFrame"
    StatsFrame.Parent = Content
    StatsFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
    StatsFrame.BorderSizePixel = 0
    StatsFrame.Size = UDim2.new(1, 0, 0, 150)
    
    local StatsCorner = Instance.new("UICorner")
    StatsCorner.CornerRadius = UDim.new(0, 10)
    StatsCorner.Parent = StatsFrame
    
    -- Time Label
    local TimeLabel = Instance.new("TextLabel")
    TimeLabel.Name = "TimeLabel"
    TimeLabel.Parent = StatsFrame
    TimeLabel.BackgroundTransparency = 1
    TimeLabel.Position = UDim2.new(0, 20, 0, 15)
    TimeLabel.Size = UDim2.new(0.3, -30, 0, 25)
    TimeLabel.Font = Enum.Font.Gotham
    TimeLabel.Text = "⏱️ Time in Server"
    TimeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    TimeLabel.TextSize = 14
    TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local TimeValue = Instance.new("TextLabel")
    TimeValue.Name = "TimeValue"
    TimeValue.Parent = StatsFrame
    TimeValue.BackgroundTransparency = 1
    TimeValue.Position = UDim2.new(0, 20, 0, 40)
    TimeValue.Size = UDim2.new(0.3, -30, 0, 40)
    TimeValue.Font = Enum.Font.GothamBold
    TimeValue.Text = "00:00:00"
    TimeValue.TextColor3 = Color3.fromRGB(100, 255, 150)
    TimeValue.TextSize = 24
    TimeValue.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Reconnects Label
    local ReconnectsLabel = Instance.new("TextLabel")
    ReconnectsLabel.Name = "ReconnectsLabel"
    ReconnectsLabel.Parent = StatsFrame
    ReconnectsLabel.BackgroundTransparency = 1
    ReconnectsLabel.Position = UDim2.new(0.33, 10, 0, 15)
    ReconnectsLabel.Size = UDim2.new(0.3, -30, 0, 25)
    ReconnectsLabel.Font = Enum.Font.Gotham
    ReconnectsLabel.Text = "🔄 Total Reconnects"
    ReconnectsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    ReconnectsLabel.TextSize = 14
    ReconnectsLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local ReconnectsValue = Instance.new("TextLabel")
    ReconnectsValue.Name = "ReconnectsValue"
    ReconnectsValue.Parent = StatsFrame
    ReconnectsValue.BackgroundTransparency = 1
    ReconnectsValue.Position = UDim2.new(0.33, 10, 0, 40)
    ReconnectsValue.Size = UDim2.new(0.3, -30, 0, 40)
    ReconnectsValue.Font = Enum.Font.GothamBold
    ReconnectsValue.Text = "0"
    ReconnectsValue.TextColor3 = Color3.fromRGB(100, 150, 255)
    ReconnectsValue.TextSize = 24
    ReconnectsValue.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = StatsFrame
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0.66, 10, 0, 15)
    StatusLabel.Size = UDim2.new(0.34, -30, 0, 25)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "📡 Status"
    StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local StatusValue = Instance.new("TextLabel")
    StatusValue.Name = "StatusValue"
    StatusValue.Parent = StatsFrame
    StatusValue.BackgroundTransparency = 1
    StatusValue.Position = UDim2.new(0.66, 10, 0, 40)
    StatusValue.Size = UDim2.new(0.34, -30, 0, 40)
    StatusValue.Font = Enum.Font.GothamBold
    StatusValue.Text = "Active"
    StatusValue.TextColor3 = Color3.fromRGB(100, 255, 150)
    StatusValue.TextSize = 20
    StatusValue.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Progress Bar
    local ProgressBG = Instance.new("Frame")
    ProgressBG.Name = "ProgressBG"
    ProgressBG.Parent = StatsFrame
    ProgressBG.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
    ProgressBG.Position = UDim2.new(0, 20, 0, 95)
    ProgressBG.Size = UDim2.new(1, -40, 0, 8)
    
    local ProgressCorner = Instance.new("UICorner")
    ProgressCorner.CornerRadius = UDim.new(1, 0)
    ProgressCorner.Parent = ProgressBG
    
    local ProgressBar = Instance.new("Frame")
    ProgressBar.Name = "ProgressBar"
    ProgressBar.Parent = ProgressBG
    ProgressBar.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
    ProgressBar.BorderSizePixel = 0
    ProgressBar.Size = UDim2.new(0, 0, 1, 0)
    
    local ProgressBarCorner = Instance.new("UICorner")
    ProgressBarCorner.CornerRadius = UDim.new(1, 0)
    ProgressBarCorner.Parent = ProgressBar
    
    local ProgressText = Instance.new("TextLabel")
    ProgressText.Name = "ProgressText"
    ProgressText.Parent = StatsFrame
    ProgressText.BackgroundTransparency = 1
    ProgressText.Position = UDim2.new(0, 20, 0, 110)
    ProgressText.Size = UDim2.new(1, -40, 0, 20)
    ProgressText.Font = Enum.Font.Gotham
    ProgressText.Text = "No time limit set"
    ProgressText.TextColor3 = Color3.fromRGB(150, 150, 150)
    ProgressText.TextSize = 12
    ProgressText.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Reconnect Button
    local ReconnectButton = Instance.new("TextButton")
    ReconnectButton.Name = "ReconnectButton"
    ReconnectButton.Parent = Content
    ReconnectButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    ReconnectButton.Position = UDim2.new(0, 0, 0, 160)
    ReconnectButton.Size = UDim2.new(0.48, 0, 0, 40)
    ReconnectButton.Font = Enum.Font.GothamBold
    ReconnectButton.Text = "🔄 Reconnect Now"
    ReconnectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ReconnectButton.TextSize = 16
    
    local ReconnectCorner = Instance.new("UICorner")
    ReconnectCorner.CornerRadius = UDim.new(0, 10)
    ReconnectCorner.Parent = ReconnectButton
    
    ReconnectButton.MouseButton1Click:Connect(function()
        reconnect("Manual reconnect")
    end)
    
    -- Settings Button
    local SettingsButton = Instance.new("TextButton")
    SettingsButton.Name = "SettingsButton"
    SettingsButton.Parent = Content
    SettingsButton.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
    SettingsButton.Position = UDim2.new(0.52, 0, 0, 160)
    SettingsButton.Size = UDim2.new(0.48, 0, 0, 40)
    SettingsButton.Font = Enum.Font.GothamBold
    SettingsButton.Text = "⚙️ Settings"
    SettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SettingsButton.TextSize = 16
    
    local SettingsCorner = Instance.new("UICorner")
    SettingsCorner.CornerRadius = UDim.new(0, 10)
    SettingsCorner.Parent = SettingsButton
    
    -- Log Frame
    local LogFrame = Instance.new("ScrollingFrame")
    LogFrame.Name = "LogFrame"
    LogFrame.Parent = Content
    LogFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
    LogFrame.BorderSizePixel = 0
    LogFrame.Position = UDim2.new(0, 0, 0, 210)
    LogFrame.Size = UDim2.new(1, 0, 1, -210)
    LogFrame.ScrollBarThickness = 6
    LogFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local LogCorner = Instance.new("UICorner")
    LogCorner.CornerRadius = UDim.new(0, 10)
    LogCorner.Parent = LogFrame
    
    local LogList = Instance.new("UIListLayout")
    LogList.Parent = LogFrame
    LogList.SortOrder = Enum.SortOrder.LayoutOrder
    LogList.Padding = UDim.new(0, 5)
    
    local LogPadding = Instance.new("UIPadding")
    LogPadding.Parent = LogFrame
    LogPadding.PaddingTop = UDim.new(0, 10)
    LogPadding.PaddingBottom = UDim.new(0, 10)
    LogPadding.PaddingLeft = UDim.new(0, 10)
    LogPadding.PaddingRight = UDim.new(0, 10)
    
    -- Settings Panel
    local SettingsPanel = Instance.new("Frame")
    SettingsPanel.Name = "SettingsPanel"
    SettingsPanel.Parent = MainFrame
    SettingsPanel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
    SettingsPanel.BorderSizePixel = 0
    SettingsPanel.Position = UDim2.new(0, 10, 0, 70)
    SettingsPanel.Size = UDim2.new(1, -20, 1, -80)
    SettingsPanel.Visible = false
    
    local SettingsPanelCorner = Instance.new("UICorner")
    SettingsPanelCorner.CornerRadius = UDim.new(0, 10)
    SettingsPanelCorner.Parent = SettingsPanel
    
    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Parent = SettingsPanel
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
    SettingsScroll.ScrollBarThickness = 6
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
    
    local SettingsList = Instance.new("UIListLayout")
    SettingsList.Parent = SettingsScroll
    SettingsList.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsList.Padding = UDim.new(0, 15)
    
    local SettingsPadding = Instance.new("UIPadding")
    SettingsPadding.Parent = SettingsScroll
    SettingsPadding.PaddingTop = UDim.new(0, 15)
    SettingsPadding.PaddingBottom = UDim.new(0, 15)
    SettingsPadding.PaddingLeft = UDim.new(0, 15)
    SettingsPadding.PaddingRight = UDim.new(0, 15)
    
    -- Helper function to create settings
    local function createSetting(name, type, defaultValue, description)
        local Setting = Instance.new("Frame")
        Setting.Name = name
        Setting.Parent = SettingsScroll
        Setting.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
        Setting.BorderSizePixel = 0
        Setting.Size = UDim2.new(1, -30, 0, 80)
        
        local SettingCorner = Instance.new("UICorner")
        SettingCorner.CornerRadius = UDim.new(0, 8)
        SettingCorner.Parent = Setting
        
        local NameLabel = Instance.new("TextLabel")
        NameLabel.Parent = Setting
        NameLabel.BackgroundTransparency = 1
        NameLabel.Position = UDim2.new(0, 15, 0, 10)
        NameLabel.Size = UDim2.new(1, -30, 0, 20)
        NameLabel.Font = Enum.Font.GothamBold
        NameLabel.Text = name
        NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        NameLabel.TextSize = 14
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local DescLabel = Instance.new("TextLabel")
        DescLabel.Parent = Setting
        DescLabel.BackgroundTransparency = 1
        DescLabel.Position = UDim2.new(0, 15, 0, 30)
        DescLabel.Size = UDim2.new(1, -30, 0, 15)
        DescLabel.Font = Enum.Font.Gotham
        DescLabel.Text = description
        DescLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        DescLabel.TextSize = 11
        DescLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        if type == "text" then
            local TextBox = Instance.new("TextBox")
            TextBox.Parent = Setting
            TextBox.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
            TextBox.Position = UDim2.new(0, 15, 0, 50)
            TextBox.Size = UDim2.new(1, -30, 0, 25)
            TextBox.Font = Enum.Font.Gotham
            TextBox.PlaceholderText = defaultValue
            TextBox.Text = defaultValue
            TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            TextBox.TextSize = 12
            TextBox.ClearTextOnFocus = false
            
            local TextBoxCorner = Instance.new("UICorner")
            TextBoxCorner.CornerRadius = UDim.new(0, 6)
            TextBoxCorner.Parent = TextBox
            
            return TextBox
        elseif type == "number" then
            local TextBox = Instance.new("TextBox")
            TextBox.Parent = Setting
            TextBox.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
            TextBox.Position = UDim2.new(0, 15, 0, 50)
            TextBox.Size = UDim2.new(1, -30, 0, 25)
            TextBox.Font = Enum.Font.Gotham
            TextBox.PlaceholderText = tostring(defaultValue)
            TextBox.Text = tostring(defaultValue)
            TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            TextBox.TextSize = 12
            TextBox.ClearTextOnFocus = false
            
            local TextBoxCorner = Instance.new("UICorner")
            TextBoxCorner.CornerRadius = UDim.new(0, 6)
            TextBoxCorner.Parent = TextBox
            
            return TextBox
        elseif type == "toggle" then
            local Toggle = Instance.new("TextButton")
            Toggle.Parent = Setting
            Toggle.BackgroundColor3 = defaultValue and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(100, 100, 100)
            Toggle.Position = UDim2.new(1, -70, 0, 50)
            Toggle.Size = UDim2.new(0, 50, 0, 25)
            Toggle.Font = Enum.Font.GothamBold
            Toggle.Text = defaultValue and "ON" or "OFF"
            Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            Toggle.TextSize = 12
            
            local ToggleCorner = Instance.new("UICorner")
            ToggleCorner.CornerRadius = UDim.new(0, 6)
            ToggleCorner.Parent = Toggle
            
            local toggleState = defaultValue
            Toggle.MouseButton1Click:Connect(function()
                toggleState = not toggleState
                Toggle.Text = toggleState and "ON" or "OFF"
                Toggle.BackgroundColor3 = toggleState and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(100, 100, 100)
            end)
            
            return Toggle
        end
    end
    
    -- Create settings
    local WebhookBox = createSetting("Discord Webhook", "text", Config.webhookUrl, "Send logs to Discord webhook")
    local PlaceIDBox = createSetting("Place ID", "text", Config.placeId, "Game place ID to reconnect to")
    local MaxTimeBox = createSetting("Max Time (minutes)", "number", Config.maxTimeInServer, "Auto-reconnect after this time (0 = unlimited)")
    local AutoReconnectToggle = createSetting("Auto Reconnect", "toggle", Config.autoReconnect, "Automatically reconnect on disconnect")
    
    -- Save Settings Button
    local SaveButton = Instance.new("TextButton")
    SaveButton.Parent = SettingsScroll
    SaveButton.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
    SaveButton.Size = UDim2.new(1, -30, 0, 40)
    SaveButton.Font = Enum.Font.GothamBold
    SaveButton.Text = "💾 Save Settings"
    SaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveButton.TextSize = 16
    
    local SaveCorner = Instance.new("UICorner")
    SaveCorner.CornerRadius = UDim.new(0, 10)
    SaveCorner.Parent = SaveButton
    
    SaveButton.MouseButton1Click:Connect(function()
        Config.webhookUrl = WebhookBox.Text
        Config.placeId = PlaceIDBox.Text
        Config.maxTimeInServer = tonumber(MaxTimeBox.Text) or 0
        Config.autoReconnect = AutoReconnectToggle.Text == "ON"
        
        saveConfig() -- Save to persistent storage!
        addLog("success", "Settings saved!")
        SettingsPanel.Visible = false
        Content.Visible = true
    end)
    
    -- Back Button
    local BackButton = Instance.new("TextButton")
    BackButton.Parent = SettingsScroll
    BackButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    BackButton.Size = UDim2.new(1, -30, 0, 35)
    BackButton.Font = Enum.Font.GothamBold
    BackButton.Text = "← Back"
    BackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    BackButton.TextSize = 14
    
    local BackCorner = Instance.new("UICorner")
    BackCorner.CornerRadius = UDim.new(0, 10)
    BackCorner.Parent = BackButton
    
    BackButton.MouseButton1Click:Connect(function()
        SettingsPanel.Visible = false
        Content.Visible = true
    end)
    
    -- Settings Button Click
    SettingsButton.MouseButton1Click:Connect(function()
        SettingsPanel.Visible = true
        Content.Visible = false
    end)
    
    -- ========================================
    -- UPDATE FUNCTIONS
    -- ========================================
    local function formatTime(seconds)
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    
    local function updateLogs()
        -- Clear old logs
        for _, child in ipairs(LogFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Add new logs
        for i, log in ipairs(Logs) do
            local LogEntry = Instance.new("Frame")
            LogEntry.Name = "LogEntry" .. i
            LogEntry.Parent = LogFrame
            LogEntry.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
            LogEntry.BorderSizePixel = 0
            LogEntry.Size = UDim2.new(1, -20, 0, 50)
            
            local LogEntryCorner = Instance.new("UICorner")
            LogEntryCorner.CornerRadius = UDim.new(0, 8)
            LogEntryCorner.Parent = LogEntry
            
            local Icon = Instance.new("TextLabel")
            Icon.Parent = LogEntry
            Icon.BackgroundTransparency = 1
            Icon.Position = UDim2.new(0, 10, 0, 0)
            Icon.Size = UDim2.new(0, 30, 1, 0)
            Icon.Font = Enum.Font.GothamBold
            Icon.TextSize = 18
            Icon.TextXAlignment = Enum.TextXAlignment.Center
            
            if log.type == "success" then
                Icon.Text = "✅"
                Icon.TextColor3 = Color3.fromRGB(100, 255, 150)
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
            Message.Position = UDim2.new(0, 45, 0, 5)
            Message.Size = UDim2.new(1, -55, 0, 25)
            Message.Font = Enum.Font.Gotham
            Message.Text = log.message
            Message.TextColor3 = Color3.fromRGB(220, 220, 220)
            Message.TextSize = 13
            Message.TextXAlignment = Enum.TextXAlignment.Left
            Message.TextWrapped = true
            
            local Time = Instance.new("TextLabel")
            Time.Parent = LogEntry
            Time.BackgroundTransparency = 1
            Time.Position = UDim2.new(0, 45, 0, 28)
            Time.Size = UDim2.new(1, -55, 0, 17)
            Time.Font = Enum.Font.Gotham
            Time.Text = os.date("%H:%M:%S", log.time)
            Time.TextColor3 = Color3.fromRGB(120, 120, 120)
            Time.TextSize = 11
            Time.TextXAlignment = Enum.TextXAlignment.Left
        end
        
        -- Update canvas size
        LogFrame.CanvasSize = UDim2.new(0, 0, 0, #Logs * 55 + 20)
    end
    
    local function updateStats()
        TimeValue.Text = formatTime(Stats.timeInServer)
        ReconnectsValue.Text = tostring(Stats.totalReconnects)
        StatusValue.Text = Stats.status
        
        -- Update time color based on progress
        if Config.maxTimeInServer > 0 then
            local percentage = (Stats.timeInServer / (Config.maxTimeInServer * 60)) * 100
            if percentage >= 90 then
                TimeValue.TextColor3 = Color3.fromRGB(255, 100, 100)
            elseif percentage >= 70 then
                TimeValue.TextColor3 = Color3.fromRGB(255, 200, 100)
            else
                TimeValue.TextColor3 = Color3.fromRGB(100, 255, 150)
            end
            
            -- Update progress bar
            ProgressBar.Size = UDim2.new(math.min(1, percentage / 100), 0, 1, 0)
            ProgressText.Text = string.format("%.1f%% - %d minutes remaining", 
                percentage, 
                math.max(0, Config.maxTimeInServer - math.floor(Stats.timeInServer / 60))
            )
        else
            TimeValue.TextColor3 = Color3.fromRGB(100, 150, 255)
            ProgressBar.Size = UDim2.new(0, 0, 1, 0)
            ProgressText.Text = "No time limit set"
        end
        
        -- Update status color
        if Stats.status == "Active" then
            StatusValue.TextColor3 = Color3.fromRGB(100, 255, 150)
        elseif Stats.status == "Reconnecting" then
            StatusValue.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            StatusValue.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
    
    -- ========================================
    -- MAIN UPDATE LOOP
    -- ========================================
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
        
        -- Auto-reconnect based on max time
        if Config.autoReconnect and Config.maxTimeInServer > 0 then
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
    
    -- If no heartbeat for 5+ seconds, connection is dying
    if timeSinceLastBeat > 5 and not connectionWarningIssued then
        addLog("warning", string.format("Connection unstable! No heartbeat for %.1fs", timeSinceLastBeat))
        sendWebhook("⚠️ Connection unstable!", 16776960)
        connectionWarningIssued = true
    end
    
    -- If no heartbeat for 10+ seconds, emergency reconnect
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
        addLog("info", "Player being removed from server")
        if Config.autoReconnect then
            reconnect("Player removing event")
        end
    end
end)

-- ========================================
-- INITIALIZE
-- ========================================
addLog("success", "Auto-Reconnect Dashboard initializing...")
sendWebhook("✅ Auto-Reconnect Dashboard loaded!", 3066993)

-- Load saved config first!
loadConfig()

-- Wait for character to load
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

task.wait(2) -- Wait a bit for game to fully load

-- Create the GUI
local gui = createGUI()

addLog("success", "Dashboard ready! Press the minimize button to hide.")
addLog("info", "Place ID: " .. Config.placeId)
addLog("info", "Max time: " .. (Config.maxTimeInServer == 0 and "Unlimited" or Config.maxTimeInServer .. " minutes"))
addLog("info", "Auto-reconnect: " .. (Config.autoReconnect and "Enabled" or "Disabled"))

Stats.status = "Active"

print("========================================")
print("AUTO-RECONNECT DASHBOARD LOADED!")
print("Make sure 'Verify Teleports' is OFF in Delta settings!")
print("========================================")
