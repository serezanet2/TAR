-- LocalScript (Client)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Vim = game:GetService("VirtualInputManager")

-- ====== ДИНАМИЧЕСКИЕ ССЫЛКИ ======
local function getChar()
    return player.Character
end

local function getRoot()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local backpack = player:WaitForChild("Backpack")

-- ====== СОСТОЯНИЯ ======
local isFarming = false
local isDropping = false
local homeCFrame = nil
local sessionHighlights = {}      -- все подсветки для целей сессии
local farmCoroutine = nil
local dropCoroutine = nil
local stopRequested = false
local isFarmBusy = false
local droppedItems = {}           -- чёрный список выброшенных предметов

-- ====== КАТЕГОРИИ И ПРИОРИТЕТЫ ======
local CATEGORIES = {
    Boxes      = { priority = 1, words = {"box"} },
    Essences   = { priority = 2, words = {"essence"} },
    Genesis    = { priority = 3, words = {"genesis"} },
    Metals     = { priority = 4, words = {"gold", "silver", "copper"} },
    OilBlood   = { priority = 5, words = {"oil", "blood"} },
}

-- Состояние включённых категорий (по умолчанию все true)
local enabledCategories = {
    Boxes    = true,
    Essences = true,
    Genesis  = true,
    Metals   = true,
    OilBlood = true,
}

-- Динамический список разрешённых слов (перестраивается при изменении настроек)
local function buildAllowedWords()
    local words = {}
    for cat, enabled in pairs(enabledCategories) do
        if enabled then
            for _, w in ipairs(CATEGORIES[cat].words) do
                table.insert(words, w)
            end
        end
    end
    return words
end

-- Текущий список целей (объекты, которые нужно собрать)
local sessionTargets = {}   -- таблица объектов (не промптов)

-- ====== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ======

