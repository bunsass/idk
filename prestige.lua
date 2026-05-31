local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Interface = playerGui:WaitForChild("Interface")

task.wait(2)

local GOLD_THRESHOLD  = 200_000_000
local LEVEL_THRESHOLD = 100

local function parseNumber(str)
    str = str:gsub(",", "")
    local num, suffix = str:match("^([%d%.]+)([KkMmBb]?)$")
    if not num then return 0 end
    num = tonumber(num) or 0
    suffix = suffix:upper()
    if suffix == "K" then num = num * 1_000
    elseif suffix == "M" then num = num * 1_000_000
    elseif suffix == "B" then num = num * 1_000_000_000
    end
    return math.floor(num)
end

local function navClick(obj)
    if not obj then return end
    GuiService.SelectedObject = obj
    task.wait(0.2)
    VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    task.wait(0.3)
end

local Topbar = Interface:WaitForChild("Topbar")
local HUD = Interface:WaitForChild("Gear_Up"):WaitForChild("HUD")

local gold = parseNumber(Topbar.Main.Currencies.Gold.Amount.Text)
local level = tonumber(HUD.Level.Title.Text:match("%d+")) or 0

print(string.format("[Prestige] Gold: %d | Level: %d", gold, level))

if gold >= GOLD_THRESHOLD and level >= LEVEL_THRESHOLD then
    print("[Prestige] Threshold met! Starting...")

    navClick(Topbar.Main.Categories.Equipment.Interact)
    task.wait(0.8)

    navClick(Interface.Equipment.Categories.Prestige)
    task.wait(0.8)

    navClick(Interface.Equipment.Prestige.B_Prestige)
    task.wait(0.8)

    navClick(Interface.Warning.Prompt.Main.Yes)
    print("[Prestige] Done! Waiting for Memories screen...")

    -- Wait for memories screen then alert you
    local boostFrame = Interface.Gear_Up.Boosts
    local timeout = 30
    local elapsed = 0
    while elapsed < timeout do
        if boostFrame.Visible then
            -- Play a sound to alert you
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://4612332731"
            sound.Volume = 1
            sound.Parent = game:GetService("SoundService")
            sound:Play()
            
            print("[Prestige] *** MEMORIES SCREEN OPEN - CLICK GOLD BOOST NOW! ***")
            
            -- Wait for you to click gold then auto confirm
            local confirmBtn = Interface.Memories_Buttons.M_Confirm
            local waited = 0
            while waited < 15 do
                if confirmBtn.Visible then
                    task.wait(0.3)
                    navClick(confirmBtn)
                    print("[Prestige] Confirmed! All done!")
                    return
                end
                task.wait(0.3)
                waited += 0.3
            end
            return
        end
        task.wait(0.5)
        elapsed += 0.5
    end
    warn("[Prestige] Timed out waiting for Memories screen.")
else
    print("[Prestige] Threshold NOT met.")
end
