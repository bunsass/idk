-- Auto Ability Script with Advanced UI
-- Multiple abilities per unit with boss detection

repeat task.wait() until game:IsLoaded()

print("[Auto Abilities] Initializing...")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

repeat task.wait() until LocalPlayer.Character

getgenv().AutoAbilitiesEnabled = getgenv().AutoAbilitiesEnabled or false
getgenv().UnitAbilities = getgenv().UnitAbilities or {}

print("[Auto Abilities] Loading WindUI...")
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
print("[Auto Abilities] WindUI loaded")

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
                for i = 1, #levelData.Abilities do
                    addAbility(levelData.Abilities[i], level)
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

local function isBossInRange(tower)
    local inRange = false
    pcall(function()
        if not tower or not tower:FindFirstChild("HumanoidRootPart") then return end
        local towerPos = tower.HumanoidRootPart.Position
        local range = 50
        
        if tower:FindFirstChild("Config") then
            local config = tower.Config
            if config:FindFirstChild("Range") then
                range = config.Range.Value
            end
        end
        
        local enemies = workspace:FindFirstChild("Enemies")
        if not enemies then return end
        
        for _, enemy in pairs(enemies:GetChildren()) do
            if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                if enemy:FindFirstChild("Boss") and enemy.Boss.Value == true then
                    if enemy:FindFirstChild("HumanoidRootPart") then
                        local distance = (towerPos - enemy.HumanoidRootPart.Position).Magnitude
                        if distance <= range then
                            inRange = true
                            break
                        end
                    end
                end
            end
        end
    end)
    return inRange
end

local function isBossSpawned()
    local spawned = false
    pcall(function()
        local enemies = workspace:FindFirstChild("Enemies")
        if not enemies then return end
        
        for _, enemy in pairs(enemies:GetChildren()) do
            if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                if enemy:FindFirstChild("Boss") and enemy.Boss.Value == true then
                    spawned = true
                    break
                end
            end
        end
    end)
    return spawned
end

local function getOwnedUnits()
    local units = {}
    pcall(function()
        local towers = workspace:FindFirstChild("Towers")
        if towers then
            for _, tower in pairs(towers:GetChildren()) do
                if tower:FindFirstChild("Owner") and tower.Owner.Value == LocalPlayer then
                    if not table.find(units, tower.Name) then
                        table.insert(units, tower.Name)
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

local function shouldUseAbility(tower, abilityInfo, abilityConfig)
    if not abilityConfig or not abilityConfig.enabled then return false end
    
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
    
    local mode = abilityConfig.mode or "Always On"
    
    if mode == "Boss In Range" then
        if not isBossInRange(tower) then return false end
    elseif mode == "Boss Spawn" then
        if not isBossSpawned() then return false end
    end
    
    local conditions = abilityConfig.conditions or {}
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
        elseif condition == "Wave >= 30" then
            local wave = 0
            pcall(function() wave = RS.Wave.Value end)
            if wave < 30 then return false end
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
                        
                        if unitConfig then
                            local abilities = getAllAbilities(unitName)
                            
                            for abilityName, abilityInfo in pairs(abilities) do
                                if not abilityInfo.isAttribute then
                                    local abilityConfig = unitConfig[abilityName]
                                    
                                    if abilityConfig and shouldUseAbility(tower, abilityInfo, abilityConfig) then
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
            
            task.wait(0.3)
        end
        
        autoAbilityRunning = false
    end)
end

-- Create UI
print("[Auto Abilities] Creating UI...")

