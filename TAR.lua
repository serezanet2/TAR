-- [[ CUSTOM MULTI-KEYWORD & BOX FARMER + FREECAM (TMI V3.1 — CHARACTER MODE) ]] --
-- Изменения V3.1:
--  * ВСЕ предметы помещаются в МОДЕЛЬ ИГРОКА (Character), а НЕ в Backpack/инвентарь
--    — Тулы лежат в Character (workspace), а не в инвентаре
--  * После возврата — DROP тулов из Character в Workspace
--  * `isInPlayerInventory` проверяет Character вместо Backpack
--  * `dropAllTools` ищет тулы в Character и сбрасывает в Workspace
-- Изменения V3.0:
--  * Игнор боксов с "supply" в имени (Supply Box и т.п.) — в blacklist автоматически
--  * После возврата к исходной точке — DROP всех собранных тулов на землю
-- Изменения V2.9:
--  * НАСТОЯЩЕЕ удержание через prompt:InputHoldBegin() / :InputHoldEnd()
-- Изменения V2.8:
--  * БОКСЫ В ПРИОРИТЕТЕ: всегда обрабатываются раньше тулз
-- Изменения V2.7:
--  * Флаг processingBusy блокирует параллельные цели
-- Изменения V2.6:
--  * Добавлена кнопка ✕ (Close) — полностью удаляет скрипт
-- Изменения V2.5:
--  * Переработаны тайминги: сканирование каждые 5 сек, подбор каждые 0.1 сек
--  * Добавлен упрощённый FreeCam
-- Изменения V2.4:
--  * Бокс может быть Model или BasePart
--  * ProximityPrompt ищется РЕКУРСИВНО внутри бокса
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

-- ===== НАСТРОЙКИ ТАЙМИНГОВ =====
local SCAN_INTERVAL = 5
local PICKUP_INTERVAL = 0.1

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

-- Очередь обнаруженных целей
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
TitleLabel.Text = "TMI V3.1 - Character Mode"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleLabel

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

-- V3.1: ИЗМЕНЕНО — проверяет, находится ли тул в МОДЕЛИ ИГРОКА (Character),
-- а не в Backpack/инвентаре.
local function isInPlayerInventory(tool)
    local character = LocalPlayer.Character
    if character and tool:IsDescendantOf(character) then
        return true
    end
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

-- V3.1: ИЗМЕНЕНО — Сбрасывает все тулы из МОДЕЛИ ИГРОКА (Character) в Workspace.
local function dropAllTools()
    local character = LocalPlayer.Character
    if not character then return 0 end

    local droppedCount = 0

    -- Перебираем все дочерние элементы Character и сбрасываем Tool'ы в Workspace
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            pcall(function()
                child.Parent = workspace
                droppedCount = droppedCount + 1
            end)
        end
    end

    return droppedCount
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

-- ===== СКАНИРОВАНИЕ =====
local function scanWorkspace()
    TargetsQueue = {}

    -- 1. БОКСЫ (Model/BasePart с "box")
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

    -- 2. ИНСТРУМЕНТЫ
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

-- ===== БЫСТРЫЙ ПОДБОР =====
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
    if not targetIndex then targetIndex = 1 end

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

            -- V3.1: ИЗМЕНЕНО — Помещаем тул ПРЯМО в Character (модель игрока),
            -- а НЕ через EquipTool (который кладёт в Backpack).
            pcall(function()
                target.obj.Parent = character
            end)

            task.wait(0.03)
            hrp.CFrame = originalCFrame

            task.wait(0.05)
            local dropped = dropAllTools()
            if dropped > 0 then
                StatusLabel.Text = string.format("📤 Сброшено %d тулз", dropped)
            end

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
                if hrp.Parent then hrp.CFrame = boxCFrame end
                task.wait()
            end

            if holdBeginOk then pcall(function() prompt:InputHoldEnd() end) end
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.1)

            if triggeredConn then pcall(function() triggeredConn:Disconnect() end) end

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

            task.wait(0.1)
            local dropped = dropAllTools()
            if dropped > 0 then
                StatusLabel.Text = string.format("📤 Сброшено %d тулз после бокса", dropped)
            end
        end
    end)

    processingBusy = false
    if not ok then
        warn("[TMI V3.1] processQueue error: " .. tostring(err))
    end
end

-- ===== FREECAM =====
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
    if freeCamRender then freeCamRender:Disconnect(); freeCamRender = nil end
    if freeCamMouseConn then freeCamMouseConn:Disconnect(); freeCamMouseConn = nil end
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
        StatusLabel.Text = "Farm Enabled. Скан каждые 5с, подбор каждые 0.1с\nТулы → Character (не Backpack)"
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

-- ===== ПОЛНОЕ ЗАКРЫТИЕ =====
local fInputConn = nil

local function destroyScript()
    _G.CupBoxFarmActive = false
    _G.ScriptAlive = false
    if _G.FreeCamActive then pcall(stopFreeCam) end
    TargetsQueue = {}
    Blacklist = setmetatable({}, { __mode = "k" })
    if fInputConn then fInputConn:Disconnect(); fInputConn = nil end
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
    pcall(function() ScreenGui:Destroy() end)
    _G.CupBoxFarmActive = nil
    _G.FreeCamActive = nil
    _G.ScriptAlive = nil
end

CloseButton.MouseButton1Click:Connect(destroyScript)

fInputConn = UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F and _G.FreeCamActive then
        stopFreeCam()
    end
end)

task.spawn(function()
    while _G.ScriptAlive do
        if _G.CupBoxFarmActive then pcall(scanWorkspace) end
        task.wait(SCAN_INTERVAL)
    end
end)

task.spawn(function()
    while _G.ScriptAlive do
        if _G.CupBoxFarmActive then pcall(processQueue) end
        task.wait(PICKUP_INTERVAL)
    end
end)
