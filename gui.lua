local UIS = game:GetService("UserInputService")

local running = true

-- Toggle with P
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.P then
        running = not running
        warn("Auto skill: " .. (running and "ON" or "OFF"))
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if running then
            -- Press X
            keypress(0x58)
            task.wait(0.05)
            keyrelease(0x58)
            
            task.wait(0.05)
            
            -- Press C
            keypress(0x43)
            task.wait(0.05)
            keyrelease(0x43)
        end
    end
end)

warn("Auto skill loaded! Press P to toggle ON/OFF.")
