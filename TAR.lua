--[[
	Auto Cup & Box Farm V4.0 (Complete & Fixed)
	- Боксы: любая Model/BasePart с ProximityPrompt, в иерархии которой есть "box" (кроме "supply")
	- Чаши: только Tool/BackpackItem с cup, genesis, gold, silver, copper
	- Полноценная отладка и корректная работа с workspace.Cups.Box...
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local farmActive = false
local dropActive = false
local scriptAlive = true
local targetsQueue = {}
local blacklist = setmetatable({}, { __mode = "k" })

local gui, mainFrame, contentFrame
local farmBtn, dropBtn, debugBtn, closeBtn
local debugFrame, debugLabel

-- Получение позиции объекта (модели или части)
local function getPos(obj)
	if obj:IsA("Model") then
		if obj.PrimaryPart then return obj.PrimaryPart.Position end
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("BasePart") then return child.Position end
		end
		return obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return Vector3.zero
end

-- Рекурсивный поиск ProximityPrompt внутри объекта
local function getPrompt(obj)
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("ProximityPrompt") then return d end
	end
	return nil
end

-- Запись в отладочное окно
local function debugLog(msg, color)
	if debugLabel then
		debugLabel.Text = msg
		if color then debugLabel.TextColor3 = color end
	end
end

-- Проверка на $ в любом поле промпта
local function hasDollar(prompt)
	local text = (prompt.ActionText or "") .. (prompt.ObjectText or "") .. (prompt.Name or "")
	return text:find("$", 1, true) ~= nil
end

-- Проверка на наличие "box" в иерархии (включая родительские папки)
local function hasBoxInHierarchy(obj)
	local current = obj
	while current and current ~= workspace do
		local name = current.Name:lower()
		if name:find("box") and not name:find("supply") then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Находится ли предмет в рюкзаке/персонаже любого игрока
local function isInAnyCharacter(obj)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and obj:IsDescendantOf(char) then return true end
	end
	return false
end

-- Ключевые слова для инструментов‑чаш
local CUP_NAMES = { "cup", "genesis", "gold", "silver", "copper" }
local function isCupTool(obj)
	if not (obj:IsA("Tool") or obj:IsA("BackpackItem")) then return false end
	local name = obj.Name:lower()
	for _, kw in ipairs(CUP_NAMES) do
		if name:find(kw) then return true end
	end
	return false
end

-- ========================
-- СКАНИРОВАНИЕ
-- ========================
local function scan()
	local list = {}
	local totalPrompts = 0
	local skippedDollar = 0
	local boxCount = 0
	local cupCount = 0

	for _, obj in ipairs(workspace:GetDescendants()) do
		if blacklist[obj] then continue end

		local prompt = getPrompt(obj)
		if not prompt then continue end
		totalPrompts = totalPrompts + 1

		-- Игнорируем промпты с долларом
		if hasDollar(prompt) then
			blacklist[obj] = true
			skippedDollar = skippedDollar + 1
			continue
		end

		-- Инструменты‑чаши (Tool / BackpackItem)
		if isCupTool(obj) then
			if isInAnyCharacter(obj) then
				blacklist[obj] = true
				continue
			end
			local handle = obj:FindFirstChild("Handle")
			if handle and not handle.Anchored then
				table.insert(list, {type = "tool", obj = obj, pos = handle.Position})
				cupCount = cupCount + 1
				blacklist[obj] = true
			end
		-- Боксы: Model или BasePart, в иерархии которых есть "box"
		elseif (obj:IsA("Model") or obj:IsA("BasePart")) and hasBoxInHierarchy(obj) then
			table.insert(list, {
				type = "box",
				obj = obj,
				pos = getPos(obj),
				prompt = prompt,
				dur = tonumber(prompt.HoldDuration) or 0
			})
			boxCount = boxCount + 1
			blacklist[obj] = true
		end
	end

	-- Боксы в начало очереди
	table.sort(list, function(a, b)
		return a.type == "box" and b.type ~= "box"
	end)

	targetsQueue = list

	-- Вывод отладки
	local msg = string.format(
		"Промптов всего: %d\nПропущено $: %d\nБоксов: %d\nЧаш(Tool): %d",
		totalPrompts, skippedDollar, boxCount, cupCount
	)
	debugLog(msg, Color3.fromRGB(200,200,255))
end

-- ========================
-- ОБРАБОТКА ОДНОЙ ЦЕЛИ
-- ========================
local busy = false
local function processTarget()
	if busy or #targetsQueue == 0 then return end
	busy = true

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then busy = false; return end

	local origCFrame = hrp.CFrame
	hrp.Anchored = false

	local target = table.remove(targetsQueue, 1)
	local name = target.obj.Name
	debugLog("-> " .. name .. " (" .. target.type .. ")", Color3.fromRGB(255,255,200))

	pcall(function()
		if not target.obj.Parent then return end

		if target.type == "tool" then
			hrp.CFrame = CFrame.new(target.pos + Vector3.new(0,2,0))
			task.wait(0.05)
			hum:EquipTool(target.obj)
			debugLog("Подобран: " .. name, Color3.fromRGB(0,230,118))
		elseif target.type == "box" then
			local prompt = target.prompt
			local hold = target.dur
			local pos = target.pos + Vector3.new(0,3,0)
			hrp.CFrame = CFrame.new(pos)

			pcall(function() prompt.RequiresLineOfSight = false end)
			pcall(function() prompt.MaxActivationDistance = 50 end)

			if hold > 0 then
				pcall(function() prompt:InputHoldBegin() end)
				local t0 = tick()
				while tick() - t0 < (hold + 0.5) and farmActive do
					pcall(function() fireproximityprompt(prompt) end)
					if hrp.Parent then hrp.CFrame = CFrame.new(pos) end
					task.wait(0.1)
				end
				pcall(function() prompt:InputHoldEnd() end)
			else
				-- Мгновенный бокс
				pcall(function() fireproximityprompt(prompt) end)
			end

			-- Финальное нажатие для надёжности
			pcall(function() fireproximityprompt(prompt) end)
			debugLog("Бокс открыт: " .. name, Color3.fromRGB(0,200,200))
		end
	end)

	-- Возврат на исходную позицию и закрепление
	task.wait(0.15)
	pcall(function()
		if hrp.Parent then
			hrp.CFrame = origCFrame
			if farmActive then hrp.Anchored = true end
		end
	end)

	busy = false
end

-- ========================
-- АВТО‑ДРОП (Backspace)
-- ========================
task.spawn(function()
	while scriptAlive do
		if farmActive and dropActive then
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hrp.Anchored and hum then
				local tools = {}
				local bp = LocalPlayer:FindFirstChild("Backpack")
				if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end end
				if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end end
				if #tools > 0 then
					local tool = tools[math.random(#tools)]
					if tool.Parent ~= char then
						pcall(function() hum:EquipTool(tool) end)
						task.wait(0.1)
					end
					pcall(function()
						VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
						task.wait(0.1)
						VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
					end)
					debugLog("Дроп: " .. tool.Name, Color3.fromRGB(255,180,100))
				end
			end
		end
		task.wait(0.5)
	end
end)

-- ========================
-- ГЛАВНЫЕ ЦИКЛЫ
-- ========================
task.spawn(function() while scriptAlive do if farmActive then scan() end task.wait(5) end end)
task.spawn(function() while scriptAlive do if farmActive then processTarget() end task.wait(0.1) end end)

-- ========================
-- GUI
-- ========================
gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
gui.Name = "FarmGUI"
gui.ResetOnSpawn = false

mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0,220,0,30)
mainFrame.Position = UDim2.new(0,100,0,100)
mainFrame.BackgroundColor3 = Color3.fromRGB(20,25,35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,8)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(0,130,0,30)
title.Position = UDim2.new(0,5,0,0)
title.BackgroundTransparency = 1
title.Text = "Farm V4.0 (Cups.Box)"
title.TextColor3 = Color3.fromRGB(220,220,220)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(0,30,0,30)
toggleBtn.Position = UDim2.new(1,-30,0,0)
toggleBtn.Text = "-"
toggleBtn.BackgroundTransparency = 1
toggleBtn.TextColor3 = Color3.fromRGB(200,200,200)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24

contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1,0,0,120)
contentFrame.Position = UDim2.new(0,0,0,35)
contentFrame.BackgroundColor3 = Color3.fromRGB(30,35,45)
contentFrame.BackgroundTransparency = 0.2
contentFrame.BorderSizePixel = 0
contentFrame.Visible = true
Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0,8)

farmBtn = Instance.new("TextButton", contentFrame)
farmBtn.Size = UDim2.new(0,200,0,28)
farmBtn.Position = UDim2.new(0.5,-100,0,5)
farmBtn.Text = "Farm: OFF"
farmBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
farmBtn.BackgroundTransparency = 0.3
farmBtn.TextColor3 = Color3.fromRGB(255,255,255)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 13
Instance.new("UICorner", farmBtn).CornerRadius = UDim.new(0,6)

dropBtn = Instance.new("TextButton", contentFrame)
dropBtn.Size = UDim2.new(0,200,0,28)
dropBtn.Position = UDim2.new(0.5,-100,0,38)
dropBtn.Text = "Drop: OFF"
dropBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
dropBtn.BackgroundTransparency = 0.3
dropBtn.TextColor3 = Color3.fromRGB(255,255,255)
dropBtn.Font = Enum.Font.GothamBold
dropBtn.TextSize = 13
Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0,6)