local function getAllPrompts()
    local prompts = {}
    local function searchIn(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if not Players:GetPlayerFromCharacter(child) then
                if child:IsA("ProximityPrompt") then
                    table.insert(prompts, child)
                else
                    searchIn(child)
                end
            end
        end
    end
    searchIn(workspace)
    local cups = workspace:FindFirstChild("Cups")
    if cups then searchIn(cups) end
    return prompts
end

local function getParentObject(prompt)
    local parent = prompt.Parent
    while parent and parent:IsA("BasePart") do parent = parent.Parent end
    return parent
end

local function isPurchaseItem(prompt)
    if prompt.ObjectText and string.find(prompt.ObjectText, "$", 1, true) then return true end
    if prompt.ActionText and string.find(prompt.ActionText, "$", 1, true) then return true end
    return false
end

local function shouldSkipItem(prompt)
    if isPurchaseItem(prompt) then return true end
    local obj = getParentObject(prompt)
    if not obj then return true end
    if droppedItems[obj] then return true end
    -- Пропускаем цветы, чеснок, лилии, аптечки
    local lowerName = obj.Name:lower()
    if lowerName:find("bloom") or lowerName:find("garlic") or lowerName:find("lil")
       or lowerName:find("supply") or lowerName:find("medical") then
        return true
    end
    -- Проверяем по разрешённым словам (динамический список)
    local allowed = buildAllowedWords()
    for _, word in ipairs(allowed) do
        if lowerName:find(word) then return false end
    end
    return true
end

-- Функция для проверки, является ли объект целью (без учёта приоритета)
local function isTargetObject(obj)
    if not obj then return false end
    if droppedItems[obj] then return false end
    local lowerName = obj.Name:lower()
    local allowed = buildAllowedWords()
    for _, word in ipairs(allowed) do
        if lowerName:find(word) then return true end
    end
    return false
end

-- Получить приоритет объекта (число, чем меньше, тем выше)
local function getObjectPriority(obj)
    if not obj then return 999 end
    local lowerName = obj.Name:lower()
    local minPriority = 999
    for catName, data in pairs(CATEGORIES) do
        if enabledCategories[catName] then
            for _, w in ipairs(data.words) do
                if lowerName:find(w) then
                    if data.priority < minPriority then
                        minPriority = data.priority
                    end
                end
            end
        end
    end
    return minPriority
end

-- Создание подсветки для объекта
local function createHighlight(obj, useRedOutline)
    if not obj then return nil end
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("Highlight") and child.Name == "SessionHighlight" then
            child.OutlineColor = useRedOutline and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
            return child
        end
    end
    local highlight = Instance.new("Highlight")
    highlight.Name = "SessionHighlight"
    highlight.FillColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = useRedOutline and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = obj
    return highlight
end

-- Очистка всех подсветок сессии
local function clearSessionHighlights()
    for _, highlight in ipairs(sessionHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    sessionHighlights = {}
end

-- Обновить список целей и подсветку
local function updateSessionTargets()
    clearSessionHighlights()
    sessionTargets = {}
    -- Собираем все промпты, находим объекты, которые являются целями
    local allPrompts = getAllPrompts()
    local seenObjects = {}
    for _, prompt in ipairs(allPrompts) do
        if not shouldSkipItem(prompt) then
            local obj = getParentObject(prompt)
            if obj and not seenObjects[obj] then
                seenObjects[obj] = true
                if isTargetObject(obj) then
                    table.insert(sessionTargets, obj)
                    local hl = createHighlight(obj, false) -- зелёная
                    if hl then table.insert(sessionHighlights, hl) end
                end
            end
        end
    end
    -- Сортируем цели по приоритету (от меньшего числа к большему)
    table.sort(sessionTargets, function(a, b)
        return getObjectPriority(a) < getObjectPriority(b)
    end)
end

-- Получить следующую цель для активации (первую в списке, которая ещё существует и не в чёрном списке)
local function getNextTarget()
    for _, obj in ipairs(sessionTargets) do
        if obj and obj.Parent and not droppedItems[obj] then
            return obj
        end
    end
    return nil
end

-- Поиск промпта для объекта
local function findPromptForObject(obj)
    if not obj then return nil end
    for _, prompt in ipairs(getAllPrompts()) do
        if getParentObject(prompt) == obj then
            return prompt
        end
    end
    return nil
end

-- Активация промпта
local function activatePrompt(prompt)
    local root = getRoot()
    if not root then return false end
    if not prompt or not prompt.Parent then return false end
    local targetPos = nil
    local parent = prompt.Parent
    if parent:IsA("BasePart") then
        targetPos = parent.Position
    else
        local handle = parent:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then targetPos = handle.Position end
        if not targetPos then
            local primary = parent:FindFirstChild("PrimaryPart")
            if primary and primary:IsA("BasePart") then targetPos = primary.Position end
        end
        if not targetPos then
            for _, child in ipairs(parent:GetDescendants()) do
                if child:IsA("BasePart") then
                    targetPos = child.Position
                    break
                end
            end
        end
    end
    if not targetPos then return false end
    local angle = math.random() * 2 * math.pi
    local dist = math.random() * 1
    local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
    root.CFrame = CFrame.new(targetPos + offset)
    task.wait(0.5)
    local success = false
    local conn = prompt.Triggered:Connect(function() success = true end)
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration + 0.1)
    prompt:InputHoldEnd()
    task.wait(0.3)
    conn:Disconnect()
    return success
end

-- Телепорт домой (запоминаем позицию при старте)
local function teleportHome()
    local root = getRoot()
    if homeCFrame and root then
        root.CFrame = homeCFrame
    end
end

-- ====== ОСНОВНОЙ ЦИКЛ ФАРМА ======
local function farmCycle()
    while isFarming and not stopRequested do
        -- Получаем следующую цель (с учётом приоритета)
        local targetObj = getNextTarget()
        if targetObj then
            isFarmBusy = true
            local prompt = findPromptForObject(targetObj)
            if prompt and isTargetObject(targetObj) and not droppedItems[targetObj] then
                -- Временно включаем промпт
                prompt.Enabled = true
                local success = activatePrompt(prompt)
                prompt.Enabled = false
                if success then
                    -- Если предмет поднят, он исчезнет, подсветка удалится автоматически
                    -- Но мы можем убрать его из списка, чтобы не искать заново
                    -- (он уже не будет существовать, поэтому next раз его пропустит)
                else
                    -- Если не удалось, возможно, он недоступен – пропускаем
                end
            end
            isFarmBusy = false
            task.wait(0.2)
        else
            -- Нет целей – ждём появления новых
            isFarmBusy = false
            teleportHome()
            local waited = 0
            while waited < 3 and isFarming and not stopRequested do
                task.wait(0.5); waited += 0.5
            end
            -- Обновляем список целей (могли появиться новые)
            if isFarming then
                updateSessionTargets()
            end
        end
    end
    clearSessionHighlights()
    teleportHome()
    isFarmBusy = false
end

-- ====== АВТОДРОП ======
function dropCycle()
    local needPositionUpdate = true
    while isDropping do
        if isFarmBusy then
            needPositionUpdate = true
            task.wait(0.5)
        else
            teleportHome()
            if needPositionUpdate then
                local char = getChar()
                if not char then task.wait(0.5) goto continue end
                local toolsToMove = {}
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then table.insert(toolsToMove, item) end
                end
                for _, tool in ipairs(toolsToMove) do tool.Parent = char end
                task.wait(0.5)
                for _, tool in ipairs(toolsToMove) do tool.Parent = backpack end
                task.wait(0.5)
                needPositionUpdate = false
            end
            while isDropping and not isFarmBusy do
                local char = getChar()
                if not char then task.wait(0.5) break end
                local toolInHand = char:FindFirstChildOfClass("Tool")
                if toolInHand then
                    Vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
                    task.wait(0.2)
                    Vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
                    droppedItems[toolInHand] = true
                    task.wait(0.1)
                else
                    local items = {}
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then table.insert(items, item) end
                    end
                    if #items > 0 then
                        local randItem = items[math.random(1, #items)]
                        if char:FindFirstChild("Humanoid") then
                            char.Humanoid:EquipTool(randItem)
                        end
                        task.wait(0.1)
                        Vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
                        task.wait(0.2)
                        Vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
                        droppedItems[randItem] = true
                        task.wait(0.1)
                    else
                        task.wait(0.5)
                    end
                end
            end
            ::continue::
        end
    end
end

-- ====== GUI ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ====== ГЛАВНОЕ ОКНО ======
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 220, 0, 180)
mainFrame.Position = UDim2.new(0.5, -110, 0.5, -90)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 14)

local mainGradient = Instance.new("UIGradient", mainFrame)
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
})
mainGradient.Rotation = 135

