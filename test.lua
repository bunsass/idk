-- Auto Ability Script with UI
-- Extracted from ALS Halloween Event Script

repeat task.wait() until game:IsLoaded()

print("[Auto Abilities] Game loaded, initializing...")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Wait for character
repeat task.wait() until LocalPlayer.Character
print("[Auto Abilities] Character loaded")

-- Config
getgenv().AutoAbilitiesEnabled = getgenv().AutoAbilitiesEnabled or false
getgenv().UnitAbilities = getgenv().UnitAbilities or {}

-- Load WindUI
print("[Auto Abilities] Loading WindUI...")
local success, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if not success then
    warn("[Auto Abilities] Failed to load WindUI:", WindUI)
    return
end

print("[Auto Abilities] WindUI loaded successfully")
task.wait(0.5)

-- Helper Functions
local function getTowerInfo(unitName)
    local ok, data = pcall(function()
        local towerInfoPath = RS:WaitForChild("Modules", 5):WaitForChild("TowerInfo", 5)
        local towerModule = towerInfoPath:FindFirstChild(unitName)
        if towerModule and towerModule:IsA("ModuleScript") then
            return require(towerModule)
        end
        return nil
    end)
    return ok and data or nil
end

local function getAllAbilities(unitName)
    if not unitName or unitName == "" then return {} end
    local towerNameToCheck = unitName == "TuskSummon_Act4" and "JohnnyGodly" or unitName
    local towerInfo = getTowerInfo(towerNameToCheck)
    if not towerInfo then return {} end
    local abilities = {}
    
    local function checkAttribute(a)
        if not a.AttributeRequired then return false end
        if type(a.AttributeRequired) == "table" then
            return a.AttributeRequired.Name ~= "JUST_TO_DISPLAY_IN_LOBBY"
        end
        return true
    end
    
    local function addAbility(a, level)
        local nm = a.Name
        if not abilities[nm] then
            abilities[nm] = { 
                name = nm, 
                cooldown = a.Cd, 
                requiredLevel = level, 
                isGlobal = a.IsCdGlobal or false, 
                isAttribute = checkAttribute(a) 
            }
        end
    end
    
    for level = 0, 50 do
        local levelData = towerInfo[level]
        if levelData then
            if levelData.Ability then
                addAbility(levelData.Ability, level)
            end
            if levelData.Abilities then
                local abilityList = levelData.Abilities
                for i = 1, #abilityList do
                    addAbility(abilityList[i], level)
                end
            end
        end
    end
    return abilities
end

local function getTimeScale()
    local timeScale = 1
    pcall(function()
        local TimeScaleValue = RS:FindFirstChild("TimeScale")
        if TimeScaleValue and TimeScaleValue:IsA("NumberValue") then
            timeScale = TimeScaleValue.Value or 1
        end
    end)
    return timeScale
end

local function getOwnedUnits()
    local units = {}
    pcall(function()
        local towers = workspace:FindFirstChild("Towers")
        if towers then
            for _, tower in pairs(towers:GetChildren()) do
                if tower:FindFirstChild("Owner") and tower.Owner.Value == LocalPlayer then
                    local unitName = tower.Name
                    if not table.find(units, unitName) then
                        table.insert(units, unitName)
                    end
                end
            end
        end
    end)
    table.sort(units)
    return units
end

-- Auto Ability System
local unitCooldowns = {}
local unitGlobalCooldowns = {}

