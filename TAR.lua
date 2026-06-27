-- LocalScript (Client)
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

-- ====== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ======

local function getAllPrompts()
    local prompts = {}
    local cups = workspace:FindFirstChild("Cups")
    if not cups then return prompts end

    local function search(obj)
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("ProximityPrompt") then
                table.insert(prompts, child)
            else
                search(child)
            end
        end
    end
    search(cups)
    return prompts
end

local function getParentObject(prompt)
    local parent = prompt.Parent
    while parent and parent:IsA("BasePart") do
        parent = parent.Parent
    end
    return parent
end

local function createHighlight(obj)
    if not obj then return nil end
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("Highlight") and child.Name == "FarmHighlight" then
            return child
        end
    end
    local highlight = Instance.new("Highlight")
    highlight.Name = "FarmHighlight"
    highlight.FillColor = Color3.new(0, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.new(0, 1, 0)
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

local function activatePrompt(prompt)
    local targetPos = getTargetPosition(prompt)
    if not targetPos then return false end

    local offset = Vector3.new(0, 3, 0)
    rootPart.CFrame = CFrame.new(targetPos + offset)
    task.wait(0.1)

    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration)
    prompt:InputHoldEnd()
    return true
end

-- ====== ОСНОВНОЙ ЦИКЛ ======

local function farmCycle()
    while isFarming and not stopRequested do
        rootPart.Anchored = false

        local prompts = getAllPrompts()
        if #prompts > 0 then
            clearHighlights()
            for _, prompt in ipairs(prompts) do
                local obj = getParentObject(prompt)
                if obj then
                    local hl = createHighlight(obj)
                    if hl then table.insert(currentHighlights, hl) end
                end
            end

            for _, prompt in ipairs(prompts) do
                if not isFarming or stopRequested then break end
                activatePrompt(prompt)
                if returnPosition then
                    rootPart.CFrame = CFrame.new(returnPosition)
                end
                task.wait(0.1)
            end

            clearHighlights()
            task.wait(0.2)
            rootPart.Anchored = true   -- закрепляем на время ожидания между сессиями
        else
            rootPart.Anchored = true
        end

        local elapsed = 0
        while elapsed < 5 and isFarming and not stopRequested do
            task.wait(1)
            elapsed = elapsed + 1
        end
    end

    -- Когда цикл завершается (например, при остановке) — делаем персонажа свободным
    clearHighlights()
    rootPart.Anchored = false   -- <--- теперь false, чтобы можно было ходить
end

-- ====== СОЗДАНИЕ GUI ======

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

-- ====== ОБРАБОТЧИКИ КНОПОК ======

toggleButton.MouseButton1Click:Connect(function()
    if not isFarming then
        -- Включение
        isFarming = true
        stopRequested = false
        toggleButton.Text = "⏹ Остановить"
        toggleButton.BackgroundColor3 = Color3.new(0.6, 0.2, 0.2)
        returnPosition = rootPart.Position

        if farmCoroutine then coroutine.close(farmCoroutine) end
        farmCoroutine = coroutine.create(farmCycle)
        coroutine.resume(farmCoroutine)
    else
        -- Выключение – персонаж остаётся НЕзакреплённым
        isFarming = false
        stopRequested = true

        -- Убираем Highlight
        clearHighlights()

        -- Делаем rootPart свободным (false)
        rootPart.Anchored = false   -- <--- теперь false

        -- Принудительно завершаем корутину
        if farmCoroutine then
            coroutine.close(farmCoroutine)
            farmCoroutine = nil
        end

        toggleButton.Text = "▶ Включить"
        toggleButton.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    isFarming = false
    stopRequested = true
    clearHighlights()
    if rootPart then
        rootPart.Anchored = false   -- <--- теперь false
    end
    if farmCoroutine then
        coroutine.close(farmCoroutine)
        farmCoroutine = nil
    end
    screenGui:Destroy()
end)

frame.Active = true
frame.Draggable = true
