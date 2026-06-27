-- [[ CUSTOM CUP, GENESIS, GOLD, COPPER & SILVER FARMER + INSTANT FREECAM (TMI V2.2) ]] --
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

_G.CupBoxFarmActive = false
_G.FreecamActive = false

-- Создание GUI на стороне CoreGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CupBoxFarmGuiV2_2"
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 230, 0, 210)
MainFrame.Position = UDim2.new(0.5, -115, 0.4, -105)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 230, 118)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -30, 0, 35)
TitleLabel.Position = UDim2.new(0, 5, 0, 0)
TitleLabel.Text = "Cup & Box Farmer V2.2"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Parent = MainFrame

local HeaderBg = Instance.new("Frame")
HeaderBg.Size = UDim2.new(1, 0, 0, 35)
HeaderBg.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
HeaderBg.ZIndex = 0
HeaderBg.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = HeaderBg

-- КНОПКА ЗАКРЫТИЯ/УДАЛЕНИЯ СКРИПТА (×)
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Position = UDim2.new(1, -30, 0, 5)
CloseButton.Text = "×"
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 16
CloseButton.ZIndex = 2
CloseButton.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseButton

-- Кнопка переключения Фарма
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 190, 0, 35)
ToggleButton.Position = UDim2.new(0.5, -95, 0, 45)
ToggleButton.Text = "Farm: OFF"
ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 13
ToggleButton.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

-- Кнопка переключения Freecam (Прикам)
local FreecamButton = Instance.new("TextButton")
FreecamButton.Size = UDim2.new(0, 190, 0, 35)
FreecamButton.Position = UDim2.new(0.5, -95, 0, 90)
FreecamButton.Text = "Freecam: OFF (Shift + P / F)"
FreecamButton.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
FreecamButton.TextColor3 = Color3.fromRGB(255, 255, 255)
FreecamButton.Font = Enum.Font.GothamBold
FreecamButton.TextSize = 12
FreecamButton.Parent = MainFrame

local FreecamCorner = Instance.new("UICorner")
FreecamCorner.CornerRadius = UDim.new(0, 6)
FreecamCorner.Parent = FreecamButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 30)
StatusLabel.Position = UDim2.new(0, 0, 0, 135)
StatusLabel.Text = "Scan: 5s | Collect: 0.1s"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.Parent = MainFrame

local HelpLabel = Instance.new("TextLabel")
HelpLabel.Size = UDim2.new(1, 0, 0, 30)
HelpLabel.Position = UDim2.new(0, 0, 0, 170)
HelpLabel.Text = "Press 'F' key to exit Freecam"
HelpLabel.TextColor3 = Color3.fromRGB(120, 130, 140)
HelpLabel.BackgroundTransparency = 1
HelpLabel.Font = Enum.Font.Gotham
HelpLabel.TextSize = 9
HelpLabel.Parent = MainFrame

-- Очереди и Черные Списки
local CollectedTools = {}
local TargetsQueue = {}

