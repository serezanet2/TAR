-- [[ TMI V3.1 — CUSTOM MULTI-KEYWORD & BOX FARMER + FREECAM ]] --
-- Изменения V3.1:
--  * При старте фарма: HRP закрепляется (Anchored), запоминается CFrame
--  * После подбора: все Tool → Character, затем h:UnequipTools()
--  * Спам Backspace ТОЛЬКО если игрок на сохранённой позиции
--
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
_G.ScriptAlive = true

-- ===== V3.1: СОХРАНЁННАЯ ПОЗИЦИЯ HRP =====
local SavedCFrame = nil
local WasHRPAnchored = false

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
MainFrame.Size = UDim2.new(0, 260, 0, 280)
MainFrame.Position = UDim2.new(0.5, -130, 0.4, -140)
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
TitleLabel.Text = "TMI V3.1 - Anchor + Backspace"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleLabel

-- Кнопка закрытия скрипта (крестик)
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
ToggleButton.Size = UDim2.new(0, 240, 0, 36)
ToggleButton.Position = UDim2.new(0.5, -120, 0, 36)
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
FreeCamButton.Size = UDim2.new(0, 240, 0, 36)
FreeCamButton.Position = UDim2.new(0.5, -120, 0, 78)
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
ClearBlacklistButton.Size = UDim2.new(0, 240, 0, 26)
ClearBlacklistButton.Position = UDim2.new(0.5, -120, 0, 120)
ClearBlacklistButton.Text = "Очистить Blacklist"
ClearBlacklistButton.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
ClearBlacklistButton.TextColor3 = Color3.fromRGB(220, 220, 220)
ClearBlacklistButton.Font = Enum.Font.Gotham
ClearBlacklistButton.TextSize = 11
ClearBlacklistButton.Parent = MainFrame

local ClearCorner = Instance.new("UICorner")
ClearCorner.CornerRadius = UDim.new(0, 4)
ClearCorner.Parent = ClearBlacklistButton

-- V3.1: Индикатор статуса закрепления HRP
local AnchorStatus = Instance.new("TextLabel")
AnchorStatus.Size = UDim2.new(0, 240, 0, 16)
AnchorStatus.Position = UDim2.new(0.5, -120, 0, 150)
AnchorStatus.Text = "🔒 HRP: ожидание фарма..."
AnchorStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
AnchorStatus.BackgroundTransparency = 1
AnchorStatus.Font = Enum.Font.Gotham
AnchorStatus.TextSize = 10
AnchorStatus.TextXAlignment = Enum.TextXAlignment.Center
AnchorStatus.Parent = MainFrame

-- V3.1: Отображение сохранённой позиции
local SavedPosLabel = Instance.new("TextLabel")
SavedPosLabel.Size = UDim2.new(0, 240, 0, 16)
SavedPosLabel.Position = UDim2.new(0.5, -120, 0, 166)
SavedPosLabel.Text = "📍 XYZ: ---  Rot: ---"
SavedPosLabel.TextColor3 = Color3.fromRGB(100, 150, 220)
SavedPosLabel.BackgroundTransparency = 1
SavedPosLabel.Font = Enum.Font.Gotham
SavedPosLabel.TextSize = 9
SavedPosLabel.TextXAlignment = Enum.TextXAlignment.Center
SavedPosLabel.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 50)
StatusLabel.Position = UDim2.new(0, 5, 0, 186)
StatusLabel.Text = "Ожидание запуска..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextWrapped = true
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Parent = MainFrame

-- =====================================================================
-- ===== V3.1: НОВЫЕ ФУНКЦИИ: ANCHOR HRP + ЗАПОМИНАНИЕ ПОЗИЦИИ =====
-- =====================================================================

