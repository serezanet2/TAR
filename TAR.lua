-- LocalScript (Client)-----------------------------
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
local sessionHighlights = {}
local farmCoroutine = nil
local dropCoroutine = nil
local stopRequested = false
local isFarmBusy = false
local droppedItems = {}

-- ====== КАТЕГОРИИ И ПРИОРИТЕТЫ ======
local CATEGORIES = {
    Boxes      = { priority = 1, words = {"box"} },
    Essences   = { priority = 2, words = {"essence"} },
    Genesis    = { priority = 3, words = {"genesis"} },
    Metals     = { priority = 4, words = {"gold", "silver", "copper"} },
    OilBlood   = { priority = 5, words = {"oil", "blood"} },
}

local enabledCategories = {
    Boxes    = true,
    Essences = true,
    Genesis  = true,
    Metals   = true,
    OilBlood = true,
}

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

local sessionTargets = {}

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
    if lowerName:find("bloom") or lowerName:find("garlic") or lowerName:find("lil")
       or lowerName:find("supply") or lowerName:find("medical") then
        return true
    end
    local allowed = buildAllowedWords()
    for _, word in ipairs(allowed) do
        if lowerName:find(word) then return false end
    end
    return true
end

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

local function clearSessionHighlights()
    for _, highlight in ipairs(sessionHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    sessionHighlights = {}
end

local function updateSessionTargets()
    clearSessionHighlights()
    sessionTargets = {}
    local allPrompts = getAllPrompts()
    local seenObjects = {}
    for _, prompt in ipairs(allPrompts) do
        if not shouldSkipItem(prompt) then
            local obj = getParentObject(prompt)
            if obj and not seenObjects[obj] then
                seenObjects[obj] = true
                if isTargetObject(obj) then
                    table.insert(sessionTargets, obj)
                    local hl = createHighlight(obj, false)
                    if hl then table.insert(sessionHighlights, hl) end
                end
            end
        end
    end
    table.sort(sessionTargets, function(a, b)
        return getObjectPriority(a) < getObjectPriority(b)
    end)
end

local function getNextTarget()
    for _, obj in ipairs(sessionTargets) do
        if obj and obj.Parent and not droppedItems[obj] then
            return obj
        end
    end
    return nil
end

local function findPromptForObject(obj)
    if not obj then return nil end
    for _, prompt in ipairs(getAllPrompts()) do
        if getParentObject(prompt) == obj then
            return prompt
        end
    end
    return nil
end

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

local function teleportHome()
    local root = getRoot()
    if homeCFrame and root then
        root.CFrame = homeCFrame
    end
end

-- ====== ОСНОВНОЙ ЦИКЛ ФАРМА ======
local function farmCycle()
    while isFarming and not stopRequested do
        local targetObj = getNextTarget()
        if targetObj then
            isFarmBusy = true
            local prompt = findPromptForObject(targetObj)
            if prompt and isTargetObject(targetObj) and not droppedItems[targetObj] then
                prompt.Enabled = true
                local success = activatePrompt(prompt)
                prompt.Enabled = false
                if success then
                    -- предмет подобран
                else
                    -- не получилось – пропускаем
                end
            end
            isFarmBusy = false
            task.wait(0.2)
        else
            isFarmBusy = false
            teleportHome()
            local waited = 0
            while waited < 3 and isFarming and not stopRequested do
                task.wait(0.5)
                waited = waited + 0.5
            end
            if isFarming then
                updateSessionTargets()
            end
        end
    end
    clearSessionHighlights()
    teleportHome()
    isFarmBusy = false
end

-- ====== АВТОДРОП (исправлен, без goto) ======
local function dropCycle()
    local needPositionUpdate = true
    while isDropping do
        if isFarmBusy then
            needPositionUpdate = true
            task.wait(0.5)
        else
            teleportHome()
            if needPositionUpdate then
                local char = getChar()
                if char then
                    local toolsToMove = {}
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            table.insert(toolsToMove, item)
                        end
                    end
                    for _, tool in ipairs(toolsToMove) do
                        tool.Parent = char
                    end
                    task.wait(0.5)
                    for _, tool in ipairs(toolsToMove) do
                        tool.Parent = backpack
                    end
                    task.wait(0.5)
                end
                needPositionUpdate = false
            end

            -- Внутренний цикл дропа
            while isDropping and not isFarmBusy do
                local char = getChar()
                if not char then
                    task.wait(0.5)
                    break
                end
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
                        if item:IsA("Tool") then
                            table.insert(items, item)
                        end
                    end
                    if #items > 0 then
                        local randItem = items[math.random(1, #items)]
                        local humanoid = char:FindFirstChild("Humanoid")
                        if humanoid then
                            humanoid:EquipTool(randItem)
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
        end
    end
end

-- ====== GUI ======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- (Главное окно и окно настроек — полностью такие же, как в предыдущей версии)
-- Для краткости я не буду дублировать весь код GUI, он остаётся без изменений.
-- Ниже привожу только обработчики кнопок и связи с новыми функциями.

-- ... (весь код GUI от mainFrame до closeButton такой же)

-- ====== ОБРАБОТЧИКИ КНОПОК (исправлены) ======
toggleButton.MouseButton1Click:Connect(function()
    if not isFarming then
        local root = getRoot()
        if not root then return end
        homeCFrame = root.CFrame
        isFarming = true
        stopRequested = false
        toggleButton.Text = "⏹ Остановить"
        toggleButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
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

-- Остальные кнопки (закрытие, сворачивание, настройки) — без изменений
