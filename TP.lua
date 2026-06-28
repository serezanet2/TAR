-- Создание интерфейса
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local CloseBtn = Instance.new("TextButton")
local SaveBtn = Instance.new("TextButton")
local TpBtn = Instance.new("TextButton")

ScreenGui.Name = "TeleportGUI_BY_AI"
ScreenGui.Parent = game:GetService("CoreGui") -- Защита от удаления обычными скриптами игры
ScreenGui.ResetOnSpawn = false

-- Главное окно
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.75, 0, 0.7, 0) -- Позиция на экране (справа внизу)
MainFrame.Size = UDim2.new(0, 220, 0, 140)
MainFrame.Active = true
MainFrame.Selectable = true
MainFrame.Draggable = true -- Делает окно перемещаемым мышкой

-- Заголовок окна
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.SourceSansBold
Title.Text = "  ТЕЛЕПОРТ МЕНЮ"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14.000
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Кнопка закрытия (Удалить окно)
CloseBtn.Name = "CloseBtn"
CloseBtn.Parent = MainFrame
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.BorderSizePixel = 0
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14.000

-- Кнопка "Сохранить позицию"
SaveBtn.Name = "SaveBtn"
SaveBtn.Parent = MainFrame
SaveBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
SaveBtn.BorderSizePixel = 0
SaveBtn.Position = UDim2.new(0, 10, 0, 45)
SaveBtn.Size = UDim2.new(1, -20, 0, 35)
SaveBtn.Font = Enum.Font.SourceSans
SaveBtn.Text = "Сохранить позицию"
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.TextSize = 16.000

-- Кнопка "Телепортироваться"
TpBtn.Name = "TpBtn"
TpBtn.Parent = MainFrame
TpBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
TpBtn.BorderSizePixel = 0
TpBtn.Position = UDim2.new(0, 10, 0, 90)
TpBtn.Size = UDim2.new(1, -20, 0, 35)
TpBtn.Font = Enum.Font.SourceSans
TpBtn.Text = "ТП к точке"
TpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TpBtn.TextSize = 16.000

-- ПЕРЕМЕННАЯ ДЛЯ ХРАНЕНИЯ КООРДИНАТ
local savedCFrame = nil

-- ФУНКЦИОНАЛ КНОПОК
SaveBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local lplayer = game:GetService("Players").LocalPlayer
        local char = game.Workspace:FindFirstChild(lplayer.Name) or lplayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            savedCFrame = char.HumanoidRootPart.CFrame
            SaveBtn.Text = "УСПЕШНО СОХРАНЕНО!"
            task.wait(1)
            SaveBtn.Text = "Сохранить позицию"
        end
    end)
end)

TpBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if savedCFrame then
            local lplayer = game:GetService("Players").LocalPlayer
            local char = game.Workspace:FindFirstChild(lplayer.Name) or lplayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = savedCFrame
            end
        else
            TpBtn.Text = "СНАЧАЛА СОХРАНИТЕ ТОЧКУ!"
            task.wait(1)
            TpBtn.Text = "ТП к точке"
        end
    end)
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy() -- Полностью удаляет GUI из игры
end)