local function saveAndAnchorHRP()
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Запоминаем CFrame (позиция + поворот)
    SavedCFrame = hrp.CFrame

    -- Запоминаем был ли уже заанкорен, чтобы потом восстановить
    WasHRPAnchored = hrp.Anchored

    -- Закрепляем
    hrp.Anchored = true

    -- Обновляем GUI
    local x = math.floor(SavedCFrame.Position.X * 10) / 10
    local y = math.floor(SavedCFrame.Position.Y * 10) / 10
    local z = math.floor(SavedCFrame.Position.Z * 10) / 10
    local _, _, _, _, _, rot = SavedCFrame:ToOrientation()
    local deg = math.floor(math.deg(rot))

    AnchorStatus.Text = "🔒 HRP: ЗААНКОРЕН"
    AnchorStatus.TextColor3 = Color3.fromRGB(255, 200, 80)
    SavedPosLabel.Text = string.format("📍 X=%.1f Y=%.1f Z=%.1f Rot=%d°", x, y, z, deg)
    SavedPosLabel.TextColor3 = Color3.fromRGB(130, 210, 255)

    print("[TMI V3.1] HRP заанкорен на позиции: " .. tostring(SavedCFrame.Position))
    return true
end

local function releaseHRP()
    if not WasHRPAnchored then
        -- Если HRP не был заанкорен до нас — просто снимаем
        local character = LocalPlayer.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end
    -- Если был заанкорен изначально — оставляем как есть

    AnchorStatus.Text = "🔓 HRP: свободен"
    AnchorStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
    SavedPosLabel.Text = "📍 XYZ: ---  Rot: ---"
    SavedPosLabel.TextColor3 = Color3.fromRGB(100, 150, 220)
    SavedCFrame = nil
    WasHRPAnchored = false
    print("[TMI V3.1] HRP разанкорен")
end

-- =====================================================================
-- ===== V3.1: ПРОВЕРКА НА СОХРАНЁННОЙ ЛИ ПОЗИЦИИ ИГРОК =====
-- =====================================================================

local function isAtSavedPosition()
    if not SavedCFrame then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local dist = (hrp.Position - SavedCFrame.Position).Magnitude
    return dist < 3  -- допуск 3 студа
end

-- =====================================================================
-- ===== V3.1: ПЕРЕНОС ТУЛ В CHARACTER + BACKSPACE SPAM =====
-- =====================================================================

local function moveToolsToCharacterAndSpamBackspace()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not humanoid or not backpack then return end

    local toolCount = 0

    -- 1. Переносим все Tool из Backpack в Character
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function()
                tool.Parent = character
                toolCount = toolCount + 1
            end)
        end
    end

    -- 2. Сбрасываем экипированные тулы (вызовет .Dropped для тех, что в руках)
    pcall(function() humanoid:UnequipTools() end)

    if toolCount > 0 then
        print("[TMI V3.1] Перемещено " .. tostring(toolCount) .. " тулз в Character")
    end

    -- 3. Backspace spam (ТОЛЬКО если игрок на сохранённой позиции)
    if isAtSavedPosition() then
        local spamCount = 3 + math.random(0, 5)
        print("[TMI V3.1] Спам Backspace ×" .. tostring(spamCount) .. " на сохранённой позиции")

        for i = 1, spamCount do
            pcall(function()
                -- Эмулируем нажатие и отпускание клавиши Backspace
                -- Метод 1: SendKeyEvent (поддерживается многими эксплоитами)
                UIS:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                task.wait(0.04 + math.random() * 0.03)
                UIS:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                task.wait(0.03 + math.random() * 0.02)
            end)
        end

        StatusLabel.Text = string.format("⌨️ Backspace ×%d (на позиции)", spamCount)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 138, 101)
    else
        print("[TMI V3.1] Пропущен Backspace: не на сохранённой позиции")
        StatusLabel.Text = "⛔ Backspace пропущен (не на позиции)"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
    end
end

-- ===== ХЕЛПЕРЫ ДЛЯ ПРОВЕРКИ =====

local function isInPlayerInventory(tool)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    if backpack and tool:IsDescendantOf(backpack) then return true end
    if character and tool:IsDescendantOf(character) then return true end
    return false
end

