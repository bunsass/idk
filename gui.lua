-- Improved Auto-Reconnect with Retry Logic and Error Handling
-- Handles error 773 and other reconnection issues

local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local RECONNECT_DELAY = 3 -- increased from 2 to 3 seconds
local MAX_RETRIES = 3
local RETRY_DELAY = 5

-- Store server info at script start
local originalJobId = game.JobId
local placeId = game.PlaceId

print("[Auto-Reconnect] Script started!")
print("[Auto-Reconnect] Place ID:", placeId)
print("[Auto-Reconnect] Original Job ID:", originalJobId)

-- Function to rejoin with retry logic
local function attemptReconnect(jobId, retryCount)
    retryCount = retryCount or 0
    
    if retryCount > MAX_RETRIES then
        print("[Auto-Reconnect] Max retries reached. Joining any server instead...")
        -- Fallback: join any public server if specific server doesn't exist
        TeleportService:Teleport(placeId, player)
        return
    end
    
    print("[Auto-Reconnect] Attempt", retryCount + 1, "- Rejoining Job ID:", jobId)
    
    pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
    end)
    
    -- Schedule retry if it fails
    task.delay(RETRY_DELAY, function()
        attemptReconnect(jobId, retryCount + 1)
    end)
end

-- Listen for error GUI
GuiService.ErrorMessageChanged:Connect(function()
    local errorMessage = GuiService:GetErrorMessage()
    
    if errorMessage ~= "" then
        print("[Auto-Reconnect] Error detected:", errorMessage)
        print("[Auto-Reconnect] Waiting", RECONNECT_DELAY, "seconds before reconnect...")
        
        task.wait(RECONNECT_DELAY)
        
        -- Try to rejoin the original server first
        attemptReconnect(originalJobId)
    end
end)

print("[Auto-Reconnect] Monitoring for errors...")
print("[Auto-Reconnect] Note: If server is down, will join a public server instead")
