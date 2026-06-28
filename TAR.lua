-- LocalScript (Client)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local backpack = player:WaitForChild("Backpack")

-- Состояния
local isFarming = false
local isDropping = false
local homeCFrame = nil
local currentHighlights = {}
local farmCoroutine = nil
local dropCoroutine = nil
local stopRequested = false

-- Новый флаг: true только во время активного сбора предметов
local isFarmBusy = false

-- Чёрный список выброшенных предметов (инстансы Tools)
local droppedItems = {}

-- Разрешённые ключевые слова
local ALLOWED_WORDS = {"box", "cup", "genesis", "silver", "gold", "copper", "essence"}

-- Для восстановления оригинального Enabled у мусорных промптов
local originalEnabledStates = {}

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
    if cups then
        searchIn(cups)
    end
    return prompts
end

local function getParentObject(prompt)
    local parent = prompt.Parent
    while parent and parent:IsA("BasePart") do
        parent = parent.Parent
    end
    return parent
end

local function isPurchaseItem(prompt)
    if prompt.ObjectText and string.find(prompt.ObjectText, "$", 1, true) then
        return true
    end
    if prompt.ActionText and string.find(prompt.ActionText, "$", 1, true) then
        return true
    end
    return false
end

local function shouldSkipItem(prompt)
    if isPurchaseItem(prompt) then return true end

    local obj = getParentObject(prompt)
    if not obj then return true end
    if droppedItems[obj] then return true end

    local lowerName = obj.Name:lower()
    if lowerName:find("blood") or lowerName:find("garlic") or lowerName:find("oil") then
        return true
    end
    for _, word in ipairs(ALLOWED_WORDS) do
        if lowerName:find(word) then return false end
    end
    return true
end

local function isBox(prompt)
    local obj = getParentObject(prompt)
    if not obj then return false end
    return obj.Name:lower():find("box") ~= nil
end

local function createHighlight(obj, useRedOutline)
    if not obj then return nil end
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("Highlight") and child.Name == "FarmHighlight" then
            child.OutlineColor = useRedOutline and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
            return child
        end
    end
    local highlight = Instance.new("Highlight")
    highlight.Name = "FarmHighlight"
    highlight.FillColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = useRedOutline and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = obj
    return highlight
end

local function clearHighlights()
    for _, highlight in ipairs(currentHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    currentHighlights = {}
end

local function getTargetPosition(prompt)
    local parent = prompt.Parent
    if parent:IsA("BasePart") then
        return parent.Position
    else
        local handle = parent:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            return handle.Position
        end
        local primary = parent:FindFirstChild("PrimaryPart")
        if primary and primary:IsA("BasePart") then
            return primary.Position
        end
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("BasePart") then
                return child.Position
            end
        end
    end
    return nil
end

local function isPromptValid(prompt)
    if not prompt or not prompt.Parent then return false end
    return getParentObject(prompt) ~= nil
end

local function teleportHome()
    if homeCFrame and rootPart then
        rootPart.CFrame = homeCFrame
    end
end

-- ====== ФУНКЦИЯ АКТИВАЦИИ С ПРОВЕРКОЙ Triggered ======
local function activatePrompt(prompt)
    if not isPromptValid(prompt) then return false end

    local targetPos = getTargetPosition(prompt)
    if not targetPos then return false end

    local angle = math.random() * 2 * math.pi
    local dist = math.random() * 1
    local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

    rootPart.CFrame = CFrame.new(targetPos + offset)
    task.wait(0.5)

    local success = false
    local conn
    conn = prompt.Triggered:Connect(function()
        success = true
    end)

    prompt:InputHoldBegin()
    local holdTime = prompt.HoldDuration + 0.1
    task.wait(holdTime)
    prompt:InputHoldEnd()
    task.wait(0.3)

    conn:Disconnect()
    return success
end

local function disableUnwantedPrompts(allPrompts)
    for _, prompt in ipairs(allPrompts) do
        if originalEnabledStates[prompt] == nil then
            originalEnabledStates[prompt] = prompt.Enabled
        end
        if shouldSkipItem(prompt) then
            prompt.Enabled = false
        end
    end
end

local function restorePromptsEnabled()
    local currentPrompts = getAllPrompts()
    for _, prompt in ipairs(currentPrompts) do
        local orig = originalEnabledStates[prompt]
        if orig ~= nil then
            prompt.Enabled = orig
        else
            prompt.Enabled = true
        end
    end
    originalEnabledStates = {}
end

-- ====== GUI ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 200)
frame.Position = UDim2.new(0.5, -140, 0.5, -100)
frame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = screenGui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.1, 0.2, 0.4)),
    ColorSequenceKeypoint.new(1, Color3.new(0.2, 0.1, 0.3))
})
gradient.Rotation = 45
gradient.Parent = frame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 5)
title.BackgroundTransparency = 1
title.Text = "🔹 AUTO FARM 🔹"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 200, 0, 40)
toggleButton.Position = UDim2.new(0.5, -100, 0, 50)
toggleButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
toggleButton.Text = "▶ Включить"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.GothamSemibold
toggleButton.BorderSizePixel = 0
toggleButton.Parent = frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = toggleButton

