-- ===== V3.4: ХОЛОСТОЙ ДРОП (когда нет целей) через Backspace =====
local VirtualInputManager = game:GetService("VirtualInputManager") -- добавлено

local function idleDrop()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end

    -- Собираем все подходящие Tool из инвентаря
    local toolList = {}
    for _, obj in pairs(backpack:GetChildren()) do
        if obj:IsA("Tool") and matchesKeyword(obj.Name) then
            table.insert(toolList, obj)
        end
    end
    for _, obj in pairs(character:GetChildren()) do
        if obj:IsA("Tool") and matchesKeyword(obj.Name) then
            table.insert(toolList, obj)
        end
    end

    if #toolList == 0 then return end

    local tool = toolList[math.random(#toolList)]
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if not handle then return end

    -- Экипируем инструмент, если он ещё не в руках
    if not tool:IsDescendantOf(character) then
        pcall(function() humanoid:EquipTool(tool) end)
        task.wait(0.1)
    end

    -- Эмулируем нажатие Backspace (игра сама выбросит предмет)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
    task.wait(0.15) -- даём игре время на выбрасывание

    -- После нажатия предмет должен оказаться в workspace; если нет — игнорируем
    if tool.Parent ~= workspace then return end

    -- Убираем из чёрного списка и сразу добавляем в очередь сбора
    Blacklist[tool] = nil
    table.insert(TargetsQueue, {
        type = "tool",
        obj = tool,
        handle = handle,
    })
end
