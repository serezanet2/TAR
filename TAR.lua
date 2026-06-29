-- LocalScript (Client)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-- Динамические ссылки (работают после респавна)
local function getChar()
    return player.Character
end

local function getRoot()
    local char = getChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local backpack = player:WaitForChild("Backpack")

-- Состояния
local isFarming = false
local isDropping = false
local homeCFrame = nil
local currentHighlights = {}
local farmCoroutine = nil
local dropCoroutine = nil
local stopRequested = false
local isFarmBusy = false

-- Чёрный список выброшенных предметов
local droppedItems = {}

-- Разрешённые ключевые слова
local ALLOWED_WORDS = {"box", "cup", "genesis", "silver", "gold", "copper", "essence"}

-- Для восстановления исходного Enabled
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
    local lowerName = obj.Name:lower()
    if lowerName:find("blood") or lowerName:find("garlic") or lowerName:find("oil")
       or lowerName:find("supply") or lowerName:find("medical") then
        return true
    end
    for _, word in ipairs(ALLOWED_WORDS) do
        if lowerName:find(word) then return false end
    end
    return true
end

local function isBox(prompt)
    local obj = getParentObject(prompt)
    return obj and obj.Name:lower():find("box") ~= nil
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
        if highlight and highlight.Parent then highlight:Destroy() end
    end
    currentHighlights = {}
end

local function getTargetPosition(prompt)
    local parent = prompt.Parent
    if parent:IsA("BasePart") then return parent.Position end
    local handle = parent:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle.Position end
    local primary = parent:FindFirstChild("PrimaryPart")
    if primary and primary:IsA("BasePart") then return primary.Position end
    for _, child in ipairs(parent:GetDescendants()) do
        if child:IsA("BasePart") then return child.Position end
    end
    return nil
end

local function isPromptValid(prompt)
    return prompt and prompt.Parent and getParentObject(prompt) ~= nil
end

-- Теперь всегда использует актуальный корень
local function teleportHome()
    local root = getRoot()
    if homeCFrame and root then
        root.CFrame = homeCFrame
    end
end

-- ====== АКТИВАЦИЯ ПРОМПТА С ПРОВЕРКОЙ ======
local function activatePrompt(prompt)
    local root = getRoot()
    if not root then return false end
    if not isPromptValid(prompt) then return false end
    local targetPos = getTargetPosition(prompt)
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

local function restorePromptsEnabled()
    local currentPrompts = getAllPrompts()
    for _, prompt in ipairs(currentPrompts) do
        local orig = originalEnabledStates[prompt]
        prompt.Enabled = orig ~= nil and orig or true
    end
    originalEnabledStates = {}
end

-- ====== GUI ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Главное окно (компактное)
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 200, 0, 160)
frame.Position = UDim2.new(0.5, -100, 0.5, -80)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = frame

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
})
mainGradient.Rotation = 135
mainGradient.Parent = frame

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 24)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "AUTO FARM"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

-- Кнопка сворачивания
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -70, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
minimizeButton.Text = "⤓"
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.BorderSizePixel = 0
minimizeButton.Parent = frame
local minCorner = Instance.new("UICorner", minimizeButton)
minCorner.CornerRadius = UDim.new(1, 0)

-- Кнопка закрытия
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -34, 0, 4)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.BorderSizePixel = 0
closeButton.Parent = frame
local closeCorner = Instance.new("UICorner", closeButton)
closeCorner.CornerRadius = UDim.new(1, 0)

-- Кнопка фарма
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 160, 0, 34)
toggleButton.Position = UDim2.new(0.5, -80, 0, 50)
toggleButton.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
toggleButton.Text = "▶ Включить"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.GothamSemibold
toggleButton.TextSize = 14
toggleButton.BorderSizePixel = 0
toggleButton.Parent = frame
local toggleCorner = Instance.new("UICorner", toggleButton)
toggleCorner.CornerRadius = UDim.new(0, 10)

-- Кнопка дропа
local dropButton = Instance.new("TextButton")
dropButton.Size = UDim2.new(0, 160, 0, 34)
dropButton.Position = UDim2.new(0.5, -80, 0, 100)
dropButton.BackgroundColor3 = Color3.fromRGB(160, 110, 50)
dropButton.Text = "🗑 Auto Drop"
dropButton.TextColor3 = Color3.new(1, 1, 1)
dropButton.Font = Enum.Font.GothamSemibold
dropButton.TextSize = 14
dropButton.BorderSizePixel = 0
dropButton.Parent = frame
local dropCorner = Instance.new("UICorner", dropButton)
dropCorner.CornerRadius = UDim.new(0, 10)