-- Заголовок
local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, -100, 0, 24)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "⚡ AUTO FARM"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left

-- Кнопка настроек
local settingsButton = Instance.new("TextButton", mainFrame)
settingsButton.Size = UDim2.new(0, 30, 0, 30)
settingsButton.Position = UDim2.new(1, -105, 0, 4)
settingsButton.BackgroundColor3 = Color3.fromRGB(70, 130, 200)
settingsButton.Text = "⚙"
settingsButton.TextColor3 = Color3.new(1,1,1)
settingsButton.Font = Enum.Font.GothamBold
settingsButton.TextSize = 18
settingsButton.BorderSizePixel = 0
local settingsCorner = Instance.new("UICorner", settingsButton)
settingsCorner.CornerRadius = UDim.new(1, 0)

-- Кнопка сворачивания
local minimizeButton = Instance.new("TextButton", mainFrame)
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -70, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
minimizeButton.Text = "⤓"
minimizeButton.TextColor3 = Color3.new(1,1,1)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.BorderSizePixel = 0
local minCorner = Instance.new("UICorner", minimizeButton)
minCorner.CornerRadius = UDim.new(1, 0)

-- Кнопка закрытия
local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -34, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1,1,1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.BorderSizePixel = 0
local closeCorner = Instance.new("UICorner", closeButton)
closeCorner.CornerRadius = UDim.new(1, 0)

