local TeleportService = game:GetService("TeleportService")

local REJOIN_INTERVAL = 1860 -- 1.5 hours in seconds

print("[Auto-Rejoin] Script started! Will rejoin every 1.5 hours.")

task.spawn(function()
    while true do
        task.wait(REJOIN_INTERVAL)
        print("[Auto-Rejoin] Rejoining server...")
        TeleportService:Teleport(game.PlaceId)
    end
end)