local Window = WindUI:CreateWindow({
    Title = "Auto Abilities",
    Author = "ALS",
    Folder = "AutoAbilities",
    Size = UDim2.fromOffset(700, 500),
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

local MainSection = Window:Section({ Title = "Main", Icon = "zap" })
local UnitsSection = Window:Section({ Title = "Units", Icon = "users" })

local MainTab = MainSection:Tab({ Title = "Settings", Icon = "settings" })

-- Store unit tabs
getgenv().UnitTabs = getgenv().UnitTabs or {}

MainTab:Paragraph({
    Title = "⚡ Auto Abilities System",
    Desc = "Configure each unit's abilities individually. Each ability has its own activation mode and conditions."
})

MainTab:Space()

MainTab:Toggle({
    Title = "Enable Auto Abilities",
    Default = getgenv().AutoAbilitiesEnabled,
    Callback = function(val)
        getgenv().AutoAbilitiesEnabled = val
        WindUI:Notify({
            Title = "Auto Abilities",
            Content = val and "Enabled" or "Disabled",
            Duration = 3
        })
        if val then
            startAutoAbilities()
        end
    end
})

MainTab:Space()
MainTab:Divider()
MainTab:Space()

MainTab:Section({ Title = "ℹ️ Activation Modes" })

MainTab:Paragraph({
    Title = "Mode Types",
    Desc = "• Always On - Use ability on cooldown\n• Boss In Range - Only when boss is in tower range\n• Boss Spawn - Only when any boss is spawned"
})

MainTab:Space()

MainTab:Section({ Title = "📋 Additional Conditions" })

MainTab:Paragraph({
    Title = "Optional Filters",
    Desc = "• Wave >= 10/20/30 - Wait until specific wave\n• Level >= 3/5 - Wait for tower upgrade\n• Max Level - Only at maximum upgrade"
})

MainTab:Space()

MainTab:Button({
    Title = "🔄 Scan for New Units",
    Callback = function()
        local units = getOwnedUnits()
        
        for _, unitName in ipairs(units) do
            if not getgenv().UnitTabs[unitName] then
                local unitTab = UnitsSection:Tab({ Title = unitName, Icon = "box" })
                getgenv().UnitTabs[unitName] = unitTab
                
                unitTab:Paragraph({
                    Title = "⚙️ " .. unitName,
                    Desc = "Configure abilities for this unit. Each ability can have its own mode and conditions."
                })
                
                unitTab:Space()
                
                if not getgenv().UnitAbilities[unitName] then
                    getgenv().UnitAbilities[unitName] = {}
                end
                
                local abilities = getAllAbilities(unitName)
                local abilityList = {}
                for abilityName, abilityInfo in pairs(abilities) do
                    if not abilityInfo.isAttribute then
                        table.insert(abilityList, {name = abilityName, info = abilityInfo})
                    end
                end
                
                table.sort(abilityList, function(a, b) return a.name < b.name end)
                
                for _, abilityData in ipairs(abilityList) do
                    local abilityName = abilityData.name
                    local abilityInfo = abilityData.info
                    
                    unitTab:Section({ Title = "🎯 " .. abilityName })
                    
                    unitTab:Paragraph({
                        Title = "Info",
                        Desc = string.format(
                            "Cooldown: %.1fs | Required Level: %d%s",
                            abilityInfo.cooldown or 0,
                            abilityInfo.requiredLevel,
                            abilityInfo.isGlobal and " | Global CD" or ""
                        )
                    })
                    
                    if not getgenv().UnitAbilities[unitName][abilityName] then
                        getgenv().UnitAbilities[unitName][abilityName] = {
                            enabled = false,
                            mode = "Always On",
                            conditions = {}
                        }
                    end
                    
                    local config = getgenv().UnitAbilities[unitName][abilityName]
                    
                    unitTab:Toggle({
                        Title = "Enable",
                        Default = config.enabled,
                        Callback = function(val)
                            getgenv().UnitAbilities[unitName][abilityName].enabled = val
                            WindUI:Notify({
                                Title = unitName,
                                Content = abilityName .. " " .. (val and "enabled" or "disabled"),
                                Duration = 2
                            })
                        end
                    })
                    
                    unitTab:Dropdown({
                        Title = "Activation Mode",
                        Values = {"Always On", "Boss In Range", "Boss Spawn"},
                        Value = config.mode,
                        Callback = function(val)
                            getgenv().UnitAbilities[unitName][abilityName].mode = val
                        end
                    })
                    
                    unitTab:Dropdown({
                        Title = "Additional Conditions",
                        Values = {"Wave >= 10", "Wave >= 20", "Wave >= 30", "Level >= 3", "Level >= 5", "Max Level"},
                        Multi = true,
                        Value = config.conditions,
                        Callback = function(val)
                            getgenv().UnitAbilities[unitName][abilityName].conditions = val
                        end
                    })
                    
                    unitTab:Space()
                end
            end
        end
        
        WindUI:Notify({
            Title = "Scan Complete",
            Content = "Found " .. #units .. " units",
            Duration = 3
        })
    end
})

MainTab:Space()

MainTab:Button({
    Title = "🗑️ Clear All Configs",
    Callback = function()
        getgenv().UnitAbilities = {}
        WindUI:Notify({
            Title = "Cleared",
            Content = "All configurations cleared",
            Duration = 3
        })
    end
})

print("[Auto Abilities] UI loaded successfully!")
task.wait(0.5)

WindUI:Notify({
    Title = "Auto Abilities Loaded!",
    Content = "Click 'Scan for New Units' to start",
    Duration = 5
})

-- Auto-scan on load
task.spawn(function()
    task.wait(2)
    local units = getOwnedUnits()
    if #units > 0 then
        WindUI:Notify({
            Title = "Auto-Scanning",
            Content = "Found " .. #units .. " units, creating tabs...",
            Duration = 3
        })
        
        for _, unitName in ipairs(units) do
            if not getgenv().UnitTabs[unitName] then
                local unitTab = UnitsSection:Tab({ Title = unitName, Icon = "box" })
                getgenv().UnitTabs[unitName] = unitTab
                
                unitTab:Paragraph({
                    Title = "⚙️ " .. unitName,
                    Desc = "Configure abilities for this unit. Each ability can have its own mode and conditions."
                })
                
                unitTab:Space()
                
                if not getgenv().UnitAbilities[unitName] then
                    getgenv().UnitAbilities[unitName] = {}
                end
                
                local abilities = getAllAbilities(unitName)
                local abilityList = {}
                for abilityName, abilityInfo in pairs(abilities) do
                    if not abilityInfo.isAttribute then
                        table.insert(abilityList, {name = abilityName, info = abilityInfo})
                    end
                end
                
                table.sort(abilityList, function(a, b) return a.name < b.name end)
                
                for _, abilityData in ipairs(abilityList) do
                    local abilityName = abilityData.name
                    local abilityInfo = abilityData.info
                    
                    unitTab:Section({ Title = "🎯 " .. abilityName })
                    
                    unitTab:Paragraph({
                        Title = "Info",
                        Desc = string.format(
                            "Cooldown: %.1fs | Required Level: %d%s",
                            abilityInfo.cooldown or 0,
                            abilityInfo.requiredLevel,
                            abilityInfo.isGlobal and " | Global CD" or ""
                        )
                    })
                    
                    if not getgenv().UnitAbilities[unitName][abilityName] then
                        getgenv().UnitAbilities[unitName][abilityName] = {
                            enabled = false,
                            mode = "Always On",
                            conditions = {}
                        }
                    end
                    
                    local config = getgenv().UnitAbilities[unitName][abilityName]
                    
                    unitTab:Toggle({
                        Title = "Enable",
                        Default = config.enabled,
                        Callback = function(val)
                            getgenv().UnitAbilities[unitName][abilityName].enabled = val
                            WindUI:Notify({
                                Title = unitName,
                                Content = abilityName .. " " .. (val and "enabled" or "disabled"),
                                Duration = 2
                            })
                        end
                    })
                    
                    unitTab:Dropdown({
                        Title = "Activation Mode",
                        Values = {"Always On", "Boss In Range", "Boss Spawn"},
                        Value = config.mode,
                        Callback = function(val)
                            getgenv().UnitAbilities[unitName][abilityName].mode = val
                        end
                    })
                    
                    unitTab:Dropdown({
                        Title = "Additional Conditions",
                        Values = {"Wave >= 10", "Wave >= 20", "Wave >= 30", "Level >= 3", "Level >= 5", "Max Level"},
                        Multi = true,
                        Value = config.conditions,
                        Callback = function(val)
                            getgenv().UnitAbilities[unitName][abilityName].conditions = val
                        end
                    })
                    
                    unitTab:Space()
                end
            end
        end
    end
end)

print("[Auto Abilities] Ready!")