-- Кнопка фарма
local toggleButton = Instance.new("TextButton", mainFrame)
toggleButton.Size = UDim2.new(0, 180, 0, 34)
toggleButton.Position = UDim2.new(0.5, -90, 0, 50)
toggleButton.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
toggleButton.Text = "▶ Включить"
toggleButton.TextColor3 = Color3.new(1,1,1)
toggleButton.Font = Enum.Font.GothamSemibold
toggleButton.TextSize = 14
toggleButton.BorderSizePixel = 0
local toggleCorner = Instance.new("UICorner", toggleButton)
toggleCorner.CornerRadius = UDim.new(0, 10)

-- Кнопка дропа
local dropButton = Instance.new("TextButton", mainFrame)
dropButton.Size = UDim2.new(0, 180, 0, 34)
dropButton.Position = UDim2.new(0.5, -90, 0, 100)
dropButton.BackgroundColor3 = Color3.fromRGB(160, 110, 50)
dropButton.Text = "🗑 Auto Drop"
dropButton.TextColor3 = Color3.new(1,1,1)
dropButton.Font = Enum.Font.GothamSemibold
dropButton.TextSize = 14
dropButton.BorderSizePixel = 0
local dropCorner = Instance.new("UICorner", dropButton)
dropCorner.CornerRadius = UDim.new(0, 10)

-- Круглая кнопка TARC (для восстановления окна)
local tarcButton = Instance.new("TextButton", screenGui)
tarcButton.Name = "TarcButton"
tarcButton.Size = UDim2.new(0, 56, 0, 56)
tarcButton.Position = UDim2.new(1, -70, 0.5, -28)
tarcButton.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
tarcButton.Text = "TARC"
tarcButton.TextColor3 = Color3.new(1,1,1)
tarcButton.Font = Enum.Font.GothamBlack
tarcButton.TextSize = 18
tarcButton.BorderSizePixel = 0
tarcButton.Visible = false
local tarcCorner = Instance.new("UICorner", tarcButton)
tarcCorner.CornerRadius = UDim.new(1, 0)

-- ====== ОКНО НАСТРОЕК ======
local settingsFrame = Instance.new("Frame", screenGui)
settingsFrame.Name = "SettingsFrame"
settingsFrame.Size = UDim2.new(0, 280, 0, 240)
settingsFrame.Position = UDim2.new(0.5, -140, 0.5, -120)
settingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
settingsFrame.BackgroundTransparency = 0.1
settingsFrame.BorderSizePixel = 0
settingsFrame.ClipsDescendants = true
settingsFrame.Visible = false
local settingsCorner2 = Instance.new("UICorner", settingsFrame)
settingsCorner2.CornerRadius = UDim.new(0, 14)
local settingsGradient = Instance.new("UIGradient", settingsFrame)
settingsGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 40))
})

-- Заголовок настроек
local settingsTitle = Instance.new("TextLabel", settingsFrame)
settingsTitle.Size = UDim2.new(1, -20, 0, 30)
settingsTitle.Position = UDim2.new(0, 10, 0, 6)
settingsTitle.BackgroundTransparency = 1
settingsTitle.Text = "Настройки категорий"
settingsTitle.TextColor3 = Color3.fromRGB(255,255,255)
settingsTitle.Font = Enum.Font.GothamBold
settingsTitle.TextSize = 16
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Кнопка закрытия настроек
local closeSettingsButton = Instance.new("TextButton", settingsFrame)
closeSettingsButton.Size = UDim2.new(0, 30, 0, 30)
closeSettingsButton.Position = UDim2.new(1, -34, 0, 6)
closeSettingsButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeSettingsButton.Text = "✕"
closeSettingsButton.TextColor3 = Color3.new(1,1,1)
closeSettingsButton.Font = Enum.Font.GothamBold
closeSettingsButton.TextSize = 18
closeSettingsButton.BorderSizePixel = 0
local closeSetCorner = Instance.new("UICorner", closeSettingsButton)
closeSetCorner.CornerRadius = UDim.new(1, 0)