local function isInsideOtherPlayer(tool)
    local myCharacter = LocalPlayer.Character
    local parent = tool.Parent
    while parent and parent ~= game do
        if parent:FindFirstChildOfClass("Humanoid") then
            if parent ~= myCharacter then
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

    -- 1. БОКСЫ (Model/BasePart с "box" + рекурсивный поиск ProximityPrompt)
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if string.find(name, "box") then
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

    -- 2. ИНСТРУМЕНТЫ (Cup/Genesis/Gold/Silver/Copper)
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

    local boxCount = 0
    for _, t in ipairs(TargetsQueue) do
        if t.type == "box" then boxCount = boxCount + 1 end
    end
    StatusLabel.Text = string.format("Скан: %d боксов, %d тулз", boxCount, #TargetsQueue - boxCount)
    StatusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
end

local processingBusy = false

-- ===== ПРОЦЕСС ОБРАБОТКИ ОЧЕРЕДИ (раз в PICKUP_INTERVAL=0.1 сек) =====
local function processQueue()
    if processingBusy then return end
    if #TargetsQueue == 0 then return end

    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local targetIndex = nil
    for i, t in ipairs(TargetsQueue) do
        if t.type == "box" then
            targetIndex = i
            break
        end
    end
    if not targetIndex then
        targetIndex = 1
    end
    local target = table.remove(TargetsQueue, targetIndex)
    if not target then return end
    if not target.obj or not target.obj.Parent then return end

    processingBusy = true
    local ok, err = pcall(function()
        local originalCFrame = hrp.CFrame

        if target.type == "tool" then
            if Blacklist[target.obj] then return end
            if isInPlayerInventory(target.obj) then
                Blacklist[target.obj] = true
                return
            end
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

            -- V3.1: Перенос тул в Character + Backspace spam
            task.wait(0.05)
            moveToolsToCharacterAndSpamBackspace()

        elseif target.type == "box" then
            local prompt = target.prompt
            if not prompt or not prompt.Parent then
                Blacklist[target.obj] = true
                return
            end

            local holdDuration = tonumber(prompt.HoldDuration) or 0
            local totalHoldTime = holdDuration + 0.5

            StatusLabel.Text = string.format("⏳ Держу %s (%.1fs)...", target.obj.Name, totalHoldTime)
            StatusLabel.TextColor3 = Color3.fromRGB(224, 176, 255)

            local boxCFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))
            hrp.CFrame = boxCFrame

            local wasAnchored = hrp.Anchored
            hrp.Anchored = true

            local origMaxDist = prompt.MaxActivationDistance
            pcall(function()
                prompt.MaxActivationDistance = math.max(origMaxDist or 0, 50)
            end)

            local origLineOfSight = prompt.RequiresLineOfSight
            pcall(function() prompt.RequiresLineOfSight = false end)

            local triggered = false
            local triggeredConn
            pcall(function()
                triggeredConn = prompt.Triggered:Connect(function(plr)
                    if plr == LocalPlayer then triggered = true end
                end)
            end)

            local holdBeginOk = pcall(function() prompt:InputHoldBegin() end)

            local startTime = tick()
            local lastFireTime = 0
            local fireInterval = 0.1

            while tick() - startTime < totalHoldTime do
                if not _G.CupBoxFarmActive or not _G.ScriptAlive then break end

                if tick() - lastFireTime >= fireInterval then
                    pcall(function() fireproximityprompt(prompt) end)
                    lastFireTime = tick()
                end

                if hrp.Parent then
                    hrp.CFrame = boxCFrame
                end

                task.wait()
            end

            if holdBeginOk then
                pcall(function() prompt:InputHoldEnd() end)
            end

            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.1)

            if triggeredConn then
                pcall(function() triggeredConn:Disconnect() end)
            end

            pcall(function()
                if origMaxDist then prompt.MaxActivationDistance = origMaxDist end
                if origLineOfSight ~= nil then prompt.RequiresLineOfSight = origLineOfSight end
            end)

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

            -- V3.1: Перенос тул в Character + Backspace spam
            task.wait(0.1)
            moveToolsToCharacterAndSpamBackspace()
        end
    end)

    processingBusy = false

    if not ok then
        warn("[TMI V3.1] processQueue error: " .. tostring(err))
    end
