repeat task.wait() until game:IsLoaded()

getgenv().MacroSystemKillSwitch = true
task.wait(2)

local CoreGui = game:GetService("CoreGui")
pcall(function()
    local coreChildren = CoreGui:GetChildren()
    for i = 1, #coreChildren do
        local ui = coreChildren[i]
        pcall(function()
            local children = ui:GetChildren()
            for j = 1, #children do
                local child = children[j]
                if child.Name == "Window" and child:FindFirstChild("Frame") then
                    local success, titleText = pcall(function()
                        return child.Frame.Main.Topbar.Left.Title.Title.Text
                    end)
                    if success and titleText and titleText:find("Macro System", 1, true) then
                        ui:Destroy()
                        break
                    end
                end
            end
        end)
    end
end)

getgenv().MacroSystemKillSwitch = false

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

task.wait(2)

local function isTeleportUIVisible()
    local tpUI = LocalPlayer.PlayerGui:FindFirstChild("TeleportUI")
    if not tpUI then return false end
    
    local ok, visible = pcall(function()
        return tpUI.Enabled
    end)
    return ok and visible
end

local function isPlayerInValidState()
    local character = LocalPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    return true
end

local maxWaitTime = 0
local maxWait = 20
repeat
    task.wait(0.2)
    maxWaitTime = maxWaitTime + 0.2
until (not isTeleportUIVisible() and isPlayerInValidState()) or maxWaitTime > maxWait

if maxWaitTime > maxWait and not isPlayerInValidState() then
    task.wait(3)
end

task.wait(1)

getgenv()._AbilityUIBuilt = false
getgenv()._AbilityUIBuilding = false

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

getgenv().SuppressCameraErrors = true

local FILTER_PATTERNS = {
    "playermodule", "cameramodule", "zoomcontroller", "popper", "poppercam",
    "imagelabel", "not a valid member", "is not a valid member",
    "attempt to perform arithmetic", "playerscripts", "byorials",
    "stack begin", "stack end", "runservice", "firerenderstepearlyfunctions",
    "vector3", "nil and vector", "querypoint", "queryviewport"
}

local function shouldFilterMessage(msg)
    if not getgenv().SuppressCameraErrors then return false end
    if not msg or msg == "" then return false end
    local msgLower = msg:lower()
    for i = 1, #FILTER_PATTERNS do
        if msgLower:find(FILTER_PATTERNS[i], 1, true) then
            return true
        end
    end
    return false
end

local oldLogWarn = logwarn or warn
local oldWarn = warn
local oldPrint = print

local function filteredWarn(...)
    local args = {...}
    if #args == 0 then return end
    local msg = table.concat(args, " ")
    if not shouldFilterMessage(msg) then
        oldLogWarn(...)
    end
end

local function filteredError(...)
    local args = {...}
    if #args == 0 then return end
    local msg = table.concat(args, " ")
    if not shouldFilterMessage(msg) then
        if logerror then
            logerror(...)
        else
            error(msg, 2)
        end
    end
end

if logwarn then logwarn = filteredWarn end
warn = filteredWarn

if logerror then logerror = filteredError end

local game_LogService = game:GetService("LogService")
pcall(function()
    game_LogService.MessageOut:Connect(function(message, messageType)
        if messageType == Enum.MessageType.MessageError or messageType == Enum.MessageType.MessageWarning then
            if shouldFilterMessage(message) then
                return
            end
        end
    end)
end)

pcall(function()
    local ScriptContext = game:GetService("ScriptContext")
    ScriptContext.Error:Connect(function(message, stackTrace, script)
        if shouldFilterMessage(message) or shouldFilterMessage(stackTrace) then
            return
        end
    end)
end)

task.spawn(function()
    pcall(function()
        local StarterPlayer = game:GetService("StarterPlayer")
        local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
        if StarterPlayerScripts then
            local PlayerModule = StarterPlayerScripts:FindFirstChild("PlayerModule")
            if PlayerModule then
                local CameraModule = PlayerModule:FindFirstChild("CameraModule")
                if CameraModule then
                    local ZoomController = CameraModule:FindFirstChild("ZoomController")
                    if ZoomController then
                        local Popper = ZoomController:FindFirstChild("Popper")
                        if Popper and Popper:IsA("ModuleScript") then
                            local success = pcall(function()
                                local popperModule = require(Popper)
                                if popperModule and type(popperModule) == "table" then
                                    for key, value in pairs(popperModule) do
                                        if type(value) == "function" then
                                            popperModule[key] = function(...)
                                                local ok, result = pcall(value, ...)
                                                if ok then return result end
                                                return nil
                                            end
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)
end)

local function createObsidianCompat()
    local compat = {
        Options = {},
        Toggles = {},
        ForceCheckbox = false,
        ShowToggleFrameInKeybinds = true,
        KeybindFrame = { Visible = false },
        _windows = {},
        _currentWindow = nil,
        _theme = {},
    }

    local function makeSignal()
        local listeners = {}
        return {
            Connect = function(_, fn)
                listeners[#listeners + 1] = fn
                return { Disconnect = function() end }
            end,
            Fire = function(_, ...)
                for i = 1, #listeners do
                    pcall(listeners[i], ...)
                end
            end
        }
    end

    local function makeToggleProxy(key, defaultValue)
        local signal = makeSignal()
        local proxy = {
            Key = key,
            Value = defaultValue == true,
            OnChanged = function(self, cb)
                signal:Connect(function()
                    cb(self.Value)
                end)
            end,
            _fire = function(self)
                signal:Fire(self.Value)
            end,
        }
        return proxy
    end

    local function makeOptionProxy(key, element)
        local signal = makeSignal()
        local proxy = {
            Key = key,
            _element = element,
            _values = nil,
            Value = nil,
            OnChanged = function(self, cb)
                signal:Connect(function(val)
                    cb(val)
                end)
            end,
            SetValue = function(self, val)
                self.Value = val
                local e = rawget(self, "_element")
                if e then
                    if type(e.Select) == "function" then
                        pcall(function() e:Select(val) end)
                    elseif type(e.Set) == "function" then
                        pcall(function() e:Set(val) end)
                    elseif type(e.SetValue) == "function" then
                        pcall(function() e:SetValue(val) end)
                    end
                end
                signal:Fire(val)
            end,
            SetValues = function(self, list)
                self._values = list
                local e = rawget(self, "_element")
                if e and type(e.Refresh) == "function" then
                    pcall(function() e:Refresh(list) end)
                end
            end,
            _fire = function(self, val)
                self.Value = val
                signal:Fire(val)
            end,
        }
        return proxy
    end

    local windowWrapperMT
    local tabWrapperMT
    local groupWrapperMT
    local labelWrapperMT

    labelWrapperMT = {
        __index = function(self, k)
            if k == "AddKeyPicker" then
                return function(_, key, opts)
                    opts = opts or {}
                    local el = self._tab:Keybind({
                        Flag = key,
                        Title = opts.Text or "Menu keybind",
                        Desc = opts.Desc,
                        Value = (opts.Default or "LeftControl"),
                        Callback = function(v)
                            local opt = compat.Options[key]
                            if opt then opt:_fire(v) end
                            if compat._currentWindow and type(compat._currentWindow.SetToggleKey) == "function" then
                                pcall(function() compat._currentWindow:SetToggleKey(Enum.KeyCode[v]) end)
                            end
                        end,
                    })
                    local proxy = makeOptionProxy(key, el)
                    compat.Options[key] = proxy
                    return el
                end
            end
        end
    }

    groupWrapperMT = {
        __index = function(self, k)
            if k == "AddLabel" then
                return function(_, text)
                    self._tab:Section({ Title = tostring(text) })
                    return setmetatable({ _tab = self._tab }, labelWrapperMT)
                end
            elseif k == "AddDivider" then
                return function()
                    self._tab:Space({ Columns = 1 })
                end
            elseif k == "AddButton" then
                return function(_, text, cb)
                    self._tab:Button({ Title = tostring(text), Callback = function()
                        if type(cb) == "function" then cb() end
                    end })
                end
            elseif k == "AddToggle" then
                return function(_, key, cfg)
                    cfg = cfg or {}
                    local initial = cfg.Default == true
                    local proxy = compat.Toggles[key] or makeToggleProxy(key, initial)
                    compat.Toggles[key] = proxy
                    local el = self._tab:Toggle({
                        Flag = key,
                        Title = cfg.Text or key,
                        Desc = cfg.Desc,
                        Default = initial,
                        Locked = cfg.Locked == true,
                        Callback = function(state)
                            proxy.Value = state
                            if type(cfg.Callback) == "function" then
                                pcall(function() cfg.Callback(state) end)
                            end
                            proxy:_fire()
                        end
                    })
                    return el
                end
            elseif k == "AddDropdown" then
                return function(_, key, cfg)
                    cfg = cfg or {}
                    local el = self._tab:Dropdown({
                        Flag = key,
                        Title = cfg.Text or key,
                        Values = cfg.Values or {},
                        Value = cfg.Default,
                        Multi = cfg.Multi == true,
                        Searchable = cfg.Searchable == true,
                        Callback = function(value)
                            local opt = compat.Options[key]
                            if type(cfg.Callback) == "function" then
                                pcall(function() cfg.Callback(value) end)
                            end
                            if opt then opt:_fire(value) end
                        end
                    })
                    local proxy = makeOptionProxy(key, el)
                    if cfg.Default ~= nil then proxy.Value = cfg.Default end
                    compat.Options[key] = proxy
                    return el
                end
            elseif k == "AddInput" then
                return function(_, key, cfg)
                    cfg = cfg or {}
                    local el = self._tab:Input({
                        Flag = key,
                        Title = cfg.Text or key,
                        Desc = cfg.Placeholder,
                        Value = cfg.Default or "",
                        Type = (cfg.Type == "Textarea" and "Textarea" or "Input"),
                        Placeholder = cfg.Placeholder,
                        Callback = function(val)
                            if type(cfg.Callback) == "function" then
                                pcall(function() cfg.Callback(val) end)
                            end
                            local opt = compat.Options[key]
                            if opt then opt:_fire(val) end
                        end
                    })
                    local proxy = makeOptionProxy(key, el)
                    proxy.Value = cfg.Default or ""
                    compat.Options[key] = proxy
                    return el
                end
            end
        end
    }

    tabWrapperMT = {
        __index = function(self, k)
            if k == "AddLeftGroupbox" or k == "AddRightGroupbox" then
                return function(_, title)
                    if title and title ~= "" then
                        self._tab:Section({ Title = tostring(title) })
                    end
                    return setmetatable({ _tab = self._tab }, groupWrapperMT)
                end
            elseif k == "AddLabel" then
                return function(_, text)
                    self._tab:Section({ Title = tostring(text) })
                end
            end
        end
    }

    windowWrapperMT = {
        __index = function(self, k)
            if k == "AddTab" then
                return function(_, title, icon)
                    return self._wnd:Tab({ Title = tostring(title), Icon = tostring(icon or "") })
                end
            elseif k == "Section" then
                return function(_, opts)
                    return self._wnd:Section(opts)
                end
            else
                return self._wnd[k]
            end
        end
    }

    function compat:CreateWindow(opts)
        opts = opts or {}
        local wnd = WindUI:CreateWindow({
            Title = tostring(opts.Title or "ALS"),
            Author = tostring(opts.Footer or ""),
            Folder = "ALS-WindUI",
            Size = opts.Size or UDim2.fromOffset(700, 460),
            NewElements = true,
            HideSearchBar = false,
            OpenButton = {
                Title = tostring(opts.Title or "ALS"),
                CornerRadius = UDim.new(1, 0),
                StrokeThickness = 1,
                Enabled = true,
                Draggable = true,
                OnlyMobile = false,
                Color = ColorSequence.new(Color3.fromRGB(48, 255, 106), Color3.fromRGB(231, 255, 47)),
            },
        })
        local wrapper = setmetatable({ _wnd = wnd }, windowWrapperMT)
        self._currentWindow = wnd
        return wrapper
    end

    function compat:Notify(info)
        local title = (info and (info.Title or info.title)) or "ALS"
        local content = (info and (info.Description or info.Desc or info.Content)) or ""
        local duration = (info and (info.Duration or info.Time)) or nil
        WindUI:Notify({ Title = title, Content = content, Duration = duration })
    end

    function compat:Unload()
        self.Unloaded = true
        if self._currentWindow and type(self._currentWindow.Destroy) == "function" then
            pcall(function() self._currentWindow:Destroy() end)
        end
    end

    function compat:Toggle()
        if self._currentWindow then
            local ok = pcall(function()
                if type(self._currentWindow.Toggle) == "function" then
                    self._currentWindow:Toggle()
                elseif type(self._currentWindow.SetVisible) == "function" then
                    self._currentWindow:SetVisible(not self._visible)
                    self._visible = not self._visible
                end
            end)
            if not ok then
            end
        end
    end

    return compat
end

local Library = createObsidianCompat()
local ThemeManager = {
    SetLibrary = function() end,
    SetFolder = function() end,
    ApplyToTab = function() end,
}

getgenv().ALS_Library = Library
getgenv().ALS_ThemeManager = ThemeManager

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local MOBILE_DELAY_MULTIPLIER = isMobile and 1.5 or 1.0

local function cleanupBeforeTeleport()    
    pcall(function()
        if Library and Library.Unload then
            Library:Unload()
        end
    end)
    
    pcall(function()
        getgenv().ALS_Library = nil
        getgenv().ALS_ThemeManager = nil
        getgenv().AutoAbilitiesEnabled = nil
        getgenv().CardSelectionEnabled = nil
        getgenv().SlowerCardSelectionEnabled = nil
    end)
    
    pcall(function()
        if getconnections then
            local services = {RunService.Heartbeat, RunService.RenderStepped, RunService.Stepped}
            for i = 1, #services do
                local connections = getconnections(services[i])
                for j = 1, #connections do
                    local conn = connections[j]
                    if conn.Disable then conn:Disable() end
                    if conn.Disconnect then conn:Disconnect() end
                end
            end
        end
    end)
    
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local children = coreGui:GetChildren()
        for i = 1, #children do
            local gui = children[i]
            local name = gui.Name
            if name:find("Wind") or name:find("ALS") or name:find("UI") then
                gui:Destroy()
            end
        end
    end)
    
    pcall(collectgarbage, "collect")
    task.wait(0.2)
end

getgenv().CleanupBeforeTeleport = cleanupBeforeTeleport

local LOBBY_PLACEIDS = {12886143095, 18583778121}
local function checkIsInLobby()
    local currentPlaceId = game.PlaceId
    for i = 1, #LOBBY_PLACEIDS do
        if currentPlaceId == LOBBY_PLACEIDS[i] then return true end
    end
    return false
end
local isInLobby = checkIsInLobby()

local CONFIG_FOLDER = "ALSHalloweenEvent"
local CONFIG_FILE = "config.json"
local USER_ID = tostring(LocalPlayer.UserId)

local function getConfigPath()
    return CONFIG_FOLDER .. "/" .. USER_ID .. "/" .. CONFIG_FILE
end
local function getUserFolder()
    return CONFIG_FOLDER .. "/" .. USER_ID
end
local function loadConfig()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    local userFolder = getUserFolder()
    if not isfolder(userFolder) then makefolder(userFolder) end
    local configPath = getConfigPath()
    if isfile(configPath) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(configPath))
        end)
        if ok and type(data) == "table" then
            data.toggles = data.toggles or {}
            data.inputs = data.inputs or {}
            data.dropdowns = data.dropdowns or {}
            data.abilities = data.abilities or {}
            data.autoJoin = data.autoJoin or {}
            return data
        end
    end
    return { toggles = {}, inputs = {}, dropdowns = {}, abilities = {}, autoJoin = {} }
end
local function saveConfig(config)
    local userFolder = getUserFolder()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    if not isfolder(userFolder) then makefolder(userFolder) end
    local ok, err = pcall(function()
        local json = HttpService:JSONEncode(config)
        writefile(getConfigPath(), json)
    end)
    if not ok then warn("[Config] Save failed: " .. tostring(err)) end
    return ok
end

getgenv().Config = loadConfig()
getgenv().Config.toggles = getgenv().Config.toggles or {}
getgenv().Config.inputs = getgenv().Config.inputs or {}
getgenv().Config.dropdowns = getgenv().Config.dropdowns or {}
getgenv().Config.abilities = getgenv().Config.abilities or {}

local MACRO_FOLDER = CONFIG_FOLDER .. "/macros"
local SETTINGS_FILE = MACRO_FOLDER .. "/settings.json"

    if not isfolder(MACRO_FOLDER) then makefolder(MACRO_FOLDER) end

    getgenv().Macros = {}
    getgenv().MacroMaps = {}

local function loadMacroSettings()
    local settings = {
        playMacroEnabled = false,
        selectedMacro = nil,
        macroMaps = {},
        stepDelay = 0
    }
    pcall(function()
        if isfile(SETTINGS_FILE) then
            local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
            if type(data) == "table" then
                settings = data
            end
        end
    end)
    return settings
end

local function saveMacroSettings()
    pcall(function()
        local settings = {
            playMacroEnabled = getgenv().MacroPlayEnabled or false,
            selectedMacro = getgenv().CurrentMacro,
            macroMaps = getgenv().MacroMaps or {},
            stepDelay = getgenv().MacroStepDelay or 0
        }
        writefile(SETTINGS_FILE, HttpService:JSONEncode(settings))
    end)
end

local function loadMacros()
    table.clear(getgenv().Macros or {})
    getgenv().Macros = getgenv().Macros or {}
    if not isfolder(MACRO_FOLDER) then return end
    local files = listfiles(MACRO_FOLDER)
    if not files then return end
    for i = 1, #files do
        local file = files[i]
        if file:sub(-5) == ".json" then
            local fileName = file:match("([^/\\]+)%.json$")
            
            if fileName ~= "settings" and fileName ~= "playback_state" then
                local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(file))
                if ok and type(data) == "table" then
                    local isSettings = (data.playMacroEnabled ~= nil or data.selectedMacro ~= nil or data.macroMaps ~= nil)
                    if not isSettings then
                        getgenv().Macros[fileName] = data
                    end
                end
            end
        end
    end
end

local function saveMacro(name, data)
    local success, err = pcall(function()
        writefile(MACRO_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
        getgenv().Macros[name] = data
    end)
    if not success then
        warn("[Macro] Failed to save:", err)
    end
    return success
end

local function getMacroNames()
    local names = {}
    local count = 0
    for name in pairs(getgenv().Macros) do 
        count = count + 1
        names[count] = name
    end
    table.sort(names)
    return names
end

local savedMacroSettings = loadMacroSettings()
getgenv().MacroMaps = savedMacroSettings.macroMaps or {}
getgenv().MacroStepDelay = savedMacroSettings.stepDelay or 0
getgenv().CurrentMacro = savedMacroSettings.selectedMacro
getgenv().MacroPlayEnabled = savedMacroSettings.playMacroEnabled or false

print("[Macro] Loaded settings - CurrentMacro:", getgenv().CurrentMacro)

loadMacros()

if getgenv().CurrentMacro and getgenv().Macros[getgenv().CurrentMacro] then
    getgenv().MacroData = getgenv().Macros[getgenv().CurrentMacro]
    getgenv().TotalSteps = #getgenv().MacroData
    print("[Macro] Loaded MacroData for", getgenv().CurrentMacro, "- Steps:", getgenv().TotalSteps)
else
    getgenv().MacroData = {}
    getgenv().TotalSteps = 0
    print("[Macro] No macro data loaded - CurrentMacro:", getgenv().CurrentMacro)
end

getgenv().LoadMacroSettings = loadMacroSettings
getgenv().SaveMacroSettings = saveMacroSettings
getgenv().LoadMacros = loadMacros
getgenv().SaveMacro = saveMacro
getgenv().GetMacroNames = getMacroNames

getgenv().MacroStatusText = "Idle"
getgenv().MacroActionText = ""
getgenv().MacroUnitText = ""
getgenv().MacroWaitingText = ""
getgenv().MacroCurrentStep = 0
getgenv().MacroTotalSteps = 0
getgenv().MacroLastStatusUpdate = 0

getgenv().UpdateMacroStatus = function()
    local now = tick()
    if now - getgenv().MacroLastStatusUpdate < 0.033 then 
        return 
    end
    getgenv().MacroLastStatusUpdate = now
    
    local statusLabel = getgenv().MacroStatusLabel
    local stepLabel = getgenv().MacroStepLabel
    local actionLabel = getgenv().MacroActionLabel
    local unitLabel = getgenv().MacroUnitLabel
    local waitingLabel = getgenv().MacroWaitingLabel
    
    pcall(function()
        if statusLabel and statusLabel.SetTitle then
            statusLabel:SetTitle("Status: " .. (getgenv().MacroStatusText or "Idle"))
        end
        
        if stepLabel and stepLabel.SetTitle then
            stepLabel:SetTitle("📝 Step: " .. (getgenv().MacroCurrentStep or 0) .. "/" .. (getgenv().MacroTotalSteps or 0))
        end
        
        if actionLabel and actionLabel.SetTitle then
            local actionText = (getgenv().MacroActionText and getgenv().MacroActionText ~= "") and getgenv().MacroActionText or "None"
            actionLabel:SetTitle("⚡ Action: " .. actionText)
        end
        
        if unitLabel and unitLabel.SetTitle then
            local unitText = (getgenv().MacroUnitText and getgenv().MacroUnitText ~= "") and getgenv().MacroUnitText or "None"
            unitLabel:SetTitle("🗼 Unit: " .. unitText)
        end
        
        if waitingLabel and waitingLabel.SetTitle then
            local waitingText = (getgenv().MacroWaitingText and getgenv().MacroWaitingText ~= "") and getgenv().MacroWaitingText or "None"
            waitingLabel:SetTitle("⏳ Waiting: " .. waitingText)
        end
    end)
end

getgenv().MacroCurrentCash = 0
getgenv().MacroLastCash = 0
getgenv().MacroCashHistory = {}
local MAX_CASH_HISTORY = 30

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        pcall(function()
            getgenv().MacroCurrentCash = LocalPlayer.Cash.Value
        end)
    end
end)