-- Контейнер для чекбоксов (с прокруткой, если надо)
local checkboxContainer = Instance.new("ScrollingFrame", settingsFrame)
checkboxContainer.Size = UDim2.new(1, -20, 1, -70)
checkboxContainer.Position = UDim2.new(0, 10, 0, 40)
checkboxContainer.BackgroundTransparency = 1
checkboxContainer.BorderSizePixel = 0
checkboxContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
checkboxContainer.ScrollBarThickness = 6
checkboxContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y

local categoryOrder = {"Boxes", "Essences", "Genesis", "Metals", "OilBlood"}
local displayNames = {
    Boxes = "📦 Boxes",
    Essences = "💎 Essences",
    Genesis = "✨ Genesis",
    Metals = "🥇 Metals (Gold/Silver/Copper)",
    OilBlood = "🩸 Oil / Blood"
}
local checkboxes = {}

-- Создаём чекбоксы для каждой категории
local yPos = 0
for _, cat in ipairs(categoryOrder) do
    local frameCheck = Instance.new("Frame", checkboxContainer)
    frameCheck.Size = UDim2.new(1, 0, 0, 30)
    frameCheck.Position = UDim2.new(0, 0, 0, yPos)
    frameCheck.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frameCheck)
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = displayNames[cat]
    label.TextColor3 = Color3.fromRGB(220,220,220)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left

    local check = Instance.new("ImageButton", frameCheck)
    check.Size = UDim2.new(0, 24, 0, 24)
    check.Position = UDim2.new(1, -28, 0.5, -12)
    check.BackgroundColor3 = Color3.fromRGB(60,60,80)
    check.BorderSizePixel = 0
    local checkCorner = Instance.new("UICorner", check)
    checkCorner.CornerRadius = UDim.new(0, 4)
    check.Image = "rbxassetid://3926305904" -- квадрат (можно заменить на галочку)
    check.ImageColor3 = Color3.fromRGB(100,200,100)
    check.ImageTransparency = 1  -- скрыта, пока не включено

    -- состояние
    checkboxes[cat] = { button = check, enabled = true }

    -- клик
    check.MouseButton1Click:Connect(function()
        local newState = not enabledCategories[cat]
        enabledCategories[cat] = newState
        checkboxes[cat].enabled = newState
        check.ImageTransparency = newState and 0 or 1
        -- обновляем список целей и подсветку, если фарм активен
        if isFarming then
            updateSessionTargets()
        end
    end)

    -- устанавливаем начальное состояние
    check.ImageTransparency = enabledCategories[cat] and 0 or 1

    yPos = yPos + 30
end

-- Кнопка "Применить" (можно не делать, изменения сразу применяются)
-- Но добавим для удобства кнопку закрытия
local applyButton = Instance.new("TextButton", settingsFrame)
applyButton.Size = UDim2.new(0, 120, 0, 30)
applyButton.Position = UDim2.new(0.5, -60, 1, -40)
applyButton.BackgroundColor3 = Color3.fromRGB(70, 180, 100)
applyButton.Text = "Закрыть"
applyButton.TextColor3 = Color3.new(1,1,1)
applyButton.Font = Enum.Font.GothamBold
applyButton.TextSize = 14
applyButton.BorderSizePixel = 0
local applyCorner = Instance.new("UICorner", applyButton)
applyCorner.CornerRadius = UDim.new(0, 8)
applyButton.MouseButton1Click:Connect(function()
    settingsFrame.Visible = false
end)

