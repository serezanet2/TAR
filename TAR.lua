--[[
	Auto Cup & Box Farm V3.3 (Reliable Backspace Drop)
	- Универсальный поиск чаш (по мгновенному ProximityPrompt + старые Tool)
	- Возврат на исходную точку, закрепление (Anchored) с задержкой
	- Надёжный дроп через имитацию Backspace (VirtualInputManager)
	- Отладочное окно с логом
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

-- GUI элементы
local gui, mainFrame, contentFrame
local farmBtn, dropBtn, debugBtn, closeBtn
local debugFrame, debugLabel

local function getModelPos(m) return m.PrimaryPart and m.PrimaryPart.Position or m:GetPivot().Position end
local function hasPrompt(m) for _,d in ipairs(m:GetDescendants()) do if d:IsA("ProximityPrompt") then return d end end end

local function debugPrint(msg, color)
	if debugLabel and debugLabel.Parent then
		debugLabel.Text = msg
		if color then debugLabel.TextColor3 = color end
	end
end

-- Сканирование
local function scan()
	local list = {}
	local boxCount = 0
	local cupByPrompt = 0
	local cupByTool = 0

	-- Боксы
	for _, obj in ipairs(workspace:GetDescendants()) do
		if not (obj:IsA("Model") or obj:IsA("BasePart")) then continue end
		local name = obj.Name:lower()
		if not name:find("box") then continue end
		if name:find("supply") then
			blacklist[obj] = true
			continue
		end
		if blacklist[obj] then continue end

		local prompt = hasPrompt(obj)
		if prompt and not (prompt.ActionText and prompt.ActionText:find("$")) then
			table.insert(list, {
				type = "box",
				obj = obj,
				pos = getModelPos(obj),
				prompt = prompt,
				dur = tonumber(prompt.HoldDuration) or 0
			})
			boxCount = boxCount + 1
		end
	end

	-- Чаши через универсальный ProximityPrompt (HoldDuration=0, без '$')
	for _, obj in ipairs(workspace:GetDescendants()) do
		if blacklist[obj] then continue end
		local prompt = hasPrompt(obj)
		if not prompt then continue end
		if tonumber(prompt.HoldDuration) ~= 0 then continue end
		if prompt.ActionText and prompt.ActionText:find("$") then continue end
		local name = obj.Name:lower()
		if name:find("box") then continue end
		local alreadyInList = false
		for _, t in ipairs(list) do
			if t.obj == obj then alreadyInList = true break end
		end
		if not alreadyInList then
			table.insert(list, {
				type = "prompt_cup",
				obj = obj,
				pos = getModelPos(obj),
				prompt = prompt
			})
			cupByPrompt = cupByPrompt + 1
		end
	end

	-- Старые Tool-чаши
	local keywords = { "cup", "genesis", "gold", "silver", "copper" }
	for _, obj in ipairs(workspace:GetDescendants()) do
		if blacklist[obj] then continue end
		if not (obj:IsA("Tool") or obj:IsA("BackpackItem")) then continue end
		local name = obj.Name:lower()
		local matched = false
		for _, kw in ipairs(keywords) do
			if name:find(kw) then matched = true break end
		end
		if not matched then continue end
		if obj:FindFirstChildWhichIsA("Humanoid") then continue end
		local handle = obj:FindFirstChild("Handle")
		if handle and not handle.Anchored then
			table.insert(list, {
				type = "tool",
				obj = obj,
				pos = handle.Position
			})
			cupByTool = cupByTool + 1
		end
	end

	table.sort(list, function(a,b) return a.type=="box" and b.type~="box" end)
	targetsQueue = list
	debugPrint(string.format("Скан: %d боксов | %d чаш(prompt) + %d чаш(tool) = всего %d",
		boxCount, cupByPrompt, cupByTool, #list), Color3.fromRGB(200,200,255))
end

-- Обработка одной цели
local function process()
	if #targetsQueue == 0 then return end
	local char = LocalPlayer.Character
	if not char then debugPrint("Нет персонажа", Color3.fromRGB(255,150,150)); return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then debugPrint("Нет HRP/Humanoid", Color3.fromRGB(255,150,150)); return end

	local origCFrame = hrp.CFrame
	hrp.Anchored = false

	local target = table.remove(targetsQueue, 1)
	local targetName = target.obj.Name
	debugPrint("-> Цель: " .. targetName .. " (" .. target.type .. ")", Color3.fromRGB(255,255,200))

	local ok, err = pcall(function()
		if not target.obj or not target.obj.Parent then
			debugPrint("Цель исчезла", Color3.fromRGB(255,100,100))
			return
		end
		blacklist[target.obj] = true

		if target.type == "tool" then
			hrp.CFrame = CFrame.new(target.pos + Vector3.new(0,2,0))
			task.wait(0.05)
			hum:EquipTool(target.obj)
			debugPrint("Подобран: " .. targetName, Color3.fromRGB(0,230,118))
		elseif target.type == "prompt_cup" then
			hrp.CFrame = CFrame.new(target.pos + Vector3.new(0,2,0))
			task.wait(0.05)
			fireproximityprompt(target.prompt)
			debugPrint("Чаша активирована: " .. targetName, Color3.fromRGB(0,230,118))
		elseif target.type == "box" then
			local prompt = target.prompt
			local dur = target.dur + 0.5
			local boxPos = target.pos + Vector3.new(0,3,0)
			hrp.CFrame = CFrame.new(boxPos)
			pcall(function() prompt.RequiresLineOfSight = false end)
			pcall(function() prompt.MaxActivationDistance = 50 end)
			local t0 = tick()
			pcall(function() prompt:InputHoldBegin() end)
			while tick()-t0 < dur and farmActive do
				pcall(function() fireproximityprompt(prompt) end)
				if hrp.Parent then hrp.CFrame = CFrame.new(boxPos) end
				task.wait(0.1)
			end
			pcall(function() prompt:InputHoldEnd() end)
			pcall(function() fireproximityprompt(prompt) end)
			debugPrint("Бокс открыт: " .. targetName, Color3.fromRGB(0,200,200))
		end
	end)

	if not ok then
		debugPrint("ОШИБКА: " .. tostring(err), Color3.fromRGB(255,50,50))
	end

	task.wait(0.15)
	pcall(function() if hrp.Parent then hrp.CFrame = origCFrame; if farmActive then hrp.Anchored = true end end end)
end

-- Цикл дропа (Backspace)
task.spawn(function()
	while scriptAlive do
		if farmActive and dropActive then
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hrp.Anchored and hum then
				local tools = {}
				local bp = LocalPlayer:FindFirstChild("Backpack")
				if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end end
				if char then for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(tools,t) end end end
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
					debugPrint("Дроп: " .. tool.Name, Color3.fromRGB(255,180,100))
				end
			end
		end
		task.wait(0.5)
	end
end)

-- Главные циклы
task.spawn(function() while scriptAlive do if farmActive then scan() end task.wait(5) end end)
task.spawn(function() while scriptAlive do if farmActive then process() end task.wait(0.1) end end)

-- ===== GUI =====
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
title.Text = "Cup & Box Farm V3.3"
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
debugFrame.Size = UDim2.new(0, 250, 0, 120)
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

-- Обработчики
toggleBtn.MouseButton1Click:Connect(function()
	contentFrame.Visible = not contentFrame.Visible
	toggleBtn.Text = contentFrame.Visible and "-" or "+"
end)

farmBtn.MouseButton1Click:Connect(function()
	farmActive = not farmActive
	if farmActive then
		farmBtn.Text = "Farm: ON"
		farmBtn.BackgroundColor3 = Color3.fromRGB(0,200,100)
		debugPrint("Farm запущен", Color3.fromRGB(0,200,100))
	else
		farmBtn.Text = "Farm: OFF"
		farmBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
		targetsQueue = {}
		local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end
		debugPrint("Farm остановлен", Color3.fromRGB(200,200,200))
	end
end)

dropBtn.MouseButton1Click:Connect(function()
	dropActive = not dropActive
	dropBtn.Text = dropActive and "Drop: ON" or "Drop: OFF"
	dropBtn.BackgroundColor3 = dropActive and Color3.fromRGB(200,150,0) or Color3.fromRGB(200,50,50)
	debugPrint(dropActive and "Дроп включен" or "Дроп выключен", dropActive and Color3.fromRGB(255,180,100) or Color3.fromRGB(200,200,200))
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

debugPrint("V3.3 – Надёжный Backspace-дроп", Color3.fromRGB(150,150,150))
