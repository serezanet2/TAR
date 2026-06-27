-- LocalScript (Client11111111111111)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Состояния
local isFarming = false
local returnPosition = nil
local currentHighlights = {}
local farmCoroutine = nil
local stopRequested = false
local restartRequested = false

-- Разрешённые ключевые слова
local ALLOWED_WORDS = {"box", "cup", "genesis", "silver", "gold", "copper"}

-- Для восстановления исходного Enabled у промптов
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

local function shouldSkipItem(prompt)
    local obj = getParentObject(prompt)
    if not obj then return true end
    local lowerName = obj.Name:lower()

    if lowerName:find("blood") or lowerName:find("garlic") or lowerName:find("oil") then
        return true
    end

    for _, word in ipairs(ALLOWED_WORDS) do
        if lowerName:find(word) then
            return false
        end
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

-- Проверка, существует ли ещё промпт и его объект
local function isPromptValid(prompt)
    if not prompt or not prompt.Parent then return false end
    return getParentObject(prompt) ~= nil
end

-- Активация промпта с боковым смещением
local function activatePrompt(prompt)
    if not isPromptValid(prompt) then return false end

    local targetPos = getTargetPosition(prompt)
    if not targetPos then return false end

    -- Смещение в случайную сторону по XZ на расстояние до 1 блока
    local angle = math.random() * 2 * math.pi
    local dist = math.random() * 1
    local xOff = math.cos(angle) * dist
    local zOff = math.sin(angle) * dist
    local offset = Vector3.new(xOff, 0, zOff)

    rootPart.CFrame = CFrame.new(targetPos + offset)
    task.wait(0.1)

    prompt:InputHoldBegin()
    local holdTime = prompt.HoldDuration + 0.1
    task.wait(holdTime)
    prompt:InputHoldEnd()
    return true
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
    for prompt, originalState in pairs(originalEnabledStates) do
        if prompt and prompt.Parent then
            prompt.Enabled = originalState
        end
    end
    originalEnabledStates = {}
end

-- ====== ОСНОВНОЙ ЦИКЛ ======

local function farmCycle()
    while isFarming and not stopRequested do
        rootPart.Anchored = false

        -- Новое сканирование
        local allPrompts = getAllPrompts()
        disableUnwantedPrompts(allPrompts)

        -- Отбор разрешённых
        local validPrompts = {}
        for _, prompt in ipairs(allPrompts) do
            if not shouldSkipItem(prompt) then
                table.insert(validPrompts, prompt)
            end
        end

        -- Разделяем на боксы и остальное
        local boxPrompts = {}
        local otherPrompts = {}
        for _, prompt in ipairs(validPrompts) do
            if isBox(prompt) then
                table.insert(boxPrompts, prompt)
            else
                table.insert(otherPrompts, prompt)
            end
        end

        -- Порядок: сначала боксы, потом остальные
        local sortedPrompts = {}
        for _, v in ipairs(boxPrompts) do table.insert(sortedPrompts, v) end
        for _, v in ipairs(otherPrompts) do table.insert(sortedPrompts, v) end

        if #sortedPrompts > 0 then
            clearHighlights()
            for _, prompt in ipairs(sortedPrompts) do
                local obj = getParentObject(prompt)
                if obj then
                    local useRed = isBox(prompt)
                    local hl = createHighlight(obj, useRed)
                    if hl then table.insert(currentHighlights, hl) end
                end
            end

            for _, prompt in ipairs(sortedPrompts) do
                if not isFarming or stopRequested then break end
                -- Проверяем, не пропал ли предмет перед активацией
                if isPromptValid(prompt) then
                    activatePrompt(prompt)
                end
                if returnPosition and rootPart then
                    rootPart.CFrame = CFrame.new(returnPosition)
                end
                task.wait(0.1)
            end

            clearHighlights()
            task.wait(0.2)
            rootPart.Anchored = true
        else
            rootPart.Anchored = true
        end

        -- Пауза между проходами (прерывается при запросе перезапуска)
        local waited = 0
        while waited < 5 and isFarming and not stopRequested do
            if restartRequested then
                restartRequested = false
                break  -- выходим из паузы, начнём новый цикл сканирования
            end
            task.wait(0.5)
            waited = waited + 0.5
        end
    end

    clearHighlights()
    rootPart.Anchored = false
end

-- ====== ТАЙМЕР АВТОРЕСТАРТА ======

local restartTimerCoroutine
local function startRestartTimer()
    if restartTimerCoroutine then coroutine.close(restartTimerCoroutine) end
    restartTimerCoroutine = coroutine.create(function()
        while isFarming do
            task.wait(5)
            if isFarming then
                restartRequested = true
            end
        end
    end)
    coroutine.resume(restartTimerCoroutine)
end

-- ====== GUI ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 160)
frame.Position = UDim2.new(0.5, -140, 0.5, -80)
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
toggleButton.Position = UDim2.new(0.5, -100, 0.5, -20)
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

-- ====== ОБРАБОТЧИКИ ======
toggleButton.MouseButton1Click:Connect(function()
    if not isFarming then
        -- Запоминаем исходное состояние всех промптов
        local initialPrompts = getAllPrompts()
        originalEnabledStates = {}
        for _, prompt in ipairs(initialPrompts) do
            originalEnabledStates[prompt] = prompt.Enabled
        end

        isFarming = true
        stopRequested = false
        restartRequested = false
        toggleButton.Text = "⏹ Остановить"
        toggleButton.BackgroundColor3 = Color3.new(0.6, 0.2, 0.2)
        returnPosition = rootPart.Position

        startRestartTimer()  -- запускаем таймер авторестарта

        if farmCoroutine then coroutine.close(farmCoroutine) end
        farmCoroutine = coroutine.create(farmCycle)
        coroutine.resume(farmCoroutine)
    else
        isFarming = false
        stopRequested = true
        clearHighlights()
        if rootPart then
            rootPart.Anchored = false
        end
        if farmCoroutine then
            coroutine.close(farmCoroutine)
            farmCoroutine = nil
        end
        if restartTimerCoroutine then
            coroutine.close(restartTimerCoroutine)
            restartTimerCoroutine = nil
        end
        restorePromptsEnabled()
        toggleButton.Text = "▶ Включить"
        toggleButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    isFarming = false
    stopRequested = true
    clearHighlights()
    if rootPart then
        rootPart.Anchored = false
    end
    if farmCoroutine then
        coroutine.close(farmCoroutine)
        farmCoroutine = nil
    end
    if restartTimerCoroutine then
        coroutine.close(restartTimerCoroutine)
        restartTimerCoroutine = nil
    end
    restorePromptsEnabled()
    screenGui:Destroy()
end)

frame.Active = true
frame.Draggable = true