end

-- ===== FREECAM (упрощённый) =====
local camera = workspace.CurrentCamera
local freeCamCFrame = nil
local freeCamPitch = 0
local freeCamYaw = 0
local freeCamRender = nil
local freeCamMouseConn = nil
local SPEED = 50
local SLOW_SPEED = 12
local MOUSE_SENS = 0.005

local function startFreeCam()
    if _G.FreeCamActive then return end
    _G.FreeCamActive = true

    freeCamCFrame = camera.CFrame
    local lookVec = camera.CFrame.LookVector
    freeCamPitch = math.asin(lookVec.Y)
    freeCamYaw = math.atan2(-lookVec.X, -lookVec.Z)

    camera.CameraType = Enum.CameraType.Scriptable
    UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

    FreeCamButton.Text = "FreeCam: ON (F=exit)"
    FreeCamButton.BackgroundColor3 = Color3.fromRGB(0, 150, 220)

    freeCamMouseConn = UIS.InputChanged:Connect(function(input)
        if not _G.FreeCamActive then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            freeCamYaw = freeCamYaw - input.Delta.X * MOUSE_SENS
            freeCamPitch = math.clamp(freeCamPitch - input.Delta.Y * MOUSE_SENS, -math.pi/2 + 0.01, math.pi/2 - 0.01)
        end
    end)

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

        local rotCFrame = CFrame.fromEulerAnglesYXZ(freeCamPitch, freeCamYaw, 0)
        local moveVec = rotCFrame:VectorToWorldSpace(Vector3.new(moveX, 0, moveZ))
        moveVec = moveVec + Vector3.new(0, moveY, 0)

        freeCamCFrame = CFrame.new(freeCamCFrame.Position + moveVec * speed * dt) * rotCFrame.Rotation
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

        -- V3.1: Закрепляем HRP и запоминаем позицию при старте фарма
        saveAndAnchorHRP()
    else
        ToggleButton.Text = "Farm: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        TargetsQueue = {}
        StatusLabel.Text = "Farm Disabled"
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)

        -- V3.1: Отпускаем HRP при выключении фарма
        releaseHRP()
    end
end)

FreeCamButton.MouseButton1Click:Connect(toggleFreeCam)

ClearBlacklistButton.MouseButton1Click:Connect(function()
    Blacklist = setmetatable({}, { __mode = "k" })
    TargetsQueue = {}
    StatusLabel.Text = "Blacklist очищен!"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
end)

-- ===== ПОЛНОЕ ЗАКРЫТИЕ СКРИПТА =====
local fInputConn = nil

local function destroyScript()
    _G.CupBoxFarmActive = false
    _G.ScriptAlive = false

    if _G.FreeCamActive then
        pcall(stopFreeCam)
    end

    TargetsQueue = {}
    Blacklist = setmetatable({}, { __mode = "k" })

    if fInputConn then
        fInputConn:Disconnect()
        fInputConn = nil
    end

    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        camera.CameraType = Enum.CameraType.Custom
    end)

    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end)

    -- V3.1: Снимаем анкор при закрытии
    releaseHRP()

    pcall(function() ScreenGui:Destroy() end)

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

-- ===== ЦИКЛ СКАНИРОВАНИЯ =====
task.spawn(function()
    while _G.ScriptAlive do
        if _G.CupBoxFarmActive then
            pcall(scanWorkspace)
        end
        task.wait(SCAN_INTERVAL)
    end
end)

-- ===== ЦИКЛ ПОДБОРА =====
task.spawn(function()
    while _G.ScriptAlive do
        if _G.CupBoxFarmActive then
            pcall(processQueue)
        end
        task.wait(PICKUP_INTERVAL)
    end
end)