local function shouldUseAbility(tower, abilityInfo, unitConfig)
    if not unitConfig or not unitConfig.enabled then return false end
    
    local unitName = tower.Name
    local abilityName = abilityInfo.name
    
    local towerUpgrade = tower:FindFirstChild("Upgrade")
    if not towerUpgrade then return false end
    local currentLevel = towerUpgrade.Value
    
    if currentLevel < abilityInfo.requiredLevel then return false end
    
    local now = tick()
    local timeScale = getTimeScale()
    local adjustedCooldown = (abilityInfo.cooldown or 0) / timeScale
    
    if abilityInfo.isGlobal then
        if not unitGlobalCooldowns[unitName] then
            unitGlobalCooldowns[unitName] = {}
        end
        local lastUse = unitGlobalCooldowns[unitName][abilityName] or 0
        if (now - lastUse) < adjustedCooldown then return false end
    else
        local towerId = tower:GetDebugId()
        if not unitCooldowns[towerId] then
            unitCooldowns[towerId] = {}
        end
        local lastUse = unitCooldowns[towerId][abilityName] or 0
        if (now - lastUse) < adjustedCooldown then return false end
    end
    
    local conditions = unitConfig.conditions or {}
    for i = 1, #conditions do
        local condition = conditions[i]
        if condition == "Wave >= 10" then
            local wave = 0
            pcall(function() wave = RS.Wave.Value end)
            if wave < 10 then return false end
        elseif condition == "Wave >= 20" then
            local wave = 0
            pcall(function() wave = RS.Wave.Value end)
            if wave < 20 then return false end
        elseif condition == "Level >= 3" then
            if currentLevel < 3 then return false end
        elseif condition == "Level >= 5" then
            if currentLevel < 5 then return false end
        elseif condition == "Max Level" then
            local maxLevel = tower:FindFirstChild("MaxUpgrade")
            if not maxLevel or currentLevel < maxLevel.Value then return false end
        end
    end
    
    return true
end

local autoAbilityRunning = false

