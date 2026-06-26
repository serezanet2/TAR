-- [[ CUSTOM CUP & BOX FARMER SCRIPT (TMI V2.1) ]] --
-- Изменения:
--  * Blacklist по Instance ID (а не по имени) — игнорирует уже обработанные предметы
--  * Игнорирует тулы которые уже в Backpack / Character игрока
--  * Игнорирует Anchored (закрепленные) Handle / Box — это магазинные витрины
--  * Игнорирует Prompts с символом "$" в ActionText/ObjectText/Name — это магазин

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

_G.CupBoxFarmActive = false

-- Blacklist по Instance reference. Используем weak table чтоб мусорные ссылки авто-чистились.
local Blacklist = setmetatable({}, { __mode = "k" })

-- Создание GUI на стороне CoreGui (или PlayerGui для тестов в Студии)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CupBoxFarmGui"
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 170)
MainFrame.Position = UDim2.new(0.5, -110, 0.4, -85)
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
TitleLabel.Text = "Cup & Box AutoFarm V2.1"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleLabel

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 180, 0, 40)
ToggleButton.Position = UDim2.new(0.5, -90, 0.32, 0)
ToggleButton.Text = "Farm: OFF"
ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 14
ToggleButton.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

local ClearBlacklistButton = Instance.new("TextButton")
ClearBlacklistButton.Size = UDim2.new(0, 180, 0, 22)
ClearBlacklistButton.Position = UDim2.new(0.5, -90, 0.62, 0)
ClearBlacklistButton.Text = "Очистить Blacklist"
ClearBlacklistButton.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
ClearBlacklistButton.TextColor3 = Color3.fromRGB(220, 220, 220)
ClearBlacklistButton.Font = Enum.Font.Gotham
ClearBlacklistButton.TextSize = 11
ClearBlacklistButton.Parent = MainFrame

local ClearCorner = Instance.new("UICorner")
ClearCorner.CornerRadius = UDim.new(0, 4)
ClearCorner.Parent = ClearBlacklistButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 30)
StatusLabel.Position = UDim2.new(0, 0, 0.82, 0)
StatusLabel.Text = "Ожидание запуска..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Parent = MainFrame

-- ===== ХЕЛПЕРЫ ДЛЯ ПРОВЕРКИ =====

-- Проверяет, находится ли инструмент уже в инвентаре/руке игрока
local function isInPlayerInventory(tool)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character

    if backpack and tool:IsDescendantOf(backpack) then
        return true
    end
    if character and tool:IsDescendantOf(character) then
        return true
    end
    return false
end

-- Проверяет, является ли ProximityPrompt магазинным (содержит $ в полях)
local function isShopPrompt(prompt)
    local fields = { prompt.ActionText or "", prompt.ObjectText or "", prompt.Name or "" }
    for _, text in ipairs(fields) do
        if string.find(text, "%$") then
            return true
        end
    end
    return false
end

-- Проверяет, закреплен ли объект (или его Handle)
local function isAnchored(obj)
    if obj:IsA("BasePart") then
        return obj.Anchored
    end
    local handle = obj:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        return handle.Anchored
    end
    -- Альтернативно, ищем любую BasePart внутри Tool
    local anyPart = obj:FindFirstChildWhichIsA("BasePart")
    if anyPart then
        return anyPart.Anchored
    end
    return false
end

-- ===== ГЛАВНАЯ ФУНКЦИЯ ПОДБОРА =====
local function performFarm()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local originalCFrame = hrp.CFrame
    local targetFound = false

    -- 1. СКАНИРОВАНИЕ ЧАШ (Tools с Cup/cup/CUP в имени)
    for _, obj in pairs(workspace:GetDescendants()) do
        if not _G.CupBoxFarmActive then break end

        if obj:IsA("Tool") or obj:IsA("BackpackItem") then
            local name = string.lower(obj.Name)
            if string.find(name, "cup", "genesis") then
                -- (А) Игнорируем уже обработанные (по Instance ref, а не по имени)
                if Blacklist[obj] then continue end
                -- (Б) Игнорируем то, что уже в руке/рюкзаке
                if isInPlayerInventory(obj) then
                    Blacklist[obj] = true
                    continue
                end
                -- (В) Игнорируем Anchored (закрепленные = магазинные витрины)
                if isAnchored(obj) then
                    Blacklist[obj] = true
                    continue
                end

                local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                if handle and not handle.Anchored then
                    targetFound = true
                    StatusLabel.Text = "Beру чашу: " .. obj.Name
                    StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)

                    -- Запоминаем эту чашу в чёрный список (по ID Instance)
                    Blacklist[obj] = true

                    originalCFrame = hrp.CFrame

                    -- Телепорт к чаше
                    hrp.CFrame = CFrame.new(handle.Position)
                    task.wait(0.15)

                    -- Принудительная экипировка
                    pcall(function()
                        humanoid:EquipTool(obj)
                    end)

                    task.wait(0.1)
                    -- Возврат на исходную позицию
                    hrp.CFrame = originalCFrame
                    task.wait(0.25)
                    break
                end
            end
        end
    end

    -- 2. СКАНИРОВАНИЕ БОКСОВ (BasePart с "box" + ProximityPrompt)
    if not targetFound then
        for _, obj in pairs(workspace:GetDescendants()) do
            if not _G.CupBoxFarmActive then break end

            if obj:IsA("BasePart") then
                local name = string.lower(obj.Name)
                if string.find(name, "silver","box") then
                    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt then
                        -- (А) Игнор если уже в blacklist
                        if Blacklist[obj] then continue end
                        -- (Б) Игнор магазинных Prompts с символом "$"
                        if isShopPrompt(prompt) then
                            Blacklist[obj] = true
                            continue
                        end

                        targetFound = true
                        StatusLabel.Text = "Активирую бокс: " .. obj.Name
                        StatusLabel.TextColor3 = Color3.fromRGB(224, 176, 255)

                        originalCFrame = hrp.CFrame

                        -- Телепорт сверху бокса
                        hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                        task.wait(0.15)

                        -- Активация ProximityPrompt
                        pcall(function()
                            fireproximityprompt(prompt)
                        end)

                        task.wait(0.15)
                        -- Возврат на исходную позицию
                        hrp.CFrame = originalCFrame
                        task.wait(0.2)
                        break
                    end
                end
            end
        end
    end

    if not targetFound then
        StatusLabel.Text = "Сканирование... нет целей"
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end

-- ===== UI ОБРАБОТЧИКИ =====
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

ClearBlacklistButton.MouseButton1Click:Connect(function()
    Blacklist = setmetatable({}, { __mode = "k" })
    StatusLabel.Text = "Blacklist очищен!"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
end)

-- ===== ГЛАВНЫЙ ЦИКЛ =====
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.CupBoxFarmActive then
            pcall(performFarm)
        end
    end
end)
