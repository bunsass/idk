-- Auto Equipment Upgrader
-- Runs immediately on execute

local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local SPAM_COUNT = 15
local SPAM_DELAY = 0.1
local LOOP_DELAY = 1.0

local function navClick(obj)
    GuiService.SelectedObject = obj
    task.wait(0.2)
    VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end

local playerGui = player:WaitForChild("PlayerGui")

-- Click Equipment tab ONCE
print("[Upgrader] Clicking EQUIPMENT tab...")
local equipBtn = playerGui.Interface.Topbar.Main.Categories.Equipment.Interact
navClick(equipBtn)
task.wait(0.8)
print("[Upgrader] Equipment tab opened! Starting upgrade loop...")

-- Loop only on UPGRADE ALL
local upgradeBtn = playerGui.Interface.Equipment.Stats.All
while true do
    for i = 1, SPAM_COUNT do
        navClick(upgradeBtn)
        task.wait(SPAM_DELAY)
    end
    print("[Upgrader] Cycle done, looping...")
    task.wait(LOOP_DELAY)
end
