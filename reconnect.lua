-- ========================================
-- AUTO-RECONNECT SCRIPT (NO UI)
-- ========================================
-- Put this in your Delta autoexec folder!
-- Make sure "Verify Teleports" is OFF in Delta settings
-- ========================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- CONFIGURATION
-- ========================================
local Config = {
    webhookUrl = "https://discord.com/api/webhooks/1434305865296379954/L2Sm8qbftl0iSU9H-2aDucuvMzd0dRaQP4eikKTGoTgR1KgS-c7ZgX6_GINjipBN3_Nv",  -- YOUR DISCORD WEBHOOK URL
    placeId = "16146832113",                -- GAME PLACE ID TO RECONNECT TO
    maxTimeInServer = 60,                   -- MINUTES BEFORE AUTO-RECONNECT (0 = UNLIMITED)
    autoReconnect = true,                   -- AUTO RECONNECT ON DISCONNECT
    enableMaxTime = false,                  -- ENABLE TIME-BASED RECONNECTION
    logConsoleToWebhook = true              -- LOG ALL CONSOLE MESSAGES TO WEBHOOK
}

-- ========================================
-- WEBHOOK FUNCTIONS
-- ========================================
local function sendWebhook(message, color)
    if not Config.webhookUrl or Config.webhookUrl == "" or Config.webhookUrl == "YOUR_WEBHOOK_URL_HERE" then
        return
    end
    
    pcall(function()
        local embed = {
            ["embeds"] = {{
                ["description"] = message,
                ["color"] = color or 3447003,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                ["footer"] = {
                    ["text"] = "Auto-Reconnect Script"
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
-- STATS & STATE
-- ========================================
local Stats = {
    timeInServer = 0,
    totalReconnects = 0
}

local isTeleporting = false

-- ========================================
-- RECONNECT FUNCTION
-- ========================================
local function reconnect(reason)
    if isTeleporting then
        return
    end
    
    isTeleporting = true
    Stats.totalReconnects = Stats.totalReconnects + 1
    
    print("[RECONNECT] " .. reason)
    sendWebhook("🔄 Reconnecting - " .. reason, 16776960)
    
    task.wait(0.5)
    
    local success, err = pcall(function()
        TeleportService:Teleport(tonumber(Config.placeId))
    end)
    
    if not success then
        print("[ERROR] Reconnect failed: " .. tostring(err))
        sendWebhook("❌ Reconnect failed: " .. tostring(err), 15158332)
        isTeleporting = false
    else
        sendWebhook("✅ Reconnect successful!", 3066993)
    end
end

-- ========================================
-- CONSOLE LOG MONITORING (TO WEBHOOK)
-- ========================================
if Config.logConsoleToWebhook then
    LogService.MessageOut:Connect(function(message, messageType)
        local color = 3447003  -- Blue (default)
        local icon = "ℹ️"
        
        if messageType == Enum.MessageType.MessageError then
            color = 15158332  -- Red
            icon = "❌"
        elseif messageType == Enum.MessageType.MessageWarning then
            color = 16776960  -- Yellow
            icon = "⚠️"
        elseif messageType == Enum.MessageType.MessageInfo then
            color = 3447003  -- Blue
            icon = "ℹ️"
        end
        
        sendWebhook(icon .. " **Console:** " .. message, color)
    end)
end

-- ========================================
-- DISCONNECT DETECTION
-- ========================================
GuiService.ErrorMessageChanged:Connect(function()
    local errorMsg = GuiService:GetErrorMessage()
    print("[DISCONNECT] " .. tostring(errorMsg))
    sendWebhook("⚠️ Disconnect detected: " .. tostring(errorMsg), 16776960)
    
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

RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    local timeSinceLastBeat = currentTime - lastHeartbeat
    
    if timeSinceLastBeat > 10 and Config.autoReconnect then
        print("[ERROR] Critical connection failure!")
        sendWebhook("❌ Critical connection failure!", 15158332)
        reconnect("Connection timeout")
    end
    
    lastHeartbeat = currentTime
end)

-- ========================================
-- PLAYER REMOVING DETECTION
-- ========================================
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        local hours = math.floor(Stats.timeInServer / 3600)
        local minutes = math.floor((Stats.timeInServer % 3600) / 60)
        local sessionTime = string.format("%dh %dm", hours, minutes)
        
        print("[SESSION] Ended after " .. sessionTime)
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
print("AUTO-RECONNECT SCRIPT LOADED!")
print("========================================")
print("Place ID: " .. Config.placeId)
print("Max time: " .. (Config.maxTimeInServer == 0 and "Unlimited" or Config.maxTimeInServer .. " minutes"))
print("Auto-reconnect: " .. (Config.autoReconnect and "Enabled" or "Disabled"))
print("Console logging: " .. (Config.logConsoleToWebhook and "Enabled" or "Disabled"))
print("Make sure 'Verify Teleports' is OFF in Delta settings!")
print("========================================")

sendWebhook("✅ Auto-Reconnect Script loaded!", 3066993)
