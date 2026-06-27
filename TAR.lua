--[[
	Auto Cup & Box Farm V2.1
	Основан на лучших механиках TMI V3.3 (InputHoldBegin, игнор supply/$/других игроков, постоянный blacklist).
	- Сохраняет CFrame игрока, после обработки ВСЕХ целей возвращает обратно.
	- Сканирование каждые 5 сек, подбор каждые 0.1 сек.
	- Боксы в приоритете, настоящий hold + расширение дистанции.
	- НОВОЕ: автоматическое закрепление (Anchored) после возврата на исходную позицию.
	  Перед телепортом к цели закрепление снимается, после возврата — включается.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Состояния
local farmActive = false
local scriptAlive = true

-- Очередь целей (заполняется при сканировании)
local targetsQueue = {}

-- Чёрные списки (Instance reference)
local Blacklist = setmetatable({}, { __mode = "k" })          -- временный
local PermanentBlacklist = setmetatable({}, { __mode = "k" })  -- навсегда (открытые боксы)

-- Ключевые слова для инструментов
local TOOL_KEYWORDS = { "cup", "genesis", "gold", "silver", "copper" }

-- Вспомогательные функции
local function matchesKeyword(name)
	local lower = string.lower(name)
	for _, kw in ipairs(TOOL_KEYWORDS) do
		if lower:find(kw) then return true end
	end
	return false
end

local function isInAnyCharacter(model)
	for _, plr in pairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and model:IsDescendantOf(char) then
			return true
		end
	end
	return false
end

local function promptHasDollar(model)
	for _, desc in pairs(model:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			local combined = (desc.ActionText or "") .. (desc.ObjectText or "") .. (desc.Name or "")
			if combined:find("$", 1, true) then
				return true
			end
		end
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

-- Позиция модели (PrimaryPart или первый BasePart)
local function getModelPosition(model)
	if model.PrimaryPart then return model.PrimaryPart.Position end
	for _, child in pairs(model:GetDescendants()) do
		if child:IsA("BasePart") then return child.Position end
	end
	return model:GetPivot().Position
end

-- ========================
-- Сканирование workspace
-- ========================
local function scanWorkspace()
	local newTargets = {}

	-- 1. Боксы (Model/BasePart с "box", исключая "supply")
	for _, obj in pairs(workspace:GetDescendants()) do
		if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end
		local name = string.lower(obj.Name)
		if not name:find("box") then continue end

		-- Игнорируем supply box
		if name:find("supply") then
			Blacklist[obj] = true
			PermanentBlacklist[obj] = true
			continue
		end

		if Blacklist[obj] or PermanentBlacklist[obj] then continue end

		-- Ищем ProximityPrompt (рекурсивно)
		local prompt = nil
		for _, d in pairs(obj:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				prompt = d
				break
			end
		end
		if not prompt then continue end

		-- Проверка на доллар
		if promptHasDollar(obj) then
			Blacklist[obj] = true
			PermanentBlacklist[obj] = true
			continue
		end

		-- Определяем позицию телепорта
		local targetPos = getModelPosition(obj)
		if not targetPos then continue end

		table.insert(newTargets, {
			type = "box",
			obj = obj,
			prompt = prompt,
			pos = targetPos,
			holdDuration = tonumber(prompt.HoldDuration) or 0
		})
	end

	-- 2. Инструменты (Tool/BackpackItem) по ключевым словам
	for _, obj in pairs(workspace:GetDescendants()) do
		if not (obj:IsA("Tool") or obj:IsA("BackpackItem")) then continue end
		if not matchesKeyword(obj.Name) then continue end
		if Blacklist[obj] or PermanentBlacklist[obj] then continue end

		-- Проверки на игнор
		if isInAnyCharacter(obj) then Blacklist[obj] = true; continue end
		if isAnchored(obj) then Blacklist[obj] = true; continue end

		local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
		if handle and not handle.Anchored then
			table.insert(newTargets, {
				type = "tool",
				obj = obj,
				handle = handle,
				pos = handle.Position
			})
		else
			Blacklist[obj] = true
		end
	end

	-- Сортируем: боксы всегда первые
	table.sort(newTargets, function(a, b)
		if a.type == "box" and b.type ~= "box" then return true end
		if a.type ~= "box" and b.type == "box" then return false end
		return false
	end)

	targetsQueue = newTargets
end

-- ========================
-- Обработка одной цели
-- ========================
local busy = false

local function processOneTarget()
	if busy then return end
	if #targetsQueue == 0 then return end

	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	busy = true

	-- Снимаем закрепление перед телепортом
	if hrp.Anchored then
		hrp.Anchored = false
	end

	-- Сохраняем исходный CFrame ДО любых действий
	local originalCFrame = hrp.CFrame

	local target = table.remove(targetsQueue, 1)
	local ok, err = pcall(function()
		if not target.obj or not target.obj.Parent then return end

		if target.type == "tool" then
			-- Дополнительная проверка на существование
			if Blacklist[target.obj] then return end
			if isInAnyCharacter(target.obj) then
				Blacklist[target.obj] = true
				return
			end

			Blacklist[target.obj] = true

			-- Телепорт к предмету
			hrp.CFrame = CFrame.new(target.pos + Vector3.new(0, 2, 0))
			task.wait(0.05)

			-- Подбор
			pcall(function() humanoid:EquipTool(target.obj) end)
			task.wait(0.03)

		elseif target.type == "box" then
			local prompt = target.prompt
			if not prompt or not prompt.Parent then
				Blacklist[target.obj] = true
				PermanentBlacklist[target.obj] = true
				return
			end

			local holdDuration = target.holdDuration
			local totalHoldTime = holdDuration + 0.5

			-- Телепорт к боксу (чуть сверху, чтобы не провалиться)
			local boxCFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))
			hrp.CFrame = boxCFrame

			-- Временно убираем ограничения
			local origMaxDist = prompt.MaxActivationDistance
			local origLineOfSight = prompt.RequiresLineOfSight
			pcall(function() prompt.MaxActivationDistance = math.max(origMaxDist or 0, 50) end)
			pcall(function() prompt.RequiresLineOfSight = false end)

			-- Начинаем удержание
			local holdOk = pcall(function() prompt:InputHoldBegin() end)

			local startTime = tick()
			while tick() - startTime < totalHoldTime do
				if not farmActive or not scriptAlive then break end
				-- Спамим fireproximityprompt для надёжности
				pcall(function() fireproximityprompt(prompt) end)
				-- Удерживаем позицию у бокса
				if hrp.Parent then
					hrp.CFrame = boxCFrame
				end
				task.wait(0.1)
			end

			-- Завершаем удержание
			if holdOk then
				pcall(function() prompt:InputHoldEnd() end)
			end
			-- Финальный рывок
			pcall(function() fireproximityprompt(prompt) end)
			task.wait(0.1)

			-- Восстанавливаем настройки
			pcall(function()
				if origMaxDist then prompt.MaxActivationDistance = origMaxDist end
				if origLineOfSight ~= nil then prompt.RequiresLineOfSight = origLineOfSight end
			end)

			-- Помечаем бокс как обработанный НАВСЕГДА
			Blacklist[target.obj] = true
			PermanentBlacklist[target.obj] = true
		end
	end)

	-- Возврат на исходную позицию (даже если была ошибка)
	pcall(function()
		if hrp and hrp.Parent then
			hrp.CFrame = originalCFrame
			-- ЗАКРЕПЛЯЕМ HRP, если фарм ещё активен
			if farmActive then
				hrp.Anchored = true
			end
		end
	end)

	if not ok then
		warn("[Farm] Ошибка обработки: " .. tostring(err))
	end

	busy = false
end

-- ========================
-- Главные циклы
-- ========================
-- Сканирование каждые 5 секунд (если фарм активен)
task.spawn(function()
	while scriptAlive do
		if farmActive then
			pcall(scanWorkspace)
		end
		task.wait(5)
	end
end)

-- Обработка очереди каждые 0.1 секунды
task.spawn(function()
	while scriptAlive do
		if farmActive and not busy then
			pcall(processOneTarget)
		end
		task.wait(0.1)
	end
end)

-- ========================
-- GUI
-- ========================
local gui = Instance.new("ScreenGui")
gui.Name = "CupBoxFarmGUI"
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

-- Главный фрейм (перемещаемый)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 30)
mainFrame.Position = UDim2.new(0, 100, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 8)
cornerMain.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 120, 0, 30)
titleLabel.Position = UDim2.new(0, 5, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Cup & Box Farm V2.1"
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Кнопка сворачивания/разворачивания
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 30, 0, 30)
toggleBtn.Position = UDim2.new(1, -30, 0, 0)
toggleBtn.Text = "-"
toggleBtn.BackgroundTransparency = 1
toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.Parent = mainFrame

