-- [[ CUSTOM MULTI-KEYWORD & BOX FARMER + FREECAM (TMI V3.4) ]] --
-- Изменения V3.4:
--  * cng666setna теперь ИГРОК (Player), не объект в Workspace
--  * Скрипт телепортируется НАД HRP игрока cng666setna (на 4 studs выше)
--  * HRP игрока поворачивается в ту же сторону куда смотрит HRP NPC игрока (Rotation)
--  * Все Tool из Backpack перемещаются в Character одной операцией (без EquipTool)
--  * Backspace спамится МНОГО раз (totalTools*2+10) — пока все тулы не упадут
--  * Дроп НЕ происходит после каждого подбора — копим и сдаём в конце каждого скана
-- Изменения V3.3:
--  * Сдача ВСЕГО инвентаря (все Tool без фильтра по cup/genesis) — для NPC-торговца
--  * Автоматическая сдача после каждого скана (каждые 5 сек)
-- Изменения V3.2:
--  * Дроп тулз через эмуляцию Backspace (VirtualInputManager:SendKeyEvent)
--    — стандартный хоткей Roblox для дропа тулы, работает как реальное нажатие
-- Изменения V3.1:
--  * Тулы сдаются в точку с именем "cng666setna" (ProximityPrompt/BasePart/Model)
--  * Скрипт сначала телепортируется к точке сдачи, дропает, и возвращается обратно
--  * Кэширование позиции точки сдачи на 5 сек (не сканит Workspace каждый раз)
-- Изменения V3.0:
--  * Игнор боксов с "supply" в имени (Supply Box и т.п.) — в blacklist автоматически
--  * После возврата к исходной точке — DROP всех собранных тулов на землю
--    (humanoid:UnequipTools() + перенос всех Tool из Backpack в Character)
-- Изменения V2.9:
--  * НАСТОЯЩЕЕ удержание через prompt:InputHoldBegin() / :InputHoldEnd()
--    (эмулирует реальное зажатие клавиши игроком — самый надёжный способ)
--  * Параллельно спамим fireproximityprompt как fallback
--  * Отключаем RequiresLineOfSight на время удержания
--  * Финальный fire после InputHoldEnd для надёжности
-- Изменения V2.8:
--  * БОКСЫ В ПРИОРИТЕТЕ: всегда обрабатываются раньше тулз
--  * Удержание полное HoldDuration + 0.5с
--  * Анкор + ежекадровая фиксация CFrame
--  * Временное увеличение MaxActivationDistance
-- Изменения V2.7:
--  * Боксы активируются полностью (но через Triggered — не всегда срабатывало)
--  * Тело анкорится во время удержания
--  * Флаг processingBusy блокирует параллельные цели
-- Изменения V2.6:
--  * Добавлена кнопка ✕ (Close) — полностью удаляет скрипт, чистит все ресурсы
--  * Игнорирует предметы внутри ДРУГИХ ИГРОКОВ (тулы в руках/рюкзаке других Character)
-- Изменения V2.5:
--  * Переработаны тайминги: сканирование каждые 5 сек, подбор каждые 0.1 сек
--  * Добавлен упрощённый FreeCam (без плавностей, без скрытия GUI)
--  * FreeCam: WASD движение, Space - вверх, Q - вниз, Shift - медленно
--  * Камера от 1 лица с центром привязанным к курсору
--  * Выход из FreeCam: клавиша F или повторное нажатие кнопки (для тач-устройств)
-- Изменения V2.4:
--  * Бокс может быть Model или BasePart (раньше только BasePart)
--  * ProximityPrompt ищется РЕКУРСИВНО внутри бокса (box.Main.ProximityPrompt и т.п.)
-- Изменения V2.3:
--  * Добавлены ключевые слова "gold", "silver", "copper"
-- Изменения V2.2:
--  * Добавлено ключевое слово "genesis"
-- Изменения V2.1:
--  * Blacklist по Instance ID, игнор Anchored, игнор "$"-Prompts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

_G.CupBoxFarmActive = false
_G.FreeCamActive = false
_G.ScriptAlive = true  -- V2.6: флаг живости для остановки циклов при закрытии

