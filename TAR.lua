-- LocalScript (Client)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Переменные состояния
local isFarming = false          -- флаг работы автофарма
local returnPosition = nil       -- точка возврата
local farmCoroutine = nil        -- ссылка на корутину цикла

-- Поиск всех ProximityPrompt внутри workspace.Cups (рекурсивно)
local function getAllPrompts()
    local prompts = {}
    local cups = workspace:FindFirstChild("Cups")
    if not cups then return prompts end

    local function search(obj)
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("ProximityPrompt") then
                table.insert(prompts, child)
            else
                search(child) -- рекурсивный обход
            end
        end
    end
    search(cups)
    return prompts
end

-- Получение позиции для телепортации к промпту
local function getTargetPosition(prompt)
    local parent = prompt.Parent
    if parent:IsA("BasePart") then
        return parent.Position
    else
        -- Ищем Handle или PrimaryPart
        local handle = parent:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            return handle.Position
        end
        local primary = parent:FindFirstChild("PrimaryPart")
        if primary and primary:IsA("BasePart") then
            return primary.Position
        end
        -- Иначе ищем любую BasePart внутри
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("BasePart") then
                return child.Position
            end
        end
    end
    return nil
end

-- Симуляция удержания промпта (с телепортацией)
local function activatePrompt(prompt)
    local targetPos = getTargetPosition(prompt)
    if not targetPos then return false end

    -- Телепортируемся к цели (с небольшим смещением вверх)
    local offset = Vector3.new(0, 3, 0)
    rootPart.CFrame = CFrame.new(targetPos + offset)
    task.wait(0.1) -- даём время на телепорт

    -- Имитация нажатия и удержания
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration) -- ждём, пока удержание завершится
    prompt:InputHoldEnd()
    return true
end

-- Основной цикл фарма
local function farmCycle()
    while isFarming do
        -- 1. Сканируем каждые 10 секунд
        local prompts = getAllPrompts()
        if #prompts > 0 then
            for _, prompt in ipairs(prompts) do
                if not isFarming then break end -- остановка при выключении

                -- Активируем промпт
                activatePrompt(prompt)

                -- Возвращаемся в исходную точку
                if returnPosition then
                    rootPart.CFrame = CFrame.new(returnPosition)
                end

                task.wait(0.1) -- пауза 0.1 сек между промптами
            end
        end

        -- Ждём 10 секунд до следующего сканирования (с возможностью прерывания)
        local elapsed = 0
        while elapsed < 10 and isFarming do
            task.wait(1)
            elapsed = elapsed + 1
        end
    end
end

-- ====== СОЗДАНИЕ GUI ======
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0.5, -100, 0.5, -50)
frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
frame.Parent = screenGui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 180, 0, 50)
button.Position = UDim2.new(0.5, -90, 0.5, -25)
button.Text = "Включить авто фарм"
button.BackgroundColor3 = Color3.new(0.3, 0.8, 0.3)
button.Parent = frame

-- Обработка нажатия на кнопку
button.MouseButton1Click:Connect(function()
    isFarming = not isFarming

    if isFarming then
        button.Text = "Выключить авто фарм"
        button.BackgroundColor3 = Color3.new(0.8, 0.3, 0.3)

        -- Запоминаем текущую позицию как точку возврата
        returnPosition = rootPart.Position

        -- Запускаем цикл в отдельной корутине
        if farmCoroutine then coroutine.close(farmCoroutine) end
        farmCoroutine = coroutine.create(farmCycle)
        coroutine.resume(farmCoroutine)
    else
        button.Text = "Включить авто фарм"
        button.BackgroundColor3 = Color3.new(0.3, 0.8, 0.3)
        -- Остановка произойдёт автоматически (флаг isFarming = false)
        farmCoroutine = nil
    end
end)
