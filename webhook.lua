local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local WEBHOOK      = "https://discord.com/api/webhooks/1491999512506531850/9Bg3zLKyTkIBB7xgJCTekFluozbvUfH4eHUoBtCIxsXL4jlsgI44HCa-Mb3HUr1iZCzt"
local INTERVAL_MIN = 30
local WAIT_TIMEOUT = 30

local CATEGORIES = {
    { label = "Chests",    keys = { "Common Chest", "Rare Chest", "Epic Chest", "Legendary Chest", "Mythical Chest", "Boss Chest" } },
    { label = "Rerolls",   keys = { "Trait Reroll", "Haki Color Reroll", "Clan Reroll", "Race Reroll", "Stat Reroll" } },
    { label = "Keys",      keys = { "Tower Key", "Rush Key", "Dungeon Key", "Boss Key", "Limitless Key", "Malevolent Key" } },
    { label = "Materials", keys = { "Wood", "Iron", "Obsidian", "Mythril", "Adamantite", "Dust", "Stone" } },
    { label = "Gears",     keys = nil },
    { label = "Others",    keys = nil },
}

local GEAR_PATTERNS = { "Helmet", "Gloves", "Body", "Boots", "Chest Plate", "Leggings" }

local nameToCategory = {}
for _, cat in ipairs(CATEGORIES) do
    if cat.keys then
        for _, k in ipairs(cat.keys) do
            nameToCategory[k] = cat.label
        end
    end
end

local function getCategory(name)
    if nameToCategory[name] then
        return nameToCategory[name]
    end
    for _, pattern in ipairs(GEAR_PATTERNS) do
        if name:find(pattern) then
            return "Gears"
        end
    end
    return "Others"
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
    for _, arg in ipairs(capturedData) do
        extractItems(arg, snap)
    end
    return snap
end

local function diffSnapshots(prev, curr)
    local gained = {}
    for name, qty in pairs(curr) do
        local old = prev[name] or 0
        if qty > old then
            table.insert(gained, { name = name, gained = qty - old, total = qty })
        end
    end
    return gained
end

local function buildMessage(diffList, sessionStart)
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

local function sendToDiscord(message)
    if not requestFunc then return end

    local chunks = {}
    if #message <= 2000 then
        chunks = { message }
    else
        local chunk = ""
        for line in (message .. "\n"):gmatch("([^\n]*)\n") do
            if #chunk + #line + 1 > 1990 then
                table.insert(chunks, chunk)
                chunk = line
            else
                chunk = chunk == "" and line or (chunk .. "\n" .. line)
            end
        end
        if chunk ~= "" then table.insert(chunks, chunk) end
    end

    for _, chunk in ipairs(chunks) do
        pcall(requestFunc, {
            Url     = WEBHOOK,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = '{"content":"' .. escapeJson(chunk) .. '"}'
        })
        wait(1)
    end
end

local function captureSnapshot(updateInventory)
    local capturedData, received = nil, false

    local conn
    conn = updateInventory.OnClientEvent:Connect(function(...)
        capturedData = { ... }
        received = true
        conn:Disconnect()
    end)

    local waited = 0
    while not received and waited < WAIT_TIMEOUT do
        wait(1)
        waited = waited + 1
    end

    if not received then
        conn:Disconnect()
        return nil
    end

    return buildSnapshot(capturedData)
end

local function main()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotes then return end

    local updateInventory = remotes:FindFirstChild("UpdateInventory")
    if not updateInventory then return end

    local sessionStart = os.time()
    local prevSnapshot = nil

    while true do
        local snap = captureSnapshot(updateInventory)

        if snap then
            if prevSnapshot == nil then
                prevSnapshot = snap
            else
                local diff = diffSnapshots(prevSnapshot, snap)
                local msg = buildMessage(diff, sessionStart)
                if msg then sendToDiscord(msg) end
                prevSnapshot = snap
            end
        end

        wait(INTERVAL_MIN * 60)
    end
end

main()