-- [[ 1. ПОИСК ЦЕЛЕЙ (Происходит каждые 5.0 секунд) ]] --
task.spawn(function()
    while true do
        task.wait(5.0)
        if _G.CupBoxFarmActive then
            -- Очищаем очередь на этом проходе
            TargetsQueue = {}

            -- [[ ТЕПЕРЬ БОКСЫ ИМЕЮТ ПРИОРИТЕТ ВЫШЕ ]]
            -- 1. Сначала находим боксы (игнорируя те, у которых в имени есть "supply")
            for _, obj in pairs(workspace:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("Model")) and not obj.Anchored then
                    local name = string.lower(obj.Name)
                    if string.find(name, "box") and not string.find(name, "supply") then
                        local prompt = nil
                        for _, desc in pairs(obj:GetDescendants()) do
                            if desc:IsA("ProximityPrompt") then
                                prompt = desc
                                break
                            end
                        end

                        if prompt then
                            -- Проверяем, нет ли платного ценника $ у бокса
                            local isShopItem = string.find(prompt.ActionText, "%$") or string.find(prompt.ObjectText, "%$")
                            if not isShopItem then
                                local tpPos = obj:IsA("BasePart") and obj.Position or (obj:FindFirstChildWhichIsA("BasePart") and obj:FindFirstChildWhichIsA("BasePart").Position or nil)
                                if tpPos then
                                    table.insert(TargetsQueue, {Type = "Box", Object = obj, Prompt = prompt, Position = tpPos})
                                end
                            end
                        end
                    end
                end
            end

            -- 2. Затем находим чаши / генезис / металлы
            for _, obj in pairs(workspace:GetDescendants()) do
                if (obj:IsA("Tool") or obj:IsA("BackpackItem")) and not CollectedTools[obj] then
                    -- Проверяем, не лежит ли предмет в рюкзаке или в руках у кого-то (где есть Humanoid)
                    local isEquipped = false
                    local parent = obj.Parent
                    while parent and parent ~= workspace do
                        -- Если у родителя есть класс Humanoid, или родитель - это Backpack, или игрок
                        if parent:IsA("Player") or parent:IsA("Backpack") or parent:FindFirstChildWhichIsA("Humanoid") then
                            isEquipped = true
                            break
                        end
                        parent = parent.Parent
                    end

                    if not isEquipped then
                        local name = string.lower(obj.Name)
                        if string.find(name, "cup") or string.find(name, "genesis") or string.find(name, "gold") or string.find(name, "copper") or string.find(name, "silver") then
                            local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                            if handle and not handle.Anchored then
                                table.insert(TargetsQueue, {Type = "Tool", Object = obj, Position = handle.Position})
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- [[ 2. БРИНЬКАНЬЕ (Сбор целей из очереди каждые 0.1 секунд) ]] --
task.spawn(function()
    while true do
        task.wait(0.1)
        if _G.CupBoxFarmActive and #TargetsQueue > 0 then
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChild("Humanoid")

            if hrp and humanoid then
                local target = table.remove(TargetsQueue, 1)

                if target.Type == "Tool" and target.Object.Parent and not CollectedTools[target.Object] then
                    CollectedTools[target.Object] = true -- Навечно блокируем этот объект
                    
                    -- Временно разблокируем персонажа для телепортации и забора физического предмета
                    hrp.Anchored = false
                    hrp.CFrame = CFrame.new(target.Position)
                    task.wait(0.1) -- микро-задержка на обработку физики касания
                    
                    pcall(function()
                        humanoid:EquipTool(target.Object)
                    end)
                    task.wait(0.1)
                    
                    -- Возвращаемся ровно на изначальную точку с тем же вращением и заново закрепляем (Anchored)
                    if _G.OriginalCFrame then
                        hrp.CFrame = _G.OriginalCFrame
                        hrp.Anchored = true
                    end
                    task.wait(0.1)
                    
                    -- [[ ЭКИПИРОВКА И МНОГОКРАТНЫЙ BACKSPACE / ДРОП С ПОВОРОТОМ И ПАДЕНИЕМ В НАПРАВЛЕНИИ ВЗГЛЯДА ]]
                    pcall(function()
                        -- 1. Переносим абсолютно ВСЕ предметы из рюкзака в Character себя (берем в руки)
                        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                            if tool:IsA("Tool") then
                                tool.Parent = character
                            end
                        end
                        task.wait(0.1)

                        -- 2. Быстро спамим клавишей Backspace (15 раз) через VirtualInputManager
                        local VirtualInputManager = game:GetService("VirtualInputManager")
                        for i = 1, 15 do
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                            task.wait(0.02)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                            task.wait(0.02)
                        end

                        -- 3. Резервный выброс по направлению взгляда, если CanBeDropped заблокировано в игре
                        for _, tool in pairs(character:GetChildren()) do
                            if tool:IsA("Tool") then
                                tool.Parent = workspace
                                local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
                                if handle then
                                    -- Выкидываем строго вперед по направлению взгляда hrp
                                    handle.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 4 + Vector3.new(0, 1, 0)
                                    handle.Velocity = hrp.CFrame.LookVector * 25 + Vector3.new(0, 5, 0)
                                end
                            end
                        end
                    end)
                    
                elseif target.Type == "Box" and target.Object.Parent then
                    local originalCFrame = hrp.CFrame
                    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
                    
                    -- Ждем 0.1 сек для корректной стыковки
                    task.wait(0.1)
                    
                    -- ПОЛНЫЙ НЕПРЕРЫВНЫЙ СПАМ КНОПКИ АКТИВАЦИИ ВО ВРЕМЯ УДЕРЖАНИЯ:
                    local holdTime = target.Prompt.HoldDuration or 0
                    local duration = holdTime + 0.5
                    local elapsed = 0
                    
                    -- Цикл спама каждые 0.1 секунды
                    while elapsed < duration do
                        if not _G.CupBoxFarmActive then break end
                        
                        pcall(function()
                            fireproximityprompt(target.Prompt)
                        end)
                        
                        task.wait(0.1)
                        elapsed = elapsed + 0.1
                    end
                    
                    hrp.CFrame = originalCFrame
                end
            end
        end
    end
end)

-- [[ 3. МОМЕНТАЛЬНЫЙ FREECAM (БЕЗ СКРЫТИЙ И ПЛАВНОСТЕЙ) ]] --
local FreecamConnection = nil
local freecamSpeed = 1.5

local function EnterFreecam()
    _G.FreecamActive = true
    FreecamButton.Text = "Freecam: ON"
    FreecamButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    
    camera.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter -- Центр припаян к курсору для вида от 1 лица

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = true end

    FreecamConnection = RunService.RenderStepped:Connect(function(dt)
        local currentCFrame = camera.CFrame
        local moveVector = Vector3.new()

        -- Считывание нажатий без сглаживания
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + currentCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - currentCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - currentCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + currentCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector - Vector3.new(0, 1, 0) end

        local multiplier = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1
        camera.CFrame = currentCFrame + (moveVector * freecamSpeed * multiplier)
    end)
end

local function ExitFreecam()
    _G.FreecamActive = false
    FreecamButton.Text = "Freecam: OFF"
    FreecamButton.BackgroundColor3 = Color3.fromRGB(40, 50, 65)

    if FreecamConnection then
        FreecamConnection:Disconnect()
        FreecamConnection = nil
    end

    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    camera.CameraType = Enum.CameraType.Custom
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = false end
end

-- Обработка клавиш (F - выход, Shift + P - тумблер)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode.F then
            if _G.FreecamActive then
                ExitFreecam()
            end
        elseif input.KeyCode == Enum.KeyCode.P and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            if _G.FreecamActive then ExitFreecam() else EnterFreecam() end
        end
    end
end)

-- Привязка кнопок GUI (сохранение CFrame и Anchored)
ToggleButton.MouseButton1Click:Connect(function()
    _G.CupBoxFarmActive = not _G.CupBoxFarmActive
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if _G.CupBoxFarmActive then
        ToggleButton.Text = "Farm: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        
        -- Запоминаем исходный CFrame (включая позицию и поворот взгляда!)
        if hrp then
            _G.OriginalCFrame = hrp.CFrame
            hrp.Anchored = true -- Закрепляем игрока на месте
        end
    else
        ToggleButton.Text = "Farm: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        
        -- Снимаем закрепление при отключении фарма
        if hrp then
            hrp.Anchored = false
        end
    end
end)

FreecamButton.MouseButton1Click:Connect(function()
    if _G.FreecamActive then ExitFreecam() else EnterFreecam() end
end)

-- Удаление и полная самоликвидация скрипта (очистка)
CloseButton.MouseButton1Click:Connect(function()
    _G.CupBoxFarmActive = false
    ExitFreecam()
    ScreenGui:Destroy()
end)