debugBtn = Instance.new("TextButton", contentFrame)
debugBtn.Size = UDim2.new(0,200,0,28)
debugBtn.Position = UDim2.new(0.5,-100,0,71)
debugBtn.Text = "Debug: OFF"
debugBtn.BackgroundColor3 = Color3.fromRGB(80,80,120)
debugBtn.BackgroundTransparency = 0.3
debugBtn.TextColor3 = Color3.fromRGB(255,255,255)
debugBtn.Font = Enum.Font.GothamBold
debugBtn.TextSize = 13
Instance.new("UICorner", debugBtn).CornerRadius = UDim.new(0,6)

closeBtn = Instance.new("TextButton", contentFrame)
closeBtn.Size = UDim2.new(0,200,0,28)
closeBtn.Position = UDim2.new(0.5,-100,0,104)
closeBtn.Text = "Close GUI"
closeBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
closeBtn.BackgroundTransparency = 0.3
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

-- Окно отладки
debugFrame = Instance.new("Frame", gui)
debugFrame.Size = UDim2.new(0, 260, 0, 130)
debugFrame.Position = UDim2.new(0, 330, 0, 100)
debugFrame.BackgroundColor3 = Color3.fromRGB(10,10,20)
debugFrame.BorderSizePixel = 1
debugFrame.BorderColor3 = Color3.fromRGB(100,100,255)
debugFrame.Active = true
debugFrame.Draggable = true
debugFrame.Visible = false
Instance.new("UICorner", debugFrame).CornerRadius = UDim.new(0,6)

