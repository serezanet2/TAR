local localPlayer = game:GetService("Players").LocalPlayer
local targetName = "cng666setna"

-- Функция для телепортации
local function teleport()
    local myChar = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local targetPlayer = game:GetService("Players"):FindFirstChild(targetName)
    
    if targetPlayer and targetPlayer.Character then
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if myRoot and targetRoot then
            -- Перемещаем CFrame вашего рут-парта к рут-парту цели
            myRoot.CFrame = targetRoot.CFrame
        else
            warn("У вас или у цели отсутствует HumanoidRootPart!")
        end
    else
        warn("Игрок " .. targetName .. " не найден на сервере или еще не возродился!")
    end
end

teleport()