-- ===== НАСТРОЙКИ ТАЙМИНГОВ =====
local SCAN_INTERVAL = 5      -- Сканирование Workspace каждые 5 сек
local PICKUP_INTERVAL = 0.1  -- Подбор найденных предметов каждые 0.1 сек

-- Ключевые слова для поиска инструментов (case-insensitive)
local TOOL_KEYWORDS = { "cup", "genesis", "gold", "silver", "copper" }

local function matchesKeyword(name)
    local lowerName = string.lower(name)
    for _, keyword in ipairs(TOOL_KEYWORDS) do
        if string.find(lowerName, keyword) then
            return true
        end
    end
    return false
end

-- Blacklist по Instance reference
local Blacklist = setmetatable({}, { __mode = "k" })

-- Очередь обнаруженных целей (заполняется каждые 5 сек, обрабатывается каждые 0.1 сек)
local TargetsQueue = {}

-- ===== СОЗДАНИЕ GUI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CupBoxFarmGui"
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 230)
MainFrame.Position = UDim2.new(0.5, -110, 0.4, -115)
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
TitleLabel.Size = UDim2.new(1, -28, 0, 28)
TitleLabel.Text = "TMI V3.4 - Drop on Player"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleLabel

-- Кнопка закрытия скрипта (крестик в правом верхнем углу)
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 28, 0, 28)
CloseButton.Position = UDim2.new(1, -28, 0, 0)
CloseButton.Text = "✕"
CloseButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 16
CloseButton.BorderSizePixel = 0
CloseButton.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

-- Кнопка Farm
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 200, 0, 36)
ToggleButton.Position = UDim2.new(0.5, -100, 0, 36)
ToggleButton.Text = "Farm: OFF"
ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 14
ToggleButton.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

-- Кнопка FreeCam
local FreeCamButton = Instance.new("TextButton")
FreeCamButton.Size = UDim2.new(0, 200, 0, 36)
FreeCamButton.Position = UDim2.new(0.5, -100, 0, 78)
FreeCamButton.Text = "FreeCam: OFF (F to exit)"
FreeCamButton.BackgroundColor3 = Color3.fromRGB(60, 100, 180)
FreeCamButton.TextColor3 = Color3.fromRGB(255, 255, 255)
FreeCamButton.Font = Enum.Font.GothamBold
FreeCamButton.TextSize = 12
FreeCamButton.Parent = MainFrame

local FreeCamCorner = Instance.new("UICorner")
FreeCamCorner.CornerRadius = UDim.new(0, 6)
FreeCamCorner.Parent = FreeCamButton

-- Кнопка очистки blacklist
local ClearBlacklistButton = Instance.new("TextButton")
ClearBlacklistButton.Size = UDim2.new(0, 200, 0, 26)
ClearBlacklistButton.Position = UDim2.new(0.5, -100, 0, 120)
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
StatusLabel.Size = UDim2.new(1, -10, 0, 50)
StatusLabel.Position = UDim2.new(0, 5, 0, 152)
StatusLabel.Text = "Ожидание запуска..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextWrapped = true
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Parent = MainFrame

-- ===== ХЕЛПЕРЫ ДЛЯ ПРОВЕРКИ =====

local function isInPlayerInventory(tool)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    if backpack and tool:IsDescendantOf(backpack) then return true end
    if character and tool:IsDescendantOf(character) then return true end
    return false
end