local debugTitle = Instance.new("TextLabel", debugFrame)
debugTitle.Size = UDim2.new(1,0,0,20)
debugTitle.BackgroundColor3 = Color3.fromRGB(30,30,50)
debugTitle.Text = "DEBUG LOG"
debugTitle.TextColor3 = Color3.fromRGB(200,200,255)
debugTitle.Font = Enum.Font.GothamBold
debugTitle.TextSize = 12
Instance.new("UICorner", debugTitle).CornerRadius = UDim.new(0,4)

debugLabel = Instance.new("TextLabel", debugFrame)
debugLabel.Size = UDim2.new(1,-8,1,-24)
debugLabel.Position = UDim2.new(0,4,0,22)
debugLabel.BackgroundTransparency = 1
debugLabel.Text = "Жду запуска..."
debugLabel.TextColor3 = Color3.fromRGB(180,180,180)
debugLabel.Font = Enum.Font.Gotham
debugLabel.TextSize = 11
debugLabel.TextWrapped = true
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.TextYAlignment = Enum.TextYAlignment.Top

-- Обработчики кнопок
toggleBtn.MouseButton1Click:Connect(function()
	contentFrame.Visible = not contentFrame.Visible
	toggleBtn.Text = contentFrame.Visible and "-" or "+"
end)

farmBtn.MouseButton1Click:Connect(function()
	farmActive = not farmActive
	farmBtn.Text = farmActive and "Farm: ON" or "Farm: OFF"
	farmBtn.BackgroundColor3 = farmActive and Color3.fromRGB(0,200,100) or Color3.fromRGB(200,50,50)
	if not farmActive then
		targetsQueue = {}
		local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end
	end
	debugLog(farmActive and "Farm запущен" or "Farm остановлен", farmActive and Color3.fromRGB(0,200,100) or Color3.fromRGB(200,200,200))
end)

dropBtn.MouseButton1Click:Connect(function()
	dropActive = not dropActive
	dropBtn.Text = dropActive and "Drop: ON" or "Drop: OFF"
	dropBtn.BackgroundColor3 = dropActive and Color3.fromRGB(200,150,0) or Color3.fromRGB(200,50,50)
	debugLog(dropActive and "Дроп включен" or "Дроп выключен", dropActive and Color3.fromRGB(255,180,100) or Color3.fromRGB(200,200,200))
end)

debugBtn.MouseButton1Click:Connect(function()
	debugFrame.Visible = not debugFrame.Visible
	debugBtn.Text = debugFrame.Visible and "Debug: ON" or "Debug: OFF"
	debugBtn.BackgroundColor3 = debugFrame.Visible and Color3.fromRGB(100,100,220) or Color3.fromRGB(80,80,120)
end)

closeBtn.MouseButton1Click:Connect(function()
	scriptAlive = false
	farmActive = false
	dropActive = false
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = false end
	gui:Destroy()
end)

debugLog("V4.0 – Боксы даже в папках", Color3.fromRGB(150,150,150))
