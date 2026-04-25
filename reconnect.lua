local TeleportService = game:GetService("TeleportService")
local REJOIN_INTERVAL = 18 -- seconds
local TARGET_PLACE_ID = 77747658251236
local WEBHOOK_URL = "https://discord.com/api/webhooks/1488987999734599731/Pm1qIleWT2Kut1Z6VBplCyfH_4HKIg58n9CPdkjbyIt50VMrLyYjyqUwzmp_ATsVXl-k"
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
            title = "🔄 Auto-Teleport Triggered",
            description = "The script is teleporting to the target place.",
            color = 5814783,
            fields = {
                { name = "Current Place ID", value = tostring(game.PlaceId), inline = true },
                { name = "Target Place ID", value = tostring(TARGET_PLACE_ID), inline = true },
                { name = "Player", value = tostring(game.Players.LocalPlayer.Name), inline = true },
                { name = "⏱️ Time on Server", value = formatTime(timeOnServer), inline = false }
            },
            footer = { text = "Auto-Teleport System" }
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
        print("[Auto-Teleport] Webhook sent!")
    else
        warn("[Auto-Teleport] Webhook failed: " .. tostring(err))
    end
end

print("[Auto-Teleport] Script started!")

task.delay(REJOIN_INTERVAL, function()
    print("[Auto-Teleport] Teleporting to place " .. TARGET_PLACE_ID .. "...")
    sendWebhook()
    task.wait(2)
    TeleportService:Teleport(TARGET_PLACE_ID)
end)