-- Проверяет находится ли предмет внутри ДРУГОГО игрока (где-то в иерархии есть Humanoid
-- из другого Character'a). Это нужно чтобы не телепортироваться к игроку и не пытаться
-- забрать у него тулу из руки.
local function isInsideOtherPlayer(tool)
    local myCharacter = LocalPlayer.Character
    local parent = tool.Parent
    while parent and parent ~= game do
        -- Если нашли Humanoid в иерархии родителей
        if parent:FindFirstChildOfClass("Humanoid") then
            -- И этот Character не наш — игнорируем предмет
            if parent ~= myCharacter then
                -- Дополнительно проверяем, что это вообще игровой персонаж
                local plr = Players:GetPlayerFromCharacter(parent)
                if plr or parent:FindFirstChildOfClass("Humanoid") then
                    return true
                end
            end
        end
        parent = parent.Parent
    end
    return false
end

-- V3.4: cng666setna — это другой ИГРОК (Player), а не объект в Workspace.
-- Скрипт ищет его Character в Players, телепортируется НАД его HRP и поворачивает
-- свой HRP в ту же сторону куда смотрит HRP NPC игрока.
local DROP_PLAYER_NAME = "cng666setna"
local DROP_ABOVE_HEIGHT = 4  -- studs над головой NPC игрока

-- Находит HRP игрока cng666setna. Возвращает HumanoidRootPart или nil.
-- V3.4: ищем именно среди Players, а не в Workspace.
local function findDropPlayerHRP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Name == DROP_PLAYER_NAME then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and hrp:IsA("BasePart") then
                    return hrp
                end
            end
        end
    end
    return nil
end

-- V3.2: VirtualInputManager — сервис для эмуляции реальных нажатий клавиш.
-- Используется для нажатия Backspace (стандартный хоткей Roblox для дропа тулы из руки).
local VIM = game:GetService("VirtualInputManager")

-- Эмулирует нажатие Backspace — Roblox дропает экипированную тулу так же,
-- как если бы это сделал реальный игрок.
local function pressBackspace()
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
    end)
end

-- V3.4: Полностью новый дроп. Скрипт телепортируется НАД игроком cng666setna,
-- поворачивает свой HRP в ту же сторону куда смотрит HRP NPC игрока, перемещает
-- ВСЕ Tool из Backpack в Character и спамит Backspace много раз чтоб всё упало.
local function dropAllTools()
    local character = LocalPlayer.Character
    if not character then return 0 end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not humanoid or not backpack or not hrp then return 0 end

    -- Считаем тулы (Backpack + Character)
    local totalTools = 0
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then totalTools = totalTools + 1 end
    end
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then totalTools = totalTools + 1 end
    end
    if totalTools == 0 then return 0 end

    -- V3.4: Ищем HRP игрока cng666setna
    local cngHRP = findDropPlayerHRP()
    if not cngHRP then
        StatusLabel.Text = "⚠ Игрок " .. DROP_PLAYER_NAME .. " не найден"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        return 0
    end

    -- Сохраняем оригинальную позицию
    local origCFrame = hrp.CFrame
    local wasAnchored = hrp.Anchored

    -- V3.4: Телепортируемся НАД игроком cng666setna и поворачиваем HRP в ту же сторону
    -- куда смотрит HRP NPC (т.е. cng_hrp.CFrame.Rotation, не LookVector).
    local cngPos = cngHRP.Position
    local cngRotation = cngHRP.CFrame - cngPos  -- чистый Rotation без позиции

    local newPos = cngPos + Vector3.new(0, DROP_ABOVE_HEIGHT, 0)
    hrp.CFrame = CFrame.new(newPos) * cngRotation

    hrp.Anchored = true
    task.wait(0.15)  -- даём время телепорту прижиться

    -- V3.4: Перемещаем ВСЕ Tool из Backpack в Character (НЕ через EquipTool — это
    -- сразу всё засунет в руку как стек, и Backspace будет дропать по одному)
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() tool.Parent = character end)
        end
    end
    task.wait(0.05)

    -- V3.4: СПАМИМ Backspace много раз — Roblox дропнет тулы из руки по одной.
    -- Делаем 50 нажатий с задержкой 30мс — этого хватит на любое количество тулз.
    local spamCount = math.max(totalTools * 2 + 10, 30)
    for i = 1, spamCount do
        pressBackspace()
        task.wait(0.03)

        -- Проверяем не закончились ли тулы (есть ли ещё что дропать)
        if i > 5 and i % 5 == 0 then
            local stillHasTools = false
            for _, tool in pairs(character:GetChildren()) do
                if tool:IsA("Tool") then stillHasTools = true; break end
            end
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then stillHasTools = true; break end
            end
            if not stillHasTools then break end  -- всё сброшено — выходим раньше
        end
    end

    task.wait(0.1)
    -- Возвращаемся на исходную позицию
    hrp.Anchored = wasAnchored
    hrp.CFrame = origCFrame

    return totalTools
end

