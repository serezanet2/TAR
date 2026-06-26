-- [[ CUSTOM CUP & BOX FARMER SCRIPT (TMI V2) ]] --
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

_G.CupBoxFarmActive = false

-- Создание GUI на стороне CoreGui (или PlayerGui для тестов в Студии)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CupBoxFarmGui"
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 200, 0, 150)
MainFrame.Position = UDim2.new(0.5, -100, 0.4, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 230, 118)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Text = "Cup & Box AutoFarm"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleLabel

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 160, 0, 40)
ToggleButton.Position = UDim2.new(0.5, -80, 0.45, -20)
ToggleButton.Text = "Farm: OFF"
ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 14
ToggleButton.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 30)
StatusLabel.Position = UDim2.new(0, 0, 0.8, 0)
StatusLabel.Text = "Scanning..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Parent = MainFrame

-- Главная функция подбора и активации
local function performFarm()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local originalCFrame = hrp.CFrame
    local targetFound = false

    -- 1. СКАНИРОВАНИЕ ЧАШ (Инструменты, содержащие Cup/cup/CUP)
    for _, obj in pairs(workspace:GetDescendants()) do
        if not _G.CupBoxFarmActive then break end
        
        if obj:IsA("Tool") or obj:IsA("BackpackItem") then
            local name = string.lower(obj.Name)
            if string.find(name, "cup") then
                local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                if handle then
                    targetFound = true
                    StatusLabel.Text = "Grabbing Cup: " .. obj.Name
                    StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
                    
                    -- Запоминаем исходное положение
                    originalCFrame = hrp.CFrame
                    
                    -- Телепортируемся к чаше
                    hrp.CFrame = CFrame.new(handle.Position)
                    
                    -- Даем физике Roblox 0.15 секунд на триггер касания
                    task.wait(0.15) 
                    
                    -- Принудительно экипируем в руку для надежности
                    pcall(function()
                        humanoid:EquipTool(obj)
                    end)
                    
                    task.wait(0.1)
                    -- Возвращаемся обратно
                    hrp.CFrame = originalCFrame
                    task.wait(0.25)
                    break
                end
            end
        end
    end

    -- 2. СКАНИРОВАНИЕ БОКСОВ (Детали, НЕ модели, содержащие "box" + ProximityPrompt)
    if not targetFound then
        for _, obj in pairs(workspace:GetDescendants()) do
            if not _G.CupBoxFarmActive then break end

            if obj:IsA("BasePart") and not obj:IsA("Model") then
                local name = string.lower(obj.Name)
                if string.find(name, "box") then
                    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt then
                        targetFound = true
                        StatusLabel.Text = "Activating Box: " .. obj.Name
                        StatusLabel.TextColor3 = Color3.fromRGB(224, 176, 255)

                        -- Запоминаем позицию
                        originalCFrame = hrp.CFrame
                        
                        -- Телепортируемся сверху бокса
                        hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                        
                        task.wait(0.15)
                        
                        -- Активируем ProximityPrompt
                        pcall(function()
                            fireproximityprompt(prompt)
                        end)

                        task.wait(0.15)
                        -- Возвращаемся обратно
                        hrp.CFrame = originalCFrame
                        task.wait(0.2)
                        break
                    end
                end
            end
        end
    end

    if not targetFound then
        StatusLabel.Text = "Scanning... No targets found"
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end

-- Обработка клика по кнопке ON/OFF
ToggleButton.MouseButton1Click:Connect(function()
    _G.CupBoxFarmActive = not _G.CupBoxFarmActive
    if _G.CupBoxFarmActive then
        ToggleButton.Text = "Farm: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        StatusLabel.Text = "Farm Enabled"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
    else
        ToggleButton.Text = "Farm: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        StatusLabel.Text = "Farm Disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

-- Периодический цикл каждые 0.5 секунд
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.CupBoxFarmActive then
            pcall(performFarm)
        end
    end
end)