-- Контент (кнопки)
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 0, 80)
contentFrame.Position = UDim2.new(0, 0, 0, 35)
contentFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
contentFrame.BackgroundTransparency = 0.2
contentFrame.BorderSizePixel = 0
contentFrame.Visible = true
contentFrame.Parent = mainFrame

local cornerContent = Instance.new("UICorner")
cornerContent.CornerRadius = UDim.new(0, 8)
cornerContent.Parent = contentFrame

-- Кнопка Auto Farm
local farmBtn = Instance.new("TextButton")
farmBtn.Size = UDim2.new(0, 200, 0, 30)
farmBtn.Position = UDim2.new(0.5, -100, 0, 10)
farmBtn.Text = "Auto Farm (OFF)"
farmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
farmBtn.BackgroundTransparency = 0.3
farmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 14
farmBtn.Parent = contentFrame

local cornerFarmBtn = Instance.new("UICorner")
cornerFarmBtn.CornerRadius = UDim.new(0, 6)
cornerFarmBtn.Parent = farmBtn

-- Кнопка Close GUI
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 200, 0, 30)
closeBtn.Position = UDim2.new(0.5, -100, 0, 45)
closeBtn.Text = "Close GUI"
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.BackgroundTransparency = 0.3
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = contentFrame

local cornerCloseBtn = Instance.new("UICorner")
cornerCloseBtn.CornerRadius = UDim.new(0, 6)
cornerCloseBtn.Parent = closeBtn

-- Логика сворачивания
toggleBtn.MouseButton1Click:Connect(function()
	contentFrame.Visible = not contentFrame.Visible
	toggleBtn.Text = contentFrame.Visible and "-" or "+"
end)

-- Кнопка Auto Farm
farmBtn.MouseButton1Click:Connect(function()
	farmActive = not farmActive
	if farmActive then
		farmBtn.Text = "Auto Farm (ON)"
		farmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	else
		farmBtn.Text = "Auto Farm (OFF)"
		farmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		targetsQueue = {}
		-- Снимаем закрепление при выключении
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
	end
end)

-- Закрытие и полная очистка
closeBtn.MouseButton1Click:Connect(function()
	scriptAlive = false
	farmActive = false
	targetsQueue = {}
	Blacklist = setmetatable({}, { __mode = "k" })
	PermanentBlacklist = setmetatable({}, { __mode = "k" })
	-- Убираем закрепление
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
	end
	gui:Destroy()
end)
