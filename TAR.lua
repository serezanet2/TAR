-- [[ CUSTOM MULTI-KEYWORD & BOX FARMER + FREECAM (TMI V2.7) ]] --
-- Изменения V2.7:
--  * Боксы теперь активируются ПОЛНОСТЬЮ: ждём HoldDuration + 0.5с запаса
--  * Подписка на prompt.Triggered для точного определения момента активации
--  * Тело анкорится во время удержания (не падает/не уплывает)
--  * Флаг processingBusy блокирует параллельный запуск следующей цели
--  * Повторный fire каждые 0.1 сек на случай античитов требующих "real hold"
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
TitleLabel.Text = "TMI V2.7 - Hold Box Fix"
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

-- ===== СКАНИРОВАНИЕ (раз в SCAN_INTERVAL=5 сек, заполняет очередь TargetsQueue) =====
local function scanWorkspace()
    TargetsQueue = {}

    -- 1. ИНСТРУМЕНТЫ (Cup/Genesis/Gold/Silver/Copper)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Tool") or obj:IsA("BackpackItem") then
            if matchesKeyword(obj.Name) then
                if Blacklist[obj] then continue end
                if isInPlayerInventory(obj) then Blacklist[obj] = true; continue end
                -- НОВОЕ V2.6: игнор предметов внутри другого игрока (в руке/рюкзаке другого Character)
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

    -- 2. БОКСЫ (Model/BasePart с "box" + рекурсивный поиск ProximityPrompt)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if string.find(name, "box") then
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
                        })
                    end
                end
            end
        end
    end

    StatusLabel.Text = string.format("Сканирование завершено: %d целей в очереди", #TargetsQueue)
    StatusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
end

-- Флаг занятости — пока обрабатываем одну цель (особенно бокс с длинным HoldDuration),
-- следующий тик процесса не должен запускать новый таргет параллельно.
local processingBusy = false

-- ===== БЫСТРЫЙ ПОДБОР (раз в PICKUP_INTERVAL=0.1 сек, берёт одну цель из очереди) =====
local function processQueue()
    if processingBusy then return end
    if #TargetsQueue == 0 then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local target = table.remove(TargetsQueue, 1)
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

        elseif target.type == "box" then
            local prompt = target.prompt
            if not prompt or not prompt.Parent then
                Blacklist[target.obj] = true
                return
            end

            local holdDuration = (prompt.HoldDuration or 0)
            StatusLabel.Text = string.format("Активирую: %s (hold %.1fs)", target.obj.Name, holdDuration)
            StatusLabel.TextColor3 = Color3.fromRGB(224, 176, 255)

            -- V2.7: подписываемся на Triggered, чтоб точно знать когда бокс открылся
            local triggered = false
            local triggeredConn
            pcall(function()
                triggeredConn = prompt.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then
                        triggered = true
                    end
                end)
            end)

            -- Телепорт к боксу
            hrp.CFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))

            -- Анкорим тело, чтоб не упасть/уплыть пока ждём активацию
            local wasAnchored = hrp.Anchored
            hrp.Anchored = true

            -- Первая активация
            pcall(function() fireproximityprompt(prompt) end)

            -- V2.7: Ждём активацию столько сколько требует HoldDuration + запас 0.5 сек.
            -- Каждые 0.1 сек повторно жмём (для prompt'ов которые проверяют что игрок реально "держит")
            local waitTime = holdDuration + 0.5
            local elapsed = 0
            local fireInterval = 0.1
            while elapsed < waitTime do
                if triggered then break end
                if not _G.CupBoxFarmActive or not _G.ScriptAlive then break end
                pcall(function() fireproximityprompt(prompt) end)
                task.wait(fireInterval)
                elapsed = elapsed + fireInterval
            end

            -- Отписываемся от события
            if triggeredConn then
                pcall(function() triggeredConn:Disconnect() end)
            end

            -- Снимаем анкор и возвращаемся обратно
            hrp.Anchored = wasAnchored
            hrp.CFrame = originalCFrame

            if triggered then
                StatusLabel.Text = "✓ Активирован: " .. target.obj.Name
                StatusLabel.TextColor3 = Color3.fromRGB(0, 230, 118)
                Blacklist[target.obj] = true
            else
                StatusLabel.Text = "✗ Не активирован: " .. target.obj.Name
                StatusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
                -- Не добавляем в blacklist — попробуем позже снова
            end
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
