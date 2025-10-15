INSTRUCTIONS: Add these sections to your existing script

=== 1. ADD THIS AFTER LINE THAT SAYS: getgenv().AutoExecuteEnabled = getgenv().Config.toggles.AutoExecuteToggle or false ===

getgenv().AutoPlayEnabled = getgenv().Config.toggles.AutoPlayToggle or false
getgenv().AutoPlayPercentage = tonumber(getgenv().Config.inputs.AutoPlayPercentage) or 40

=== 2. REPLACE THE SECTIONS CREATION (around line with Window:Section) ===

Replace this:
```lua
local ModesSection = Window:Section({
    Title = "Game Modes",
    Icon = "gamepad-2",
})

local AutomationSection = Window:Section({
    Title = "Automation",
    Icon = "zap",
})
```

With this:
```lua
local ModesSection = Window:Section({
    Title = "Game Modes",
    Icon = "gamepad-2",
})

local AutoPlaySection = Window:Section({
    Title = "Auto Play",
    Icon = "cpu",
})

local AutomationSection = Window:Section({
    Title = "Automation",
    Icon = "zap",
})
```

=== 3. ADD THIS TO THE Tabs TABLE (after FinalExp line) ===

Add this line:
```lua
    AutoPlay = AutoPlaySection:Tab({ Title = "Auto Play", Icon = "play" }),
```

So it looks like:
```lua
    BossRush = ModesSection:Tab({ Title = "Boss Rush", Icon = "shield" }),
    Breach = ModesSection:Tab({ Title = "Breach", Icon = "alert-triangle" }),
    FinalExp = ModesSection:Tab({ Title = "Final Expedition", Icon = "map" }),
    
    AutoPlay = AutoPlaySection:Tab({ Title = "Auto Play", Icon = "play" }),
    
    Webhook = AutomationSection:Tab({ Title = "Webhook", Icon = "send" }),
```

=== 4. ADD THESE LINES AFTER GB.FinalExp_Right = adaptTab(Tabs.FinalExp) ===

```lua
GB.AutoPlay_Left = adaptTab(Tabs.AutoPlay)
GB.AutoPlay_Right = adaptTab(Tabs.AutoPlay)
```

=== 5. ADD AUTO PLAY UI CODE (BEFORE THE BREACH SECTION) ===

Add this entire block before `GB.Breach_Left:Paragraph({`:

```lua
GB.AutoPlay_Left:Paragraph({
    Title = "🎮 Auto Play System",
    Desc = "Automatically place units from your slots based on map percentage. The script will intelligently select affordable units."
})
GB.AutoPlay_Left:Space()

GB.AutoPlay_Left:Section({ Title = "⚙️ Auto Play Settings" })

addToggle(GB.AutoPlay_Left, "AutoPlayToggle", "Enable Auto Play", getgenv().AutoPlayEnabled or false, function(val)
    getgenv().AutoPlayEnabled = val
    getgenv().Config.toggles.AutoPlayToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Play", val and "Enabled" or "Disabled", 3)
end)

GB.AutoPlay_Left:AddInput("AutoPlayPercentage", {
    Text = "Placement Percentage (0-100)",
    Default = tostring(getgenv().AutoPlayPercentage or 40),
    Numeric = true,
    Finished = true,
    Placeholder = "Default: 40",
    Callback = function(value)
        local num = tonumber(value)
        if num and num >= 0 and num <= 100 then
            getgenv().AutoPlayPercentage = num
            getgenv().Config.inputs.AutoPlayPercentage = tostring(num)
            saveConfig(getgenv().Config)
            notify("Auto Play", "Placement set to " .. num .. "%", 3)
        else
            notify("Auto Play", "Invalid percentage! Must be 0-100", 5)
        end
    end,
})

GB.AutoPlay_Left:Paragraph({
    Title = "💡 How It Works",
    Desc = "• Calculates placement position based on percentage (0% = start, 100% = end)\n• Tries to place units from Slot 1-6 in order\n• If a unit is too expensive, selects the cheapest affordable slot\n• Waits for sufficient cash before placing each unit"
})

GB.AutoPlay_Right:Section({ Title = "📊 Auto Play Status" })

getgenv().AutoPlayStatusLabel = GB.AutoPlay_Right:Paragraph({
    Title = "Status: Idle",
    Desc = ""
})

getgenv().AutoPlayCashLabel = GB.AutoPlay_Right:Paragraph({
    Title = "💰 Cash: $0",
    Desc = ""
})

getgenv().AutoPlayProgressLabel = GB.AutoPlay_Right:Paragraph({
    Title = "📦 Progress: 0/6 units placed",
    Desc = ""
})

getgenv().AutoPlayNextUnitLabel = GB.AutoPlay_Right:Paragraph({
    Title = "⏳ Next: None",
    Desc = ""
})

getgenv().UpdateAutoPlayStatus = function()
    pcall(function()
        if getgenv().AutoPlayStatusLabel and getgenv().AutoPlayStatusLabel.SetTitle then
            getgenv().AutoPlayStatusLabel:SetTitle("Status: " .. (getgenv().AutoPlayStatusText or "Idle"))
        end
        
        if getgenv().AutoPlayCashLabel and getgenv().AutoPlayCashLabel.SetTitle then
            local cash = getgenv().MacroCurrentCash or 0
            getgenv().AutoPlayCashLabel:SetTitle("💰 Cash: $" .. tostring(cash))
        end
        
        if getgenv().AutoPlayProgressLabel and getgenv().AutoPlayProgressLabel.SetTitle then
            local placed = getgenv().AutoPlayUnitsPlaced or 0
            getgenv().AutoPlayProgressLabel:SetTitle("📦 Progress: " .. placed .. "/6 units placed")
        end
        
        if getgenv().AutoPlayNextUnitLabel and getgenv().AutoPlayNextUnitLabel.SetTitle then
            local nextUnit = getgenv().AutoPlayNextUnit or "None"
            local nextCost = getgenv().AutoPlayNextCost or 0
            if nextUnit ~= "None" then
                getgenv().AutoPlayNextUnitLabel:SetTitle("⏳ Next: " .. nextUnit .. " ($" .. nextCost .. ")")
            else
                getgenv().AutoPlayNextUnitLabel:SetTitle("⏳ Next: None")
            end
        end
    end)
end
```