local function isShopPrompt(prompt)
    local fields = { prompt.ActionText or "", prompt.ObjectText or "", prompt.Name or "" }
    for _, text in ipairs(fields) do
        if string.find(text, "%$") then return true end
    end
    return false
end

local function isAnchored(obj)
    if obj:IsA("BasePart") then return obj.Anchored end
    local handle = obj:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle.Anchored end
    local anyPart = obj:FindFirstChildWhichIsA("BasePart")
    if anyPart then return anyPart.Anchored end
    return false
end

-- Флаг занятости — пока обрабатываем одну цель (особенно бокс с длинным HoldDuration),
-- следующий тик процесса не должен запускать новый таргет параллельно.
-- V3.3: также используется при авто-сдаче в конце scanWorkspace.
local processingBusy = false

-- ===== СКАНИРОВАНИЕ (раз в SCAN_INTERVAL=5 сек, заполняет очередь TargetsQueue) =====
local function scanWorkspace()
    TargetsQueue = {}

    -- V2.8: БОКСЫ В ПРИОРИТЕТЕ. Сканируем их первыми и кладём в начало очереди.
    -- 1. БОКСЫ (Model/BasePart с "box" + рекурсивный поиск ProximityPrompt)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if string.find(name, "box") then
                -- V3.0: игнорируем боксы с "supply" в имени (Supply Box, SUPPLY_CRATE и т.п.)
                if string.find(name, "supply") then
                    Blacklist[obj] = true
                    continue
                end
                if Blacklist[obj] then continue end

                local prompt = nil
                for _, descendant in pairs(obj:GetDescendants()) do
                    if descendant:IsA("ProximityPrompt") then
                        prompt = descendant
                        break
                    end
                end

                if prompt then
                    if isShopPrompt(prompt) then Blacklist[obj] = true; continue end

                    local targetPos = nil
                    if obj:IsA("Model") and obj.PrimaryPart then
                        targetPos = obj.PrimaryPart.Position
                    elseif obj:IsA("BasePart") then
                        targetPos = obj.Position
                    elseif prompt.Parent and prompt.Parent:IsA("BasePart") then
                        targetPos = prompt.Parent.Position
                    else
                        local anyPart = obj:FindFirstChildWhichIsA("BasePart", true)
                        if anyPart then targetPos = anyPart.Position end
                    end

                    if targetPos then
                        table.insert(TargetsQueue, {
                            type = "box",
                            obj = obj,
                            prompt = prompt,
                            pos = targetPos,
                            holdDuration = (tonumber(prompt.HoldDuration) or 0),
                        })
                    end
                end
            end
        end
    end

    -- 2. ИНСТРУМЕНТЫ (Cup/Genesis/Gold/Silver/Copper) — добавляются после боксов
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") or obj:IsA("BackpackItem") then
            if matchesKeyword(obj.Name) then
                if Blacklist[obj] then continue end
                if isInPlayerInventory(obj) then Blacklist[obj] = true; continue end
                if isInsideOtherPlayer(obj) then Blacklist[obj] = true; continue end
                if isAnchored(obj) then Blacklist[obj] = true; continue end

                local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                if handle and not handle.Anchored then
                    table.insert(TargetsQueue, {
                        type = "tool",
                        obj = obj,
                        handle = handle,
                    })
                end
            end
        end
    end

    -- Подсчитаем боксы для статуса
    local boxCount = 0
    for _, t in ipairs(TargetsQueue) do
        if t.type == "box" then boxCount = boxCount + 1 end
    end
    StatusLabel.Text = string.format("Скан: %d боксов, %d тулз", boxCount, #TargetsQueue - boxCount)
    StatusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)

    -- V3.3: после каждого скана автоматически сдаём весь инвентарь NPC.
    -- Это гарантирует что Backpack всегда очищается, даже если новых целей не нашлось.
    -- Делаем в отдельном потоке чтоб не блокировать сам цикл сканирования.
    task.spawn(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local character = LocalPlayer.Character
        if not backpack or not character then return end

        -- Проверяем что есть что сдавать
        local hasTools = false
        for _, t in pairs(backpack:GetChildren()) do
            if t:IsA("Tool") then hasTools = true; break end
        end
        if not hasTools then
            for _, t in pairs(character:GetChildren()) do
                if t:IsA("Tool") then hasTools = true; break end
            end
        end

        if hasTools and not processingBusy then
            processingBusy = true
            local ok, dropped = pcall(dropAllTools)
            processingBusy = false
            if ok and dropped and dropped > 0 then
                StatusLabel.Text = string.format("📤 Авто-сдача: %d тулз → cng666setna", dropped)
                StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            end
        end
    end)