local function startAutoAbilities()
    if autoAbilityRunning then return end
    autoAbilityRunning = true
    
    task.spawn(function()
        while getgenv().AutoAbilitiesEnabled do
            local towers = workspace:FindFirstChild("Towers")
            if towers then
                for _, tower in pairs(towers:GetChildren()) do
                    if tower:FindFirstChild("Owner") and tower.Owner.Value == LocalPlayer then
                        local unitName = tower.Name
                        local unitConfig = getgenv().UnitAbilities[unitName]
                        
                        if unitConfig and unitConfig.enabled then
                            local abilities = getAllAbilities(unitName)
                            
                            for abilityName, abilityInfo in pairs(abilities) do
                                if not abilityInfo.isAttribute then
                                    if shouldUseAbility(tower, abilityInfo, unitConfig) then
                                        pcall(function()
                                            local remote = RS:FindFirstChild("Remotes")
                                            if remote then
                                                local abilityRemote = remote:FindFirstChild("Ability")
                                                if abilityRemote then
                                                    abilityRemote:InvokeServer(tower, abilityName)
                                                    
                                                    local now = tick()
                                                    if abilityInfo.isGlobal then
                                                        if not unitGlobalCooldowns[unitName] then
                                                            unitGlobalCooldowns[unitName] = {}
                                                        end
                                                        unitGlobalCooldowns[unitName][abilityName] = now
                                                    else
                                                        local towerId = tower:GetDebugId()
                                                        if not unitCooldowns[towerId] then
                                                            unitCooldowns[towerId] = {}
                                                        end
                                                        unitCooldowns[towerId][abilityName] = now
                                                    end
                                                end
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            task.wait(0.5)
        end
        
        autoAbilityRunning = false
    end)
end

-- Create UI
print("[Auto Abilities] Creating window...")

local Window
local windowSuccess = pcall(function()
    Window = WindUI:CreateWindow({
        Title = "Auto Abilities",
        Author = "ALS",
        Folder = "AutoAbilities",
        Size = UDim2.fromOffset(600, 460),
        NewElements = true,
        HideSearchBar = false,
        OpenButton = {
            Title = "Auto Abilities",
            CornerRadius = UDim.new(1, 0),
            StrokeThickness = 1,
            Enabled = true,
            Draggable = true,
            OnlyMobile = false,
            Color = ColorSequence.new(Color3.fromRGB(48, 255, 106), Color3.fromRGB(231, 255, 47)),
        },
    })
end)

if not windowSuccess or not Window then
    warn("[Auto Abilities] Failed to create window")
    return
end

print("[Auto Abilities] Window created successfully")
task.wait(0.3)

local MainSection = Window:Section({
    Title = "Main",
    Icon = "zap",
})

local UnitsSection = Window:Section({
    Title = "Units",
    Icon = "users",
})

local MainTab = MainSection:Tab({ Title = "Settings", Icon = "settings" })
local UnitsTab = UnitsSection:Tab({ Title = "Configure Units", Icon = "sliders" })

print("[Auto Abilities] Tabs created")

-- Main Tab Content
MainTab:Paragraph({
    Title = "⚡ Auto Abilities System",
    Desc = "Automatically uses abilities for your towers based on conditions you set. Configure each unit in the Units tab."
})

MainTab:Space()

local masterToggle = MainTab:Toggle({
    Title = "Enable Auto Abilities",
    Default = getgenv().AutoAbilitiesEnabled,
    Callback = function(val)
        getgenv().AutoAbilitiesEnabled = val
        if val then
            WindUI:Notify({
                Title = "Auto Abilities",
                Content = "Enabled",
                Duration = 3
            })
            startAutoAbilities()
        else
            WindUI:Notify({
                Title = "Auto Abilities",
                Content = "Disabled",
                Duration = 3
            })
        end
    end
})

MainTab:Space()
MainTab:Divider()
MainTab:Space()

MainTab:Section({ Title = "ℹ️ Available Conditions" })

MainTab:Paragraph({
    Title = "Condition Types",
    Desc = "• Wave >= 10 - Use ability after wave 10\n• Wave >= 20 - Use ability after wave 20\n• Level >= 3 - Use when tower is level 3+\n• Level >= 5 - Use when tower is level 5+\n• Max Level - Use only at max level"
})

MainTab:Space()
MainTab:Section({ Title = "📊 Stats" })

local statsLabel = MainTab:Paragraph({
    Title = "Current Status",
    Desc = "Waiting for data..."
})

task.spawn(function()
    while task.wait(2) do
        local enabledCount = 0
        for _, config in pairs(getgenv().UnitAbilities) do
            if config.enabled then
                enabledCount = enabledCount + 1
            end
        end
        
        local ownedUnits = getOwnedUnits()
        local statusText = string.format(
            "Auto Abilities: %s\nConfigured Units: %d\nOwned Units: %d",
            getgenv().AutoAbilitiesEnabled and "✅ Enabled" or "❌ Disabled",
            enabledCount,
            #ownedUnits
        )
        
        pcall(function()
            if statsLabel and statsLabel.SetDesc then
                statsLabel:SetDesc(statusText)
            end
        end)
    end
end)

-- Units Tab Content
UnitsTab:Paragraph({
    Title = "🎯 Unit Configuration",
    Desc = "Select a unit below to configure its auto ability settings. The unit must be placed in the game for it to appear in the list."
})

UnitsTab:Space()

local selectedUnit = nil
local unitDropdown = nil
local enableToggle = nil
local conditionsDropdown = nil
local abilityInfoLabel = nil

local function refreshUnitList()
    local units = getOwnedUnits()
    if #units == 0 then
        units = {"No units found - Place a tower!"}
    end
    
    if unitDropdown then
        pcall(function()
            unitDropdown:Refresh(units)
        end)
    end
    
    return units
end

local function updateAbilityInfo(unitName)
    if not unitName or unitName == "No units found - Place a tower!" then
        if abilityInfoLabel then
            pcall(function()
                abilityInfoLabel:SetDesc("Select a unit to view its abilities.")
            end)
        end
        return
    end
    
    local abilities = getAllAbilities(unitName)
    if not abilities or not next(abilities) then
        if abilityInfoLabel then
            pcall(function()
                abilityInfoLabel:SetDesc("No abilities found for this unit.")
            end)
        end
        return
    end
    
    local abilityText = ""
    for abilityName, abilityInfo in pairs(abilities) do
        if not abilityInfo.isAttribute then
            abilityText = abilityText .. string.format(
                "• %s (CD: %.1fs, Lvl %d)%s\n",
                abilityName,
                abilityInfo.cooldown or 0,
                abilityInfo.requiredLevel,
                abilityInfo.isGlobal and " [Global]" or ""
            )
        end
    end
    
    if abilityText == "" then
        abilityText = "No usable abilities found."
    end
    
    if abilityInfoLabel then
        pcall(function()
            abilityInfoLabel:SetDesc(abilityText)
        end)
    end
end

unitDropdown = UnitsTab:Dropdown({
    Title = "Select Unit",
    Values = refreshUnitList(),
    Callback = function(value)
        if value == "No units found - Place a tower!" then return end
        
        selectedUnit = value
        
        local config = getgenv().UnitAbilities[value] or { enabled = false, conditions = {} }
        
        if enableToggle then
            pcall(function()
                enableToggle:Set(config.enabled)
            end)
        end
        
        if conditionsDropdown then
            pcall(function()
                conditionsDropdown:Select(config.conditions or {})
            end)
        end
        
        updateAbilityInfo(value)
    end,
    Searchable = true
})

UnitsTab:Space()

enableToggle = UnitsTab:Toggle({
    Title = "Enable Auto Ability",
    Default = false,
    Callback = function(val)
        if not selectedUnit or selectedUnit == "No units found - Place a tower!" then 
            WindUI:Notify({
                Title = "Error",
                Content = "Please select a unit first",
                Duration = 3
            })
            return 
        end
        
        if not getgenv().UnitAbilities[selectedUnit] then
            getgenv().UnitAbilities[selectedUnit] = { enabled = false, conditions = {} }
        end
        
        getgenv().UnitAbilities[selectedUnit].enabled = val
        
        WindUI:Notify({
            Title = selectedUnit,
            Content = val and "Auto ability enabled" or "Auto ability disabled",
            Duration = 3
        })
    end
})

UnitsTab:Space()

conditionsDropdown = UnitsTab:Dropdown({
    Title = "Conditions (Multi-Select)",
    Values = {"Wave >= 10", "Wave >= 20", "Level >= 3", "Level >= 5", "Max Level"},
    Multi = true,
    Callback = function(values)
        if not selectedUnit or selectedUnit == "No units found - Place a tower!" then return end
        
        if not getgenv().UnitAbilities[selectedUnit] then
            getgenv().UnitAbilities[selectedUnit] = { enabled = false, conditions = {} }
        end
        
        getgenv().UnitAbilities[selectedUnit].conditions = values
        
        local conditionText = #values > 0 and table.concat(values, ", ") or "None"
        WindUI:Notify({
            Title = selectedUnit,
            Content = "Conditions: " .. conditionText,
            Duration = 3
        })
    end
})

UnitsTab:Space()
UnitsTab:Divider()
UnitsTab:Space()

UnitsTab:Section({ Title = "📋 Unit Abilities" })

abilityInfoLabel = UnitsTab:Paragraph({
    Title = "Ability Information",
    Desc = "Select a unit to view its abilities."
})

UnitsTab:Space()

UnitsTab:Button({
    Title = "🔄 Refresh Unit List",
    Callback = function()
        local units = refreshUnitList()
        WindUI:Notify({
            Title = "Refreshed",
            Content = "Found " .. (#units == 1 and units[1] == "No units found - Place a tower!" and 0 or #units) .. " units",
            Duration = 3
        })
    end
})

UnitsTab:Space()

UnitsTab:Button({
    Title = "🗑️ Clear Unit Config",
    Callback = function()
        if not selectedUnit or selectedUnit == "No units found - Place a tower!" then 
            WindUI:Notify({
                Title = "Error",
                Content = "Please select a unit first",
                Duration = 3
            })
            return 
        end
        
        getgenv().UnitAbilities[selectedUnit] = { enabled = false, conditions = {} }
        
        if enableToggle then
            pcall(function()
                enableToggle:Set(false)
            end)
        end
        
        if conditionsDropdown then
            pcall(function()
                conditionsDropdown:Select({})
            end)
        end
        
        WindUI:Notify({
            Title = selectedUnit,
            Content = "Configuration cleared",
            Duration = 3
        })
    end
})

print("[Auto Abilities] UI loaded successfully!")
task.wait(0.5)

WindUI:Notify({
    Title = "Auto Abilities",
    Content = "UI loaded! Place towers to configure them.",
    Duration = 5
})

print("[Auto Abilities] Script fully initialized!")