local dropButton = Instance.new("TextButton")
dropButton.Size = UDim2.new(0, 200, 0, 40)
dropButton.Position = UDim2.new(0.5, -100, 0, 100)
dropButton.BackgroundColor3 = Color3.new(0.6, 0.4, 0.2)
dropButton.Text = "🗑 Auto Drop"
dropButton.TextColor3 = Color3.new(1, 1, 1)
dropButton.TextScaled = true
dropButton.Font = Enum.Font.GothamSemibold
dropButton.BorderSizePixel = 0
dropButton.Parent = frame

local dropCorner = Instance.new("UICorner")
dropCorner.CornerRadius = UDim.new(0, 8)
dropCorner.Parent = dropButton

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 5)
closeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.GothamBold
closeButton.BorderSizePixel = 0
closeButton.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- ====== ОСНОВНОЙ ЦИКЛ ФАРМА (С АВТОВОЗВРАТОМ НА БАЗУ ПОСЛЕ СБОРА) ======
local function farmCycle()
    while isFarming and not stopRequested do
        local allPrompts = getAllPrompts()
        disableUnwantedPrompts(allPrompts)

        local validPrompts = {}
        for _, prompt in ipairs(allPrompts) do
            if not shouldSkipItem(prompt) then
                table.insert(validPrompts, prompt)
            end
        end

        local boxPrompts, otherPrompts = {}, {}
        for _, prompt in ipairs(validPrompts) do
            if isBox(prompt) then
                table.insert(boxPrompts, prompt)
            else
                table.insert(otherPrompts, prompt)
            end
        end
        local sortedPrompts = {}
        for _, v in ipairs(boxPrompts) do table.insert(sortedPrompts, v) end
        for _, v in ipairs(otherPrompts) do table.insert(sortedPrompts, v) end

        if #sortedPrompts > 0 then
            -- НАЧИНАЕМ АКТИВНЫЙ СБОР
            isFarmBusy = true

            clearHighlights()
            for _, prompt in ipairs(sortedPrompts) do
                local obj = getParentObject(prompt)
                if obj then
                    local hl = createHighlight(obj, isBox(prompt))
                    if hl then table.insert(currentHighlights, hl) end
                end
            end

            for _, prompt in ipairs(sortedPrompts) do
                if not isFarming or stopRequested then break end
                if isPromptValid(prompt) then
                    activatePrompt(prompt)
                end
                task.wait(0.2)
            end

            clearHighlights()

            -- ВОЗВРАЩАЕМСЯ ДОМОЙ ПОСЛЕ СБОРА
            teleportHome()
            -- ЗАВЕРШИЛИ АКТИВНУЮ ФАЗУ
            isFarmBusy = false
        else
            -- Если предметов нет, фарм точно не занят
            isFarmBusy = false
        end

        -- Ждём 5 секунд перед следующим сканированием (уже на точке home)
        local waited = 0
        while waited < 5 and isFarming and not stopRequested do
            task.wait(0.5)
            waited = waited + 0.5
        end
    end

    clearHighlights()
    teleportHome()
    isFarmBusy = false  -- на случай, если вышли из цикла во время сбора