end

-- ===== БЫСТРЫЙ ПОДБОР (раз в PICKUP_INTERVAL=0.1 сек, берёт одну цель из очереди) =====
local function processQueue()
    if processingBusy then return end
    if #TargetsQueue == 0 then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    -- V2.8: БОКСЫ В ПРИОРИТЕТЕ. Сначала ищем box в очереди, и только если их нет — берём tool.
    local targetIndex = nil
    for i, t in ipairs(TargetsQueue) do
        if t.type == "box" then
            targetIndex = i
            break
        end
    end
    if not targetIndex then
        -- Боксов нет — берём первую цель (она будет tool'ом)
        targetIndex = 1
    end
    local target = table.remove(TargetsQueue, targetIndex)
    if not target then return end
    if not target.obj or not target.obj.Parent then return end

    -- Устанавливаем флаг занятости. Снимем его в конце через ok/err-обёртку.
    processingBusy = true
    local ok, err = pcall(function()
        local originalCFrame = hrp.CFrame

        if target.type == "tool" then
            if Blacklist[target.obj] then return end
            if isInPlayerInventory(target.obj) then
                Blacklist[target.obj] = true
                return
            end
            -- V2.6: предмет успел попасть в руку другому игроку — игнор
            if isInsideOtherPlayer(target.obj) then
                Blacklist[target.obj] = true
                return
            end

            Blacklist[target.obj] = true
            StatusLabel.Text = "Беру: " .. target.obj.Name
            StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)

            hrp.CFrame = CFrame.new(target.handle.Position)
            task.wait(0.05)
            pcall(function() humanoid:EquipTool(target.obj) end)
            task.wait(0.03)
            hrp.CFrame = originalCFrame

            -- V3.4: НЕ дропаем после каждого подбора — копим всё и сдаём в конце скана.

        elseif target.type == "box" then
            local prompt = target.prompt
            if not prompt or not prompt.Parent then
                Blacklist[target.obj] = true
                return
            end

            -- V2.9: НАСТОЯЩЕЕ удержание через InputHoldBegin/End + fireproximityprompt спам.
            -- Эмулируем реальное нажатие клавиши, как если бы игрок зажал кнопку.
            local holdDuration = tonumber(prompt.HoldDuration) or 0
            local totalHoldTime = holdDuration + 0.5

            StatusLabel.Text = string.format("⏳ Держу %s (%.1fs)...", target.obj.Name, totalHoldTime)
            StatusLabel.TextColor3 = Color3.fromRGB(224, 176, 255)

            -- Телепорт к боксу
            local boxCFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))
            hrp.CFrame = boxCFrame

            -- Анкорим тело
            local wasAnchored = hrp.Anchored
            hrp.Anchored = true

            -- Временно расширяем MaxActivationDistance чтоб точно был в зоне
            local origMaxDist = prompt.MaxActivationDistance
            pcall(function()
                prompt.MaxActivationDistance = math.max(origMaxDist or 0, 50)
            end)

            -- Также увеличим RequiresLineOfSight = false (если он включен)
            local origLineOfSight = prompt.RequiresLineOfSight
            pcall(function() prompt.RequiresLineOfSight = false end)

            -- Подписываемся на Triggered чтобы знать что бокс открылся (для статуса)
            local triggered = false
            local triggeredConn
            pcall(function()
                triggeredConn = prompt.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then triggered = true end
                end)
            end)

            -- =========== ОСНОВНОЙ ХАК ===========
            -- 1) Эмулируем зажатие кнопки методом InputHoldBegin (реальный API ProximityPrompt)
            local holdBeginOk = pcall(function() prompt:InputHoldBegin() end)

            -- 2) Параллельно спамим fireproximityprompt как fallback (для эксплоитов)
            local startTime = tick()
            local lastFireTime = 0
            local fireInterval = 0.1  -- спамим fire каждые 100 мс

            while tick() - startTime < totalHoldTime do
                if not _G.CupBoxFarmActive or not _G.ScriptAlive then break end

                if tick() - lastFireTime >= fireInterval then
                    pcall(function() fireproximityprompt(prompt) end)
                    lastFireTime = tick()
                end

                -- Удерживаем позицию у бокса (на всякий случай)
                if hrp.Parent then
                    hrp.CFrame = boxCFrame
                end

                task.wait()  -- 1 кадр
            end

            -- 3) Отпускаем кнопку через InputHoldEnd
            if holdBeginOk then
                pcall(function() prompt:InputHoldEnd() end)
            end

            -- Доп. финальный fire на всякий случай
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.1)

            -- Отписываемся
            if triggeredConn then
                pcall(function() triggeredConn:Disconnect() end)
            end

            -- Восстанавливаем оригинальные настройки промпта
            pcall(function()
                if origMaxDist then prompt.MaxActivationDistance = origMaxDist end
                if origLineOfSight ~= nil then prompt.RequiresLineOfSight = origLineOfSight end
            end)

            -- Снимаем анкор и возвращаемся
            hrp.Anchored = wasAnchored
            hrp.CFrame = originalCFrame

            if triggered then
                StatusLabel.Text = "✓ Открыт: " .. target.obj.Name
                StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
            else
                StatusLabel.Text = "? Удержал: " .. target.obj.Name
                StatusLabel.TextColor3 = Color3.fromRGB(220, 200, 100)
            end
            Blacklist[target.obj] = true

            -- V3.4: НЕ дропаем после каждого бокса — копим всё и сдаём в конце скана.
        end
    end)

    -- В любом случае снимаем флаг занятости
    processingBusy = false

    if not ok then
        warn("[TMI V2.7] processQueue error: " .. tostring(err))
    end