-- Круглая кнопка TARC
local tarcButton = Instance.new("TextButton")
tarcButton.Name = "TarcButton"
tarcButton.Size = UDim2.new(0, 56, 0, 56)
tarcButton.Position = UDim2.new(1, -70, 0.5, -28)
tarcButton.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
tarcButton.Text = "TARC"
tarcButton.TextColor3 = Color3.new(1, 1, 1)
tarcButton.Font = Enum.Font.GothamBlack
tarcButton.TextSize = 18
tarcButton.BorderSizePixel = 0
tarcButton.Visible = false
tarcButton.Parent = screenGui
local tarcCorner = Instance.new("UICorner", tarcButton)
tarcCorner.CornerRadius = UDim.new(1, 0)

-- Анимации сворачивания
local tweenInfoShow = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenInfoHide = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function hideMainPanel()
    local goal = {Position = UDim2.new(-0.5, -100, 0.5, -80)}
    local tween = TweenService:Create(frame, tweenInfoHide, goal)
    tween:Play()
    tween.Completed:Connect(function()
        frame.Visible = false
        tarcButton.Visible = true
        tarcButton.Size = UDim2.new(0, 0, 0, 0)
        local appear = TweenService:Create(tarcButton, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = UDim2.new(0, 56, 0, 56)})
        appear:Play()
    end)
end

local function showMainPanel()
    tarcButton.Visible = false
    frame.Visible = true
    frame.Position = UDim2.new(-0.5, -100, 0.5, -80)
    local goal = {Position = UDim2.new(0.5, -100, 0.5, -80)}
    local tween = TweenService:Create(frame, tweenInfoShow, goal)
    tween:Play()
end

minimizeButton.MouseButton1Click:Connect(hideMainPanel)
tarcButton.MouseButton1Click:Connect(showMainPanel)

closeButton.MouseButton1Click:Connect(function()
    isFarming = false
    stopRequested = true
    isDropping = false
    clearHighlights()
    if farmCoroutine then coroutine.close(farmCoroutine); farmCoroutine = nil end
    if dropCoroutine then coroutine.close(dropCoroutine); dropCoroutine = nil end
    isFarmBusy = false
    restorePromptsEnabled()
    teleportHome()
    screenGui:Destroy()
end)

-- ====== ФАРМ ЦИКЛ ======
local function farmCycle()
    while isFarming and not stopRequested do
        local allPrompts = getAllPrompts()
        for _, prompt in ipairs(allPrompts) do prompt.Enabled = false end

        local validPrompts = {}
        for _, prompt in ipairs(allPrompts) do
            if not shouldSkipItem(prompt) then table.insert(validPrompts, prompt) end
        end

        if #validPrompts > 0 then
            local targetPrompt = validPrompts[math.random(1, #validPrompts)]
            isFarmBusy = true
            clearHighlights()
            local obj = getParentObject(targetPrompt)
            if obj then
                local hl = createHighlight(obj, isBox(targetPrompt))
                if hl then table.insert(currentHighlights, hl) end
            end
            targetPrompt.Enabled = true
            if isPromptValid(targetPrompt) then activatePrompt(targetPrompt) end
            targetPrompt.Enabled = false
            clearHighlights()
            isFarmBusy = false
            task.wait(0.1)
        else
            isFarmBusy = false
            teleportHome()
            local waited = 0
            while waited < 5 and isFarming and not stopRequested do
                task.wait(0.5); waited += 0.5
            end
        end
    end
    clearHighlights()
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
                if not char then task.wait(0.5); continue end
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
                if not char then task.wait(0.5); break end
                local toolInHand = char:FindFirstChildOfClass("Tool")
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
                        if item:IsA("Tool") then table.insert(items, item) end
                    end
                    if #items > 0 then
                        local randItem = items[math.random(1, #items)]
                        if char:FindFirstChild("Humanoid") then
                            char.Humanoid:EquipTool(randItem)
                        end
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
        local root = getRoot()
        if not root then return end
        homeCFrame = root.CFrame
        local initialPrompts = getAllPrompts()
        for _, prompt in ipairs(initialPrompts) do
            originalEnabledStates[prompt] = prompt.Enabled
        end
        isFarming = true
        stopRequested = false
        toggleButton.Text = "⏹ Остановить"
        toggleButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
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
        -- 👇 Сброс флага, чтобы автодроп мог работать
        isFarmBusy = false
        restorePromptsEnabled()
        teleportHome()
        toggleButton.Text = "▶ Включить"
        toggleButton.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
        -- (опционально) Автоматически запустить дроп:
        -- if not isDropping then
        --     isDropping = true
        --     dropButton.Text = "⏹ Stop Drop"
        --     dropButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
        --     if dropCoroutine then coroutine.close(dropCoroutine) end
        --     dropCoroutine = coroutine.create(dropCycle)
        --     coroutine.resume(dropCoroutine)
        -- end
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

frame.Active = true
frame.Draggable = true