end

-- ====== ЦИКЛ АВТОДРОПА (С ПЕРЕМЕЩЕНИЕМ ПРЕДМЕТОВ В CHARACTER ДЛЯ ПРИВЯЗКИ К HOME) ======
function dropCycle()
    local needPositionUpdate = true

    while isDropping do
        -- Пропускаем дроп, только когда фарм РЕАЛЬНО в движении (собирает предметы)
        if isFarmBusy then
            needPositionUpdate = true   -- после окончания busy-режима обновим позиции предметов
            task.wait(0.5)
        else
            -- Шаг 1: телепорт на home (на всякий случай, если вдруг не там)
            teleportHome()

            -- Шаг 2: одноразовое перемещение всех предметов в character и обратно для обновления позиций
            if needPositionUpdate then
                local toolsToMove = {}
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then
                        table.insert(toolsToMove, item)
                    end
                end
                for _, tool in ipairs(toolsToMove) do
                    tool.Parent = character
                end
                task.wait(0.5)

                for _, tool in ipairs(toolsToMove) do
                    tool.Parent = backpack
                end
                task.wait(0.5)

                needPositionUpdate = false
            end

            -- Шаг 3: быстрый циклический выброс
            while isDropping and not isFarmBusy do
                local toolInHand = character:FindFirstChildOfClass("Tool")
                local vim = game:GetService("VirtualInputManager")

                if toolInHand then
                    vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
                    task.wait(0.2)
                    vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
                    droppedItems[toolInHand] = true
                    task.wait(0.1)
                else
                    local items = {}
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            table.insert(items, item)
                        end
                    end

                    if #items > 0 then
                        local randItem = items[math.random(1, #items)]
                        character.Humanoid:EquipTool(randItem)
                        task.wait(0.1)

                        vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
                        task.wait(0.2)
                        vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
                        droppedItems[randItem] = true
                        task.wait(0.1)
                    else
                        task.wait(0.5)
                    end
                end
            end
        end
    end
end

-- ====== ОБРАБОТЧИКИ КНОПОК ======
toggleButton.MouseButton1Click:Connect(function()
    if not isFarming then
        homeCFrame = rootPart.CFrame

        local initialPrompts = getAllPrompts()
        originalEnabledStates = {}
        for _, prompt in ipairs(initialPrompts) do
            originalEnabledStates[prompt] = prompt.Enabled
        end

        isFarming = true
        stopRequested = false
        toggleButton.Text = "⏹ Остановить"
        toggleButton.BackgroundColor3 = Color3.new(0.6, 0.2, 0.2)

        if farmCoroutine then coroutine.close(farmCoroutine) end
        farmCoroutine = coroutine.create(farmCycle)
        coroutine.resume(farmCoroutine)
    else
        isFarming = false
        stopRequested = true
        clearHighlights()
        if farmCoroutine then
            coroutine.close(farmCoroutine)
            farmCoroutine = nil
        end
        restorePromptsEnabled()
        teleportHome()

        toggleButton.Text = "▶ Включить"
        toggleButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
    end
end)

dropButton.MouseButton1Click:Connect(function()
    if not isDropping then
        isDropping = true
        dropButton.Text = "⏹ Stop Drop"
        dropButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)

        if dropCoroutine then coroutine.close(dropCoroutine) end
        dropCoroutine = coroutine.create(dropCycle)
        coroutine.resume(dropCoroutine)
    else
        isDropping = false
        if dropCoroutine then
            coroutine.close(dropCoroutine)
            dropCoroutine = nil
        end
        dropButton.Text = "🗑 Auto Drop"
        dropButton.BackgroundColor3 = Color3.new(0.6, 0.4, 0.2)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    isFarming = false
    stopRequested = true
    isDropping = false

    clearHighlights()
    if farmCoroutine then
        coroutine.close(farmCoroutine)
        farmCoroutine = nil
    end
    if dropCoroutine then
        coroutine.close(dropCoroutine)
        dropCoroutine = nil
    end
    restorePromptsEnabled()
    teleportHome()
    screenGui:Destroy()
end)

frame.Active = true
frame.Draggable = true
