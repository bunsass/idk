local TeleportService = game:GetService("TeleportService")

local REJOIN_INTERVAL = 1860 -- seconds
local WEBHOOK_URL = "https://discord.com/api/webhooks/1491999512506531850/9Bg3zLKyTkIBB7xgJCTekFluozbvUfH4eHUoBtCIxsXL4jlsgI44HCa-Mb3HUr1iZCzt"
local startTime = os.time()

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02dh %02dm %02ds", hours, minutes, secs)
end

local function sendWebhook()
    local timeOnServer = os.time() - startTime

    local data = {
        embeds = {{
            title = "🔄 Auto-Rejoin Triggered",
            description = "The script is rejoining the server.",
            color = 5814783,
            fields = {
                { name = "Place ID", value = tostring(game.PlaceId), inline = true },
                { name = "Player", value = tostring(game.Players.LocalPlayer.Name), inline = true },
                { name = "⏱️ Time on Server", value = formatTime(timeOnServer), inline = false }
            },
            footer = { text = "Auto-Rejoin System" }
        }}
    }

    local success, err = pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(data)
        })
    end)

    if success then
        print("[Auto-Rejoin] Webhook sent!")
    else
        warn("[Auto-Rejoin] Webhook failed: " .. tostring(err))
    end
end

print("[Auto-Rejoin] Script started!")

task.delay(REJOIN_INTERVAL, function()
    print("[Auto-Rejoin] Rejoining server...")
    sendWebhook()
    task.wait(2)
    TeleportService:Teleport(game.PlaceId)
end)