end

-- =====================================================================
-- ===== FREECAM (упрощённый, без плавностей, центр привязан к курсору)
-- =====================================================================
local camera = workspace.CurrentCamera
local freeCamCFrame = nil
local freeCamPitch = 0
local freeCamYaw = 0
local freeCamRender = nil
local freeCamMouseConn = nil
local SPEED = 50      -- studs/sec
local SLOW_SPEED = 12
local MOUSE_SENS = 0.005

local function startFreeCam()
    if _G.FreeCamActive then return end
    _G.FreeCamActive = true

    -- Инициализация позиции/углов из текущей камеры
    freeCamCFrame = camera.CFrame
    local lookVec = camera.CFrame.LookVector
    freeCamPitch = math.asin(lookVec.Y)
    freeCamYaw = math.atan2(-lookVec.X, -lookVec.Z)

    camera.CameraType = Enum.CameraType.Scriptable
    UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

    FreeCamButton.Text = "FreeCam: ON (F=exit)"
    FreeCamButton.BackgroundColor3 = Color3.fromRGB(0, 150, 220)

    -- Мышь: поворот
    freeCamMouseConn = UIS.InputChanged:Connect(function(input)
        if not _G.FreeCamActive then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            freeCamYaw = freeCamYaw - input.Delta.X * MOUSE_SENS
            freeCamPitch = math.clamp(freeCamPitch - input.Delta.Y * MOUSE_SENS, -math.pi/2 + 0.01, math.pi/2 - 0.01)
        end
    end)

    -- Каждый кадр: считаем движение и применяем камеру (БЕЗ плавностей)
    freeCamRender = RS.RenderStepped:Connect(function(dt)
        if not _G.FreeCamActive then return end

        local moveX, moveY, moveZ = 0, 0, 0
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveZ = moveZ - 1 end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveZ = moveZ + 1 end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveX = moveX - 1 end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveX = moveX + 1 end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then moveY = moveY + 1 end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then moveY = moveY - 1 end

        local speed = (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)) and SLOW_SPEED or SPEED

        -- Строим CFrame из углов (от 1 лица, центр = курсор/середина экрана)
        local rotCFrame = CFrame.fromEulerAnglesYXZ(freeCamPitch, freeCamYaw, 0)
        local moveVec = rotCFrame:VectorToWorldSpace(Vector3.new(moveX, 0, moveZ))
        moveVec = moveVec + Vector3.new(0, moveY, 0)

        freeCamCFrame = CFrame.new(freeCamCFrame.Position + moveVec * speed * dt) * rotCFrame.Rotation
        -- Применяем CFrame с поворотом из углов и позицией
        camera.CFrame = CFrame.new(freeCamCFrame.Position) * rotCFrame
    end)