-- ====== АНИМАЦИИ СВОРАЧИВАНИЯ ======
local tweenInfoShow = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenInfoHide = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function hideMainPanel()
    local goal = {Position = UDim2.new(-0.5, -110, 0.5, -90)}
    local tween = TweenService:Create(mainFrame, tweenInfoHide, goal)
    tween:Play()
    tween.Completed:Connect(function()
        mainFrame.Visible = false
        tarcButton.Visible = true
        tarcButton.Size = UDim2.new(0, 0, 0, 0)
        local appear = TweenService:Create(tarcButton, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = UDim2.new(0, 56, 0, 56)})
        appear:Play()
    end)
end

local function showMainPanel()
    tarcButton.Visible = false
    mainFrame.Visible = true
    mainFrame.Position = UDim2.new(-0.5, -110, 0.5, -90)
    local goal = {Position = UDim2.new(0.5, -110, 0.5, -90)}
    local tween = TweenService:Create(mainFrame, tweenInfoShow, goal)
    tween:Play()
end

minimizeButton.MouseButton1Click:Connect(hideMainPanel)
tarcButton.MouseButton1Click:Connect(showMainPanel)

-- Кнопка настроек: показать/скрыть окно настроек
settingsButton.MouseButton1Click:Connect(function()
    settingsFrame.Visible = not settingsFrame.Visible
    if settingsFrame.Visible then
        settingsFrame.Position = UDim2.new(0.5, -140, 0.5, -120)
        local anim = TweenService:Create(settingsFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, -140, 0.5, -120)})
        anim:Play()
    end
end)

closeSettingsButton.MouseButton1Click:Connect(function()
    settingsFrame.Visible = false
end)

-- Закрытие главного окна
closeButton.MouseButton1Click:Connect(function()
    isFarming = false
    stopRequested = true
    isDropping = false
    clearSessionHighlights()
    if farmCoroutine then coroutine.close(farmCoroutine); farmCoroutine = nil end
    if dropCoroutine then coroutine.close(dropCoroutine); dropCoroutine = nil end
    isFarmBusy = false
    teleportHome()
    screenGui:Destroy()
end)

-- ====== ОБРАБОТЧИКИ КНОПОК ФАРМА И ДРОПА ======

toggleButton.MouseButton1Click:Connect(function()
    if not isFarming then
        local root = getRoot()
        if not root then return end
        homeCFrame = root.CFrame
        -- Запоминаем начальные настройки промптов (не трогаем их постоянно)
        -- (мы их будем включать только для выбранного)
        isFarming = true
        stopRequested = false
        toggleButton.Text = "⏹ Остановить"
        toggleButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        -- Обновляем список целей и подсветку
        updateSessionTargets()
        if farmCoroutine then coroutine.close(farmCoroutine) end
        farmCoroutine = coroutine.create(farmCycle)
        coroutine.resume(farmCoroutine)
    else
        isFarming = false
        stopRequested = true
        clearSessionHighlights()
        if farmCoroutine then
            coroutine.close(farmCoroutine)
            farmCoroutine = nil
        end
        isFarmBusy = false
        teleportHome()
        toggleButton.Text = "▶ Включить"
        toggleButton.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
    end
end)

dropButton.MouseButton1Click:Connect(function()
    if not isDropping then
        isDropping = true
        dropButton.Text = "⏹ Stop Drop"
        dropButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
        if dropCoroutine then coroutine.close(dropCoroutine) end
        dropCoroutine = coroutine.create(dropCycle)
        coroutine.resume(dropCoroutine)
    else
        isDropping = false
        if dropCoroutine then coroutine.close(dropCoroutine); dropCoroutine = nil end
        dropButton.Text = "🗑 Auto Drop"
        dropButton.BackgroundColor3 = Color3.fromRGB(160, 110, 50)
    end
end)

-- Перетаскивание окон
mainFrame.Active = true
mainFrame.Draggable = true
settingsFrame.Active = true
settingsFrame.Draggable = true

-- Обновляем подсветку при старте (если фарм уже включён, но окно только что создано)
-- (можно вызвать в конце)
