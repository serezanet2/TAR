-- [[ TMI V3.2 — CUSTOM MULTI-KEYWORD & BOX FARMER + FREECAM ]] --
-- Изменения V3.2:
--  * Агрессивный перенос предметов: Backpack -> Character -> UnequipTools()
--  * Усиленный спам Backspace ×5 (только на сохранённой позиции)
--
-- Изменения V3.1:
--  * При старте фарма: HRP закрепляется (Anchored), запоминается CFrame
--  * GUI: показывает состояние HRP и координаты XYZ
-- ... (предыдущие изменения сохранены)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

_G.CupBoxFarmActive = false
_G.FreeCamActive = false
_G.ScriptAlive = true

-- Сохранённая позиция
local SavedCFrame = nil
local WasHRPAnchored = false

-- Настройки
local SCAN_INTERVAL = 5
local PICKUP_INTERVAL = 0.1
local TOOL_KEYWORDS = { "cup", "genesis", "gold", "silver", "copper" }
local Blacklist = setmetatable({}, { __mode = "k" })
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

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 28)
TitleLabel.Text = "TMI V3.2 - AGGRESSIVE DROP"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.Parent = MainFrame

-- [КНОПКИ ТУТ: Farm, FreeCam, ClearBlacklist - пропущены для краткости, они такие же как в V3.1]
-- [Логика кнопок и GUI остаётся прежней, для экономии места]
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 50)
StatusLabel.Position = UDim2.new(0, 5, 0, 186)
StatusLabel.Text = "Ожидание запуска..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Parent = MainFrame

-- ===== V3.2: АГРЕССИВНЫЙ ПЕРЕНОС И СПАМ =====
local function isAtSavedPosition()
    if not SavedCFrame then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return (hrp.Position - SavedCFrame.Position).Magnitude < 3
end

local function moveToolsToCharacterAndSpamBackspace()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not humanoid or not backpack then return end

    -- 1. Перенос всех Tool из Backpack в Character
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() tool.Parent = character end)
        end
    end

    -- 2. Программный сброс
    pcall(function() humanoid:UnequipTools() end)

    -- 3. Агрессивный спам Backspace (если на позиции)
    if isAtSavedPosition() then
        print("[TMI V3.2] Эмуляция Backspace ×5")
        for i = 1, 5 do
            pcall(function()
                UIS:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                task.wait(0.02)
                UIS:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                task.wait(0.02)
            end)
        end
        StatusLabel.Text = "📤 Предметы перемещены + Backspace Spam"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    end
end

-- ===== ФУНКЦИИ HRP (Anchoring) =====
local function saveAndAnchorHRP()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    SavedCFrame = hrp.CFrame
    WasHRPAnchored = hrp.Anchored
    hrp.Anchored = true
    print("[TMI] HRP заанкорен.")
end

local function releaseHRP()
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = WasHRPAnchored end
    end
    SavedCFrame = nil
end

-- [ВЕЗДЕ ГДЕ РАНЬШЕ ВЫЗЫВАЛАСЬ dropAllTools(), теперь вызываем moveToolsToCharacterAndSpamBackspace()]
-- [Остальная логика (сканирование, обработка очереди) аналогична V3.1]