end

local function stopFreeCam()
    if not _G.FreeCamActive then return end
    _G.FreeCamActive = false

    if freeCamRender then freeCamRender:Disconnect() freeCamRender = nil end
    if freeCamMouseConn then freeCamMouseConn:Disconnect() freeCamMouseConn = nil end

    UIS.MouseBehavior = Enum.MouseBehavior.Default
    camera.CameraType = Enum.CameraType.Custom

    FreeCamButton.Text = "FreeCam: OFF (F=exit)"
    FreeCamButton.BackgroundColor3 = Color3.fromRGB(60, 100, 180)
end

local function toggleFreeCam()
    if _G.FreeCamActive then stopFreeCam() else startFreeCam() end
end

-- ===== UI ОБРАБОТЧИКИ =====
ToggleButton.MouseButton1Click:Connect(function()
    _G.CupBoxFarmActive = not _G.CupBoxFarmActive
    if _G.CupBoxFarmActive then
        ToggleButton.Text = "Farm: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        StatusLabel.Text = "Farm Enabled. Скан каждые 5с, подбор каждые 0.1с"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
    else
        ToggleButton.Text = "Farm: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        TargetsQueue = {}
        StatusLabel.Text = "Farm Disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

FreeCamButton.MouseButton1Click:Connect(toggleFreeCam)

ClearBlacklistButton.MouseButton1Click:Connect(function()
    Blacklist = setmetatable({}, { __mode = "k" })
    TargetsQueue = {}
    StatusLabel.Text = "Blacklist очищен!"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
end)

-- ===== ПОЛНОЕ ЗАКРЫТИЕ СКРИПТА (V2.6) =====
-- Останавливает все циклы, отключает FreeCam, чистит все ссылки и удаляет GUI
local fInputConn = nil  -- forward-declare для коннекшена клавиши F

local function destroyScript()
    -- 1. Выключаем все режимы
    _G.CupBoxFarmActive = false
    _G.ScriptAlive = false  -- остановит while-циклы скана и подбора

    -- 2. Выключаем FreeCam если был активен
    if _G.FreeCamActive then
        pcall(stopFreeCam)
    end

    -- 3. Чистим очередь и blacklist
    TargetsQueue = {}
    Blacklist = setmetatable({}, { __mode = "k" })

    -- 4. Отключаем коннекшены клавиатуры
    if fInputConn then
        fInputConn:Disconnect()
        fInputConn = nil
    end

    -- 5. Восстанавливаем поведение мыши и камеру (на случай если FreeCam подвис)
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        camera.CameraType = Enum.CameraType.Custom
    end)

    -- 5b. V2.7: снимаем Anchored у HRP на случай если убили скрипт во время активации бокса
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end)

    -- 6. Удаляем GUI
    pcall(function() ScreenGui:Destroy() end)

    -- 7. Сбрасываем глобалы (на случай повторного запуска скрипта)
    _G.CupBoxFarmActive = nil
    _G.FreeCamActive = nil
    _G.ScriptAlive = nil
end

CloseButton.MouseButton1Click:Connect(destroyScript)

-- Клавиша F — выход из FreeCam
fInputConn = UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F and _G.FreeCamActive then
        stopFreeCam()
    end
end)

-- ===== ЦИКЛ СКАНИРОВАНИЯ (каждые SCAN_INTERVAL сек) =====
task.spawn(function()
    while _G.ScriptAlive do
        if _G.CupBoxFarmActive then
            pcall(scanWorkspace)
        end
        task.wait(SCAN_INTERVAL)
    end
end)

-- ===== ЦИКЛ ПОДБОРА (каждые PICKUP_INTERVAL сек) =====
task.spawn(function()
    while _G.ScriptAlive do
        if _G.CupBoxFarmActive then
            pcall(processQueue)
        end
        task.wait(PICKUP_INTERVAL)
    end
end)
