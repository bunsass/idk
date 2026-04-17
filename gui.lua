-- Auto-Reconnect to Same Server on Error GUI
-- Rejoins the current server when ErrorMessageChanged is triggered

local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local RECONNECT_DELAY = 2 -- seconds before teleporting

print("[Auto-Reconnect] Script started!")
print("[Auto-Reconnect] Current Place ID:", game.PlaceId)
print("[Auto-Reconnect] Current Job ID:", game.JobId)

-- Function to get current server job ID
local function getCurrentJobId()
    return game.JobId
end

-- Listen for error GUI
GuiService.ErrorMessageChanged:Connect(function()
    local errorMessage = GuiService:GetErrorMessage()
    
    if errorMessage ~= "" then
        print("[Auto-Reconnect] Error detected:", errorMessage)
        print("[Auto-Reconnect] Attempting to rejoin in", RECONNECT_DELAY, "seconds...")
        
        wait(RECONNECT_DELAY)
        
        -- Rejoin the same server using current JobId
        local currentJobId = getCurrentJobId()
        print("[Auto-Reconnect] Rejoining server with Job ID:", currentJobId)
        
        TeleportService:TeleportToPlaceInstance(game.PlaceId, currentJobId, player)
    end
end)

print("[Auto-Reconnect] Monitoring for errors...")
