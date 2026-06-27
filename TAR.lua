--[[
	Auto Cup & Box Farm V2.2
	- Сохраняет CFrame игрока, после обработки целей возвращает обратно и закрепляет (Anchored).
	- Сканирование каждые 5 сек, подбор каждые 0.1 сек.
	- Боксы в приоритете, настоящий hold + расширение дистанции.
	- НОВОЕ: кнопка "Auto Drop" – пока персонаж закреплён, случайный предмет выбрасывается (имитация Backspace).
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- Состояния
local farmActive = false
local autoDropActive = false
local scriptAlive = true

-- Очередь целей
local targetsQueue = {}

-- Чёрные списки (Instance reference)
local Blacklist = setmetatable({}, { __mode = "k" })
local PermanentBlacklist = setmetatable({}, { __mode = "k" })

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

local function getModelPosition(model)
	if model.PrimaryPart then return model.PrimaryPart.Position end
	for _, child in pairs(model:GetDescendants()) do
		if child:IsA("BasePart") then return child.Position end
	end
	return model:GetPivot().Position
end

-- Сканирование workspace
local function scanWorkspace()
	local newTargets = {}

	-- 1. Боксы
	for _, obj in pairs(workspace:GetDescendants()) do
		if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end
		local name = string.lower(obj.Name)
		if not name:find("box") then continue end
		if name:find("supply") then
			Blacklist[obj] = true
			PermanentBlacklist[obj] = true
			continue
		end
		if Blacklist[obj] or PermanentBlacklist[obj] then continue end

		local prompt = nil
		for _, d in pairs(obj:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				prompt = d
				break
			end
		end
		if not prompt then continue end
		if promptHasDollar(obj) then
			Blacklist[obj] = true
			PermanentBlacklist[obj] = true
			continue
		end

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

	-- 2. Инструменты
	for _, obj in pairs(workspace:GetDescendants()) do
		if not (obj:IsA("Tool") or obj:IsA("BackpackItem")) then continue end
		if not matchesKeyword(obj.Name) then continue end
		if Blacklist[obj] or PermanentBlacklist[obj] then continue end
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

	-- Боксы первые
	table.sort(newTargets, function(a, b)
		if a.type == "box" and b.type ~= "box" then return true end
		if a.type ~= "box" and b.type == "box" then return false end
		return false
	end)

	targetsQueue = newTargets
end

-- Выброс случайного предмета
local function dropRandomItem()
	local character = LocalPlayer.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local tools = {}
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then table.insert(tools, item) end
		end
	end
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Tool") then table.insert(tools, item) end
	end
	if #tools == 0 then return end

	local randomTool = tools[math.random(#tools)]
	if randomTool.Parent ~= character then
		pcall(function() humanoid:EquipTool(randomTool) end)
		task.wait(0.1)
	end

	-- Имитация Backspace
	pcall(function()
		VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
		task.wait(0.1)
		VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
	end)
end

-- Цикл авто-дропа (работает, пока персонаж закреплён)
task.spawn(function()
	while scriptAlive do
		if farmActive and autoDropActive then
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Anchored then
				pcall(dropRandomItem)
				task.wait(0.5)
			end
		end
		task.wait(0.2)
	end
end)

-- Обработка одной цели
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

	if hrp.Anchored then
		hrp.Anchored = false
	end

	local originalCFrame = hrp.CFrame
	local target = table.remove(targetsQueue, 1)

	local ok, err = pcall(function()
		if not target.obj or not target.obj.Parent then return end

		if target.type == "tool" then
			if Blacklist[target.obj] then return end
			if isInAnyCharacter(target.obj) then
				Blacklist[target.obj] = true
				return
			end
			Blacklist[target.obj] = true

			hrp.CFrame = CFrame.new(target.pos + Vector3.new(0, 2, 0))
			task.wait(0.05)
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

			local boxCFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))
			hrp.CFrame = boxCFrame

			local origMaxDist = prompt.MaxActivationDistance
			local origLineOfSight = prompt.RequiresLineOfSight
			pcall(function() prompt.MaxActivationDistance = math.max(origMaxDist or 0, 50) end)
			pcall(function() prompt.RequiresLineOfSight = false end)

			local holdOk = pcall(function() prompt:InputHoldBegin() end)

			local startTime = tick()
			while tick() - startTime < totalHoldTime do
				if not farmActive or not scriptAlive then break end
				pcall(function() fireproximityprompt(prompt) end)
				if hrp.Parent then
					hrp.CFrame = boxCFrame
				end
				task.wait(0.1)
			end

			if holdOk then
				pcall(function() prompt:InputHoldEnd() end)
			end
			pcall(function() fireproximityprompt(prompt) end)
			task.wait(0.1)

			pcall(function()
				if origMaxDist then prompt.MaxActivationDistance = origMaxDist end
				if origLineOfSight ~= nil then prompt.RequiresLineOfSight = origLineOfSight end
			end)

			Blacklist[target.obj] = true
			PermanentBlacklist[target.obj] = true
		end
	end)

	pcall(function()
		if hrp and hrp.Parent then
			hrp.CFrame = originalCFrame
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

-- Главные циклы
task.spawn(function()
	while scriptAlive do
		if farmActive then
			pcall(scanWorkspace)
		end
		task.wait(5)
	end
end)

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
titleLabel.Text = "Cup & Box Farm V2.2"
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 30, 0, 30)
toggleBtn.Position = UDim2.new(1, -30, 0, 0)
toggleBtn.Text = "-"
toggleBtn.BackgroundTransparency = 1
toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.Parent = mainFrame

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 0, 120)  -- увеличена высота
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

-- Кнопка Auto Drop
local dropBtn = Instance.new("TextButton")
dropBtn.Size = UDim2.new(0, 200, 0, 30)
dropBtn.Position = UDim2.new(0.5, -100, 0, 45)
dropBtn.Text = "Auto Drop (OFF)"
dropBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
dropBtn.BackgroundTransparency = 0.3
dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dropBtn.Font = Enum.Font.GothamBold
dropBtn.TextSize = 14
dropBtn.Parent = contentFrame

local cornerDropBtn = Instance.new("UICorner")
cornerDropBtn.CornerRadius = UDim.new(0, 6)
cornerDropBtn.Parent = dropBtn

-- Кнопка Close GUI
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 200, 0, 30)
closeBtn.Position = UDim2.new(0.5, -100, 0, 80)
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

-- Auto Farm
farmBtn.MouseButton1Click:Connect(function()
	farmActive = not farmActive
	if farmActive then
		farmBtn.Text = "Auto Farm (ON)"
		farmBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	else
		farmBtn.Text = "Auto Farm (OFF)"
		farmBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		targetsQueue = {}
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end
	end
end)

-- Auto Drop
dropBtn.MouseButton1Click:Connect(function()
	autoDropActive = not autoDropActive
	if autoDropActive then
		dropBtn.Text = "Auto Drop (ON)"
		dropBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
	else
		dropBtn.Text = "Auto Drop (OFF)"
		dropBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end
end)

-- Закрытие
closeBtn.MouseButton1Click:Connect(function()
	scriptAlive = false
	farmActive = false
	autoDropActive = false
	targetsQueue = {}
	Blacklist = setmetatable({}, { __mode = "k" })
	PermanentBlacklist = setmetatable({}, { __mode = "k" })
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = false end
	gui:Destroy()
end)
