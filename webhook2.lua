local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local WEBHOOK      = "https://discord.com/api/webhooks/1488987999734599731/Pm1qIleWT2Kut1Z6VBplCyfH_4HKIg58n9CPdkjbyIt50VMrLyYjyqUwzmp_ATsVXl-k"
local INTERVAL_MIN = 30  -- Changed from 30 to 1 minute for more frequent checks
local EMBED_COLOR  = 12564674 -- #B027F5 in decimal

local CATEGORIES = {
    { label = "Chests",    keys = { "Common Chest", "Rare Chest", "Epic Chest", "Legendary Chest", "Mythical Chest", "Secret Chest", "Aura Crate", "Cosmetic Crate"  } },
    { label = "Rerolls",   keys = { "Trait Reroll", "Haki Color Reroll", "Clan Reroll", "Race Reroll", "Passive Shard", "Power Shard" } },
    { label = "Keys",      keys = { "Tower Key", "Rush Key", "Dungeon Key", "Boss Key", "Limitless Key", "Malevolent Key" } },
    { label = "Materials", keys = { "Wood", "Iron", "Obsidian", "Mythril", "Adamantite", "Dust", "Stone" } },
    { label = "Boss Summons", keys = { "Abyss Sigil", "Frost Relic", "Dark Grail", "Calamity Seal", "Upper Seal" } },
    { label = "Others",    keys = nil },
}

local nameToCategory = {}
for _, cat in ipairs(CATEGORIES) do
    if cat.keys then
        for _, k in ipairs(cat.keys) do
            nameToCategory[k] = cat.label
        end
    end
end

local function getCategory(name)
    return nameToCategory[name] or "Others"
end

local requestFunc = syn and syn.request or http_request or request

local function escapeJson(str)
    str = tostring(str)
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"',  '\\"')
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    return str
end

local function fmtNum(n)
    local s = tostring(math.floor(n))
    local result = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            result = result .. ","
        end
        result = result .. s:sub(i, i)
    end
    return result
end

local function extractItems(data, out)
    if type(data) == "table" then
        -- FIX: Check for both direct item format and nested structures
        if data.name and data.quantity then
            out[tostring(data.name)] = tonumber(data.quantity) or 0
        else
            for _, v in pairs(data) do
                extractItems(v, out)
            end
        end
    end
end

local function buildSnapshot(capturedData)
    local snap = {}
    -- FIX: Handle case where capturedData might be a single table or array of args
    if type(capturedData) == "table" then
        -- If it's an array of arguments
        if capturedData[1] then
            for _, arg in ipairs(capturedData) do
                extractItems(arg, snap)
            end
        else
            -- If it's a single table argument
            extractItems(capturedData, snap)
        end
    end
    return snap
end

local function diffSnapshots(prev, curr)
    local gained = {}
    for name, qty in pairs(curr) do
        local old = prev[name] or 0
        -- FIX: More robust comparison
        if tonumber(qty) and tonumber(old) then
            if qty > old then
                table.insert(gained, { name = name, gained = qty - old, total = qty })
            end
        end
    end
    return gained
end

local function buildDescription(diffList, sessionStart)
    if #diffList == 0 then return nil end

    local groups = {}
    local groupMap = {}
    for _, cat in ipairs(CATEGORIES) do
        local g = { label = cat.label, items = {} }
        table.insert(groups, g)
        groupMap[cat.label] = g
    end

    for _, entry in ipairs(diffList) do
        local cat = getCategory(entry.name)
        table.insert(groupMap[cat].items, entry)
    end

    local lines = { "**Sailor Piece**", "**New Items**" }

    for _, g in ipairs(groups) do
        if #g.items > 0 then
            table.sort(g.items, function(a, b) return a.gained > b.gained end)
            table.insert(lines, "")
            table.insert(lines, "**< " .. g.label .. " >**")
            table.insert(lines, "```")
            for _, item in ipairs(g.items) do
                table.insert(lines, string.format("+ [%s] %s [Total: %s]",
                    fmtNum(item.gained), item.name, fmtNum(item.total)))
            end
            table.insert(lines, "```")
        end
    end

    local elapsed = os.time() - sessionStart
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)

    table.insert(lines, "")
    table.insert(lines, player.Name .. " • Session: " .. string.format("%dh %02dm", h, m) .. " • " .. os.date("%m/%d/%y %H:%M:%S"))

    return table.concat(lines, "\n")
end

local function sendToDiscord(description)
    if not requestFunc then 
        print("❌ No request function available")
        return 
    end

    local bodyJson = string.format(
        '{"embeds":[{"description":"%s","color":%d}]}',
        escapeJson(description),
        EMBED_COLOR
    )

    local success = pcall(requestFunc, {
        Url     = WEBHOOK,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = bodyJson
    })
    
    if success then
        print("✅ Sent to Discord!")
    else
        print("❌ Failed to send to Discord")
    end
end

-- FIX: Complete rewrite of snapshot capturing
-- Instead of waiting for ONE event, we actively monitor and capture
local function captureInventorySnapshot(updateInventory)
    local capturedData = nil
    local eventFired = false

    print("⏳ Waiting for UpdateInventory event...")

    local conn
    conn = updateInventory.OnClientEvent:Connect(function(...)
        capturedData = { ... }
        eventFired = true
        print("✅ UpdateInventory event captured!")
        conn:Disconnect()
    end)

    -- Wait up to 30 seconds for an event
    local waited = 0
    while not eventFired and waited < 30 do
        wait(1)
        waited = waited + 1
        if waited % 5 == 0 then
            print("⏳ Still waiting... (" .. waited .. "/30s)")
        end
    end

    if not eventFired then
        print("❌ No UpdateInventory event received after 30 seconds")
        conn:Disconnect()
        return nil
    end

    return buildSnapshot(capturedData)
end

local function main()
    print("\n╔════════════════════════════════════════════════════════════════╗")
    print("║        Sailor Piece Tracker - Fixed Version                   ║")
    print("║                                                                ║")
    print("║  Tracking inventory changes and sending to Discord             ║")
    print("╚════════════════════════════════════════════════════════════════╝\n")

    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotes then 
        print("❌ Cannot find Remotes folder in ReplicatedStorage")
        return 
    end

    local updateInventory = remotes:FindFirstChild("UpdateInventory")
    if not updateInventory then 
        print("❌ Cannot find UpdateInventory remote")
        return 
    end

    print("✅ Found UpdateInventory remote!")
    print("📊 Starting tracker... Keep farming!\n")

    local sessionStart = os.time()
    local prevSnapshot = nil
    local checkCount = 0

    while true do
        wait(INTERVAL_MIN * 60)
        
        checkCount = checkCount + 1
        print("\n[Check #" .. checkCount .. "] Attempting to capture inventory...")

        local snap = captureInventorySnapshot(updateInventory)

        if snap then
            print("📦 Snapshot captured with " .. countItems(snap) .. " item types")
            
            if prevSnapshot == nil then
                print("📍 First snapshot - saving baseline")
                prevSnapshot = snap
            else
                local diff = diffSnapshots(prevSnapshot, snap)
                local desc = buildDescription(diff, sessionStart)
                
                if desc then
                    print("🎯 Items gained! Sending to Discord...")
                    sendToDiscord(desc)
                else
                    print("❌ No item changes detected")
                end
                
                prevSnapshot = snap
            end
        else
            print("⚠️  Failed to capture snapshot - will retry on next interval")
        end
    end
end

-- Helper function to count items in snapshot
function countItems(snap)
    local count = 0
    for _ in pairs(snap) do
        count = count + 1
    end
    return count
end

main()