local cashTrackingActive = false
local function trackCash()
    if cashTrackingActive then return end
    cashTrackingActive = true
    
    task.spawn(function()
        while true do
            RunService.Heartbeat:Wait()
            
            local currentCash = 0
            pcall(function()
                currentCash = LocalPlayer.Cash.Value
            end)
            
            if getgenv().MacroLastCash > 0 and currentCash < getgenv().MacroLastCash then
                local decrease = getgenv().MacroLastCash - currentCash
                table.insert(getgenv().MacroCashHistory, 1, {
                    time = tick(),
                    decrease = decrease,
                    before = getgenv().MacroLastCash,
                    after = currentCash
                })
                
                if #getgenv().MacroCashHistory > MAX_CASH_HISTORY then
                    table.remove(getgenv().MacroCashHistory, #getgenv().MacroCashHistory)
                end
            end
            
            getgenv().MacroLastCash = currentCash
        end
    end)
end

getgenv().GetRecentCashDecrease = function(withinSeconds)
    withinSeconds = withinSeconds or 1
    local now = tick()
    local history = getgenv().MacroCashHistory
    for i = 1, #history do
        local entry = history[i]
        if (now - entry.time) <= withinSeconds then
            return entry.decrease
        end
    end
    return 0
end

getgenv().GetPlaceCost = function(towerName)
    if not getgenv().MacroTowerInfoCache then
        return 0
    end
    
    if not getgenv().MacroTowerInfoCache[towerName] then 
        return 0 
    end
    
    if getgenv().MacroTowerInfoCache[towerName][0] then
        return getgenv().MacroTowerInfoCache[towerName][0].Cost or 0
    end
    
    return 0
end

trackCash()

local function isKilled()
    return getgenv().MacroSystemKillSwitch == true
end

getgenv().IsKilled = isKilled

getgenv().MacroTowerInfoCache = {}
getgenv().MacroRemoteCache = {}

local function cacheTowerInfo()
    if next(getgenv().MacroTowerInfoCache) then return end
    
    pcall(function()
        local towerInfoPath = RS:WaitForChild("Modules"):WaitForChild("TowerInfo")
        local children = towerInfoPath:GetChildren()
        for i = 1, #children do
            local mod = children[i]
            if mod:IsA("ModuleScript") then
                local ok, data = pcall(require, mod)
                if ok then 
                    getgenv().MacroTowerInfoCache[mod.Name] = data 
                end
            end
        end
    end)
end

local function cacheRemotes()
    if next(getgenv().MacroRemoteCache) then return true end
    
    local count = 0
    pcall(function()
        local descendants = RS:GetDescendants()
        for i = 1, #descendants do
            local v = descendants[i]
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                getgenv().MacroRemoteCache[v.Name:lower()] = v
                count = count + 1
            end
        end
    end)
    
    return count > 0
end

local function ensureCachesReady()
    cacheTowerInfo()
    
    local attempts = 0
    while not cacheRemotes() and attempts < 10 do
        task.wait(0.5)
        attempts = attempts + 1
    end
    
    if attempts >= 10 then
        warn("[Macro] Warning: Remote cache may be incomplete")
    end
end

getgenv().CacheTowerInfo = cacheTowerInfo
getgenv().CacheRemotes = cacheRemotes
getgenv().EnsureCachesReady = ensureCachesReady

task.spawn(function()
    task.wait(2)
    ensureCachesReady()
end)

getgenv().MacroRecording = false
if not getgenv().MacroData then
    getgenv().MacroData = {}
end
getgenv().TowerPlaceCounts = {}
local placementMonitor = {}

local hookSuccess = false
local mt, old

pcall(function()
    mt = getrawmetatable(game)
    old = mt.__namecall
    
    local makeWritableSuccess = pcall(function()
        setreadonly(mt, false)
    end)
    
    if not makeWritableSuccess then
        if make_writeable then
            make_writeable(mt)
        elseif setwriteable then
            setwriteable(mt, true)
        end
    end
    
    hookSuccess = true
end)

if not hookSuccess then
    warn("[Macro] Failed to hook metatable - recording may not work")
end

if hookSuccess then
mt.__namecall = function(self, ...)
    local method, args = getnamecallmethod(), {...}
    local remoteName = tostring(self.Name or "")
    
    local result = old(self, ...)
    
    if getgenv().MacroRecording and (method == "FireServer" or method == "InvokeServer") then
        if remoteName:lower():find("place") or remoteName:lower():find("tower") then
            if args[1] then
                task.spawn(function()
                    local success, err = pcall(function()
                        local towerName = tostring(args[1])
                        local now = tick()
                        local actionKey = towerName .. "_" .. now
                        
                        if placementMonitor[actionKey] then return end
                        placementMonitor[actionKey] = true
                        
                        if not getgenv().TowerPlaceCounts then 
                            getgenv().TowerPlaceCounts = {} 
                        end
                        local countBefore = getgenv().TowerPlaceCounts[towerName] or 0
                        
                        local placementLimit = 999
                        pcall(function()
                            local existingTower = workspace.Towers:FindFirstChild(towerName)
                            if existingTower and existingTower:FindFirstChild("PlacementLimit") then
                                placementLimit = existingTower.PlacementLimit.Value
                            end
                        end)
                        
                        if countBefore >= placementLimit then
                            placementMonitor[actionKey] = nil
                            return
                        end
                        
                        getgenv().MacroStatusText = "Recording"
                        getgenv().MacroActionText = "Placing..."
                        getgenv().MacroUnitText = towerName
                        getgenv().MacroWaitingText = ""
                        if getgenv().UpdateMacroStatus then
                            getgenv().UpdateMacroStatus()
                        end
                        
                        task.wait(0.65)
                        
                        local countAfter = 0
                        pcall(function()
                            for _, t in pairs(workspace.Towers:GetChildren()) do
                                if t.Name == towerName and t:FindFirstChild("Owner") and t.Owner.Value == LocalPlayer then
                                    countAfter = countAfter + 1
                                end
                            end
                        end)
                        
                        if countAfter > countBefore and countAfter <= placementLimit then
                            task.wait(0.12)
                            
                            local cost = 0
                            if getgenv().GetRecentCashDecrease then
                                cost = getgenv().GetRecentCashDecrease(2.5)
                            end
                            
                            if cost == 0 and getgenv().GetPlaceCost then
                                cost = getgenv().GetPlaceCost(towerName)
                            end
                            
                            local savedArgs = {}
                            savedArgs[1] = args[1]
                            if args[2] and typeof(args[2]) == "CFrame" then
                                savedArgs[2] = {args[2]:GetComponents()}
                            end
                            
                            getgenv().TowerPlaceCounts[towerName] = countAfter
                            
                            table.insert(getgenv().MacroData, {
                                RemoteName = remoteName,
                                Args = savedArgs,
                                Time = now,
                                IsInvoke = (method == "InvokeServer"),
                                Cost = cost,
                                TowerName = towerName,
                                ActionType = "Place"
                            })
                            
                            getgenv().MacroStatusText = "Recording"
                            getgenv().MacroCurrentStep = #getgenv().MacroData
                            getgenv().MacroTotalSteps = #getgenv().MacroData
                            getgenv().MacroActionText = "Place"
                            getgenv().MacroUnitText = towerName
                            getgenv().MacroWaitingText = ""
                            if getgenv().UpdateMacroStatus then
                                getgenv().UpdateMacroStatus()
                            end
                        else
                            getgenv().MacroStatusText = "Recording"
                            getgenv().MacroActionText = ""
                            getgenv().MacroUnitText = ""
                            getgenv().MacroWaitingText = ""
                            if getgenv().UpdateMacroStatus then
                                getgenv().UpdateMacroStatus()
                            end
                        end
                        
                        placementMonitor[actionKey] = nil
                    end)
                    
                    if not success then
                        warn("[Macro] Recording error:", err)
                    end
                end)
            end
        end
    end
    
    return result
end

pcall(function()
    setreadonly(mt, true)
end)

if not hookSuccess then
    warn("[Macro] Metatable hook was not set up - macro recording will not work!")
    warn("[Macro] This is usually caused by executor limitations or conflicts with other scripts")
end
end

task.spawn(function()
    while true do
        task.wait(5)
        local now = tick()
        for key, timestamp in pairs(placementMonitor) do
            if (now - timestamp) > 5 then
                placementMonitor[key] = nil
            end
        end
    end
end)

local towerMonitor = {}
local lastRecordedUpgrade = {}

local AUTO_UPGRADE_CLONES = {
    ["NarutoBaryonClone"] = true,
    ["WukongClone"] = true,
}

local function isAutoUpgradeClone(towerName)
    return AUTO_UPGRADE_CLONES[towerName] == true
end

local monitorConnection
monitorConnection = RunService.Heartbeat:Connect(function()
    if not getgenv().MacroRecording then return end
    
    pcall(function()
        local towers = workspace.Towers:GetChildren()
        for i = 1, #towers do
            local tower = towers[i]
            if tower:FindFirstChild("Owner") and tower.Owner.Value == LocalPlayer then
                local towerName = tower.Name
                local upgradeLevel = 0
                
                if tower:FindFirstChild("Upgrade") then
                    upgradeLevel = tower.Upgrade.Value
                end
                
                if not towerMonitor[towerName] then
                    towerMonitor[towerName] = {
                        lastLevel = upgradeLevel,
                        lastRecordTime = 0,
                        lastCost = 0
                    }
                end
                
                if upgradeLevel > towerMonitor[towerName].lastLevel then
                    local now = tick()
                    
                    if isAutoUpgradeClone(towerName) then
                        towerMonitor[towerName].lastLevel = upgradeLevel
                        return
                    end
                    
                    if (now - towerMonitor[towerName].lastRecordTime) > 0.12 then
                        task.spawn(function()
                            task.wait(0.08)
                            
                            local cost = getgenv().GetRecentCashDecrease(2.5)
                            local levelBefore = towerMonitor[towerName].lastLevel
                            
                            local upgradeKey = towerName .. "_" .. levelBefore .. "_" .. upgradeLevel
                            if lastRecordedUpgrade[upgradeKey] and (now - lastRecordedUpgrade[upgradeKey]) < 0.8 then
                                towerMonitor[towerName].lastLevel = upgradeLevel
                                return
                            end
                            
                            if cost == 0 and towerMonitor[towerName].lastCost > 0 then
                                cost = towerMonitor[towerName].lastCost
                            end
                            
                            if cost == towerMonitor[towerName].lastCost and cost > 0 and (now - towerMonitor[towerName].lastRecordTime) < 0.4 then
                                towerMonitor[towerName].lastLevel = upgradeLevel
                                return
                            end
                            
                            table.insert(getgenv().MacroData, {
                                RemoteName = "Upgrade",
                                Args = {nil},
                                Time = now,
                                IsInvoke = true,
                                Cost = cost,
                                TowerName = towerName,
                                ActionType = "Upgrade"
                            })
                            
                            towerMonitor[towerName].lastLevel = upgradeLevel
                            towerMonitor[towerName].lastRecordTime = now
                            if cost > 0 then
                                towerMonitor[towerName].lastCost = cost
                            end
                            lastRecordedUpgrade[upgradeKey] = now
                            
                            getgenv().MacroStatusText = "Recording"
                            getgenv().MacroCurrentStep = #getgenv().MacroData
                            getgenv().MacroTotalSteps = #getgenv().MacroData
                            getgenv().MacroActionText = "Upgrade"
                            getgenv().MacroUnitText = towerName
                            getgenv().MacroWaitingText = ""
                            getgenv().UpdateMacroStatus()
                        end)
                    end
                end
            end
        end
    end)
    
    if not getgenv().MacroRecording then
        towerMonitor = {}
        lastRecordedUpgrade = {}
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        local now = tick()
        for key, time in pairs(lastRecordedUpgrade) do
            if (now - time) > 5 then
                lastRecordedUpgrade[key] = nil
            end
        end
    end
end)

getgenv().AutoEventEnabled = getgenv().Config.toggles.AutoEventToggle or false
getgenv().AutoAbilitiesEnabled = getgenv().Config.toggles.AutoAbilityToggle or false
getgenv().AutoReadyEnabled = getgenv().Config.toggles.AutoReadyToggle or false
getgenv().CardSelectionEnabled = getgenv().Config.toggles.CardSelectionToggle or false
getgenv().SlowerCardSelectionEnabled = getgenv().Config.toggles.SlowerCardSelectionToggle or false
getgenv().BossRushEnabled = getgenv().Config.toggles.BossRushToggle or false
getgenv().WebhookEnabled = getgenv().Config.toggles.WebhookToggle or false
getgenv().PingOnSecretDrop = getgenv().Config.toggles.PingOnSecretToggle or false
getgenv().SeamlessLimiterEnabled = getgenv().Config.toggles.SeamlessToggle or false
getgenv().BingoEnabled = getgenv().Config.toggles.BingoToggle or false
getgenv().CapsuleEnabled = getgenv().Config.toggles.CapsuleToggle or false
getgenv().RemoveEnemiesEnabled = getgenv().Config.toggles.RemoveEnemiesToggle or false
getgenv().AntiAFKEnabled = getgenv().Config.toggles.AntiAFKToggle or false
getgenv().BlackScreenEnabled = getgenv().Config.toggles.BlackScreenToggle or false
getgenv().FPSBoostEnabled = (not isInLobby) and (getgenv().Config.toggles.FPSBoostToggle or false) or false

getgenv().AutoLeaveEnabled = getgenv().Config.toggles.AutoLeaveToggle or false
getgenv().AutoFastRetryEnabled = getgenv().Config.toggles.AutoFastRetryToggle or false
getgenv().AutoNextEnabled = getgenv().Config.toggles.AutoNextToggle or false
getgenv().AutoSmartEnabled = getgenv().Config.toggles.AutoSmartToggle or false

getgenv().FinalExpAutoJoinEasyEnabled = getgenv().Config.toggles.FinalExpAutoJoinEasyToggle or false
getgenv().FinalExpAutoJoinHardEnabled = getgenv().Config.toggles.FinalExpAutoJoinHardToggle or false
getgenv().FinalExpAutoSkipShopEnabled = getgenv().Config.toggles.FinalExpAutoSkipShopToggle or false

getgenv().MacroEnabled = getgenv().Config.toggles.MacroToggle or false

getgenv().AutoExecuteEnabled = getgenv().Config.toggles.AutoExecuteToggle or false

local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

if getgenv().AutoExecuteEnabled and queueteleport then
    local TeleportCheck = false
    LocalPlayer.OnTeleport:Connect(function(State)
        if getgenv().AutoExecuteEnabled and (not TeleportCheck) and queueteleport then
            TeleportCheck = true
            queueteleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/Byorl/ALS-Scripts/refs/heads/main/ALS%20Halloween%20UI.lua"))()')
            print("[ALS] Auto Execute queued for next game")
        end
    end)
    print("[ALS] Auto Execute on Teleport enabled")
elseif getgenv().AutoExecuteEnabled and not queueteleport then
    warn("[ALS] Auto Execute enabled but queueteleport function not found in your executor")
end

getgenv().WebhookURL = getgenv().Config.inputs.WebhookURL or ""
getgenv().DiscordUserID = getgenv().Config.inputs.DiscordUserID or ""
getgenv().MaxSeamlessRounds = tonumber(getgenv().Config.inputs.SeamlessRounds) or 4
getgenv().UnitAbilities = getgenv().UnitAbilities or {}

getgenv().CandyCards = {
    ["Weakened Resolve I"] = 13, ["Weakened Resolve II"] = 11, ["Weakened Resolve III"] = 4,
    ["Fog of War I"] = 12, ["Fog of War II"] = 10, ["Fog of War III"] = 5,
    ["Lingering Fear I"] = 6, ["Lingering Fear II"] = 2,
    ["Power Reversal I"] = 14, ["Power Reversal II"] = 9,
    ["Greedy Vampire's"] = 8, ["Hellish Gravity"] = 3, ["Deadly Striker"] = 7,
    ["Critical Denial"] = 1, ["Trick or Treat Coin Flip"] = 15
}
getgenv().DevilSacrifice = { ["Devil's Sacrifice"] = 999 }
getgenv().OtherCards = {
    ["Bullet Breaker I"] = 999, ["Bullet Breaker II"] = 999, ["Bullet Breaker III"] = 999,
    ["Hell Merchant I"] = 999, ["Hell Merchant II"] = 999, ["Hell Merchant III"] = 999,
    ["Hellish Warp I"] = 999, ["Hellish Warp II"] = 999,
    ["Fiery Surge I"] = 999, ["Fiery Surge II"] = 999,
    ["Grevious Wounds I"] = 999, ["Grevious Wounds II"] = 999,
    ["Scorching Hell I"] = 999, ["Scorching Hell II"] = 999,
    ["Fortune Flow"] = 999, ["Soul Link"] = 999
}
getgenv().CardPriority = getgenv().CardPriority or {}
local configInputs = getgenv().Config.inputs
local cardPriority = getgenv().CardPriority

local function loadCardPriorities(cardTable)
    if not cardTable then return end
    for n, v in pairs(cardTable) do
        local key = "Card_" .. n
        cardPriority[n] = configInputs[key] and tonumber(configInputs[key]) or v
    end
end

loadCardPriorities(getgenv().CandyCards)
loadCardPriorities(getgenv().DevilSacrifice)
loadCardPriorities(getgenv().OtherCards)

getgenv().BossRushGeneral = {
    ["Metal Skin"] = 0,["Raging Power"] = 0,["Demon Takeover"] = 0,["Fortune"] = 0,
    ["Chaos Eater"] = 0,["Godspeed"] = 0,["Insanity"] = 0,["Feeding Madness"] = 0,["Emotional Damage"] = 0
}
getgenv().BabyloniaCastle = {}
getgenv().BossRushCardPriority = getgenv().BossRushCardPriority or {}
local bossRushPriority = getgenv().BossRushCardPriority

local function loadBossRushPriorities(cardTable, prefix)
    if not cardTable then return end
    for n, v in pairs(cardTable) do
        local key = prefix .. n
        bossRushPriority[n] = configInputs[key] and tonumber(configInputs[key]) or v
    end
end

loadBossRushPriorities(getgenv().BossRushGeneral, "BossRush_")
loadBossRushPriorities(getgenv().BabyloniaCastle, "BabyloniaCastle_")

getgenv().BreachAutoJoin = getgenv().BreachAutoJoin or {}
getgenv().BreachEnabled = getgenv().Config.toggles.BreachToggle or false

local function getClientData()
    local ok, data = pcall(function()
        local modulePath = RS:WaitForChild("Modules"):WaitForChild("ClientData")
        if modulePath and modulePath:IsA("ModuleScript") then
            return require(modulePath)
        end
        return nil
    end)
    return ok and data or nil
end
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

local function notify(title, content, duration)
    Library:Notify({
        Title = title or "ALS",
        Description = content or "",
        Time = duration or 3,
    })
end

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window
local windowAttempts = 0
local windowCreated = false

while not windowCreated and windowAttempts < 3 do
    windowAttempts = windowAttempts + 1
    local windowSuccess, result = pcall(function()
        return Library:CreateWindow({
            Title = "ALS Halloween Event",
            Footer = "Anime Last Stand Script",
            Icon = 72399447876912,
            NotifySide = getgenv().Config.inputs.NotificationSide or "Right",
            ShowCustomCursor = getgenv().Config.toggles.ShowCustomCursor ~= false,
            Size = UDim2.fromOffset(700, 460),
        })
    end)
    if windowSuccess and result then
        Window = result
        windowCreated = true
    else
        warn("[UI] Failed to create window (Attempt " .. windowAttempts .. "/3):", result)
        task.wait(1)
        if windowAttempts >= 3 then
            Window = Library:CreateWindow({
                Title = "ALS Halloween Event",
                Footer = "Anime Last Stand Script",
                Size = UDim2.fromOffset(700, 460),
            })
            windowCreated = true
        end
    end
end

task.wait(0.5)



local UpdatesSection = Window:Section({
    Title = "Updates",
    Icon = "newspaper",
})

local MainSection = Window:Section({
    Title = "Main",
    Icon = "archive",
})

local MacroSection = Window:Section({
    Title = "Macro",
    Icon = "map-pin",
})

local EventSection = Window:Section({
    Title = "Halloween Event",
    Icon = "gift",
})

local CombatSection = Window:Section({
    Title = "Combat",
    Icon = "swords",
})

local ModesSection = Window:Section({
    Title = "Game Modes",
    Icon = "gamepad-2",
})

local AutomationSection = Window:Section({
    Title = "Automation",
    Icon = "zap",
})

local SettingsSection = Window:Section({
    Title = "Settings",
    Icon = "settings",
})


local Tabs = {
    Changes = UpdatesSection:Tab({ Title = "Recent Changes", Icon = "file-text" }),
    
    AutoJoin = MainSection:Tab({ Title = "Auto Join", Icon = "log-in" }),
    GameAuto = MainSection:Tab({ Title = "Game Actions", Icon = "play" }),

    Macro = MacroSection:Tab({ Title = "Macro", Icon = "play-circle" }),
    MacroMaps = MacroSection:Tab({ Title = "Map Assignment", Icon = "map" }),
    
    Abilities = CombatSection:Tab({ Title = "Auto Abilities", Icon = "zap" }),
    
    CardSelection = EventSection:Tab({ Title = "Card Priority", Icon = "layers" }),
    Event = EventSection:Tab({ Title = "Event Farm", Icon = "candy-cane" }),
    
    BossRush = ModesSection:Tab({ Title = "Boss Rush", Icon = "shield" }),
    Breach = ModesSection:Tab({ Title = "Breach", Icon = "alert-triangle" }),
    FinalExp = ModesSection:Tab({ Title = "Final Expedition", Icon = "map" }),
    
    Webhook = AutomationSection:Tab({ Title = "Webhook", Icon = "send" }),
    SeamlessFix = AutomationSection:Tab({ Title = "Seamless Fix", Icon = "refresh-cw" }),
    
    Performance = SettingsSection:Tab({ Title = "Performance", Icon = "gauge" }),
    Safety = SettingsSection:Tab({ Title = "Safety & UI", Icon = "shield-check" }),
    Config = SettingsSection:Tab({ Title = "Config", Icon = "save" }),
}


Tabs.Changes:Paragraph({
    Title = "🎉 Welcome to ALS Halloween Event Script",
    Desc = "Switched to WindUI for better performance and modern design. Check out the changes below!",
})

Tabs.Changes:Space()

Tabs.Changes:Section({ Title = "📅 October 13, 2025 - Critical Fixes & Optimization" })

Tabs.Changes:Paragraph({
    Title = "🐛 Major Bug Fixes",
    Desc = "• Fixed Auto Abilities conditions not loading from saved config\n• Fixed duplicate ability UI elements when toggling settings\n• Fixed webhook sending incomplete data (Wave 0, Unknown result)\n• Fixed ability cooldowns not respecting game speed multiplier (1x/2x/3x)",
})

Tabs.Changes:Paragraph({
    Title = "⚡ Performance Improvements",
    Desc = "• Removed all redundant code comments for cleaner codebase\n• Fixed duplicate code in Auto Ready loop causing instability\n• Optimized dropdown initialization to prevent UI freezing\n• Improved webhook timing to collect all data before auto-replay\n• Reduced memory overhead throughout the script",
})

Tabs.Changes:Paragraph({
    Title = "🔧 Technical Improvements",
    Desc = "• Conditions dropdowns now use proper array format for WindUI\n• Dynamic TimeScale reading for accurate ability cooldowns\n• Better debouncing on dropdown force-select operations\n• Enhanced webhook validation to skip incomplete match data\n• Auto-replay now waits 6 seconds for webhook data collection",
})

Tabs.Changes:Space()

Tabs.Changes:Section({ Title = "📅 October 10, 2025 - Major Update" })

Tabs.Changes:Paragraph({
    Title = "✨ New UI Library - WindUI",
    Desc = "Completely rebuilt the script using WindUI for a modern, clean interface with better organization and performance.",
})

Tabs.Changes:Paragraph({
    Title = "🔧 Critical Fixes",
    Desc = "• Fixed teleport/serverhop crashes caused by memory buildup\n• Ultra aggressive cleanup before every teleport (100% crash prevention)\n• Fixed config not loading into UI (toggles and dropdowns now show saved values)\n• Fixed dropdowns appearing blank on script load\n• Added AutoJoinConfig persistence to save your map selections",
})

Tabs.Changes:Paragraph({
    Title = "🎨 UI Improvements",
    Desc = "• Reorganized tabs into logical sections with icons\n• Cleaner ability display with better formatting\n• Added emoji icons to sections for easier navigation\n• Improved dropdown and toggle initialization\n• Better mobile optimization",
})

Tabs.Changes:Paragraph({
    Title = "⚡ Performance Enhancements",
    Desc = "• Periodic garbage collection every 30 seconds\n• Enhanced FPS Boost (removes particles, sounds, shadows)\n• More aggressive graphics reduction\n• Memory optimization throughout the script\n• Faster UI loading times",
})

Tabs.Changes:Paragraph({
    Title = "🆕 New Features",
    Desc = "• Server Hop (Safe) button with automatic cleanup\n• Better player state validation after teleport\n• Improved console logging for debugging\n• Config auto-save on every change\n• This changelog tab!",
})

Tabs.Changes:Space()

Tabs.Changes:Section({ Title = "🔮 Coming Soon" })

Tabs.Changes:Paragraph({
    Title = "Planned Features",
    Desc = "• Auto-update system\n• More customization options\n• Additional game mode support\n• Performance analytics\n• Cloud config sync",
})

Tabs.Changes:Space()

Tabs.Changes:Section({ Title = "💡 Tips" })

Tabs.Changes:Paragraph({
    Title = "Getting Started",
    Desc = "1. Configure your Auto Join settings in the Main section\n2. Set up Auto Abilities for your units in Combat section\n3. Enable FPS Boost in Settings for better performance\n4. Use Server Hop (Safe) button to avoid crashes when switching servers",
})

Tabs.Changes:Divider()

local function applyOldConfigValue(flag, elementType)
    if elementType == "toggle" and getgenv().Config.toggles[flag] ~= nil then
        return getgenv().Config.toggles[flag]
    elseif elementType == "input" and getgenv().Config.inputs[flag] ~= nil then
        return getgenv().Config.inputs[flag]
    elseif elementType == "dropdown" and getgenv().Config.dropdowns[flag] ~= nil then
        return getgenv().Config.dropdowns[flag]
    end
    return nil
end

local function adaptTab(tab)
    return setmetatable({ _tab = tab }, {
        __index = function(self, k)
            if k == "AddToggle" then
                return function(_, flag, cfg)
                    cfg = cfg or {}
                    local configValue = applyOldConfigValue(flag, "toggle")
                    if configValue ~= nil then
                        cfg.Default = configValue
                    end
                    
                    if cfg.Default == nil then
                        cfg.Default = false
                    end
                    
                    local toggle = tab:Toggle({
                        Flag = flag,
                        Title = cfg.Text or flag,
                        Desc = cfg.Desc,
                        Default = cfg.Default,
                        Locked = cfg.Locked == true,
                        Callback = function(state)
                            if Library.Toggles[flag] then
                                Library.Toggles[flag].Value = state
                            end
                            getgenv().Config.toggles[flag] = state
                            saveConfig(getgenv().Config)
                            if cfg.Callback then
                                cfg.Callback(state)
                            end
                        end,
                    })
                    
                    local proxy = {
                        Value = cfg.Default,
                        SetValue = function(self, val)
                            self.Value = val
                            if toggle and toggle.Set then
                                toggle:Set(val)
                            end
                        end,
                        _element = toggle
                    }
                    Library.Toggles[flag] = proxy
                    
                    task.spawn(function()
                        task.wait(0.15)
                        if toggle and toggle.Set and cfg.Default ~= nil then
                            toggle:Set(cfg.Default)
                        end
                    end)
                    
                    return toggle
                end
            elseif k == "AddDropdown" then
                return function(_, flag, cfg)
                    cfg = cfg or {}
                    local configValue = applyOldConfigValue(flag, "dropdown")
                    if configValue ~= nil then
                        cfg.Default = configValue
                        cfg.Value = configValue
                    end
                    
                    local initialValue = cfg.Value or cfg.Default
                    
                    local dropdown = tab:Dropdown({
                        Flag = flag,
                        Title = cfg.Text or cfg.Title or flag,
                        Values = cfg.Values or {},
                        Value = initialValue, 
                        Multi = cfg.Multi == true,
                        AllowNone = cfg.AllowNone == true,
                        Searchable = cfg.Searchable == true,
                        Callback = function(value)
                            if Library.Options[flag] then
                                Library.Options[flag].Value = value
                            end
                            getgenv().Config.dropdowns[flag] = value
                            saveConfig(getgenv().Config)
                            if cfg.Callback then
                                cfg.Callback(value)
                            end
                        end,
                    })
                    
                    local proxy = {
                        Value = initialValue,
                        SetValue = function(self, val)
                            self.Value = val
                            if dropdown and dropdown.Select then
                                dropdown:Select(val)
                            end
                        end,
                        SetValues = function(self, list)
                            if dropdown and dropdown.Refresh then
                                dropdown:Refresh(list)
                            end
                        end,
                        _element = dropdown
                    }
                    Library.Options[flag] = proxy
                    
                    getgenv()._dropdownInitDone = getgenv()._dropdownInitDone or {}
                    if not getgenv()._dropdownInitDone[flag] and initialValue ~= nil then
                        getgenv()._dropdownInitDone[flag] = true
                        task.spawn(function()
                            task.wait(0.3)
                            if dropdown and dropdown.Select then
                                pcall(function()
                                    dropdown:Select(initialValue)
                                end)
                            end
                        end)
                    end
                    
                    return dropdown
                end
            elseif k == "AddInput" then
                return function(_, flag, cfg)
                    cfg = cfg or {}
                    local configValue = applyOldConfigValue(flag, "input")
                    if configValue ~= nil then
                        cfg.Default = configValue
                    end
                    return tab:Input({
                        Flag = flag,
                        Title = cfg.Text or cfg.Title or flag,
                        Desc = cfg.Desc or cfg.Placeholder,
                        Value = cfg.Default,
                        Type = (cfg.Type == "Textarea" and "Textarea" or "Input"),
                        Placeholder = cfg.Placeholder,
                        Callback = function(value)
                            getgenv().Config.inputs[flag] = value
                            saveConfig(getgenv().Config)
                            if cfg.Callback then
                                cfg.Callback(value)
                            end
                        end,
                    })
                end
            elseif k == "AddButton" then
                return function(_, text, cb)
                    return tab:Button({ Title = tostring(text), Callback = cb })
                end
            elseif k == "AddLabel" then
                return function(_, text)
                    return tab:Section({ Title = tostring(text) })
                end
            elseif k == "AddDivider" then
                return function()
                    return tab:Divider({})
                end
            elseif k == "AddLeftGroupbox" or k == "AddRightGroupbox" then
                return function(_, title)
                    if title and title ~= "" then
                        tab:Section({ Title = tostring(title) })
                    end
                    return setmetatable({ _tab = tab }, groupWrapperMT)
                end
            elseif k == "Paragraph" or k == "Space" or k == "Divider" or k == "Button" or k == "Toggle" or k == "Dropdown" or k == "Input" or k == "Section" then
                return tab[k]
            else
                return tab[k]
            end
        end
    })
end

local GB = {}
GB.Main_Left = adaptTab(Tabs.AutoJoin)
GB.Main_Right = adaptTab(Tabs.GameAuto)
GB.Macro = adaptTab(Tabs.Macro)
GB.MacroMaps = adaptTab(Tabs.MacroMaps)
GB.Ability_Left = adaptTab(Tabs.Abilities)
GB.Ability_Right = adaptTab(Tabs.Abilities)
GB.Card_Left = adaptTab(Tabs.CardSelection)
GB.Card_Right = adaptTab(Tabs.CardSelection)
GB.Boss_Left = adaptTab(Tabs.BossRush)
GB.Boss_Right = adaptTab(Tabs.BossRush)
GB.Breach_Left = adaptTab(Tabs.Breach)
GB.FinalExp_Left = adaptTab(Tabs.FinalExp)
GB.FinalExp_Right = adaptTab(Tabs.FinalExp)
GB.Webhook_Left = adaptTab(Tabs.Webhook)
GB.Seam_Left = adaptTab(Tabs.SeamlessFix)
GB.Event_Left = adaptTab(Tabs.Event)
GB.Misc_Left = adaptTab(Tabs.Performance)
GB.Misc_Right = adaptTab(Tabs.Safety)
GB.Settings_Left = adaptTab(Tabs.Config)
GB.Settings_Right = adaptTab(Tabs.Config)

local Options = Library.Options
local Toggles = Library.Toggles

local function addToggle(group, key, text, default, onChanged)
    local configValue = applyOldConfigValue(key, "toggle")
    if configValue ~= nil then
        default = configValue
    end
    
    if default == nil then
        default = false
    end
    
    local toggle
    local success, err = pcall(function()
        toggle = group:AddToggle(key, {
            Text = text,
            Default = default,
            Callback = function(val)
                if onChanged then pcall(function() onChanged(val) end) end
            end,
        })
    end)
    
    if not success then
        warn("[addToggle] Failed to create toggle for " .. tostring(key) .. ": " .. tostring(err))
    end
    
    return toggle
end

GB.Main_Left:Paragraph({
    Title = "🎮 Auto Join System",
    Desc = "Automatically join maps and start games. Configure your preferred mode, map, act, and difficulty below."
})
GB.Main_Left:Space()

local savedAutoJoin = getgenv().Config.autoJoin or {}
getgenv().AutoJoinConfig = {
    enabled = savedAutoJoin.enabled or false,
    autoStart = savedAutoJoin.autoStart or false,
    friendsOnly = savedAutoJoin.friendsOnly or false,
    mode = savedAutoJoin.mode or "Story",
    map = savedAutoJoin.map or "",
    act = savedAutoJoin.act or 1,
    difficulty = savedAutoJoin.difficulty or "Normal"
}


local MapData = nil
pcall(function()
    local mapDataModule = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("MapData")
    if mapDataModule and mapDataModule:IsA("ModuleScript") then
        MapData = require(mapDataModule)
    end
end)
local function getMapsByMode(mode)
    if not MapData then return {} end
    if mode == "ElementalCaverns" then return {"Light","Nature","Fire","Dark","Water"} end
    local maps = {}
    for mapName, mapInfo in pairs(MapData) do
        if mapInfo.Type and type(mapInfo.Type) == "table" then
            for _, mapType in ipairs(mapInfo.Type) do
                if mapType == mode then table.insert(maps, mapName) break end
            end
        end
    end
    table.sort(maps)
    return maps
end

GB.Main_Left:AddDropdown("AutoJoinMode", {
    Values = {"Story", "Infinite", "Challenge", "LegendaryStages", "Raids", "Dungeon", "Survival", "ElementalCaverns", "Event", "MidnightHunt", "BossRush", "Siege", "Breach"},
    Default = getgenv().AutoJoinConfig.mode or "Story",
    Text = "Mode",
    Callback = function(value)
        getgenv().AutoJoinConfig.mode = value
        getgenv().Config.autoJoin.mode = value
        saveConfig(getgenv().Config)
        local newMaps = getMapsByMode(value)
        if Options.AutoJoinMap then Options.AutoJoinMap:SetValues(newMaps) end
        if #newMaps > 0 then
            if Options.AutoJoinMap then Options.AutoJoinMap:SetValue(newMaps[1]) end
            getgenv().AutoJoinConfig.map = newMaps[1]
            getgenv().Config.autoJoin.map = newMaps[1]
            saveConfig(getgenv().Config)
        end
    end,
    Searchable = true,
})
GB.Main_Left:AddDropdown("AutoJoinMap", {
    Values = getMapsByMode(getgenv().AutoJoinConfig.mode),
    Default = getgenv().AutoJoinConfig.map ~= "" and getgenv().AutoJoinConfig.map or nil,
    Text = "Map",
    Callback = function(value)
        getgenv().AutoJoinConfig.map = value
        getgenv().Config.autoJoin.map = value
        saveConfig(getgenv().Config)
    end,
    Searchable = true,
})
GB.Main_Left:AddDropdown("AutoJoinAct", {
    Values = {"1","2","3","4","5","6"},
    Default = tostring(getgenv().AutoJoinConfig.act or 1),
    Text = "Act",
    Callback = function(value)
        getgenv().AutoJoinConfig.act = tonumber(value) or 1
        getgenv().Config.autoJoin.act = tonumber(value) or 1
        saveConfig(getgenv().Config)
    end,
})
GB.Main_Left:AddDropdown("AutoJoinDifficulty", {
    Values = {"Normal","Nightmare","Purgatory","Insanity"},
    Default = getgenv().AutoJoinConfig.difficulty or "Normal",
    Text = "Difficulty",
    Callback = function(value)
        getgenv().AutoJoinConfig.difficulty = value
        getgenv().Config.autoJoin.difficulty = value
        saveConfig(getgenv().Config)
    end,
})

addToggle(GB.Main_Left, "AutoJoinToggle", "Auto Join Map", getgenv().AutoJoinConfig.enabled or false, function(val)
    getgenv().AutoJoinConfig.enabled = val
    getgenv().Config.autoJoin.enabled = val
    saveConfig(getgenv().Config)
    notify("Auto Join", val and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Main_Left, "AutoJoinStartToggle", "Auto Start", getgenv().AutoJoinConfig.autoStart or false, function(val)
    getgenv().AutoJoinConfig.autoStart = val
    getgenv().Config.autoJoin.autoStart = val
    saveConfig(getgenv().Config)
    notify("Auto Start", val and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Main_Left, "FriendsOnlyToggle", "Friends Only", getgenv().AutoJoinConfig.friendsOnly or false, function(val)
    getgenv().AutoJoinConfig.friendsOnly = val
    getgenv().Config.autoJoin.friendsOnly = val
    saveConfig(getgenv().Config)
    pcall(function()
        RS.Remotes.Teleporter.InteractEvent:FireServer("FriendsOnly")
    end)
    notify("Friends Only", val and "Enabled" or "Disabled", 3)
end)


GB.Main_Left:Space({ Columns = 1 })

GB.Main_Right:Paragraph({
    Title = "🎯 Game Actions",
    Desc = "Automate common game actions like leaving, replaying, and progressing to the next stage."
})
GB.Main_Right:Space()
GB.Main_Right:Section({ Title = "⚙️ Action Toggles" })
addToggle(GB.Main_Right, "AutoLeaveToggle", "Auto Leave", getgenv().Config.toggles.AutoLeaveToggle or false, function(val)
    getgenv().AutoLeaveEnabled = val
    getgenv().Config.toggles.AutoLeaveToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Leave", val and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Main_Right, "AutoFastRetryToggle", "Auto Replay", getgenv().Config.toggles.AutoFastRetryToggle or false, function(val)
    getgenv().AutoFastRetryEnabled = val
    getgenv().Config.toggles.AutoFastRetryToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Replay", val and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Main_Right, "AutoNextToggle", "Auto Next", getgenv().Config.toggles.AutoNextToggle or false, function(val)
    getgenv().AutoNextEnabled = val
    getgenv().Config.toggles.AutoNextToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Next", val and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Main_Right, "AutoSmartToggle", "Auto Leave/Replay/Next", getgenv().Config.toggles.AutoSmartToggle or false, function(val)
    getgenv().AutoSmartEnabled = val
    getgenv().Config.toggles.AutoSmartToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Leave/Replay/Next", val and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Main_Right, "AutoReadyToggle", "Auto Ready", getgenv().Config.toggles.AutoReadyToggle or false, function(val)
    getgenv().AutoReadyEnabled = val
    getgenv().Config.toggles.AutoReadyToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Ready", val and "Enabled" or "Disabled", 3)
end)

GB.Macro:Paragraph({
    Title = "🎬 Macro System",
    Desc = "Record and playback tower placement and upgrade sequences. Create automated strategies for different maps."
})
GB.Macro:Space()

GB.Macro:Section({ Title = "📁 Macro Management" })

getgenv().MacroDropdown = nil
getgenv().TotalSteps = 0

pcall(function()
    local dropdown = GB.Macro:AddDropdown("MacroSelect", {
        Text = "Select Macro",
        Values = getMacroNames(),
        Default = getgenv().CurrentMacro,
        Callback = function(value)
            pcall(function()
                print("[Macro] Dropdown callback triggered for:", value)
                print("[Macro] MacroData before callback:", getgenv().MacroData and #getgenv().MacroData or "nil")
                
                getgenv().CurrentMacro = value
                if value and getgenv().Macros[value] then
                    getgenv().MacroData = getgenv().Macros[value]
                    getgenv().TotalSteps = #getgenv().MacroData
                    getgenv().MacroTotalSteps = getgenv().TotalSteps
                    getgenv().MacroCurrentStep = 0
                    getgenv().UpdateMacroStatus()
                    saveMacroSettings()
                    
                    print("[Macro] MacroData after callback:", #getgenv().MacroData)
                    notify("Macro Selected", value .. " (" .. getgenv().TotalSteps .. " steps)", 3)
                else
                    getgenv().MacroData = {}
                    getgenv().TotalSteps = 0
                    getgenv().MacroTotalSteps = 0
                    getgenv().MacroCurrentStep = 0
                    getgenv().UpdateMacroStatus()
                end
            end)
        end
    })
    
    getgenv().MacroDropdown = dropdown
    
    if dropdown and type(dropdown.Refresh) == "function" then
        print("[Macro] Dropdown created successfully with Refresh method")
    else
        warn("[Macro] Dropdown missing Refresh method!")
    end
end)

pcall(function()
    local createInput = GB.Macro:AddInput("MacroCreate", {
        Text = "Create New Macro",
        Placeholder = "Enter macro name...",
        Finished = true,
        Callback = function(value)
            pcall(function()
                if value and value ~= "" then
                    saveMacro(value, {})
                    loadMacros()
                    
                    local macroNames = getMacroNames()
                    if getgenv().MacroDropdown and getgenv().MacroDropdown.SetValues then
                        getgenv().MacroDropdown:SetValues(macroNames)
                    end
                    
                    getgenv().CurrentMacro = value
                    getgenv().MacroData = {}
                    getgenv().TotalSteps = 0
                    getgenv().MacroTotalSteps = 0
                    
                    if getgenv().MacroDropdown and getgenv().MacroDropdown.SetValue then
                        getgenv().MacroDropdown:SetValue(value)
                    end
                    
                    saveMacroSettings()
                    notify("Macro Created", value, 3)
                    
                    if createInput and createInput.Set then
                        task.spawn(function()
                            task.wait(0.1)
                            pcall(function()
                                createInput:Set("")
                            end)
                        end)
                    end
                end
            end)
        end
    })
    
    getgenv().Config.inputs.MacroCreate = nil
    saveConfig(getgenv().Config)
end)

pcall(function()
    GB.Macro:AddButton("Refresh Macro List", function()
        pcall(function()
            loadMacros()
            local newMacroNames = getMacroNames()
            
            print("[Macro] Loaded macros:", table.concat(newMacroNames, ", "))
            print("[Macro] MacroDropdown exists:", getgenv().MacroDropdown ~= nil)
            
            if getgenv().MacroDropdown then
                print("[Macro] MacroDropdown type:", type(getgenv().MacroDropdown))
                print("[Macro] Has Refresh method:", type(getgenv().MacroDropdown.Refresh))
                
                local success, err = pcall(function()
                    getgenv().MacroDropdown:Refresh(newMacroNames)
                    print("[Macro] Refresh called successfully")
                end)
                
                if not success then
                    warn("[Macro] Refresh failed:", err)
                    notify("Refresh Error", tostring(err), 5)
                else
                    notify("Macro List", "Refreshed (" .. #newMacroNames .. " macros)", 3)
                end
            else
                warn("[Macro] MacroDropdown is nil")
                notify("Error", "Dropdown not found - try reloading UI", 3)
            end
        end)
    end)
end)

GB.Macro:Space()
GB.Macro:Section({ Title = "🎮 Recording & Playback" })

addToggle(GB.Macro, "MacroRecordToggle", "🔴 Record Macro", false, function(val)
    pcall(function()
        if isKilled() then return end
        getgenv().MacroRecording = val
        if val then
            getgenv().MacroData = {}
            getgenv().TotalSteps = 0
            getgenv().TowerPlaceCounts = {}
            getgenv().MacroCashHistory = {}
            
            getgenv().MacroStatusText = "Recording"
            getgenv().MacroCurrentStep = 0
            getgenv().MacroTotalSteps = 0
            getgenv().MacroActionText = ""
            getgenv().MacroUnitText = ""
            getgenv().MacroWaitingText = ""
            getgenv().UpdateMacroStatus()
            
            notify("Recording", "Started recording macro...", 3)
        else
            if getgenv().CurrentMacro and #getgenv().MacroData > 0 then
                saveMacro(getgenv().CurrentMacro, getgenv().MacroData)
                getgenv().TotalSteps = #getgenv().MacroData
                notify("Recording Stopped", "Saved " .. getgenv().TotalSteps .. " steps", 5)
            else
                notify("Recording Stopped", "No macro selected or no steps recorded", 3)
            end
            
            getgenv().MacroStatusText = "Idle"
            getgenv().MacroCurrentStep = 0
            getgenv().MacroTotalSteps = getgenv().TotalSteps or 0
            getgenv().MacroActionText = ""
            getgenv().MacroUnitText = ""
            getgenv().MacroWaitingText = ""
            getgenv().UpdateMacroStatus()
        end
    end)
end)


local function hasStartButton()
    local hasStart = false
    pcall(function()
        local b = LocalPlayer.PlayerGui:FindFirstChild("Bottom")
        if b and b.Frame and b.Frame:GetChildren()[2] then
            local sub = b.Frame:GetChildren()[2]:GetChildren()[6]
            if sub and sub.TextButton and sub.TextButton.TextLabel then
                hasStart = sub.TextButton.TextLabel.Text == "Start"
            end
        end
    end)
    return hasStart
end

local function detectMacroProgress()
    local lastCompletedStep = 0
    
    pcall(function()
        if not getgenv().CurrentMacro or not getgenv().MacroData then
            return
        end
        
        local macroData = getgenv().MacroData
        if not macroData or #macroData == 0 then return end
        
        local towerStates = {}
        local playerTowers = workspace:FindFirstChild("Towers")
        if not playerTowers then return end
        
        for _, tower in pairs(playerTowers:GetChildren()) do
            pcall(function()
                local ownerValue = tower:FindFirstChild("Owner")
                if ownerValue and ownerValue.Value == LocalPlayer then
                    local towerName = tower.Name
                    
                    if not towerStates[towerName] then
                        towerStates[towerName] = {
                            count = 0,
                            levels = {}
                        }
                    end
                    
                    towerStates[towerName].count = towerStates[towerName].count + 1
                    
                    local upgradeValue = tower:FindFirstChild("Upgrade")
                    if upgradeValue then
                        table.insert(towerStates[towerName].levels, upgradeValue.Value)
                    else
                        table.insert(towerStates[towerName].levels, 0)
                    end
                end
            end)
        end
        
        local expectedCounts = {}
        local expectedLevels = {}
        
        for i, action in ipairs(macroData) do
            local towerName = action.TowerName
            if towerName then
                if action.ActionType == "Place" then
                    expectedCounts[towerName] = (expectedCounts[towerName] or 0) + 1
                    
                    local actualCount = (towerStates[towerName] and towerStates[towerName].count) or 0
                    if actualCount < expectedCounts[towerName] then
                        lastCompletedStep = i - 1
                        return
                    end
                    
                    if not expectedLevels[towerName] then
                        expectedLevels[towerName] = {}
                    end
                    table.insert(expectedLevels[towerName], 0)
                    
                    lastCompletedStep = i
                    
                elseif action.ActionType == "Upgrade" then
                    if not expectedLevels[towerName] then
                        expectedLevels[towerName] = {}
                    end
                    
                    local instanceIndex = #expectedLevels[towerName]
                    if instanceIndex > 0 then
                        local currentExpectedLevel = expectedLevels[towerName][instanceIndex]
                        local newExpectedLevel = currentExpectedLevel + 1
                        expectedLevels[towerName][instanceIndex] = newExpectedLevel
                        
                        local actualLevels = (towerStates[towerName] and towerStates[towerName].levels) or {}
                        local actualLevel = actualLevels[instanceIndex] or 0
                        
                        if actualLevel < newExpectedLevel then
                            lastCompletedStep = i - 1
                            return
                        end
                        
                        lastCompletedStep = i
                    end
                end
            end
        end
    end)
    
    return lastCompletedStep
end

getgenv().HasStartButton = hasStartButton
getgenv().DetectMacroProgress = detectMacroProgress

addToggle(GB.Macro, "MacroPlayToggle", "▶️ Play Macro", getgenv().MacroPlayEnabled or false, function(val)
    pcall(function()
        if isKilled() then return end
        getgenv().MacroPlayEnabled = val
        saveMacroSettings()
        
        print("[Macro] Play toggle changed to:", val)
        print("[Macro] CurrentMacro:", getgenv().CurrentMacro)
        print("[Macro] MacroData exists:", getgenv().MacroData ~= nil)
        print("[Macro] MacroData length:", getgenv().MacroData and #getgenv().MacroData or 0)
        
        if val then
            if getgenv().CurrentMacro and getgenv().MacroData and #getgenv().MacroData > 0 then
                print("[Macro] Starting playback...")
                task.spawn(function()
                    pcall(function()
                getgenv().MacroStatusText = "Initializing"
                getgenv().MacroCurrentStep = 0
                getgenv().MacroTotalSteps = getgenv().TotalSteps or 0
                getgenv().MacroActionText = "Preparing..."
                getgenv().MacroUnitText = ""
                getgenv().MacroWaitingText = ""
                getgenv().UpdateMacroStatus()
                
                notify("Playback", "Initializing " .. getgenv().CurrentMacro, 3)
                
                getgenv().MacroActionText = "Loading caches..."
                getgenv().UpdateMacroStatus()
                ensureCachesReady()
                
                getgenv().MacroActionText = "Waiting for game start..."
                getgenv().UpdateMacroStatus()
                
                local waitStartTime = tick()
                while hasStartButton() and getgenv().MacroPlayEnabled and not isKilled() do
                    task.wait(0.1)
                    local elapsed = math.floor(tick() - waitStartTime)
                    getgenv().MacroWaitingText = elapsed .. "s"
                    getgenv().UpdateMacroStatus()
                end
                
                if isKilled() then
                    getgenv().MacroPlayEnabled = false
                    getgenv().MacroStatusText = "Idle"
                    getgenv().MacroActionText = ""
                    getgenv().MacroWaitingText = ""
                    getgenv().UpdateMacroStatus()
                    return
                end
                
                if not getgenv().MacroPlayEnabled then
                    getgenv().MacroStatusText = "Idle"
                    getgenv().MacroActionText = ""
                    getgenv().MacroWaitingText = ""
                    getgenv().UpdateMacroStatus()
                    return
                end
                
                getgenv().MacroActionText = "Detecting progress..."
                getgenv().MacroWaitingText = ""
                getgenv().UpdateMacroStatus()
                
                local resumeStep = detectMacroProgress()
                
                if resumeStep > 0 then
                    getgenv().MacroCurrentStep = resumeStep + 1
                    notify("Auto-Resume", "Resuming from step " .. (resumeStep + 1), 5)
                else
                    getgenv().MacroCurrentStep = 1
                end
                
                getgenv().MacroStatusText = "Playing"
                getgenv().MacroActionText = "Ready"
                getgenv().UpdateMacroStatus()
                
                notify("Playback", "Started playing " .. getgenv().CurrentMacro, 3)
                
                local step = getgenv().MacroCurrentStep or 1
                local macroData = getgenv().MacroData
                local shouldRestart = false
                local lastWave = 0
                
                pcall(function()
                    lastWave = RS.Wave.Value
                end)
                
                task.spawn(function()
                    while getgenv().MacroPlayEnabled and not isKilled() do
                        if hasStartButton() then
                            shouldRestart = true
                        end
                        task.wait()
                    end
                    if isKilled() then
                        getgenv().MacroPlayEnabled = false
                    end
                end)
                
                while getgenv().MacroPlayEnabled and not isKilled() do
                    if isKilled() then
                        getgenv().MacroPlayEnabled = false
                        break
                    end
                    
                    if shouldRestart then
                        getgenv().MacroStatusText = "Starting Macro/Restart Detected"
                        getgenv().MacroWaitingText = "Waiting for start..."
                        getgenv().MacroActionText = ""
                        getgenv().MacroUnitText = ""
                        getgenv().UpdateMacroStatus()
                        
                        repeat 
                            task.wait() 
                        until not hasStartButton() or not getgenv().MacroPlayEnabled or isKilled()
                        
                        if not getgenv().MacroPlayEnabled or isKilled() then break end
                        
                        shouldRestart = false
                        step = 1
                        task.wait(0.5)
                        notify("Game Restarted", "Macro restarting from step 1", 3)
                        continue
                    end
                    
                    if step > #macroData then
                        getgenv().MacroStatusText = "Waiting Next Round"
                        getgenv().MacroWaitingText = ""
                        getgenv().MacroActionText = ""
                        getgenv().MacroUnitText = ""
                        getgenv().UpdateMacroStatus()
                        
                        local currentWave = 0
                        repeat
                            task.wait(0.1)
                            
                            if isKilled() then
                                getgenv().MacroPlayEnabled = false
                                break
                            end
                            
                            pcall(function() 
                                currentWave = RS.Wave.Value 
                            end)
                            
                            if currentWave < lastWave and not hasStartButton() then
                                lastWave = currentWave
                                step = 1
                                task.wait(0.5)
                                notify("Seamless Retry", "Restarting macro...", 2)
                                break
                            end
                            
                            lastWave = currentWave
                        until not getgenv().MacroPlayEnabled or isKilled()
                        
                        if not getgenv().MacroPlayEnabled or isKilled() then break end
                        continue
                    end
                    
                    local action = macroData[step]
                    
                    if not action then
                        step = step + 1
                        continue
                    end
                    
                    getgenv().MacroCurrentStep = step
                    getgenv().MacroTotalSteps = #macroData
                    
                    local cash = getgenv().MacroCurrentCash or 0
                    local actionCost = action.Cost or 0
                    
                    if actionCost > 0 and cash < actionCost then
                        if isKilled() then
                            getgenv().MacroPlayEnabled = false
                            break
                        end
                        
                        if not action.waitStartTime then
                            action.waitStartTime = tick()
                        end
                        
                        local waitTime = tick() - action.waitStartTime
                        
                        getgenv().MacroStatusText = "Waiting Cash"
                        getgenv().MacroWaitingText = "$" .. actionCost .. " (" .. math.floor(waitTime) .. "s)"
                        getgenv().MacroActionText = action.ActionType or "Action"
                        getgenv().MacroUnitText = action.TowerName or "?"
                        getgenv().UpdateMacroStatus()
                        
                        RunService.Heartbeat:Wait()
                        continue
                    end
                    
                    action.waitStartTime = nil
                    
                    getgenv().MacroStatusText = "Playing"
                    getgenv().MacroWaitingText = ""
                    getgenv().MacroActionText = action.ActionType or "Action"
                    getgenv().MacroUnitText = action.TowerName or "?"
                    getgenv().UpdateMacroStatus()
                    
                    local function isAutoUpgradeClone(towerName)
                        return towerName == "NarutoBaryonClone" or towerName == "WukongClone"
                    end
                    
                    if action.TowerName and action.ActionType == "Upgrade" and isAutoUpgradeClone(action.TowerName) then
                        step = step + 1
                        continue
                    end
                    
                    pcall(function()
                        if not action.RemoteName then
                            return
                        end
                        
                        local remote = getgenv().MacroRemoteCache[action.RemoteName:lower()]
                        if not remote then 
                            return 
                        end
                        
                        if action.RemoteName:lower():find("upgrade") then
                            local towerToUpgrade = nil
                            
                            for _, t in pairs(workspace.Towers:GetChildren()) do
                                if t:FindFirstChild("Owner") and t.Owner.Value == LocalPlayer and t.Name == action.TowerName then
                                    towerToUpgrade = t
                                    break
                                end
                            end
                            
                            if not towerToUpgrade then
                                return
                            end
                            
                            local beforeLevel = towerToUpgrade:FindFirstChild("Upgrade") and towerToUpgrade.Upgrade.Value or 0
                            local maxLevel = towerToUpgrade:FindFirstChild("MaxUpgrade") and towerToUpgrade.MaxUpgrade.Value or 999
                            
                            if beforeLevel >= maxLevel then
                                return
                            end
                            
                            if remote:IsA("RemoteFunction") then
                                remote:InvokeServer(towerToUpgrade)
                            else
                                remote:FireServer(towerToUpgrade)
                            end
                            
                            task.wait(0.3)
                            
                        else
                            local towerName = action.TowerName or "Unknown"
                            
                            local args = {action.Args[1]}
                            if action.Args[2] and type(action.Args[2]) == "table" then
                                args[2] = CFrame.new(unpack(action.Args[2]))
                            else
                                args[2] = action.Args[2]
                            end
                            
                            if remote:IsA("RemoteFunction") then
                                remote:InvokeServer(unpack(args))
                            else
                                remote:FireServer(unpack(args))
                            end
                            
                            task.wait(0.3)
                        end
                    end)
                    
                    step = step + 1
                    
                    local stepDelay = getgenv().MacroStepDelay or 0
                    if stepDelay > 0 then
                        task.wait(stepDelay * MOBILE_DELAY_MULTIPLIER)
                    else
                        task.wait(0.15 * MOBILE_DELAY_MULTIPLIER)
                    end
                end
                
                getgenv().MacroCurrentStep = 0
                getgenv().MacroStatusText = "Idle"
                getgenv().MacroActionText = ""
                getgenv().MacroUnitText = ""
                getgenv().MacroWaitingText = ""
                getgenv().UpdateMacroStatus()
                
                if step > #macroData then
                    notify("Playback Finished", getgenv().CurrentMacro, 3)
                end
                    end)
                end)
            else
                print("[Macro] Cannot start playback - missing requirements")
                print("[Macro] CurrentMacro:", getgenv().CurrentMacro or "nil")
                print("[Macro] MacroData:", getgenv().MacroData and "exists" or "nil")
                print("[Macro] MacroData length:", getgenv().MacroData and #getgenv().MacroData or 0)
                getgenv().MacroPlayEnabled = false
                notify("Playback", "No macro selected or macro is empty", 3)
            end
        else
            getgenv().MacroStatusText = "Idle"
            getgenv().MacroCurrentStep = 0
            getgenv().MacroTotalSteps = getgenv().TotalSteps or 0
            getgenv().MacroActionText = ""
            getgenv().MacroUnitText = ""
            getgenv().MacroWaitingText = ""
            getgenv().UpdateMacroStatus()
            
            notify("Playback", "Stopped", 3)
        end
    end)
end)

if getgenv().MacroPlayEnabled and getgenv().CurrentMacro and getgenv().MacroData and #getgenv().MacroData > 0 then
    task.spawn(function()
        task.wait(1)
        if getgenv().MacroPlayEnabled and not isKilled() then
            notify("Auto-Start", "Resuming macro playback: " .. getgenv().CurrentMacro, 3)
            
            task.spawn(function()
                pcall(function()
                    getgenv().MacroStatusText = "Initializing"
                    getgenv().MacroCurrentStep = 0
                    getgenv().MacroTotalSteps = getgenv().TotalSteps or 0
                    getgenv().MacroActionText = "Preparing..."
                    getgenv().MacroUnitText = ""
                    getgenv().MacroWaitingText = ""
                    getgenv().UpdateMacroStatus()
                    
                    getgenv().MacroActionText = "Loading caches..."
                    getgenv().UpdateMacroStatus()
                    ensureCachesReady()
                    
                    getgenv().MacroActionText = "Waiting for game start..."
                    getgenv().UpdateMacroStatus()
                    
                    local waitStartTime = tick()
                    while hasStartButton() and getgenv().MacroPlayEnabled and not isKilled() do
                        task.wait(0.1)
                        local elapsed = math.floor(tick() - waitStartTime)
                        getgenv().MacroWaitingText = elapsed .. "s"
                        getgenv().UpdateMacroStatus()
                    end
                    
                    if isKilled() or not getgenv().MacroPlayEnabled then
                        getgenv().MacroStatusText = "Idle"
                        getgenv().MacroActionText = ""
                        getgenv().MacroWaitingText = ""
                        getgenv().UpdateMacroStatus()
                        return
                    end
                    
                    getgenv().MacroActionText = "Detecting progress..."
                    getgenv().MacroWaitingText = ""
                    getgenv().UpdateMacroStatus()
                    
                    local resumeStep = detectMacroProgress()
                    
                    if resumeStep > 0 then
                        getgenv().MacroCurrentStep = resumeStep + 1
                        notify("Auto-Resume", "Resuming from step " .. (resumeStep + 1), 5)
                    else
                        getgenv().MacroCurrentStep = 1
                    end
                    
                    getgenv().MacroStatusText = "Playing"
                    getgenv().MacroActionText = "Ready"
                    getgenv().UpdateMacroStatus()
                    
                    local step = getgenv().MacroCurrentStep or 1
                    local macroData = getgenv().MacroData
                    local shouldRestart = false
                    local lastWave = 0
                    
                    pcall(function()
                        lastWave = RS.Wave.Value
                    end)
                    
                    task.spawn(function()
                        while getgenv().MacroPlayEnabled and not isKilled() do
                            if hasStartButton() then
                                shouldRestart = true
                            end
                            task.wait()
                        end
                        if isKilled() then
                            getgenv().MacroPlayEnabled = false
                        end
                    end)
                    
                    while getgenv().MacroPlayEnabled and not isKilled() do
                        if isKilled() then
                            getgenv().MacroPlayEnabled = false
                            break
                        end
                        
                        if shouldRestart then
                            getgenv().MacroStatusText = "Starting Macro/Restart Detected"
                            getgenv().MacroWaitingText = "Waiting for start..."
                            getgenv().MacroActionText = ""
                            getgenv().MacroUnitText = ""
                            getgenv().UpdateMacroStatus()
                            
                            repeat 
                                task.wait() 
                            until not hasStartButton() or not getgenv().MacroPlayEnabled or isKilled()
                            
                            if not getgenv().MacroPlayEnabled or isKilled() then break end
                            
                            shouldRestart = false
                            step = 1
                            task.wait(0.5)
                            notify("Game Restarted", "Macro restarting from step 1", 3)
                            continue
                        end
                        
                        if step > #macroData then
                            getgenv().MacroStatusText = "Waiting Next Round"
                            getgenv().MacroWaitingText = ""
                            getgenv().MacroActionText = ""
                            getgenv().MacroUnitText = ""
                            getgenv().UpdateMacroStatus()
                            
                            local currentWave = 0
                            repeat
                                task.wait(0.1)
                                
                                if isKilled() then
                                    getgenv().MacroPlayEnabled = false
                                    break
                                end
                                
                                pcall(function() 
                                    currentWave = RS.Wave.Value 
                                end)
                                
                                if currentWave < lastWave and not hasStartButton() then
                                    lastWave = currentWave
                                    step = 1
                                    task.wait(0.5)
                                    notify("Seamless Retry", "Restarting macro...", 2)
                                    break
                                end
                                
                                lastWave = currentWave
                            until not getgenv().MacroPlayEnabled or isKilled()
                            
                            if not getgenv().MacroPlayEnabled or isKilled() then break end
                            continue
                        end
                        
                        local action = macroData[step]
                        
                        if not action then
                            step = step + 1
                            continue
                        end
                        
                        getgenv().MacroCurrentStep = step
                        getgenv().MacroTotalSteps = #macroData
                        
                        local cash = getgenv().MacroCurrentCash or 0
                        local actionCost = action.Cost or 0
                        
                        if actionCost > 0 and cash < actionCost then
                            if isKilled() then
                                getgenv().MacroPlayEnabled = false
                                break
                            end
                            
                            if not action.waitStartTime then
                                action.waitStartTime = tick()
                            end
                            
                            local waitTime = tick() - action.waitStartTime
                            
                            getgenv().MacroStatusText = "Waiting Cash"
                            getgenv().MacroWaitingText = "$" .. actionCost .. " (" .. math.floor(waitTime) .. "s)"
                            getgenv().MacroActionText = action.ActionType or "Action"
                            getgenv().MacroUnitText = action.TowerName or "?"
                            getgenv().UpdateMacroStatus()
                            
                            RunService.Heartbeat:Wait()
                            continue
                        end
                        
                        action.waitStartTime = nil
                        
                        getgenv().MacroStatusText = "Playing"
                        getgenv().MacroWaitingText = ""
                        getgenv().MacroActionText = action.ActionType or "Action"
                        getgenv().MacroUnitText = action.TowerName or "?"
                        getgenv().UpdateMacroStatus()
                        
                        local function isAutoUpgradeClone(towerName)
                            return towerName == "NarutoBaryonClone" or towerName == "WukongClone"
                        end
                        
                        if action.TowerName and action.ActionType == "Upgrade" and isAutoUpgradeClone(action.TowerName) then
                            step = step + 1
                            continue
                        end
                        
                        pcall(function()
                            if not action.RemoteName then
                                return
                            end
                            
                            local remote = getgenv().MacroRemoteCache[action.RemoteName:lower()]
                            if not remote then 
                                return 
                            end
                            
                            if action.RemoteName:lower():find("upgrade") then
                                local towerToUpgrade = nil
                                
                                for _, t in pairs(workspace.Towers:GetChildren()) do
                                    if t:FindFirstChild("Owner") and t.Owner.Value == LocalPlayer and t.Name == action.TowerName then
                                        towerToUpgrade = t
                                        break
                                    end
                                end
                                
                                if not towerToUpgrade then
                                    return
                                end
                                
                                local beforeLevel = towerToUpgrade:FindFirstChild("Upgrade") and towerToUpgrade.Upgrade.Value or 0
                                local maxLevel = towerToUpgrade:FindFirstChild("MaxUpgrade") and towerToUpgrade.MaxUpgrade.Value or 999
                                
                                if beforeLevel >= maxLevel then
                                    return
                                end
                                
                                if remote:IsA("RemoteFunction") then
                                    remote:InvokeServer(towerToUpgrade)
                                else
                                    remote:FireServer(towerToUpgrade)
                                end
                                
                                task.wait(0.3)
                                
                            else
                                local towerName = action.TowerName or "Unknown"
                                
                                local args = {action.Args[1]}
                                if action.Args[2] and type(action.Args[2]) == "table" then
                                    args[2] = CFrame.new(unpack(action.Args[2]))
                                else
                                    args[2] = action.Args[2]
                                end
                                
                                if remote:IsA("RemoteFunction") then
                                    remote:InvokeServer(unpack(args))
                                else
                                    remote:FireServer(unpack(args))
                                end
                                
                                task.wait(0.3)
                            end
                        end)
                        
                        step = step + 1
                        
                        local stepDelay = getgenv().MacroStepDelay or 0
                        if stepDelay > 0 then
                            task.wait(stepDelay * MOBILE_DELAY_MULTIPLIER)
                        else
                            task.wait(0.15 * MOBILE_DELAY_MULTIPLIER)
                        end
                    end
                    
                    getgenv().MacroCurrentStep = 0
                    getgenv().MacroStatusText = "Idle"
                    getgenv().MacroActionText = ""
                    getgenv().MacroUnitText = ""
                    getgenv().MacroWaitingText = ""
                    getgenv().UpdateMacroStatus()
                    
                    if step > #macroData then
                        notify("Playback Finished", getgenv().CurrentMacro, 3)
                    end
                end)
            end)
        end
    end)
end

GB.Macro:Space()
GB.Macro:Section({ Title = "⚙️ Playback Settings" })

GB.Macro:AddInput("MacroStepDelay", {
    Text = "Step Delay (seconds)",
    Placeholder = "0",
    Default = tostring(getgenv().MacroStepDelay or 0),
    Callback = function(value)
        local delay = tonumber(value) or 0
        getgenv().MacroStepDelay = delay
        saveMacroSettings()
        notify("Step Delay", "Set to " .. delay .. "s", 3)
    end
})

GB.Macro:Space()
GB.Macro:Section({ Title = "📊 Live Status" })

pcall(function()
    getgenv().MacroStatusLabel = GB.Macro:Paragraph({
        Title = "Status: Idle",
        Desc = ""
    })
    print("[Macro] StatusLabel created:", getgenv().MacroStatusLabel ~= nil, "Has SetTitle:", type(getgenv().MacroStatusLabel.SetTitle))
end)

pcall(function()
    getgenv().MacroStepLabel = GB.Macro:Paragraph({
        Title = "📝 Step: 0/0",
        Desc = ""
    })
    print("[Macro] StepLabel created:", getgenv().MacroStepLabel ~= nil, "Has SetTitle:", type(getgenv().MacroStepLabel.SetTitle))
end)

pcall(function()
    getgenv().MacroActionLabel = GB.Macro:Paragraph({
        Title = "⚡ Action: None",
        Desc = ""
    })
    print("[Macro] ActionLabel created:", getgenv().MacroActionLabel ~= nil, "Has SetTitle:", type(getgenv().MacroActionLabel.SetTitle))
end)

pcall(function()
    getgenv().MacroUnitLabel = GB.Macro:Paragraph({
        Title = "🗼 Unit: None",
        Desc = ""
    })
    print("[Macro] UnitLabel created:", getgenv().MacroUnitLabel ~= nil, "Has SetTitle:", type(getgenv().MacroUnitLabel.SetTitle))
end)

pcall(function()
    getgenv().MacroWaitingLabel = GB.Macro:Paragraph({
        Title = "⏳ Waiting: None",
        Desc = ""
    })
    print("[Macro] WaitingLabel created:", getgenv().MacroWaitingLabel ~= nil, "Has SetTitle:", type(getgenv().MacroWaitingLabel.SetTitle))
end)

    if not isInLobby then
        task.spawn(function()
            task.wait(2)
            
            pcall(function()
                local gamemode = RS:FindFirstChild("Gamemode")
                local mapName = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("MapName")
                
                if gamemode and mapName then
                    local gm = gamemode.Value
                    local mn = mapName.Value
                    
                    local key = gm .. "_" .. mn
                    
                    if getgenv().MacroMaps[key] and getgenv().MacroMaps[key] ~= "--" and getgenv().Macros[getgenv().MacroMaps[key]] then
                        getgenv().CurrentMacro = getgenv().MacroMaps[key]
                        getgenv().MacroData = getgenv().Macros[getgenv().CurrentMacro]
                        getgenv().TotalSteps = #getgenv().MacroData
                        
                        if getgenv().MacroDropdown and getgenv().MacroDropdown.SetValue then
                            getgenv().MacroDropdown:SetValue(getgenv().CurrentMacro)
                        end
                        
                        getgenv().MacroTotalSteps = getgenv().TotalSteps
                        getgenv().UpdateMacroStatus()
                        
                        saveMacroSettings()
                        
                        notify("Auto-Selected", getgenv().CurrentMacro .. " for " .. mn, 5)
                    end
                end
            end)
        end)
    end

GB.Ability_Left:Paragraph({
    Title = "⚡ Auto Ability System",
    Desc = "Automatically trigger unit abilities during gameplay. Configure conditions and timing for each ability on the right."
})
GB.Ability_Left:Space()

GB.Ability_Left:Section({ Title = "🎛️ Master Control" })
addToggle(GB.Ability_Left, "AutoAbilityToggle", "✨ Enable Auto Abilities", getgenv().AutoAbilitiesEnabled, function(val)
    getgenv().AutoAbilitiesEnabled = val
    getgenv().Config.toggles.AutoAbilityToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Ability", val and "Enabled" or "Disabled", 3)
end)

local function buildAutoAbilityUI()
    if getgenv()._AbilityUIBuilding then return end
    if getgenv()._AbilityUIBuilt then return end
    getgenv()._AbilityUIBuilding = true
    local clientData = getClientData()
    if not clientData or not clientData.Slots then
        notify("Auto Ability", "ClientData not available yet, retrying...", 3)
        getgenv()._AbilityUIBuilt = false
        getgenv()._AbilityUIBuilding = false
        return
    end
    local anyBuilt = false
    local success, err = pcall(function()
        local sortedSlots = {"Slot1","Slot2","Slot3","Slot4","Slot5","Slot6"}
        for _, slotName in ipairs(sortedSlots) do
            local slotData = clientData.Slots[slotName]
            if slotData and slotData.Value then
                local unitName = slotData.Value
                local abilities = getAllAbilities(unitName)
                if next(abilities) then
                    GB.Ability_Right:AddDivider()
                    GB.Ability_Right:AddLabel("📦 " .. unitName .. " (" .. slotName .. " • Lvl " .. tostring(slotData.Level or 0) .. ")")
                    anyBuilt = true
                    if not getgenv().UnitAbilities then getgenv().UnitAbilities = {} end
                    if not getgenv().UnitAbilities[unitName] then getgenv().UnitAbilities[unitName] = {} end
                    if not getgenv().Config.abilities then getgenv().Config.abilities = {} end
                    if not getgenv().Config.abilities[unitName] then getgenv().Config.abilities[unitName] = {} end
                    local sortedAbilities = {}
                    for abilityName, data in pairs(abilities) do
                        table.insert(sortedAbilities, { name = abilityName, data = data })
                    end
                    table.sort(sortedAbilities, function(a,b) 
                        local aLevel = (a.data and a.data.requiredLevel) or 0
                        local bLevel = (b.data and b.data.requiredLevel) or 0
                        return aLevel < bLevel
                    end)
                    for _, ab in ipairs(sortedAbilities) do
                        local abilityName = ab.name
                        local abilityData = ab.data
                        local saved = getgenv().Config.abilities and getgenv().Config.abilities[unitName] and getgenv().Config.abilities[unitName][abilityName]
                        if not getgenv().UnitAbilities[unitName][abilityName] then
                            getgenv().UnitAbilities[unitName][abilityName] = {
                                enabled = (saved and saved.enabled) or false,
                                onlyOnBoss = (saved and saved.onlyOnBoss) or false,
                                specificWave = (saved and saved.specificWave) or nil,
                                requireBossInRange = (saved and saved.requireBossInRange) or false,
                                delayAfterBossSpawn = (saved and saved.delayAfterBossSpawn) or false,
                                useOnWave = (saved and saved.useOnWave) or false
                            }
                        end
                        local cfg = getgenv().UnitAbilities[unitName][abilityName]
                        local defaultToggle = cfg.enabled
                        local abilityIcon = abilityData.isAttribute and "🔒" or "⚡"
                        local abilityInfo = abilityIcon .. " " .. abilityName .. " (CD: " .. tostring(abilityData.cooldown) .. "s)"
                        addToggle(GB.Ability_Right, unitName .. "_" .. abilityName .. "_Toggle", abilityInfo, defaultToggle, function(v)
                            cfg.enabled = v
                            getgenv().Config.abilities[unitName] = getgenv().Config.abilities[unitName] or {}
                            getgenv().Config.abilities[unitName][abilityName] = getgenv().Config.abilities[unitName][abilityName] or {}
                            getgenv().Config.abilities[unitName][abilityName].enabled = v
                            saveConfig(getgenv().Config)
                        end)
                        local modifierKey = unitName .. "_" .. abilityName .. "_Modifiers"
                        local defaultArray = {}
                        if cfg.onlyOnBoss then table.insert(defaultArray, "Only On Boss") end
                        if cfg.requireBossInRange then table.insert(defaultArray, "Boss In Range") end
                        if cfg.delayAfterBossSpawn then table.insert(defaultArray, "Delay After Boss Spawn") end
                        if cfg.useOnWave then table.insert(defaultArray, "On Wave") end
                        table.sort(defaultArray)
                        
                        local dropdown = GB.Ability_Right:AddDropdown(modifierKey, {
                            Values = {"Only On Boss","Boss In Range","Delay After Boss Spawn","On Wave"},
                            Multi = true,
                            AllowNone = true,
                            Value = defaultArray,
                            Text = "  > Conditions",
                            Callback = function(Value)
                                local selectedSet = {}
                                if type(Value) == "table" then
                                    for _, v in ipairs(Value) do
                                        selectedSet[v] = true
                                    end
                                end
                                cfg.onlyOnBoss = selectedSet["Only On Boss"] == true
                                cfg.requireBossInRange = selectedSet["Boss In Range"] == true
                                cfg.delayAfterBossSpawn = selectedSet["Delay After Boss Spawn"] == true
                                cfg.useOnWave = selectedSet["On Wave"] == true
                                getgenv().Config.abilities[unitName] = getgenv().Config.abilities[unitName] or {}
                                local store = getgenv().Config.abilities[unitName]
                                store[abilityName] = store[abilityName] or {}
                                store[abilityName].onlyOnBoss = cfg.onlyOnBoss
                                store[abilityName].requireBossInRange = cfg.requireBossInRange
                                store[abilityName].delayAfterBossSpawn = cfg.delayAfterBossSpawn
                                store[abilityName].useOnWave = cfg.useOnWave
                                saveConfig(getgenv().Config)
                            end,
                        })
                        GB.Ability_Right:AddInput(unitName .. "_" .. abilityName .. "_Wave", {
                            Text = "  > Wave Number",
                            Default = (cfg.specificWave and tostring(cfg.specificWave)) or "",
                            Numeric = true,
                            Finished = true,
                            Placeholder = "Required if 'On Wave' selected",
                            Callback = function(text)
                                local num = tonumber(text)
                                cfg.specificWave = num
                                getgenv().Config.abilities[unitName] = getgenv().Config.abilities[unitName] or {}
                                getgenv().Config.abilities[unitName][abilityName] = getgenv().Config.abilities[unitName][abilityName] or {}
                                getgenv().Config.abilities[unitName][abilityName].specificWave = num
                                saveConfig(getgenv().Config)
                            end,
                        })
                    end
                end
            end
        end
    end)
    if not success then
        warn("[Auto Ability UI] build failed: " .. tostring(err))
    end
    getgenv()._AbilityUIBuilt = anyBuilt
    getgenv()._AbilityUIBuilding = false
end

task.spawn(function()
    task.wait(2 * MOBILE_DELAY_MULTIPLIER)
    local maxRetries, retryDelay = 10, 3 * MOBILE_DELAY_MULTIPLIER
    for i=1,maxRetries do
        pcall(function()
            local cd = getClientData()
            if cd and cd.Slots then
                buildAutoAbilityUI()
            else
                if i <= 3 then
                    notify("Auto Ability","Loading units... ("..i.."/"..maxRetries..")",2)
                end
            end
        end)
        if getgenv()._AbilityUIBuilt then break end
        task.wait(retryDelay)
    end
end)

GB.Card_Left:Paragraph({
    Title = "🎴 Card Priority System",
    Desc = "Automatically select cards based on priority. Lower number = higher priority (1 is best, 999 to skip)."
})
GB.Card_Left:Space()

GB.Card_Left:Section({ Title = "⚙️ Selection Mode" })
addToggle(GB.Card_Left, "CardSelectionToggle", "⚡ Fast Mode", getgenv().CardSelectionEnabled, function(v)
    getgenv().CardSelectionEnabled = v
    getgenv().Config.toggles.CardSelectionToggle = v
    if v and getgenv().SlowerCardSelectionEnabled then
        getgenv().SlowerCardSelectionEnabled = false
        getgenv().Config.toggles.SlowerCardSelectionToggle = false
        if Toggles.SlowerCardSelectionToggle then
            Toggles.SlowerCardSelectionToggle:SetValue(false)
        end
    end
    saveConfig(getgenv().Config)
    notify("Card Selection", v and "Fast Mode Enabled" or "Disabled", 3)
end)
addToggle(GB.Card_Left, "SlowerCardSelectionToggle", "🐢 Slower Mode (More Reliable)", getgenv().SlowerCardSelectionEnabled, function(v)
    getgenv().SlowerCardSelectionEnabled = v
    getgenv().Config.toggles.SlowerCardSelectionToggle = v
    if v and getgenv().CardSelectionEnabled then
        getgenv().CardSelectionEnabled = false
        getgenv().Config.toggles.CardSelectionToggle = false
        if Toggles.CardSelectionToggle then
            Toggles.CardSelectionToggle:SetValue(false)
        end
    end
    saveConfig(getgenv().Config)
    notify("Card Selection", v and "Slower Mode Enabled" or "Disabled", 3)
end)

GB.Card_Left:Space()
GB.Card_Left:Paragraph({
    Title = "💡 How It Works",
    Desc = "The script will automatically select cards in order of priority (1-999). Cards with priority 999 will be skipped. Adjust priorities below to customize selection.",
})

GB.Card_Right:Section({ Title = "🍬 Candy Cards", Box = true })
do
    local candyNames = {}
    local candyCards = getgenv().CandyCards
    if candyCards and type(candyCards) == "table" then
        local count = 0
        for k in pairs(candyCards) do 
            count = count + 1
            candyNames[count] = k 
        end
    end
    table.sort(candyNames, function(a,b) return (candyCards[a] or 999) < (candyCards[b] or 999) end)
    for _, cardName in ipairs(candyNames) do
        local key = "Card_"..cardName
        local defaultValue = getgenv().Config.inputs[key] or tostring(getgenv().CandyCards[cardName])
        GB.Card_Right:AddInput(key, {
            Text = cardName,
            Default = defaultValue,
            Numeric = true,
            Finished = true,
            Placeholder = "Priority (1-999)",
            Callback = function(Value)
                local num = tonumber(Value)
                if num then
                    getgenv().CardPriority[cardName] = num
                    getgenv().Config.inputs[key] = tostring(num)
                    saveConfig(getgenv().Config)
                end
            end,
        })
        getgenv().CardPriority[cardName] = tonumber(defaultValue) or getgenv().CandyCards[cardName]
    end
end

GB.Card_Right:Space()
GB.Card_Right:Section({ Title = "😈 Devil's Sacrifice", Box = true })
if getgenv().DevilSacrifice and type(getgenv().DevilSacrifice) == "table" then
for cardName,priority in pairs(getgenv().DevilSacrifice) do
    local key = "Card_"..cardName
    local defaultValue = getgenv().Config.inputs[key] or tostring(priority)
    GB.Card_Right:AddInput(key, {
        Text = cardName,
        Default = defaultValue,
        Numeric = true,
        Finished = true,
        Placeholder = "Priority (1-999)",
        Callback = function(Value)
            local num = tonumber(Value)
            if num then
                getgenv().CardPriority[cardName] = num
                getgenv().Config.inputs[key] = tostring(num)
                saveConfig(getgenv().Config)
            end
        end,
    })
    getgenv().CardPriority[cardName] = tonumber(defaultValue) or priority
end
end

GB.Card_Right:Space()
GB.Card_Right:Section({ Title = "📋 Other Cards", Box = true })
do
    local otherNames = {}
    local otherCards = getgenv().OtherCards
    if otherCards and type(otherCards) == "table" then
        local count = 0
        for k in pairs(otherCards) do 
            count = count + 1
            otherNames[count] = k 
        end
    end
    table.sort(otherNames)
    for _, cardName in ipairs(otherNames) do
        local key = "Card_"..cardName
        local defaultValue = getgenv().Config.inputs[key] or tostring(getgenv().OtherCards[cardName])
        GB.Card_Right:AddInput(key, {
            Text = cardName,
            Default = defaultValue,
            Numeric = true,
            Finished = true,
            Placeholder = "Priority (1-999)",
            Callback = function(Value)
                local num = tonumber(Value)
                if num then
                    getgenv().CardPriority[cardName] = num
                    getgenv().Config.inputs[key] = tostring(num)
                    saveConfig(getgenv().Config)
                end
            end,
        })
        getgenv().CardPriority[cardName] = tonumber(defaultValue) or getgenv().OtherCards[cardName]
    end
end

GB.Boss_Left:Paragraph({
    Title = "Boss Rush Mode",
    Desc = "Automatically select cards during Boss Rush mode with custom priorities"
})
GB.Boss_Left:Space({ Columns = 1 })

addToggle(GB.Boss_Left, "BossRushToggle", "Enable Boss Rush Card Selection", getgenv().BossRushEnabled, function(v)
    getgenv().BossRushEnabled = v
    getgenv().Config.toggles.BossRushToggle = v
    saveConfig(getgenv().Config)
    notify("Boss Rush", v and "Enabled" or "Disabled", 3)
end)

GB.Boss_Right:AddLabel("Lower number = higher priority • Set to 999 to avoid", true)
GB.Boss_Right:AddDivider()
GB.Boss_Right:AddLabel("🎯 General Cards")
do
    local brNames = {}
    local bossRushGeneral = getgenv().BossRushGeneral
    if bossRushGeneral and type(bossRushGeneral) == "table" then
        local count = 0
        for k in pairs(bossRushGeneral) do 
            count = count + 1
            brNames[count] = k 
        end
    end
    table.sort(brNames)
    for _, cardName in ipairs(brNames) do
        local inputKey = "BossRush_"..cardName
        local defaultValue = getgenv().Config.inputs[inputKey] or tostring(getgenv().BossRushGeneral[cardName])
        local cardType = "Buff"
        pcall(function()
            local bossRushModule = RS:FindFirstChild("Modules"):FindFirstChild("CardHandler"):FindFirstChild("BossRushCards")
            if bossRushModule then
                local cards = require(bossRushModule)
                for _, card in pairs(cards) do if card.CardName == cardName then cardType = card.CardType or "Buff" break end end
            end
        end)
        GB.Boss_Right:AddInput(inputKey, {
            Text = cardName .. " ("..cardType..")",
            Default = defaultValue,
            Numeric = true,
            Finished = true,
            Placeholder = "Priority (1-999)",
            Callback = function(Value)
                local num = tonumber(Value)
                if num then
                    getgenv().BossRushCardPriority[cardName] = num
                    getgenv().Config.inputs[inputKey] = tostring(num)
                    saveConfig(getgenv().Config)
                end
            end,
        })
        getgenv().BossRushCardPriority[cardName] = tonumber(defaultValue) or getgenv().BossRushGeneral[cardName]
    end
end

if not isInLobby then
    GB.Boss_Right:AddDivider()
    GB.Boss_Right:AddLabel("🏰 Babylonia Castle")
    pcall(function()
        local babyloniaModule = RS:FindFirstChild("Modules"):FindFirstChild("CardHandler"):FindFirstChild("BossRushCards"):FindFirstChild("Babylonia Castle")
        if babyloniaModule then
            local cards = require(babyloniaModule)
            for _, card in pairs(cards) do
                local cardName = card.CardName
                local cardType = card.CardType or "Buff"
                local inputKey = "BabyloniaCastle_" .. cardName
                if not getgenv().BossRushCardPriority then getgenv().BossRushCardPriority = {} end
                if not getgenv().BossRushCardPriority[cardName] then getgenv().BossRushCardPriority[cardName] = 999 end
                local defaultValue = getgenv().Config.inputs[inputKey] or "999"
                GB.Boss_Right:AddInput(inputKey, {
                    Text = cardName .. " ("..cardType..")",
                    Default = defaultValue,
                    Numeric = true,
                    Finished = true,
                    Placeholder = "Priority (1-999)",
                    Callback = function(Value)
                        local num = tonumber(Value)
                        if num then
                            getgenv().BossRushCardPriority[cardName] = num
                            getgenv().Config.inputs[inputKey] = tostring(num)
                            saveConfig(getgenv().Config)
                        end
                    end,
                })
                getgenv().BossRushCardPriority[cardName] = tonumber(defaultValue) or 999
            end
        end
    end)
else
    GB.Boss_Right:AddLabel("Babylonia Castle cards are only available outside the lobby.", true)
end

GB.Breach_Left:Paragraph({
    Title = "Breach Auto-Join",
    Desc = "Automatically join specific Breach modes when they become available"
})
GB.Breach_Left:Space({ Columns = 1 })

addToggle(GB.Breach_Left, "BreachToggle", "Enable Breach Auto-Join", getgenv().BreachEnabled, function(v)
    getgenv().BreachEnabled = v
    getgenv().Config.toggles.BreachToggle = v
    saveConfig(getgenv().Config)
    notify("Breach Auto-Join", v and "Enabled" or "Disabled", 3)
end)
GB.Breach_Left:Space({ Columns = 1 })
GB.Breach_Left:Divider({ Title = "📋 Available Breaches" })
local breachesLoaded = false
pcall(function()
    local mapParamsModule = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Breach") and RS.Modules.Breach:FindFirstChild("MapParameters")
    if mapParamsModule and mapParamsModule:IsA("ModuleScript") then
        local mapParams = require(mapParamsModule)
        if mapParams and next(mapParams) then
            local breachList = {}
            for breachName, breachInfo in pairs(mapParams) do
                table.insert(breachList, { name = breachName, disabled = breachInfo.Disabled or false })
            end
            table.sort(breachList, function(a,b) return a.name < b.name end)
            for _, breach in ipairs(breachList) do
                local breachKey = "Breach_" .. breach.name
                local savedState = getgenv().Config.toggles[breachKey] or false
                if not getgenv().BreachAutoJoin[breach.name] then
                    getgenv().BreachAutoJoin[breach.name] = savedState
                end
                local statusText = breach.disabled and " [DISABLED]" or ""
                addToggle(GB.Breach_Left, breachKey, breach.name .. statusText, savedState, function(v)
                    getgenv().BreachAutoJoin[breach.name] = v
                    getgenv().Config.toggles[breachKey] = v
                    saveConfig(getgenv().Config)
                end)
            end
            breachesLoaded = true
        end
    end
end)
if not breachesLoaded then
    GB.Breach_Left:Paragraph({
        Title = "⚠️ Error",
        Desc = "Could not load breach data from MapParameters. The module may not be available."
    })
end


GB.FinalExp_Left:Paragraph({
    Title = "Final Expedition Auto Join",
    Desc = "Automatically join Final Expedition mode with your preferred difficulty"
})
GB.FinalExp_Left:Space({ Columns = 1 })

addToggle(GB.FinalExp_Left, "FinalExpAutoJoinEasyToggle", "Auto Join Easy", getgenv().FinalExpAutoJoinEasyEnabled, function(v)
    getgenv().FinalExpAutoJoinEasyEnabled = v
    getgenv().Config.toggles.FinalExpAutoJoinEasyToggle = v
    saveConfig(getgenv().Config)
    notify("Final Expedition", v and "Auto Join Easy Enabled" or "Auto Join Easy Disabled", 3)
end)

addToggle(GB.FinalExp_Left, "FinalExpAutoJoinHardToggle", "Auto Join Hard", getgenv().FinalExpAutoJoinHardEnabled, function(v)
    getgenv().FinalExpAutoJoinHardEnabled = v
    getgenv().Config.toggles.FinalExpAutoJoinHardToggle = v
    saveConfig(getgenv().Config)
    notify("Final Expedition", v and "Auto Join Hard Enabled" or "Auto Join Hard Disabled", 3)
end)

GB.FinalExp_Left:Paragraph({
    Title = "⚠️ Important",
    Desc = "Only enable ONE auto join option at a time to avoid conflicts"
})


GB.FinalExp_Right:Paragraph({
    Title = "Automation Features",
    Desc = "Additional automation options for Final Expedition mode"
})
GB.FinalExp_Right:Space({ Columns = 1 })

addToggle(GB.FinalExp_Right, "FinalExpAutoSkipShopToggle", "Auto Skip Shop", getgenv().FinalExpAutoSkipShopEnabled, function(v)
    getgenv().FinalExpAutoSkipShopEnabled = v
    getgenv().Config.toggles.FinalExpAutoSkipShopToggle = v
    saveConfig(getgenv().Config)
    notify("Final Expedition", v and "Auto Skip Shop Enabled" or "Auto Skip Shop Disabled", 3)
end)

GB.FinalExp_Right:Paragraph({
    Title = "How it works",
    Desc = "Automatically selects dungeon options and skips the shop screen"
})
GB.FinalExp_Right:AddLabel("Use Auto Leave/Replay/Next in Main tab to automatically leave on last round", true)

GB.Webhook_Left:Paragraph({
    Title = "Discord Notifications",
    Desc = "Get real-time notifications about game events sent directly to your Discord server"
})
GB.Webhook_Left:Space({ Columns = 1 })

addToggle(GB.Webhook_Left, "WebhookToggle", "Enable Webhook Notifications", getgenv().WebhookEnabled, function(v)
    getgenv().WebhookEnabled = v
    getgenv().Config.toggles.WebhookToggle = v
    saveConfig(getgenv().Config)
    if v then
        if (getgenv().WebhookURL == "" or not string.match(getgenv().WebhookURL, "^https://discord%.com/api/webhooks/")) then
            notify("Webhook", "Please enter a valid webhook URL first", 5)
            getgenv().WebhookEnabled = false
            getgenv().Config.toggles.WebhookToggle = false
            saveConfig(getgenv().Config)
        else
            notify("Webhook", "Enabled", 3)
        end
    else
        notify("Webhook", "Disabled", 3)
    end
end)
GB.Webhook_Left:AddInput("WebhookURL", {
    Text = "Webhook URL",
    Default = getgenv().WebhookURL or "",
    Numeric = false,
    Finished = true,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(Value)
        getgenv().WebhookURL = Value or ""
        getgenv().Config.inputs.WebhookURL = getgenv().WebhookURL
        saveConfig(getgenv().Config)
    end,
})

GB.Webhook_Left:Space({ Columns = 1 })

GB.Webhook_Left:AddInput("DiscordUserID", {
    Text = "Discord User ID",
    Default = getgenv().Config.inputs.DiscordUserID or "",
    Numeric = true,
    Finished = true,
    Placeholder = "123456789012345678",
    Callback = function(Value)
        getgenv().DiscordUserID = Value or ""
        getgenv().Config.inputs.DiscordUserID = getgenv().DiscordUserID
        saveConfig(getgenv().Config)
    end,
})

GB.Webhook_Left:Space({ Columns = 1 })

addToggle(GB.Webhook_Left, "PingOnSecretToggle", "🔔 Ping on Secret Drop", getgenv().Config.toggles.PingOnSecretToggle or false, function(v)
    getgenv().PingOnSecretDrop = v
    getgenv().Config.toggles.PingOnSecretToggle = v
    saveConfig(getgenv().Config)
    notify("Webhook", v and "Will ping on secret drops" or "Ping disabled", 3)
end)

GB.Seam_Left:Paragraph({
    Title = "Seamless Retry Fix",
    Desc = "Automatically leave after a set number of rounds to prevent game issues"
})
GB.Seam_Left:Space({ Columns = 1 })

addToggle(GB.Seam_Left, "SeamlessToggle", "Enable Seamless Fix", getgenv().SeamlessLimiterEnabled, function(v)
    getgenv().SeamlessLimiterEnabled = v
    getgenv().Config.toggles.SeamlessToggle = v
    saveConfig(getgenv().Config)
    notify("Seamless Fix", v and "Enabled" or "Disabled", 3)
end)
GB.Seam_Left:AddInput("SeamlessRounds", {
    Text = "Max Rounds Before Restart",
    Default = getgenv().Config.inputs.SeamlessRounds or "4",
    Numeric = true,
    Finished = true,
    Placeholder = "Default: 4",
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            getgenv().MaxSeamlessRounds = num
            getgenv().Config.inputs.SeamlessRounds = tostring(num)
            saveConfig(getgenv().Config)
        else
            getgenv().MaxSeamlessRounds = 4
        end
    end,
})

addToggle(GB.Event_Left, "AutoEventToggle", "Auto Event Join", getgenv().AutoEventEnabled, function(val)
    getgenv().AutoEventEnabled = val
    getgenv().Config.toggles.AutoEventToggle = val
    saveConfig(getgenv().Config)
    notify("Auto Event", val and "Enabled" or "Disabled", 3)
end)
GB.Event_Left:Paragraph({
    Title = "Halloween 2025 Event",
    Desc = "Automated features for the Halloween event including Bingo and Capsules"
})
GB.Event_Left:Space({ Columns = 1 })

if isInLobby then
    GB.Event_Left:Divider({ Title = "🎲 Auto Bingo" })
    addToggle(GB.Event_Left, "BingoToggle", "Enable Auto Bingo", getgenv().BingoEnabled, function(v)
        getgenv().BingoEnabled = v
        getgenv().Config.toggles.BingoToggle = v
        saveConfig(getgenv().Config)
        notify("Auto Bingo", v and "Enabled" or "Disabled", 3)
    end)
    GB.Event_Left:Paragraph({
        Title = "How it works",
        Desc = "Uses stamps (25x), claims rewards, and completes the board automatically"
    })
    
    GB.Event_Left:Space({ Columns = 1 })
    GB.Event_Left:Divider({ Title = "🎁 Auto Capsules" })
    addToggle(GB.Event_Left, "CapsuleToggle", "Enable Auto Capsules", getgenv().CapsuleEnabled, function(v)
        getgenv().CapsuleEnabled = v
        getgenv().Config.toggles.CapsuleToggle = v
        saveConfig(getgenv().Config)
        notify("Auto Capsules", v and "Enabled" or "Disabled", 3)
    end)
    GB.Event_Left:Paragraph({
        Title = "How it works",
        Desc = "Buys capsules (100/10/1 based on candy) and opens all automatically"
    })
else
    GB.Event_Left:Paragraph({
        Title = "⚠️ Lobby Only",
        Desc = "Bingo and Capsule features are only available in the lobby. Please rejoin the lobby to use these features."
    })
end

GB.Misc_Left:Paragraph({
    Title = "Performance Optimization",
    Desc = "Boost FPS and reduce lag by removing visual elements"
})
GB.Misc_Left:Space({ Columns = 1 })

if not isInLobby then
    addToggle(GB.Misc_Left, "FPSBoostToggle", "FPS Boost", getgenv().FPSBoostEnabled, function(v)
        getgenv().FPSBoostEnabled = v
        getgenv().Config.toggles.FPSBoostToggle = v
        saveConfig(getgenv().Config)
        notify("FPS Boost", v and "Enabled" or "Disabled", 3)
    end)
else
    getgenv().FPSBoostEnabled = false
end
addToggle(GB.Misc_Left, "RemoveEnemiesToggle", "Remove Enemies & Units", getgenv().RemoveEnemiesEnabled, function(v)
    getgenv().RemoveEnemiesEnabled = v
    getgenv().Config.toggles.RemoveEnemiesToggle = v
    saveConfig(getgenv().Config)
    notify("Remove Enemies", v and "Enabled" or "Disabled", 3)
end)
addToggle(GB.Misc_Left, "BlackScreenToggle", "Black Screen Mode", getgenv().BlackScreenEnabled, function(v)
    getgenv().BlackScreenEnabled = v
    getgenv().Config.toggles.BlackScreenToggle = v
    saveConfig(getgenv().Config)
    notify("Black Screen", v and "Enabled" or "Disabled", 3)
end)

GB.Misc_Right:Paragraph({
    Title = "Safety & Anti-AFK",
    Desc = "Keep your account safe and prevent disconnections"
})
GB.Misc_Right:Space({ Columns = 1 })

addToggle(GB.Misc_Right, "AntiAFKToggle", "Anti-AFK", getgenv().AntiAFKEnabled, function(v)
    getgenv().AntiAFKEnabled = v
    getgenv().Config.toggles.AntiAFKToggle = v
    saveConfig(getgenv().Config)
    notify("Anti-AFK", v and "Enabled" or "Disabled", 3)
end)

addToggle(GB.Misc_Right, "AutoHideUIToggle", "Auto Hide UI on Load", getgenv().Config.toggles.AutoHideUIToggle or false, function(v)
    getgenv().Config.toggles.AutoHideUIToggle = v
    saveConfig(getgenv().Config)
    notify("Auto Hide UI", v and "Enabled - UI will minimize on next load" or "Disabled", 3)
end)

GB.Misc_Right:Space({ Columns = 1 })
GB.Misc_Right:Divider({ Title = "🔄 Auto Execute" })

getgenv().AutoExecuteEnabled = getgenv().Config.toggles.AutoExecuteToggle or false

addToggle(GB.Misc_Right, "AutoExecuteToggle", "Auto Execute on Teleport", getgenv().AutoExecuteEnabled, function(v)
    getgenv().AutoExecuteEnabled = v
    getgenv().Config.toggles.AutoExecuteToggle = v
    saveConfig(getgenv().Config)
    notify("Auto Execute", v and "Enabled - Script will auto-load on teleport" or "Disabled", 3)
end)

GB.Misc_Right:Paragraph({
    Title = "⚠️ Important Note",
    Desc = "Do NOT enable this if you already have this script in your executor's auto-execute folder! This will cause the script to run twice."
})

GB.Settings_Left:Paragraph({
    Title = "Config Management",
    Desc = "Your settings are automatically saved to: " .. CONFIG_FOLDER .. "/" .. CONFIG_FILE
})
GB.Settings_Left:Space({ Columns = 1 })

GB.Settings_Left:Button({
    Title = "💾 Force Save Config",
    Callback = function()
        local success = saveConfig(getgenv().Config)
        if success then notify("Config", "Settings saved successfully!", 3) else notify("Config", "Failed to save settings!", 5) end
    end
})

GB.Settings_Left:Button({
    Title = "📁 Open Config Folder",
    Callback = function()
        notify("Config Location", CONFIG_FOLDER .. "/" .. CONFIG_FILE, 5)
    end
})

GB.Settings_Left:Space({ Columns = 1 })
GB.Settings_Left:Divider({ Title = "🎯 Macro Settings" })

getgenv().MacroEnabled = getgenv().Config.toggles.MacroToggle
if getgenv().MacroEnabled == nil then
    getgenv().MacroEnabled = true
    getgenv().Config.toggles.MacroToggle = true
end

GB.Settings_Left:Space({ Columns = 1 })

local savedKeybind = applyOldConfigValue("MenuKeybind", "input") or "LeftControl"

GB.Settings_Right:AddInput("MenuKeybind", {
    Text = "Menu Keybind",
    Default = savedKeybind,
    Placeholder = "Enter key name (e.g. LeftControl, H, G)",
    Callback = function(value)
        if value and value ~= "" then
            local keyCode = Enum.KeyCode[value]
            if keyCode then
                pcall(function()
                    if Library._currentWindow and type(Library._currentWindow.SetToggleKey) == "function" then
                        Library._currentWindow:SetToggleKey(keyCode)
                    end
                end)
            end
        end
    end,
})

GB.Settings_Right:AddButton("Server Hop (Safe)", function()
    notify("Server Hop", "Cleaning up and hopping to new server...", 3)
    task.spawn(function()
        task.wait(1)
        cleanupBeforeTeleport()
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        end)
        if not ok then
            warn("[Server Hop] Failed:", err)
        end
    end)
end)

GB.Settings_Right:AddButton("Unload", function()
    pcall(function()
        if Library and Library.Unload then
            Library:Unload()
        end
    end)
end)

GB.MacroMaps:Paragraph({
    Title = "🗺️ Map Assignment System",
    Desc = "Assign specific macros to maps. When you join a game, the assigned macro will automatically load."
})
GB.MacroMaps:Space()

local selectedGamemode = "Story"
local currentMapSection = nil

local function getMapsByGamemode(gamemode)
    return getMapsByMode(gamemode)
end

local function updateMapDisplay()
    if currentMapSection then
        pcall(function()
            currentMapSection:Destroy()
        end)
        currentMapSection = nil
    end
    
    task.wait(0.05)
    
    local maps = getMapsByGamemode(selectedGamemode)
    
    if #maps == 0 then
        currentMapSection = Tabs.MacroMaps:Section({
            Title = "⚠️ No Maps Available",
            Opened = true,
        })
        currentMapSection:Paragraph({
            Title = "No Maps Found",
            Desc = "No maps available for " .. selectedGamemode
        })
        return
    end
    
    currentMapSection = Tabs.MacroMaps:Section({
        Title = "📍 " .. selectedGamemode .. " Maps",
        Opened = true,
    })
    
    for _, mapName in ipairs(maps) do
        local key = selectedGamemode .. "_" .. mapName
        local currentMacro = getgenv().MacroMaps[key] or "--"
        
        local macroNames = getMacroNames()
        table.insert(macroNames, 1, "--")
        
        currentMapSection:Dropdown({
            Flag = "MacroFor_" .. key,
            Title = mapName,
            Values = macroNames,
            Value = currentMacro,
            Callback = function(value)
                if value ~= "--" then
                    getgenv().MacroMaps[key] = value
                    notify("Map Assignment", mapName .. " → " .. value, 3)
                else
                    getgenv().MacroMaps[key] = nil
                    notify("Map Assignment", mapName .. " cleared", 3)
                end
                saveMacroSettings()
            end,
            Searchable = true,
        })
    end
end

Tabs.MacroMaps:Dropdown({
    Flag = "MacroGamemodeSelect",
    Title = "Select Gamemode",
    Values = {"Story", "Infinite", "Challenge", "LegendaryStages", "Raids", "Dungeon", "Survival", "ElementalCaverns", "Event", "MidnightHunt", "BossRush", "Siege", "Breach"},
    Value = "Story",
    Callback = function(value)
        selectedGamemode = value
        task.spawn(function()
            updateMapDisplay()
        end)
    end,
})

Tabs.MacroMaps:Space()
Tabs.MacroMaps:Divider()
Tabs.MacroMaps:Space()

task.spawn(function()
    task.wait(0.1)
    updateMapDisplay()
end)

task.wait(0.5)

local notifyAttempts = 0
while notifyAttempts < 3 do
    notifyAttempts = notifyAttempts + 1
    local ok = pcall(function()
        notify("🎃 ALS Halloween Event", "UI loaded with improved organization! Check out the new tab sections for better navigation.", 5)
    end)
    if ok then break end
    task.wait(1)
end



if getgenv().Config.toggles.AutoHideUIToggle then
    task.spawn(function()
        task.wait(2)
        if Library and Library.Unloaded ~= true then
            local hideAttempts = 0
            local hideSuccess = false
            while hideAttempts < 3 and not hideSuccess do
                hideAttempts = hideAttempts + 1
                local ok = pcall(function()
                    if Library and Library.Toggle and type(Library.Toggle) == "function" then
                        Library:Toggle()
                        hideSuccess = true
                    end
                end)
                if ok and hideSuccess then
                    break
                else
                    warn("[Auto Hide] Attempt " .. hideAttempts .. " failed, retrying...")
                    task.wait(0.5)
                end
            end
            if not hideSuccess then
                warn("[Auto Hide] Failed to minimize UI after 3 attempts - UI will remain visible")
            end
        else
            warn("[Auto Hide] Library not ready or already unloaded, skipping auto-hide")
        end
    end)
end

if getgenv().Config and getgenv().Config.inputs then
    local inputs = getgenv().Config.inputs
    local cardPrio = getgenv().CardPriority
    local bossRushPrio = getgenv().BossRushCardPriority
    
    for inputKey, value in pairs(inputs) do
        local num = tonumber(value)
        if num then
            if inputKey:match("^Card_") then
                local cardName = inputKey:sub(6)
                if cardPrio and cardPrio[cardName] then 
                    cardPrio[cardName] = num 
                end
            elseif inputKey:match("^BossRush_") then
                local cardName = inputKey:sub(10)
                if bossRushPrio and bossRushPrio[cardName] then 
                    bossRushPrio[cardName] = num 
                end
            elseif inputKey:match("^BabyloniaCastle_") then
                local cardName = inputKey:sub(17)
                if not bossRushPrio then 
                    getgenv().BossRushCardPriority = {} 
                    bossRushPrio = getgenv().BossRushCardPriority
                end
                bossRushPrio[cardName] = num 
            end
        end
    end
end

task.spawn(function()
    repeat task.wait() until game.CoreGui:FindFirstChild("RobloxPromptGui")
    local promptOverlay = game.CoreGui.RobloxPromptGui.promptOverlay
    promptOverlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            task.spawn(function()
                cleanupBeforeTeleport()
                while true do
                    local ok = pcall(function()
                        TeleportService:Teleport(12886143095, Players.LocalPlayer)
                    end)
                    if not ok then
                        task.wait(1)
                    end
                end
            end)
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(30)
        pcall(collectgarbage, "collect")
    end
end)

task.spawn(function()
    local vu = game:GetService("VirtualUser")
    Players.LocalPlayer.Idled:Connect(function()
        if getgenv().AntiAFKEnabled then
            vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end
    end)
end)

task.spawn(function()
    local blackScreenGui, blackFrame
    local function createBlack()
        if blackScreenGui then return end
        blackScreenGui = Instance.new("ScreenGui")
        blackScreenGui.Name = "BlackScreenOverlay"
        blackScreenGui.DisplayOrder = -999999
        blackScreenGui.IgnoreGuiInset = true
        blackScreenGui.ResetOnSpawn = false
        blackFrame = Instance.new("Frame")
        blackFrame.Size = UDim2.new(1,0,1,0)
        blackFrame.BackgroundColor3 = Color3.new(0,0,0)
        blackFrame.BorderSizePixel = 0
        blackFrame.ZIndex = -999999
        blackFrame.Parent = blackScreenGui
        pcall(function() blackScreenGui.Parent = LocalPlayer.PlayerGui end)
        pcall(function()
            if workspace.CurrentCamera then workspace.CurrentCamera.MaxAxisFieldOfView = 0.001 end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
    end
    local function removeBlack()
        if blackScreenGui then blackScreenGui:Destroy() blackScreenGui=nil blackFrame=nil end
        pcall(function() if workspace.CurrentCamera then workspace.CurrentCamera.MaxAxisFieldOfView = 70 end end)
    end
    while true do
        task.wait(0.5)
        if getgenv().BlackScreenEnabled then if not blackScreenGui then createBlack() end else if blackScreenGui then removeBlack() end end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if getgenv().RemoveEnemiesEnabled then
            pcall(function()
                local enemies = workspace:FindFirstChild("Enemies")
                if enemies then
                    local children = enemies:GetChildren()
                    for i = 1, #children do
                        local enemy = children[i]
                        if enemy:IsA("Model") and enemy.Name ~= "Boss" then enemy:Destroy() end
                    end
                end
                local spawnedunits = workspace:FindFirstChild("SpawnedUnits")
                if spawnedunits then
                    for _, su in pairs(spawnedunits:GetChildren()) do if su:IsA("Model") then su:Destroy() end end
                end
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(10)
        if not isInLobby and getgenv().FPSBoostEnabled then
            pcall(function()
                local lighting = game:GetService("Lighting")
                for _, child in ipairs(lighting:GetChildren()) do child:Destroy() end
                lighting.Ambient = Color3.new(1,1,1)
                lighting.Brightness = 1
                lighting.GlobalShadows = false
                lighting.FogEnd = 100000
                lighting.FogStart = 100000
                lighting.ClockTime = 12
                lighting.GeographicLatitude = 0
                
                for _, obj in ipairs(game.Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("WedgePart") or obj:IsA("CornerWedgePart") then
                            obj.Material = Enum.Material.SmoothPlastic
                            obj.CastShadow = false
                            if obj:FindFirstChildOfClass("Texture") then
                                for _, t in ipairs(obj:GetChildren()) do if t:IsA("Texture") then t:Destroy() end end
                            end
                            if obj:IsA("MeshPart") then obj.TextureID = "" end
                        end
                        if obj:IsA("Decal") then obj:Destroy() end
                    end
                    if obj:IsA("SurfaceAppearance") then obj:Destroy() end
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                        obj.Enabled = false
                    end
                    if obj:IsA("Sound") then
                        obj.Volume = 0
                        obj:Stop()
                    end
                end
                
                local mapPath = game.Workspace:FindFirstChild("Map") and game.Workspace.Map:FindFirstChild("Map")
                if mapPath then for _, ch in ipairs(mapPath:GetChildren()) do if not ch:IsA("Model") then ch:Destroy() end end end
                
                pcall(collectgarbage, "collect")
            end)
        end
    end
end)

task.spawn(function()
    local eventsFolder = RS:FindFirstChild("Events")
    local halloweenFolder = eventsFolder and eventsFolder:FindFirstChild("Hallowen2025")
    local enterEvent = halloweenFolder and halloweenFolder:FindFirstChild("Enter")
    local startEvent = halloweenFolder and halloweenFolder:FindFirstChild("Start")
    while true do
        task.wait(0.5)
        if getgenv().AutoEventEnabled and enterEvent and startEvent then
            pcall(function() enterEvent:FireServer(); startEvent:FireServer() end)
        end
    end
end)

if isInLobby then
    task.spawn(function()
        local finalExpRemote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("FinalExpeditionStart")
        if not finalExpRemote then
            warn("[Final Expedition] FinalExpeditionStart not found")
            return
        end
        while true do
            task.wait(2)
            if getgenv().FinalExpAutoJoinEasyEnabled then
                local success = pcall(function()
                    finalExpRemote:FireServer("Easy")
                end)
                if not success then
                    warn("[Final Expedition] Failed to join Easy mode")
                end
            elseif getgenv().FinalExpAutoJoinHardEnabled then
                local success = pcall(function()
                    finalExpRemote:FireServer("Hard")
                end)
                if not success then
                    warn("[Final Expedition] Failed to join Hard mode")
                end
            end
        end
    end)
end

if not isInLobby then
    task.spawn(function()
        local abilitySelection = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("AbilitySelection")
        if not abilitySelection then
            warn("[Final Expedition] AbilitySelection remote not found")
            return
        end
        task.spawn(function()
            while true do
                task.wait(5)
                if getgenv().FinalExpAutoSkipShopEnabled then
                    pcall(function()
                        abilitySelection:FireServer("FinalExpeditionSelection", "Double_Dungeon")
                    end)
                end
            end
        end)
        task.spawn(function()
            while true do
                task.wait(5)
                if getgenv().FinalExpAutoSkipShopEnabled then
                    pcall(function()
                        abilitySelection:FireServer("FinalExpeditionSelection", "Dungeon")
                    end)
                end
            end
        end)
    end)
end

local isProcessing = false
task.spawn(function()
    local function press(key)
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(0.1)
        VIM:SendKeyEvent(false, key, false, game)
    end
    local GuiService = game:GetService("GuiService")
    local hasProcessedCurrentUI = false
    local endGameUIDetectedTime = 0
    local lastEndGameUIInstance = nil

    LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "EndGameUI" then
            hasProcessedCurrentUI = false
            endGameUIDetectedTime = tick()
            lastEndGameUIInstance = child
        end
    end)

    LocalPlayer.PlayerGui.ChildRemoved:Connect(function(child)
        if child.Name == "EndGameUI" then
            hasProcessedCurrentUI = false
            lastEndGameUIInstance = nil
        end
    end)
    while true do
        task.wait(0.5 * MOBILE_DELAY_MULTIPLIER)
        local success, errorMsg = pcall(function()
            local endGameUI = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
            if endGameUI and endGameUI:FindFirstChild("BG") and endGameUI.BG:FindFirstChild("Buttons") then
                if lastEndGameUIInstance and endGameUI ~= lastEndGameUIInstance then
                    hasProcessedCurrentUI = false
                    lastEndGameUIInstance = endGameUI
                    endGameUIDetectedTime = tick()
                end
                if hasProcessedCurrentUI then
                    return
                end
                local buttons = endGameUI.BG.Buttons
                local nextButton = buttons:FindFirstChild("Next")
                local retryButton = buttons:FindFirstChild("Retry")
                local leaveButton = buttons:FindFirstChild("Leave")
                local buttonToPress, actionName = nil, ""
                if getgenv().AutoSmartEnabled then
                    if nextButton and nextButton.Visible then
                        buttonToPress = nextButton
                        actionName = "Next"
                    elseif retryButton and retryButton.Visible then
                        buttonToPress = retryButton
                        actionName = "Replay"
                    elseif leaveButton then
                        buttonToPress = leaveButton
                        actionName = "Leave"
                    end
                elseif getgenv().AutoNextEnabled and nextButton and nextButton.Visible then
                    buttonToPress = nextButton
                    actionName = "Next"
                elseif getgenv().AutoFastRetryEnabled and retryButton and retryButton.Visible then
                    buttonToPress = retryButton
                    actionName = "Replay"
                elseif getgenv().AutoLeaveEnabled and leaveButton then
                    buttonToPress = leaveButton
                    actionName = "Leave"
                end
                if buttonToPress then
                    if getgenv().WebhookEnabled then
                        task.wait(4)
                        local maxWait = 0
                        while isProcessing and maxWait < 15 do
                            task.wait(0.5)
                            maxWait = maxWait + 0.5
                        end
                        task.wait(2)
                    end
                    hasProcessedCurrentUI = true
                    local isValidDescendant = pcall(function()
                        return buttonToPress:IsDescendantOf(LocalPlayer.PlayerGui)
                    end)
                    if isValidDescendant then
                        GuiService.SelectedObject = buttonToPress
                    end
                    repeat
                        press(Enum.KeyCode.Return)
                        task.wait(0.5)
                    until not LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
                    pcall(function() GuiService.SelectedObject = nil end)
                end
                pcall(function()
                    if GuiService.SelectedObject ~= nil then
                        GuiService.SelectedObject = nil
                    end
                end)
            end
        end)
        if not success then
            warn("[Auto Leave/Replay] Error in loop: " .. tostring(errorMsg))
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if getgenv().AutoReadyEnabled then
            local success, err = pcall(function()
                local bottomGui = LocalPlayer.PlayerGui:FindFirstChild("Bottom")
                if bottomGui then
                    local frame = bottomGui:FindFirstChild("Frame")
                    if frame then
                        local children = frame:GetChildren()
                        if children[2] then
                            local subChildren = children[2]:GetChildren()
                            if subChildren[6] then
                                local textButton = subChildren[6]:FindFirstChild("TextButton")
                                if textButton then
                                    local textLabel = textButton:FindFirstChild("TextLabel")
                                    if textLabel and textLabel.Text == "Start" then
                                        local remotes = RS:FindFirstChild("Remotes")
                                        local playerReady = remotes and remotes:FindFirstChild("PlayerReady")
                                        if playerReady then
                                            playerReady:FireServer()
                                            task.wait(2)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            if not success then
                warn("[Auto Ready] Error: " .. tostring(err))
            end
        end
    end
end)

task.spawn(function()
    local function getCurrentTimeScale()
        local ok, v = pcall(function()
            local ts = RS:FindFirstChild("TimeScale")
            return ts and ts.Value or 1
        end)
        local scale = (ok and v) or 1
        if not scale or scale <= 0 then scale = 1 end
        return scale
    end
    local Towers = workspace:WaitForChild("Towers", 10)
    local bossSpawnTime = nil
    local bossInRangeTracker = {}
    local abilityCooldowns = {}
    local towerInfoCache = {}
    local generalBossSpawnTime = nil
    local lastWave = 0
    local trackedSpawnedUnits = {}
    local lastGameEndedState = false
    local function resetRoundTrackers()
        bossSpawnTime = nil
        bossInRangeTracker = {}
        generalBossSpawnTime = nil
        abilityCooldowns = {}
        towerInfoCache = {}
        if not getgenv().SeamlessLimiterEnabled then
            trackedSpawnedUnits = {}
        end
    end
    local function checkGameEndedReset()
        local ok, gameEnded = pcall(function()
            local ge = RS:FindFirstChild("GameEnded")
            return ge and ge.Value or false
        end)
        if ok and gameEnded and not lastGameEndedState then
            lastGameEndedState = true
            if not getgenv().SeamlessLimiterEnabled then
                trackedSpawnedUnits = {}
            end
        elseif ok and not gameEnded and lastGameEndedState then
            lastGameEndedState = false
        end
    end
    local function getTowerInfoCached(towerName)
        if towerInfoCache[towerName] then return towerInfoCache[towerName] end
        local t = getTowerInfo(towerName)
        if t then towerInfoCache[towerName] = t end
        return t
    end
    local function getAbilityData(towerName, abilityName)
        local info = getTowerInfoCached(towerName)
        if not info then return nil end
        for level=0,50 do
            if info[level] then
                if info[level].Ability then
                    local a = info[level].Ability
                    if a.Name == abilityName then return { cooldown=a.Cd, requiredLevel=level, isGlobal=a.IsCdGlobal } end
                end
                if info[level].Abilities then
                    for _,a in pairs(info[level].Abilities) do
                        if a.Name == abilityName then return { cooldown=a.Cd, requiredLevel=level, isGlobal=a.IsCdGlobal } end
                    end
                end
            end
        end
        return nil
    end
    local function getCurrentWave()
        local ok, result = pcall(function()
            local waveValue = RS:FindFirstChild("Wave")
            if waveValue and waveValue:IsA("IntValue") then
                return waveValue.Value or 0
            end
            return 0
        end)
        return ok and result or 0
    end
    local function getTowerInfoName(tower)
        if not tower then return nil end
        local candidates = { tower:GetAttribute("TowerType"), tower:GetAttribute("Type"), tower:GetAttribute("TowerName"), tower:GetAttribute("BaseTower"),
            tower:FindFirstChild("TowerType") and tower.TowerType:IsA("ValueBase") and tower.TowerType.Value,
            tower:FindFirstChild("Type") and tower.Type:IsA("ValueBase") and tower.Type.Value,
            tower:FindFirstChild("TowerName") and tower.TowerName:IsA("ValueBase") and tower.TowerName.Value,
            tower.Name }
        for _, c in ipairs(candidates) do if c and type(c)=="string" and c ~= "" then return c end end
        return tower.Name
    end
    local function getTower(name) return Towers:FindFirstChild(name) end
    local function getUpgradeLevel(tower)
        if not tower then return 0 end
        local u = tower:FindFirstChild("Upgrade")
        if u and u:IsA("ValueBase") then return u.Value or 0 end
        return 0
    end
    local function fixAbilityName(abilityName)
        local fixed = abilityName
        fixed = fixed:gsub("!!+", "!")
        fixed = fixed:gsub("%?%?+", "?")
        return fixed
    end
    local function useAbility(tower, abilityName)
        if tower then
            local correctedName = fixAbilityName(abilityName)
            pcall(function() RS.Remotes.Ability:InvokeServer(tower, correctedName) end)
        end
    end
    local function isOnCooldown(towerName, abilityName)
        local d = getAbilityData(towerName, abilityName) if not d or not d.cooldown then return false end
        local key = towerName .. "_" .. abilityName
        local last = abilityCooldowns[key]
        if not last then return false end
        local scale = getCurrentTimeScale()
        local effectiveCd = d.cooldown / scale
        return (tick() - last) < (effectiveCd + 0.15)
    end
    local function setAbilityUsed(towerName, abilityName) abilityCooldowns[towerName.."_"..abilityName] = tick() end
    local function hasAbilityBeenUnlocked(towerName, abilityName, towerLevel)
        local d = getAbilityData(towerName, abilityName)
        return d and towerLevel >= d.requiredLevel
    end
    local function bossExists()
        local ok, res = pcall(function()
            local enemies = workspace:FindFirstChild("Enemies") if not enemies then return false end
            return enemies:FindFirstChild("Boss") ~= nil
        end)
        return ok and res
    end
    local function bossReadyForAbilities()
        if bossExists() then
            if not generalBossSpawnTime then generalBossSpawnTime = tick() end
            return (tick() - generalBossSpawnTime) >= 2
        else
            generalBossSpawnTime = nil
            return false
        end
    end
    local function checkBossSpawnTime()
        if bossExists() then
            if not bossSpawnTime then bossSpawnTime = tick() end
            return (tick() - bossSpawnTime) >= 16
        else
            bossSpawnTime = nil
            return false
        end
    end
    local function getBossCFrame()
        local ok, res = pcall(function()
            local enemies = workspace:FindFirstChild("Enemies")
            if not enemies then return nil end
            local boss = enemies:FindFirstChild("Boss")
            if not boss then return nil end
            local hrp = boss:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp.CFrame end
            return nil
        end)
        return ok and res or nil
    end
    local function getTowerCFrame(tower)
        if not tower then return nil end
        local ok, res = pcall(function()
            local hrp = tower:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp.CFrame end
            return nil
        end)
        return ok and res or nil
    end
    local function getTowerRange(tower)
        if not tower then return 0 end
        local ok, res = pcall(function()
            local stats = tower:FindFirstChild("Stats")
            if not stats then return 0 end
            local range = stats:FindFirstChild("Range")
            if not range then return 0 end
            return range.Value or 0
        end)
        return ok and res or 0
    end
    local function isBossInRange(tower)
        local bossCF = getBossCFrame()
        local towerCF = getTowerCFrame(tower)
        if not bossCF or not towerCF then return false end
        local range = getTowerRange(tower)
        if range <= 0 then return false end
        local distance = (bossCF.Position - towerCF.Position).Magnitude
        return distance <= range
    end
    local function checkBossInRangeForDuration(tower, requiredDuration)
        if not tower then return false end
        local name = tower.Name
        local currentTime = tick()
        if isBossInRange(tower) then
            if requiredDuration == 0 then return true end
            if not bossInRangeTracker[name] then bossInRangeTracker[name] = currentTime return false else return (currentTime - bossInRangeTracker[name]) >= requiredDuration end
        else
            bossInRangeTracker[name] = nil
        end
        return false
    end
    local function addSpawnedUnitAbilities(unitName)
        if trackedSpawnedUnits[unitName] then return end
        trackedSpawnedUnits[unitName] = true
        local abilities = getAllAbilities(unitName)
        if not next(abilities) then return end
        if not getgenv().UnitAbilities[unitName] then
            getgenv().UnitAbilities[unitName] = {}
        end
        if not getgenv().Config.abilities[unitName] then
            getgenv().Config.abilities[unitName] = {}
        end
        for abilityName, abilityData in pairs(abilities) do
            if not getgenv().UnitAbilities[unitName][abilityName] then
                local saved = getgenv().Config.abilities[unitName] and getgenv().Config.abilities[unitName][abilityName]
                getgenv().UnitAbilities[unitName][abilityName] = {
                    enabled = (saved and saved.enabled) or false,
                    onlyOnBoss = (saved and saved.onlyOnBoss) or false,
                    specificWave = (saved and saved.specificWave) or nil,
                    requireBossInRange = (saved and saved.requireBossInRange) or false,
                    delayAfterBossSpawn = (saved and saved.delayAfterBossSpawn) or false,
                    useOnWave = (saved and saved.useOnWave) or false
                }
            end
        end
    end
    task.spawn(function()
        if Towers then
            Towers.ChildAdded:Connect(function(child)
                task.wait(0.5)
                if child and child:IsA("Model") then
                    local unitName = child.Name
                    if unitName and unitName ~= "" then
                        addSpawnedUnitAbilities(unitName)
                    end
                end
            end)
        end
    end)
    while true do
        task.wait(1)
        if getgenv().AutoAbilitiesEnabled then
            pcall(function()
                checkGameEndedReset()
                local currentWave = getCurrentWave()
                local hasBoss = bossExists()
                if currentWave < lastWave then resetRoundTrackers() end
                if getgenv().SeamlessLimiterEnabled and lastWave >= 50 and currentWave < 50 then resetRoundTrackers() end
                lastWave = currentWave
                if not Towers then return end
                local unitAbilities = getgenv().UnitAbilities
                if unitAbilities and type(unitAbilities) == "table" then
                    for unitName, abilitiesConfig in pairs(unitAbilities) do
                    local tower = Towers:FindFirstChild(unitName)
                    if tower then
                        local infoName = getTowerInfoName(tower)
                        local towerLevel = getUpgradeLevel(tower)
                        for abilityName, cfg in pairs(abilitiesConfig) do
                            local savedCfg = getgenv().Config.abilities[unitName] and getgenv().Config.abilities[unitName][abilityName]
                            if savedCfg then
                                cfg.enabled = savedCfg.enabled
                                cfg.onlyOnBoss = savedCfg.onlyOnBoss or false
                                cfg.useOnWave = savedCfg.useOnWave or false
                                cfg.specificWave = savedCfg.specificWave
                                cfg.requireBossInRange = savedCfg.requireBossInRange or false
                                cfg.delayAfterBossSpawn = savedCfg.delayAfterBossSpawn or false
                            end
                            
                            if cfg.enabled then
                                local shouldUse = true
                                
                                if not hasAbilityBeenUnlocked(infoName, abilityName, towerLevel) then
                                    shouldUse = false
                                end
                                
                                if shouldUse and isOnCooldown(infoName, abilityName) then
                                    shouldUse = false
                                end
                                
                                if shouldUse and cfg.onlyOnBoss then
                                    if not hasBoss or not bossReadyForAbilities() then
                                        shouldUse = false
                                    end
                                end
                                
                                if shouldUse and cfg.useOnWave and cfg.specificWave then
                                    if currentWave ~= cfg.specificWave then
                                        shouldUse = false
                                    end
                                end
                                
                                if shouldUse and cfg.requireBossInRange then
                                    if not hasBoss or not checkBossInRangeForDuration(tower, 0) then
                                        shouldUse = false
                                    end
                                end
                                
                                if shouldUse and cfg.delayAfterBossSpawn then
                                    if not hasBoss or not checkBossSpawnTime() then
                                        shouldUse = false
                                    end
                                end
                                
                                if shouldUse then
                                    useAbility(tower, abilityName)
                                    setAbilityUsed(infoName, abilityName)
                                end
                            end
                        end
                    end
                end
                end
            end)
        end
    end
end)

task.spawn(function()
    local function getAvailableCards()
        local ok, result = pcall(function()
            local playerGui = LocalPlayer.PlayerGui
            local prompt = playerGui:FindFirstChild("Prompt") if not prompt then return nil end
            local frame = prompt:FindFirstChild("Frame") if not frame or not frame:FindFirstChild("Frame") then return nil end
            local cards, cardButtons = {}, {}
            local cardCount = 0
            local descendants = frame:GetDescendants()
            local cardPriority = getgenv().CardPriority
            for i = 1, #descendants do
                local d = descendants[i]
                if d:IsA("TextLabel") and d.Parent and d.Parent:IsA("Frame") then
                    local text = d.Text
                    if cardPriority[text] then
                        local button = d.Parent.Parent
                        if button:IsA("GuiButton") or button:IsA("TextButton") or button:IsA("ImageButton") then
                            cardCount = cardCount + 1
                            cardButtons[cardCount] = {text=text, button=button}
                        end
                    end
                end
            end
            table.sort(cardButtons, function(a,b) return a.button.AbsolutePosition.X < b.button.AbsolutePosition.X end)
            for i = 1, cardCount do 
                cards[i] = { name=cardButtons[i].text, button=cardButtons[i].button } 
            end
            return cardCount > 0 and cards or nil
        end)
        return ok and result or nil
    end
    local function findBestCard(list)
        local bestIndex, bestPriority = nil, 999
        local cardPriority = getgenv().CardPriority
        for i = 1, #list do
            local p = cardPriority[list[i].name] or 999
            if p < bestPriority then
                bestPriority = p
                bestIndex = i
            end
        end
        if bestIndex and bestPriority < 999 then
            return bestIndex, list[bestIndex], bestPriority
        end
        return nil, nil, nil
    end
    local CONFIRM_EVENTS = {"Activated","MouseButton1Click","MouseButton1Down","MouseButton1Up"}
    
    local function pressConfirm()
        local ok, confirmButton = pcall(function()
            local prompt = LocalPlayer.PlayerGui:FindFirstChild("Prompt") if not prompt then return nil end
            local frame = prompt:FindFirstChild("Frame") if not frame then return nil end
            local inner = frame:FindFirstChild("Frame") if not inner then return nil end
            local children = inner:GetChildren() if #children < 5 then return nil end
            local button = children[5]:FindFirstChild("TextButton") if not button then return nil end
            local label = button:FindFirstChild("TextLabel") if label and label.Text == "Confirm" then return button end
            return nil
        end)
        if ok and confirmButton then
            for i = 1, #CONFIRM_EVENTS do 
                pcall(function() 
                    local conns = getconnections(confirmButton[CONFIRM_EVENTS[i]])
                    for j = 1, #conns do conns[j]:Fire() end
                end) 
            end
            return true
        end
        return false
    end
    local BUTTON_EVENTS = {"Activated","MouseButton1Click","MouseButton1Down","MouseButton1Up"}
    
    local function selectCard()
        if not getgenv().CardSelectionEnabled then return false end
        local ok = pcall(function()
            local list = getAvailableCards() if not list then return false end
            local _, best, priority = findBestCard(list)
            if not best or not best.button or not priority or priority >= 999 then return false end
            local button = best.button
            for i = 1, #BUTTON_EVENTS do
                pcall(function()
                    local conns = getconnections(button[BUTTON_EVENTS[i]])
                    for j = 1, #conns do conns[j]:Fire() end
                end)
                task.wait(0.05)
            end
            task.wait(0.3)
            pressConfirm()
            task.wait(0.2)
        end)
        return ok
    end
    local function selectCardSlower()
        if not getgenv().SlowerCardSelectionEnabled then return false end
        local ok = pcall(function()
            local list = getAvailableCards() if not list then return false end
            local _, best, priority = findBestCard(list)
            if not best or not best.button or not priority then return false end
            if priority >= 999 then return false end
            local GuiService = game:GetService("GuiService")
            local function press(key)
                VIM:SendKeyEvent(true, key, false, game)
                task.wait(0.15)
                VIM:SendKeyEvent(false, key, false, game)
            end
            GuiService.SelectedObject = best.button
            task.wait(0.4)
            press(Enum.KeyCode.Return)
            task.wait(0.5)
            local ok2, confirmButton = pcall(function()
                local prompt = LocalPlayer.PlayerGui:FindFirstChild("Prompt")
                if not prompt then return nil end
                local frame = prompt:FindFirstChild("Frame")
                if not frame or not frame:FindFirstChild("Frame") then return nil end
                local inner = frame.Frame
                local children = inner:GetChildren()
                if #children < 5 then return nil end
                local btn = children[5]:FindFirstChild("TextButton")
                if btn and btn:FindFirstChild("TextLabel") and btn.TextLabel.Text == "Confirm" then
                    return btn
                end
                return nil
            end)
            if ok2 and confirmButton then
                GuiService.SelectedObject = confirmButton
                task.wait(0.4)
                press(Enum.KeyCode.Return)
                task.wait(0.5)
            end
            GuiService.SelectedObject = nil
        end)
        return ok
    end
    while true do
        task.wait(1.5)
        if getgenv().CardSelectionEnabled then
            selectCard()
        elseif getgenv().SlowerCardSelectionEnabled then
            selectCardSlower()
        end
    end
end)

task.spawn(function()
    local function getBossRushCards()
        local ok, result = pcall(function()
            local playerGui = LocalPlayer.PlayerGui
            local prompt = playerGui:FindFirstChild("Prompt") if not prompt then return nil end
            local frame = prompt:FindFirstChild("Frame") if not frame or not frame:FindFirstChild("Frame") then return nil end
            local cards, cardButtons = {}, {}
            local descendants = frame:GetDescendants()
            for i = 1, #descendants do
                local d = descendants[i]
                if d:IsA("TextLabel") and d.Parent and d.Parent:IsA("Frame") then
                    local text = d.Text
                    if getgenv().BossRushCardPriority and getgenv().BossRushCardPriority[text] then
                        local button = d.Parent.Parent
                        if button:IsA("GuiButton") or button:IsA("TextButton") or button:IsA("ImageButton") then
                            table.insert(cardButtons, {text=text, button=button})
                        end
                    end
                end
            end
            table.sort(cardButtons, function(a,b) return a.button.AbsolutePosition.X < b.button.AbsolutePosition.X end)
            for i, c in ipairs(cardButtons) do cards[i] = { name=c.text, button=c.button } end
            return #cards > 0 and cards or nil
        end)
        return ok and result or nil
    end
    local function best(list)
        local idx, bestPriority = nil, math.huge
        for i=1,#list do
            local nm=list[i].name
            local p=(getgenv().BossRushCardPriority and getgenv().BossRushCardPriority[nm]) or 999
            if p<bestPriority and p<999 then
                bestPriority=p
                idx=i
            end
        end
        if idx then
            return idx, list[idx], bestPriority
        end
        return nil, nil, nil
    end
    local function confirm()
        local ok, confirmButton = pcall(function()
            local prompt = LocalPlayer.PlayerGui:FindFirstChild("Prompt") if not prompt then return nil end
            local frame = prompt:FindFirstChild("Frame") if not frame then return nil end
            local inner = frame:FindFirstChild("Frame") if not inner then return nil end
            local children = inner:GetChildren() if #children < 5 then return nil end
            local button = children[5]:FindFirstChild("TextButton") if not button then return nil end
            local label = button:FindFirstChild("TextLabel") if label and label.Text == "Confirm" then return button end
            return nil
        end)
        if ok and confirmButton then
            local events={"Activated","MouseButton1Click","MouseButton1Down","MouseButton1Up"}
            for _,ev in ipairs(events) do pcall(function() for _,conn in ipairs(getconnections(confirmButton[ev])) do conn:Fire() end end) end
            return true
        end
        return false
    end
    local function select()
        if not getgenv().BossRushEnabled then return false end
        local ok = pcall(function()
            local list = getBossRushCards() if not list then return false end
            local _, bc, pri = best(list)
            if pri >= 999 then return false end
            if not bc or not bc.button then return false end
            local events={"Activated","MouseButton1Click","MouseButton1Down","MouseButton1Up"}
            for _,ev in ipairs(events) do pcall(function() for _,conn in ipairs(getconnections(bc.button[ev])) do conn:Fire() end end) end
            task.wait(0.2)
            confirm()
        end)
        return ok
    end
    while true do
        task.wait(1.5)
        if getgenv().BossRushEnabled then select() end
    end
end)

task.spawn(function()
    local hasRun = 0
    local function formatNumber(num)
        if not num or num == 0 then return "0" end
        local s = tostring(num) local k
        while true do s,k = string.gsub(s, "^(-?%d+)(%d%d%d)", '%1,%2') if k==0 then break end end
        return s
    end
    local function SendMessageEMBED(url, embed, content)
        local headers = { ["Content-Type"] = "application/json" }
        local data = { embeds = { { title=embed.title, description=embed.description, color=embed.color, fields=embed.fields, footer=embed.footer, timestamp=os.date("!%Y-%m-%dT%H:%M:%S.000Z") } } }
        if content and content ~= "" then
            data.content = content
        end
        local body = HttpService:JSONEncode(data)
        request({ Url=url, Method="POST", Headers=headers, Body=body })
    end
    local function getRewards()
        local rewards = {}
        local ok, res = pcall(function()
            local ui = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
            if not ui then return {} end
            local holder = ui:FindFirstChild("BG") and ui.BG:FindFirstChild("Container") and ui.BG.Container:FindFirstChild("Rewards") and ui.BG.Container.Rewards:FindFirstChild("Holder")
            if not holder then return {} end
            local waitTime = 0
            local lastCount = 0
            local stableCount = 0
            repeat
                task.wait(0.3) waitTime = waitTime + 0.3
                local children = holder:GetChildren()
                local currentCount = 0
                for i = 1, #children do if children[i]:IsA("TextButton") then currentCount = currentCount + 1 end end
                if currentCount == lastCount and currentCount > 0 then stableCount = stableCount + 1 else stableCount = 0 end
                lastCount = currentCount
            until (stableCount >= 5 and currentCount > 0) or waitTime > 4
            for _, item in pairs(holder:GetChildren()) do
                if item:IsA("TextButton") then
                    local rewardName, rewardAmount
                    local unitName = item:FindFirstChild("UnitName")
                    if unitName and unitName.Text and unitName.Text ~= "" then rewardName = unitName.Text end
                    local itemName = item:FindFirstChild("ItemName")
                    if itemName and itemName.Text and itemName.Text ~= "" then rewardName = itemName.Text end
                    if rewardName then
                        local amountLabel = item:FindFirstChild("Amount")
                        if amountLabel and amountLabel.Text then
                            local amountText = amountLabel.Text
                            local clean = string.gsub(string.gsub(string.gsub(amountText, "x", ""), "+", ""), ",", "")
                            rewardAmount = tonumber(clean)
                        else
                            rewardAmount = 1
                        end
                        if rewardAmount then table.insert(rewards, { name = rewardName, amount = rewardAmount }) end
                    end
                end
            end
            return rewards
        end)
        return ok and res or {}
    end
    local function getMatchResult()
        local ok, time, wave, result = pcall(function()
            local ui = LocalPlayer.PlayerGui:FindFirstChild("EndGameUI")
            if not ui then return "00:00:00","0","Unknown" end
            local stats = ui:FindFirstChild("BG") and ui.BG:FindFirstChild("Container") and ui.BG.Container:FindFirstChild("Stats")
            if not stats then return "00:00:00", "0", "Unknown" end
            local r = (stats:FindFirstChild("Result") and stats.Result.Text) or "Unknown"
            local t = (stats:FindFirstChild("ElapsedTime") and stats.ElapsedTime.Text) or "00:00:00"
            local w = (stats:FindFirstChild("EndWave") and stats.EndWave.Text) or "0"
            if t:find("Total Time:") then local m,s = t:match("Total Time:%s*(%d+):(%d+)") if m and s then t = string.format("%02d:%02d:%02d", 0, tonumber(m) or 0, tonumber(s) or 0) end end
            if w:find("Wave Reached:") then local wm = w:match("Wave Reached:%s*(%d+)") if wm then w = wm end end
            if r:lower():find("win") or r:lower():find("victory") then r = "VICTORY" elseif r:lower():find("defeat") or r:lower():find("lose") or r:lower():find("loss") then r = "DEFEAT" end
            return t, w, r
        end)
        if ok then return time, wave, result else return "00:00:00","0","Unknown" end
    end
    local function getMapInfo()
        local ok, name, difficulty = pcall(function()
            local map = workspace:FindFirstChild("Map") if not map then return "Unknown Map","Unknown" end
            local mapName = map:FindFirstChild("MapName")
            local mapDifficulty = map:FindFirstChild("MapDifficulty")
            return mapName and mapName.Value or "Unknown Map", mapDifficulty and mapDifficulty.Value or "Unknown"
        end)
        if ok then return name, difficulty else return "Unknown Map","Unknown" end
    end
    local lastWebhookHash = ""
    local lastWebhookTime = 0
    local WEBHOOK_COOLDOWN = 15
    local function sendWebhook()
        pcall(function()
            if not getgenv().WebhookEnabled then return end
            if isProcessing then return end
            local currentTime = tick()
            if currentTime - lastWebhookTime < WEBHOOK_COOLDOWN then return end
            if getgenv()._webhookLock and (currentTime - getgenv()._webhookLock) < 10 then return end
            getgenv()._webhookLock = currentTime
            lastWebhookTime = currentTime
            isProcessing = true
            hasRun = currentTime
            local rewards = getRewards()
            local matchTime, matchWave, matchResult = getMatchResult()
            local mapName, mapDifficulty = getMapInfo()
            local clientData = getClientData()
            if not clientData then isProcessing = false return end
            if matchWave == "0" or matchResult == "Unknown" or matchTime == "00:00:00" then
                warn("[Webhook] Incomplete data detected, skipping send")
                isProcessing = false
                return
            end
            local function formatStats()
                local stats = "<:jewel:1217525743408648253> " .. formatNumber(clientData.Gold or 0)
                stats = stats .. "\n<:gold:1265957290251522089> " .. formatNumber(clientData.Jewels or 0)
                stats = stats .. "\n<:emerald:1389165843966984192> " .. formatNumber(clientData.Emeralds or 0)
                stats = stats .. "\n<:rerollshard:1426315987019501598> " .. formatNumber(clientData.Rerolls or 0)
                stats = stats .. "\n<:candybasket:1426304615284084827> " .. formatNumber(clientData.CandyBasket or 0)
                local bingoStamps = 0
                if clientData.ItemData and clientData.ItemData.HallowenBingoStamp then bingoStamps = clientData.ItemData.HallowenBingoStamp.Amount or 0 end
                stats = stats .. "\n<:bingostamp:1426362482141954068> " .. formatNumber(bingoStamps)
                return stats
            end
            local rewardsText = ""
            if #rewards > 0 then
                for _, r in ipairs(rewards) do
                    local total = 0
                    local itemName = r.name
                    if clientData[itemName] and type(clientData[itemName]) == "number" then total = clientData[itemName]
                    elseif clientData.ItemData and clientData.ItemData[itemName] and clientData.ItemData[itemName].Amount then total = clientData.ItemData[itemName].Amount
                    elseif clientData.Items and clientData.Items[itemName] and clientData.Items[itemName].Amount then total = clientData.Items[itemName].Amount
                    elseif itemName == "Candy Basket" and clientData.CandyBasket then total = clientData.CandyBasket
                    elseif itemName:find("Bingo Stamp") and clientData.ItemData and clientData.ItemData.HallowenBingoStamp then total = clientData.ItemData.HallowenBingoStamp.Amount or 0
                    else total = r.amount end
                    rewardsText = rewardsText .. "+"..formatNumber(r.amount).." "..itemName.." [ Total: "..formatNumber(total).." ]\n"
                end
            else rewardsText = "No rewards found" end
            local unitsText = ""
            if clientData.Slots then
                local slots = {"Slot1","Slot2","Slot3","Slot4","Slot5","Slot6"}
                for _,slotName in ipairs(slots) do
                    local slot = clientData.Slots[slotName]
                    if slot and slot.Value then
                        local level = slot.Level or 0
                        local kills = formatNumber(slot.Kills or 0)
                        local unitName = slot.Value
                        unitsText = unitsText .. "[ "..level.." ] "..unitName.." = "..kills.." ⚔️\n"
                    end
                end
            end
            local hasUnitDrop = false
            for _, r in ipairs(rewards) do
                if r.name and (r.name:find("Unit") or r.type == "Unit") then
                    hasUnitDrop = true
                    break
                end
            end
            
            local description = "**Username:** ||"..LocalPlayer.Name.."||\n**Level:** "..(clientData.Level or 0).." ["..formatNumber(clientData.EXP or 0).."/"..formatNumber(clientData.MaxEXP or 0).."]"
            local embed = { title="Anime Last Stand", description=description or "N/A", color=0x00ff00, fields={
                { name="Player Stats", value=(formatStats() ~= "" and formatStats() or "N/A"), inline=true },
                { name="Rewards", value=(rewardsText ~= "" and rewardsText or "No rewards found"), inline=true },
                { name="Units", value=(unitsText ~= "" and unitsText or "No units"), inline=false },
                { name="Match Result", value=(matchTime or "00:00:00") .. " - Wave " .. tostring(matchWave or "0") .. "\n" .. (mapName or "Unknown Map") .. ((mapDifficulty and mapDifficulty ~= "Unknown") and (" ["..mapDifficulty.."]") or "") .. " - " .. (matchResult or "Unknown"), inline=false }
            }, footer={ text="Halloween Hook" } }
            
            local webhookContent = ""
            if hasUnitDrop and getgenv().PingOnSecretDrop and getgenv().DiscordUserID and getgenv().DiscordUserID ~= "" then
                webhookContent = "<@" .. getgenv().DiscordUserID .. "> 🎉 **SECRET UNIT DROP!**"
            end
            local webhookHash = LocalPlayer.Name .. "_" .. matchTime .. "_" .. matchWave .. "_" .. rewardsText
            if webhookHash == lastWebhookHash then
                isProcessing = false
                return
            end
            lastWebhookHash = webhookHash
            local sendSuccess = false
            local sendAttempts = 0
            while not sendSuccess and sendAttempts < 2 do
                sendAttempts = sendAttempts + 1
                local ok = pcall(function()
                    if webhookContent ~= "" then
                        SendMessageEMBED(getgenv().WebhookURL, embed, webhookContent)
                    else
                        SendMessageEMBED(getgenv().WebhookURL, embed)
                    end
                end)
                if ok then
                    sendSuccess = true
                else
                    warn("[Webhook] Send failed (Attempt " .. sendAttempts .. "/2)")
                    task.wait(2)
                end
            end
            task.wait(1)
            isProcessing = false
        end)
    end
    LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "EndGameUI" and getgenv().WebhookEnabled then
            task.wait(3)
            sendWebhook()
        end
    end)
    LocalPlayer.PlayerGui.ChildRemoved:Connect(function(child)
        if child.Name == "EndGameUI" then
            task.wait(2)
            isProcessing = false
            if getgenv()._lastRewardHash then
                getgenv()._lastRewardHash = nil
            end
        end
    end)
end)

task.spawn(function()
    pcall(function()
        local endgameCount = 0
        local hasRun = false
        local lastEndgameTime = 0
        local DEBOUNCE_TIME = 5
        local maxWait = 0
        local maxRoundsReached = false
        
        repeat task.wait(0.5) maxWait = maxWait + 0.5 until not LocalPlayer.PlayerGui:FindFirstChild("TeleportUI") or maxWait > 30
        
        print("[Seamless Fix] Waiting for Settings GUI...")
        maxWait = 0
        repeat task.wait(0.5) maxWait = maxWait + 0.5 until LocalPlayer.PlayerGui:FindFirstChild("Settings") or maxWait > 30
        print("[Seamless Fix] Settings GUI found!")
        
        local function getSeamlessValue()
            local ok, result = pcall(function()
                local settings = LocalPlayer.PlayerGui:FindFirstChild("Settings")
                if settings then
                    local seamless = settings:FindFirstChild("SeamlessRetry")
                    if seamless then 
                        return seamless.Value 
                    else
                        print("[Seamless Fix] SeamlessRetry not found in Settings")
                    end
                else
                    print("[Seamless Fix] Settings not found")
                end
                return false
            end)
            return ok and result or false
        end
        
        local function setSeamlessRetry()
            pcall(function()
                local remotes = RS:FindFirstChild("Remotes")
                local setSettings = remotes and remotes:FindFirstChild("SetSettings")
                if setSettings then 
                    setSettings:InvokeServer("SeamlessRetry")
                end
            end)
        end
        
        local function enableSeamlessIfNeeded()
            if not getgenv().SeamlessLimiterEnabled then return end
            local maxRounds = getgenv().MaxSeamlessRounds or 4
            
            if endgameCount < maxRounds then
                if not getSeamlessValue() then
                    setSeamlessRetry()
                    print("[Seamless Fix] Enabled Seamless Retry (" .. endgameCount .. "/" .. maxRounds .. ")")
                    task.wait(0.5)
                end
            elseif endgameCount >= maxRounds then
                if getSeamlessValue() then
                    setSeamlessRetry()
                    print("[Seamless Fix] Disabled Seamless Retry - Max rounds reached (" .. endgameCount .. "/" .. maxRounds .. ")")
                    task.wait(0.5)
                end
            end
        end
        
        print("[Seamless Fix] Checking initial seamless state...")
        enableSeamlessIfNeeded()
        
        local seamlessToggleConnection
        seamlessToggleConnection = task.spawn(function()
            while true do
                task.wait(1)
                if getgenv().SeamlessLimiterEnabled then
                    enableSeamlessIfNeeded()
                end
            end
        end)
        
        LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
            pcall(function()
                if child.Name == "EndGameUI" and not hasRun then
                    local currentTime = tick()
                    if currentTime - lastEndgameTime < DEBOUNCE_TIME then
                        print("[Seamless Fix] Debounced duplicate EndGameUI trigger")
                        return
                    end
                    hasRun = true
                    lastEndgameTime = currentTime
                    endgameCount = endgameCount + 1
                    local maxRounds = getgenv().MaxSeamlessRounds or 4
                    print("[Seamless Fix] Endgame detected. Current seamless rounds: " .. endgameCount .. "/" .. maxRounds)
                    
                    if endgameCount >= maxRounds and getgenv().SeamlessLimiterEnabled then
                        maxRoundsReached = true
                        print("[Seamless Fix] Max rounds reached, disabling seamless retry to restart match...")
                        task.wait(0.5)
                        if getSeamlessValue() then
                            setSeamlessRetry()
                            print("[Seamless Fix] Disabled Seamless Retry")
                            task.wait(0.5)
                        else
                            print("[Seamless Fix] Seamless already disabled")
                        end
                        
                        task.spawn(function()
                            print("[Seamless Fix] Waiting for EndGameUI to close...")
                            local maxWait = 0
                            while LocalPlayer.PlayerGui:FindFirstChild("EndGameUI") and maxWait < 30 do
                                task.wait(0.5)
                                maxWait = maxWait + 0.5
                            end
                            
                            if not LocalPlayer.PlayerGui:FindFirstChild("EndGameUI") then
                                print("[Seamless Fix] EndGameUI closed, firing RestartMatch...")
                                task.wait(0.5)
                                local success, err = pcall(function()
                                    local remotes = RS:FindFirstChild("Remotes")
                                    local restartEvent = remotes and remotes:FindFirstChild("RestartMatch")
                                    if restartEvent then
                                        restartEvent:FireServer()
                                        print("[Seamless Fix] RestartMatch fired successfully")
                                    else
                                        warn("[Seamless Fix] RestartMatch not found")
                                    end
                                end)
                                if not success then
                                    warn("[Seamless Fix] Failed to fire RestartMatch: " .. tostring(err))
                                end
                            else
                                warn("[Seamless Fix] EndGameUI did not close in time, skipping restart")
                            end
                        end)
                    end
                end
            end)
        end)
        
        LocalPlayer.PlayerGui.ChildRemoved:Connect(function(child) 
            if child.Name == "EndGameUI" then 
                task.wait(2) 
                hasRun = false 
            end 
        end)
        
        LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
            if child.Name == "TeleportUI" and maxRoundsReached then
                print("[Seamless Fix] New match starting, resetting seamless counter...")
                endgameCount = 0
                maxRoundsReached = false
                task.wait(2)
                enableSeamlessIfNeeded()
            end
        end)
    end)
end)

task.spawn(function()
    if not isInLobby then return end
    task.wait(1)
    local BingoEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Bingo")
    if not BingoEvents then return end
    local UseStampEvent = BingoEvents:FindFirstChild("UseStamp")
    local ClaimRewardEvent = BingoEvents:FindFirstChild("ClaimReward")
    local CompleteBoardEvent = BingoEvents:FindFirstChild("CompleteBoard")
    print("[Auto Bingo] Bingo automation loaded!")
    while true do
        task.wait(0.1)
        if getgenv().BingoEnabled then
            pcall(function()
                if UseStampEvent then
                    for i=1,25 do 
                        UseStampEvent:FireServer()
                    end
                end
                if ClaimRewardEvent then
                    for i=1,25 do 
                        ClaimRewardEvent:InvokeServer(i)
                    end
                end
                if CompleteBoardEvent then 
                    CompleteBoardEvent:InvokeServer()
                end
            end)
        end
        if Library and Library.Unloaded then break end
    end
end)

task.spawn(function()
    if not isInLobby then return end
    task.wait()
    local PurchaseEvent = RS:WaitForChild("Events"):WaitForChild("Hallowen2025"):WaitForChild("Purchase")
    local OpenCapsuleEvent = RS:WaitForChild("Remotes"):WaitForChild("OpenCapsule")
    
    local function clickButton(button)
        if not button then return false end
        local events = {"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}
        for _, ev in ipairs(events) do
            pcall(function()
                for _, conn in ipairs(getconnections(button[ev])) do
                    conn:Fire()
                end
            end)
        end
        return true
    end
    
    local function clickAllPromptButtons()
        local success = false
        pcall(function()
            local prompt = LocalPlayer.PlayerGui:FindFirstChild("Prompt")
            if not prompt then return end
            
            local frame = prompt:FindFirstChild("Frame")
            if not frame then return end
            
            local textButton = frame:FindFirstChild("TextButton")
            if textButton then
                clickButton(textButton)
                success = true
            end
            
            local folder = frame:FindFirstChild("Folder")
            if folder then
                local folderButton = folder:FindFirstChild("TextButton")
                if folderButton then
                    clickButton(folderButton)
                    success = true
                end
            end
        end)
        return success
    end
    
    while true do
        task.wait(0.1)
        if getgenv().CapsuleEnabled then
            local clientData = getClientData()
            if clientData then
                local candyBasket = clientData.CandyBasket or 0
                
                if candyBasket >= 100000 then
                    pcall(function() PurchaseEvent:InvokeServer(1, 100) end)
                elseif candyBasket >= 10000 then
                    pcall(function() PurchaseEvent:InvokeServer(1, 10) end)
                elseif candyBasket >= 1000 then
                    pcall(function() PurchaseEvent:InvokeServer(1, 1) end)
                end
                
                if candyBasket < 1000 then
                    clientData = getClientData()
                    local capsuleAmount = 0
                    if clientData and clientData.ItemData and clientData.ItemData.HalloweenCapsule2025 then
                        capsuleAmount = clientData.ItemData.HalloweenCapsule2025.Amount or 0
                    end
                    
                    if capsuleAmount > 0 then
                        pcall(function()
                            OpenCapsuleEvent:FireServer("HalloweenCapsule2025", capsuleAmount)
                        end)
                        
                        task.wait(0.2)
                        
                        while LocalPlayer.PlayerGui:FindFirstChild("Prompt") and getgenv().CapsuleEnabled do
                            clickAllPromptButtons()
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end
end)

if isInLobby then
    task.spawn(function()
        local function getAvailableBreaches()
            local ok, breaches = pcall(function()
                local lobby = workspace:FindFirstChild("Lobby")
                if not lobby then return {} end
                local breachesFolder = lobby:FindFirstChild("Breaches")
                if not breachesFolder then return {} end
                local available = {}
                local children = breachesFolder:GetChildren()
                for i = 1, #children do
                    local part = children[i]
                    local breachPart = part:FindFirstChild("Breach")
                    if breachPart then
                        local proximityPrompt = breachPart:FindFirstChild("ProximityPrompt")
                        if proximityPrompt and proximityPrompt:IsA("ProximityPrompt") then
                            if proximityPrompt.ObjectText and proximityPrompt.ObjectText ~= "" then
                                local breachName = proximityPrompt.ObjectText
                                available[#available + 1] = { name = breachName, instance = part }
                            end
                        end
                    end
                end
                return available
            end)
            if not ok then return {} end
            return breaches or {}
        end
        while true do
            task.wait(1)
            if getgenv().BreachEnabled then
                local availableBreaches = getAvailableBreaches()
                for _, breach in ipairs(availableBreaches) do
                    local shouldJoin = getgenv().BreachAutoJoin[breach.name]
                    if shouldJoin then
                        pcall(function()
                            local remote = RS.Remotes.Breach.EnterEvent
                            remote:FireServer(breach.instance)
                        end)
                        task.wait(0.5)
                    end
                end
            end
        end
    end)
end

if isInLobby then
    task.spawn(function()
        while true do
            task.wait(2)
            if getgenv().AutoJoinConfig and getgenv().AutoJoinConfig.enabled then
                pcall(function()
                    local cfg = getgenv().AutoJoinConfig
                    if not cfg.map or cfg.map == "" then return end
                    cleanupBeforeTeleport()
                    local teleporterRemote = RS.Remotes.Teleporter.InteractEvent
                    if cfg.mode == "Story" then
                        teleporterRemote:FireServer("Select", cfg.map, cfg.act, cfg.difficulty, "Story")
                    elseif cfg.mode == "Infinite" then
                        teleporterRemote:FireServer("Select", cfg.map, cfg.act, cfg.difficulty, "Infinite")
                    elseif cfg.mode == "Raids" then
                        teleporterRemote:FireServer("Select", cfg.map, cfg.act)
                    elseif cfg.mode == "Dungeon" or cfg.mode == "Survival" then
                        teleporterRemote:FireServer("Select", cfg.map)
                    elseif cfg.mode == "ElementalCaverns" then
                        teleporterRemote:FireServer("Select", cfg.map, cfg.difficulty)
                    elseif cfg.mode == "Challenge" then
                        teleporterRemote:FireServer("Select", "Challenge", cfg.act)
                    elseif cfg.mode == "LegendaryStages" then
                        teleporterRemote:FireServer("Select", cfg.map, cfg.act, cfg.difficulty, "LegendaryStages")
                    end
                    task.wait(1)
                end)
            end
            if getgenv().AutoJoinConfig and getgenv().AutoJoinConfig.autoStart then
                pcall(function()
                    local bottomGui = LocalPlayer.PlayerGui:FindFirstChild("Bottom")
                    if not bottomGui then return end
                    local path = bottomGui:FindFirstChild("Frame")
                    if not path or not path:GetChildren()[2] then return end
                    local subChildren = path:GetChildren()[2]:GetChildren()
                    if not subChildren[6] then return end
                    local textButton = subChildren[6]:FindFirstChild("TextButton")
                    if not textButton then return end
                    local textLabel = textButton:FindFirstChild("TextLabel")
                    if textLabel and textLabel.Text == "Start" then
                        local playerReady = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("PlayerReady")
                        if playerReady then playerReady:FireServer() end
                    end
                end)
            end
        end
    end)
end


