-- Auto Ability Script
-- Extracted from ALS Halloween Event Script

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Config
getgenv().AutoAbilitiesEnabled = getgenv().AutoAbilitiesEnabled or false
getgenv().UnitAbilities = getgenv().UnitAbilities or {}

-- Helper Functions
local function getTowerInfo(unitName)
    local ok, data = pcall(function()
        local towerInfoPath = RS:WaitForChild("Modules"):WaitForChild("TowerInfo")
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
    for _, condition in ipairs(conditions) do
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

-- Toggle Auto Abilities
function toggleAutoAbilities(enabled)
    getgenv().AutoAbilitiesEnabled = enabled
    if enabled then
        print("[Auto Abilities] Enabled")
        startAutoAbilities()
    else
        print("[Auto Abilities] Disabled")
    end
end

-- Configure Unit
function configureUnit(unitName, enabled, conditions)
    getgenv().UnitAbilities[unitName] = {
        enabled = enabled,
        conditions = conditions or {}
    }
    print("[Auto Abilities] Configured " .. unitName .. " - Enabled: " .. tostring(enabled))
end

-- Example Usage:
-- configureUnit("YourUnitName", true, {"Wave >= 10", "Level >= 5"})
-- toggleAutoAbilities(true)

print("[Auto Abilities] Script loaded! Use toggleAutoAbilities(true) to enable.")
print("Available conditions: 'Wave >= 10', 'Wave >= 20', 'Level >= 3', 'Level >= 5', 'Max Level'")