=== 6. ADD AUTO PLAY LOGIC (AT THE END OF SCRIPT, BEFORE FINAL LOBBY CHECKS) ===

Add this entire block before the lobby auto-join sections at the very end:

```lua
task.spawn(function()
    if not isInLobby then
        getgenv().AutoPlayStatusText = "Idle"
        getgenv().AutoPlayUnitsPlaced = 0
        getgenv().AutoPlayNextUnit = "None"
        getgenv().AutoPlayNextCost = 0
        
        local placedUnits = {}
        
        local function getMapBounds()
            local ok, startPos, endPos = pcall(function()
                local map = workspace:FindFirstChild("Map")
                if not map then return nil, nil end
                
                local mapModel = map:FindFirstChild("Map")
                if not mapModel then return nil, nil end
                
                local startPoint = mapModel:FindFirstChild("Start") or mapModel:FindFirstChild("StartPoint")
                local endPoint = mapModel:FindFirstChild("End") or mapModel:FindFirstChild("EndPoint") or mapModel:FindFirstChild("Exit")
                
                if startPoint and endPoint then
                    return startPoint.Position, endPoint.Position
                end
                
                return nil, nil
            end)
            
            if ok and startPos and endPos then
                return startPos, endPos
            end
            return nil, nil
        end
        
        local function getPlacementPosition(percentage)
            local startPos, endPos = getMapBounds()
            if not startPos or not endPos then
                return nil
            end
            
            local t = percentage / 100
            local x = startPos.X + (endPos.X - startPos.X) * t
            local y = startPos.Y + (endPos.Y - startPos.Y) * t
            local z = startPos.Z + (endPos.Z - startPos.Z) * t
            
            return CFrame.new(x, y, z)
        end
        
        local function getUnitCost(unitName)
            if not getgenv().MacroTowerInfoCache then
                return math.huge
            end
            
            if not getgenv().MacroTowerInfoCache[unitName] then
                return math.huge
            end
            
            if getgenv().MacroTowerInfoCache[unitName][0] then
                return getgenv().MacroTowerInfoCache[unitName][0].Cost or math.huge
            end
            
            return math.huge
        end
        
        local function getAffordableSlot(clientData)
            local currentCash = getgenv().MacroCurrentCash or 0
            local slots = {"Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6"}
            local affordableUnits = {}
            
            for _, slotName in ipairs(slots) do
                if not placedUnits[slotName] then
                    local slotData = clientData.Slots[slotName]
                    if slotData and slotData.Value then
                        local unitName = slotData.Value
                        local cost = getUnitCost(unitName)
                        
                        if cost <= currentCash then
                            table.insert(affordableUnits, {
                                slot = slotName,
                                unit = unitName,
                                cost = cost
                            })
                        end
                    end
                end
            end
            
            if #affordableUnits == 0 then
                return nil
            end
            
            table.sort(affordableUnits, function(a, b)
                return a.cost < b.cost
            end)
            
            return affordableUnits[1]
        end
        
        local function placeUnit(unitName, position)
            if not position then return false end
            
            local success = false
            pcall(function()
                local placeRemote = getgenv().MacroRemoteCache["place"] or 
                                   getgenv().MacroRemoteCache["tower"] or
                                   getgenv().MacroRemoteCache["placetower"]
                
                if not placeRemote then
                    for name, remote in pairs(getgenv().MacroRemoteCache) do
                        if name:lower():find("place") then
                            placeRemote = remote
                            break
                        end
                    end
                end
                
                if placeRemote then
                    if placeRemote:IsA("RemoteFunction") then
                        placeRemote:InvokeServer(unitName, position)
                    else
                        placeRemote:FireServer(unitName, position)
                    end
                    success = true
                end
            end)
            
            return success
        end
        
        while true do
            task.wait(0.5)
            
            if getgenv().AutoPlayEnabled then
                pcall(function()
                    if hasStartButton() then
                        getgenv().AutoPlayStatusText = "Waiting for game start..."
                        getgenv().UpdateAutoPlayStatus()
                        return
                    end
                    
                    local clientData = getClientData()
                    if not clientData or not clientData.Slots then
                        getgenv().AutoPlayStatusText = "Waiting for client data..."
                        getgenv().UpdateAutoPlayStatus()
                        return
                    end
                    
                    if getgenv().AutoPlayUnitsPlaced >= 6 then
                        getgenv().AutoPlayStatusText = "All units placed"
                        getgenv().AutoPlayNextUnit = "None"
                        getgenv().AutoPlayNextCost = 0
                        getgenv().UpdateAutoPlayStatus()
                        return
                    end
                    
                    local affordableSlot = getAffordableSlot(clientData)
                    
                    if affordableSlot then
                        getgenv().AutoPlayStatusText = "Placing unit..."
                        getgenv().AutoPlayNextUnit = affordableSlot.unit
                        getgenv().AutoPlayNextCost = affordableSlot.cost
                        getgenv().UpdateAutoPlayStatus()
                        
                        local placementPos = getPlacementPosition(getgenv().AutoPlayPercentage or 40)
                        
                        if placementPos then
                            local success = placeUnit(affordableSlot.unit, placementPos)
                            
                            if success then
                                task.wait(0.5)
                                
                                placedUnits[affordableSlot.slot] = true
                                getgenv().AutoPlayUnitsPlaced = (getgenv().AutoPlayUnitsPlaced or 0) + 1
                                
                                getgenv().AutoPlayStatusText = "Placed " .. affordableSlot.unit
                                getgenv().UpdateAutoPlayStatus()
                                
                                task.wait(1)
                            else
                                getgenv().AutoPlayStatusText = "Failed to place unit"
                                getgenv().UpdateAutoPlayStatus()
                            end
                        else
                            getgenv().AutoPlayStatusText = "Cannot find placement position"
                            getgenv().UpdateAutoPlayStatus()
                        end
                    else
                        local currentCash = getgenv().MacroCurrentCash or 0
                        local slots = {"Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6"}
                        local cheapestUnplaced = nil
                        local cheapestCost = math.huge
                        
                        for _, slotName in ipairs(slots) do
                            if not placedUnits[slotName] then
                                local slotData = clientData.Slots[slotName]
                                if slotData and slotData.Value then
                                    local unitName = slotData.Value
                                    local cost = getUnitCost(unitName)
                                    
                                    if cost < cheapestCost then
                                        cheapestCost = cost
                                        cheapestUnplaced = unitName
                                    end
                                end
                            end
                        end
                        
                        if cheapestUnplaced then
                            getgenv().AutoPlayStatusText = "Waiting for cash..."
                            getgenv().AutoPlayNextUnit = cheapestUnplaced
                            getgenv().AutoPlayNextCost = cheapestCost
                            getgenv().UpdateAutoPlayStatus()
                        else
                            getgenv().AutoPlayStatusText = "All units placed"
                            getgenv().AutoPlayNextUnit = "None"
                            getgenv().AutoPlayNextCost = 0
                            getgenv().UpdateAutoPlayStatus()
                        end
                    end
                end)
            else
                getgenv().AutoPlayStatusText = "Idle"
                getgenv().UpdateAutoPlayStatus()
            end
        end
    end
end)
```

=== SUMMARY OF CHANGES ===

You need to add code in 6 locations:

1. After AutoExecuteEnabled line - add AutoPlay config variables
2. Replace ModesSection/AutomationSection - add AutoPlaySection
3. In Tabs table - add AutoPlay tab
4. After GB.FinalExp_Right - add AutoPlay_Left and AutoPlay_Right
5. Before Breach section - add entire Auto Play UI code block
6. At end before lobby checks - add entire Auto Play logic code block

The Auto Play system will:
- Place units at a specified percentage along the map path
- Try slots 1-6 in order
- If expensive, choose the cheapest affordable unit
- Wait for cash before placing
- Show live status updates

Example: If Slot 1 costs $5000, Slot 2 costs $600, Slot 3 costs $400, and you have $800:
→ It will place Slot 2 ($600) since it's the cheapest affordable option!
