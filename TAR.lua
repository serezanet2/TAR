--[[
	Отдельный скрипт: авто-фарм чаш, кубков, ящиков через ProximityPrompt.
	- Сохраняет позицию игрока, возвращается на неё после сбора всех целей.
	- Ждёт 5 секунд после завершения сессии и начинает новое сканирование.
	- Телепортируется точно к PrimaryPart модели (или к первому найденному BasePart),
	  чтобы избежать проваливания под карту.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmCupsGUI"
gui.Parent = player:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 30)
mainFrame.Position = UDim2.new(0, 100, 0, 100)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.2
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 8)
cornerMain.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 120, 0, 30)
titleLabel.Position = UDim2.new(0, 30, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Cup & Box Farm"
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Кнопка сворачивания/разворачивания
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 30, 0, 30)
toggleBtn.Position = UDim2.new(0, 170, 0, 0)
toggleBtn.Text = "-"
toggleBtn.BackgroundTransparency = 1
toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.Parent = mainFrame

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 0, 80)
contentFrame.Position = UDim2.new(0, 0, 0, 35)
contentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
contentFrame.BackgroundTransparency = 0.2
contentFrame.BorderSizePixel = 0
contentFrame.Visible = true
contentFrame.Parent = mainFrame

local cornerContent = Instance.new("UICorner")
cornerContent.CornerRadius = UDim.new(0, 8)
cornerContent.Parent = contentFrame

-- Кнопка Auto Farm
local autoFarmBtn = Instance.new("TextButton")
autoFarmBtn.Size = UDim2.new(0, 170, 0, 30)
autoFarmBtn.Position = UDim2.new(0, 15, 0, 10)
autoFarmBtn.Text = "Auto Farm (OFF)"
autoFarmBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
autoFarmBtn.BackgroundTransparency = 0.3
autoFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoFarmBtn.Font = Enum.Font.GothamBold
autoFarmBtn.TextSize = 14
autoFarmBtn.Parent = contentFrame

local cornerBtn1 = Instance.new("UICorner")
cornerBtn1.CornerRadius = UDim.new(0, 6)
cornerBtn1.Parent = autoFarmBtn

-- Кнопка закрытия GUI
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 170, 0, 30)
closeBtn.Position = UDim2.new(0, 15, 0, 45)
closeBtn.Text = "Close GUI"
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.BackgroundTransparency = 0.3
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = contentFrame

local cornerBtn2 = Instance.new("UICorner")
cornerBtn2.CornerRadius = UDim.new(0, 6)
cornerBtn2.Parent = closeBtn

-- Логика сворачивания/разворачивания
toggleBtn.MouseButton1Click:Connect(function()
	contentFrame.Visible = not contentFrame.Visible
	toggleBtn.Text = contentFrame.Visible and "-" or "+"
end)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- Управление состоянием
local autoFarmActive = false
local scanCoroutine = nil

-- Функция проверки, находится ли модель в руках игрока (в Character любого игрока)
local function isInAnyCharacter(model)
	for _, plr in pairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and model:IsDescendantOf(char) then
			return true
		end
	end
	return false
end

-- Проверка на символ '$' в ProximityPrompt
local function promptHasDollar(model)
	for _, desc in pairs(model:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			local text = (desc.ActionText or "") .. (desc.ObjectText or "")
			if string.find(text, "$", 1, true) then
				return true
			end
		end
	end
	return false
end

-- Получение корректной позиции модели (PrimaryPart или первый BasePart)
local function getModelPosition(model)
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	-- ищем любой BasePart
	for _, child in pairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child.Position
		end
	end
	-- fallback: используем Pivot, если совсем ничего нет
	return model:GetPivot().Position
end

-- Поиск всех подходящих целей
local function findTargets()
	local targets = {}
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local name = obj.Name
			local lowerName = name:lower()
			-- Ящики: box
			if lowerName:find("box") then
				-- ищем ProximityPrompt внутри
				local hasPrompt = false
				for _, d in pairs(obj:GetDescendants()) do
					if d:IsA("ProximityPrompt") then
						hasPrompt = true
						break
					end
				end
				if hasPrompt then
					table.insert(targets, {model = obj, type = "box"})
				end
			-- Чаши/кубки/генезис: cup или genesis
			elseif lowerName:find("cup") or lowerName:find("genesis") then
				-- Игнорируем, если в руках игрока
				if isInAnyCharacter(obj) then continue end
				-- Игнорируем, если промпт содержит доллар
				if promptHasDollar(obj) then continue end
				-- Нужен промпт для взаимодействия
				local hasPrompt = false
				for _, d in pairs(obj:GetDescendants()) do
					if d:IsA("ProximityPrompt") then
						hasPrompt = true
						break
					end
				end
				if hasPrompt then
					table.insert(targets, {model = obj, type = "cup"})
				end
			end
		end
	end
	return targets
end

-- Активация первого найденного ProximityPrompt в модели
local function activateModelPrompt(model)
	for _, d in pairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			fireproximityprompt(d)
			break
		end
	end
end

-- Основной цикл: одна сессия = сбор всех текущих целей, затем возврат домой и пауза 5 сек
local function autoFarmLoop()
	while autoFarmActive do
		local character = player.Character
		if not character then
			wait(1)
			continue
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			wait(1)
			continue
		end

		-- Сохраняем стартовую позицию
		local startPosition = hrp.Position

		local targets = findTargets()

		if #targets > 0 then
			-- Сортируем по расстоянию от игрока (опционально)
			table.sort(targets, function(a, b)
				local posA = getModelPosition(a.model)
				local posB = getModelPosition(b.model)
				return (startPosition - posA).Magnitude < (startPosition - posB).Magnitude
			end)

			-- Обходим все цели
			for _, t in ipairs(targets) do
				if not autoFarmActive then break end
				local model = t.model
				if model and model.Parent then -- модель всё ещё существует
					local targetPos = getModelPosition(model)
					-- Телепорт к цели (чуть выше, чтобы не провалиться)
					hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
					wait(0.05) -- задержка, чтобы персонаж успел появиться
					activateModelPrompt(model)
					wait(0.1) -- пауза между подборами
				end
			end
		end

		-- Возвращаемся на исходную позицию
		pcall(function()
			hrp.CFrame = CFrame.new(startPosition)
		end)

		-- Ждём 5 секунд до следующего сканирования (следующей сессии)
		wait(5)
	end
end

-- Кнопка Auto Farm
autoFarmBtn.MouseButton1Click:Connect(function()
	autoFarmActive = not autoFarmActive
	if autoFarmActive then
		autoFarmBtn.Text = "Auto Farm (ON)"
		autoFarmBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
		scanCoroutine = coroutine.create(autoFarmLoop)
		coroutine.resume(scanCoroutine)
	else
		autoFarmBtn.Text = "Auto Farm (OFF)"
		autoFarmBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
		if scanCoroutine then
			coroutine.close(scanCoroutine)
			scanCoroutine = nil
		end
	end
end)
