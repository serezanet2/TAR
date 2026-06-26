--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local FileName = "TMI_V1_Settings.json"

local Settings = {
    DeleteList = {"Blood Cup", "Oil Cup", "Acid Cup", "Light Cup"},
    OpenList = {"chest"},
    CollectionInterval = 0.1,
    TeleportInterval = 0.1,
    SafeHeight = -5.75
}

if isfile(FileName) then
    pcall(function()
        Settings = HttpService:JSONDecode(readfile(FileName))
        if not Settings.SafeHeight then Settings.SafeHeight = -5.75 end
    end)
end

local function SaveSettings()
    writefile(FileName, HttpService:JSONEncode(Settings))
end

game.Workspace.FallenPartsDestroyHeight = -50000

_G.AutoFarm = false
_G.AutoDelete = false
_G.IsFloating = false
_G.AutoOpen = false
_G.CanTouchEnabled = true
_G.SafeMode = false
_G.GrabTools = false
_G.KillNPCsLoop = false
_G.GuiAlive = true

local Noclipping = nil
local GrabToolsConnections = {}

local DeleteCupsFolder = workspace:FindFirstChild("DELETECUPSFOLDER")
if not DeleteCupsFolder then
    DeleteCupsFolder = Instance.new("Folder")
    DeleteCupsFolder.Name = "DELETECUPSFOLDER"
    DeleteCupsFolder.Parent = workspace
end

local function NoclipLoop()
    local character = Players.LocalPlayer.Character
    if character then
        for _, child in pairs(character:GetDescendants()) do
            if child:IsA("BasePart") and child.CanCollide == true then
                child.CanCollide = false
            end
        end
    end
end

local function EnableSafeMode()
    local character = Players.LocalPlayer.Character
    if not character then return end
    local HRP = character:FindFirstChild("HumanoidRootPart")
    local Humanoid = character:FindFirstChild("Humanoid")
    
    if not Noclipping then
        Noclipping = RunService.Stepped:Connect(NoclipLoop)
    end

    if HRP and Humanoid then
        local BG = Instance.new('BodyGyro')
        local BV = Instance.new('BodyVelocity')
        BG.Name = "SafeModeBG"
        BV.Name = "SafeModeBV"
        BG.P = 9e4
        BG.Parent = HRP
        BV.Parent = HRP
        BG.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        BG.CFrame = HRP.CFrame
        BV.Velocity = Vector3.new(0, 0, 0)
        BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        Humanoid.PlatformStand = true
    end
end

local function DisableSafeMode()
    if Noclipping then
        Noclipping:Disconnect()
        Noclipping = nil
    end

    local character = Players.LocalPlayer.Character
    if character then
        local HRP = character:FindFirstChild("HumanoidRootPart")
        local Humanoid = character:FindFirstChild("Humanoid")
        
        if HRP then
            if HRP:FindFirstChild("SafeModeBG") then HRP.SafeModeBG:Destroy() end
            if HRP:FindFirstChild("SafeModeBV") then HRP.SafeModeBV:Destroy() end
        end
        
        if Humanoid then
            Humanoid.PlatformStand = false
        end
    end
end

if game:GetService("CoreGui"):FindFirstChild("TMIV1Gui") then
    game:GetService("CoreGui").TMIV1Gui:Destroy()
end

local TMIV1Gui = Instance.new("ScreenGui")
TMIV1Gui.Name = "TMIV1Gui"
TMIV1Gui.Parent = game.CoreGui
TMIV1Gui.ResetOnSpawn = false

local Frame = Instance.new("Frame")
Frame.Parent = TMIV1Gui
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Frame.BackgroundTransparency = 0.2
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0, 100, 0, 100)
Frame.Size = UDim2.new(0, 180, 0, 30)
Frame.Active = true
Frame.Draggable = true

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = Frame

local Frame2 = Instance.new("Frame")
Frame2.Parent = Frame
Frame2.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Frame2.BackgroundTransparency = 0.2
Frame2.BorderSizePixel = 0
Frame2.Position = UDim2.new(0, 0, 0, 35)
Frame2.Size = UDim2.new(0, 180, 0, 205)
Frame2.Visible = true

local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0, 8)
corner2.Parent = Frame2

local Frame3 = Instance.new("Frame")
Frame3.Parent = Frame
Frame3.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Frame3.BackgroundTransparency = 0.2
Frame3.BorderSizePixel = 0
Frame3.Position = UDim2.new(0, 0, 0, 35)
Frame3.Size = UDim2.new(0, 180, 0, 205)
Frame3.Visible = false

local corner3 = Instance.new("UICorner")
corner3.CornerRadius = UDim.new(0, 8)
corner3.Parent = Frame3

local SettingsFrame = Instance.new("Frame")
SettingsFrame.Parent = Frame
SettingsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SettingsFrame.BackgroundTransparency = 0.1
SettingsFrame.BorderSizePixel = 0
SettingsFrame.Position = UDim2.new(1, 10, 0, 0)
SettingsFrame.Size = UDim2.new(0, 140, 0, 135)
SettingsFrame.Visible = false
SettingsFrame.ClipsDescendants = true

local cornerSettings = Instance.new("UICorner")
cornerSettings.CornerRadius = UDim.new(0, 8)
cornerSettings.Parent = SettingsFrame

local DeletedViewFrame = Instance.new("Frame")
DeletedViewFrame.Parent = Frame
DeletedViewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
DeletedViewFrame.BackgroundTransparency = 0.1
DeletedViewFrame.BorderSizePixel = 0
DeletedViewFrame.Position = UDim2.new(1, 10, 0, 0)
DeletedViewFrame.Size = UDim2.new(0, 160, 0, 200)
DeletedViewFrame.Visible = false
DeletedViewFrame.ClipsDescendants = true

local cornerDeletedView = Instance.new("UICorner")
cornerDeletedView.CornerRadius = UDim.new(0, 8)
cornerDeletedView.Parent = DeletedViewFrame

local DeletedViewTitle = Instance.new("TextLabel")
DeletedViewTitle.Parent = DeletedViewFrame
DeletedViewTitle.Size = UDim2.new(1, -30, 0, 25)
DeletedViewTitle.Position = UDim2.new(0, 5, 0, 5)
DeletedViewTitle.Text = "Deleted Tools"
DeletedViewTitle.BackgroundTransparency = 1
DeletedViewTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
DeletedViewTitle.TextSize = 12
DeletedViewTitle.Font = Enum.Font.GothamBold
DeletedViewTitle.TextXAlignment = Enum.TextXAlignment.Left

local DeletedViewClose = Instance.new("TextButton")
DeletedViewClose.Parent = DeletedViewFrame
DeletedViewClose.Size = UDim2.new(0, 20, 0, 20)
DeletedViewClose.Position = UDim2.new(1, -25, 0, 5)
DeletedViewClose.Text = "×"
DeletedViewClose.BackgroundTransparency = 1
DeletedViewClose.TextColor3 = Color3.fromRGB(255, 100, 100)
DeletedViewClose.TextSize = 18
DeletedViewClose.Font = Enum.Font.GothamBold
DeletedViewClose.MouseButton1Click:Connect(function()
    DeletedViewFrame.Visible = false
end)

local DeletedScroll = Instance.new("ScrollingFrame")
DeletedScroll.Parent = DeletedViewFrame
DeletedScroll.Size = UDim2.new(1, -10, 1, -35)
DeletedScroll.Position = UDim2.new(0, 5, 0, 30)
DeletedScroll.BackgroundTransparency = 1
DeletedScroll.ScrollBarThickness = 4
DeletedScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local DeletedUIList = Instance.new("UIListLayout")
DeletedUIList.Parent = DeletedScroll
DeletedUIList.SortOrder = Enum.SortOrder.LayoutOrder
DeletedUIList.Padding = UDim.new(0, 3)

local function GetDeletedToolsCounts()
    local counts = {}
    if DeleteCupsFolder and DeleteCupsFolder.Parent then
        for _, tool in pairs(DeleteCupsFolder:GetChildren()) do
            if tool:IsA("Tool") then
                counts[tool.Name] = (counts[tool.Name] or 0) + 1
            end
        end
    end
    return counts
end

local function RestoreToolsByName(toolName)
    local player = Players.LocalPlayer
    local backpack = player:FindFirstChild("Backpack")
    if backpack and DeleteCupsFolder and DeleteCupsFolder.Parent then
        for _, tool in pairs(DeleteCupsFolder:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == toolName then
                tool.Parent = backpack
            end
        end
    end
end

local RestoreConnections = {}

local function RefreshDeletedView()
    if not DeletedScroll or not DeletedScroll.Parent then return end
    
    for _, conn in pairs(RestoreConnections) do
        if conn then conn:Disconnect() end
    end
    RestoreConnections = {}
    
    for _, v in pairs(DeletedScroll:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end
    
    local counts = GetDeletedToolsCounts()
    
    for toolName, count in pairs(counts) do
        local ItemFrame = Instance.new("Frame")
        ItemFrame.Parent = DeletedScroll
        ItemFrame.Size = UDim2.new(1, 0, 0, 22)
        ItemFrame.BackgroundTransparency = 1
        
        local RestoreBtn = Instance.new("TextButton")
        RestoreBtn.Parent = ItemFrame
        RestoreBtn.Size = UDim2.new(0, 20, 0, 20)
        RestoreBtn.Position = UDim2.new(1, -22, 0, 1)
        RestoreBtn.Text = "↩"
        RestoreBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 40)
        RestoreBtn.BackgroundTransparency = 0.3
        RestoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        RestoreBtn.TextSize = 12
        RestoreBtn.Font = Enum.Font.GothamBold
        
        local cRestore = Instance.new("UICorner")
        cRestore.CornerRadius = UDim.new(0, 4)
        cRestore.Parent = RestoreBtn
        
        local conn = RestoreBtn.MouseButton1Click:Connect(function()
            RestoreToolsByName(toolName)
            RefreshDeletedView()
        end)
        table.insert(RestoreConnections, conn)
        
        local displayText = toolName
        if count > 1 then
            displayText = toolName .. " x" .. count
        end
        
        local Lbl = Instance.new("TextLabel")
        Lbl.Parent = ItemFrame
        Lbl.Size = UDim2.new(1, -28, 1, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.Text = displayText
        Lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        Lbl.TextXAlignment = Enum.TextXAlignment.Left
        Lbl.Font = Enum.Font.Gotham
        Lbl.TextSize = 11
        Lbl.TextTruncate = Enum.TextTruncate.AtEnd
    end
    
    DeletedScroll.CanvasSize = UDim2.new(0, 0, 0, DeletedUIList.AbsoluteContentSize.Y)
end

spawn(function()
    while _G.GuiAlive do
        wait(3)
        if _G.GuiAlive and DeletedViewFrame and DeletedViewFrame.Parent and DeletedViewFrame.Visible then
            RefreshDeletedView()
        end
    end
end)

local TextLabel = Instance.new("TextLabel")
TextLabel.Parent = Frame
TextLabel.Size = UDim2.new(0, 100, 0, 30)
TextLabel.Position = UDim2.new(0, 30, 0, 0)
TextLabel.Text = "TMI V1"
TextLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TextLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
TextLabel.TextSize = 16
TextLabel.TextScaled = false
TextLabel.BackgroundTransparency = 1
TextLabel.Font = Enum.Font.GothamBold
TextLabel.TextXAlignment = Enum.TextXAlignment.Left

local KillGui = Instance.new("TextButton")
KillGui.Parent = Frame
KillGui.Size = UDim2.new(0, 30, 0, 30)
KillGui.Position = UDim2.new(0, 0, 0, 0)
KillGui.Text = "×"
KillGui.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
KillGui.BackgroundTransparency = 1
KillGui.TextColor3 = Color3.fromRGB(255, 100, 100)
KillGui.TextSize = 24
KillGui.Font = Enum.Font.GothamBold

KillGui.MouseButton1Up:Connect(function()
    _G.GuiAlive = false
    _G.AutoFarm = false
    _G.AutoDelete = false
    _G.IsFloating = false
    _G.AutoOpen = false
    _G.CanTouchEnabled = true
    _G.SafeMode = false
    _G.GrabTools = false
    _G.KillNPCsLoop = false
    for _, conn in pairs(GrabToolsConnections) do
        if conn then conn:Disconnect() end
    end
    GrabToolsConnections = {}
    for _, conn in pairs(RestoreConnections) do
        if conn then conn:Disconnect() end
    end
    RestoreConnections = {}
    DisableSafeMode()
    TMIV1Gui:Destroy()
end)

local Mini = Instance.new("TextButton")
Mini.Parent = Frame
Mini.Size = UDim2.new(0, 30, 0, 30)
Mini.Position = UDim2.new(0, 150, 0, 0)
Mini.Text = "-"
Mini.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Mini.BackgroundTransparency = 1
Mini.TextColor3 = Color3.fromRGB(200, 200, 200)
Mini.TextSize = 24
Mini.Font = Enum.Font.GothamBold

Mini.MouseButton1Up:Connect(function()
    if Mini.Text == "-" then
        Mini.Text = "+"
        Frame2.Visible = false
        Frame3.Visible = false
        SettingsFrame.Visible = false
        DeletedViewFrame.Visible = false
    else
        Mini.Text = "-"
        Frame2.Visible = true
        Frame3.Visible = false
    end
end)

local function createButton(parent, text, position, color, width)
    local btn = Instance.new("TextButton")
    btn.Parent = parent
    btn.Size = UDim2.new(0, width or 160, 0, 28)
    btn.Position = position
    btn.Text = text
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.3
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    return btn
end

local function createListManager(parentFrame, listTable, saveFunc)
    local ManagerFrame = Instance.new("Frame")
    ManagerFrame.Parent = parentFrame
    ManagerFrame.Size = UDim2.new(1, 0, 1, 0)
    ManagerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ManagerFrame.BorderSizePixel = 0
    ManagerFrame.Visible = false
    ManagerFrame.ZIndex = 5

    local cManager = Instance.new("UICorner")
    cManager.CornerRadius = UDim.new(0, 8)
    cManager.Parent = ManagerFrame

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = ManagerFrame
    CloseBtn.Size = UDim2.new(0, 20, 0, 20)
    CloseBtn.Position = UDim2.new(1, -25, 0, 5)
    CloseBtn.Text = "×"
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseBtn.TextSize = 20
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.ZIndex = 6
    CloseBtn.MouseButton1Click:Connect(function() ManagerFrame.Visible = false end)

    local InputBox = Instance.new("TextBox")
    InputBox.Parent = ManagerFrame
    InputBox.Size = UDim2.new(0, 110, 0, 25)
    InputBox.Position = UDim2.new(0, 5, 0, 5)
    InputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.PlaceholderText = "Name/Key..."
    InputBox.Text = ""
    InputBox.Font = Enum.Font.Gotham
    InputBox.TextSize = 12
    InputBox.ZIndex = 6
    
    local cInput = Instance.new("UICorner")
    cInput.CornerRadius = UDim.new(0, 4)
    cInput.Parent = InputBox

    local AddBtn = Instance.new("TextButton")
    AddBtn.Parent = ManagerFrame
    AddBtn.Size = UDim2.new(0, 30, 0, 25)
    AddBtn.Position = UDim2.new(0, 120, 0, 5)
    AddBtn.Text = "+"
    AddBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
    AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AddBtn.Font = Enum.Font.GothamBold
    AddBtn.TextSize = 16
    AddBtn.ZIndex = 6

    local cAdd = Instance.new("UICorner")
    cAdd.CornerRadius = UDim.new(0, 4)
    cAdd.Parent = AddBtn

    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Parent = ManagerFrame
    Scroll.Size = UDim2.new(1, -10, 1, -40)
    Scroll.Position = UDim2.new(0, 5, 0, 35)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness = 4
    Scroll.ZIndex = 6
    Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local UIList = Instance.new("UIListLayout")
    UIList.Parent = Scroll
    UIList.SortOrder = Enum.SortOrder.LayoutOrder
    UIList.Padding = UDim.new(0, 2)

    local listConnections = {}

    local function RefreshList()
        for _, conn in pairs(listConnections) do
            if conn then conn:Disconnect() end
        end
        listConnections = {}
        
        for _, v in pairs(Scroll:GetChildren()) do
            if v:IsA("Frame") then v:Destroy() end
        end
        for i, item in ipairs(listTable) do
            local ItemFrame = Instance.new("Frame")
            ItemFrame.Parent = Scroll
            ItemFrame.Size = UDim2.new(1, 0, 0, 20)
            ItemFrame.BackgroundTransparency = 1
            ItemFrame.ZIndex = 7

            local DelBtn = Instance.new("TextButton")
            DelBtn.Parent = ItemFrame
            DelBtn.Size = UDim2.new(0, 20, 0, 20)
            DelBtn.Position = UDim2.new(1, -20, 0, 0)
            DelBtn.Text = "×"
            DelBtn.BackgroundTransparency = 1
            DelBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
            DelBtn.TextSize = 14
            DelBtn.Font = Enum.Font.GothamBold
            DelBtn.ZIndex = 8

            local conn = DelBtn.MouseButton1Click:Connect(function()
                table.remove(listTable, i)
                saveFunc()
                RefreshList()
            end)
            table.insert(listConnections, conn)

            local Lbl = Instance.new("TextLabel")
            Lbl.Parent = ItemFrame
            Lbl.Size = UDim2.new(1, -25, 1, 0)
            Lbl.BackgroundTransparency = 1
            Lbl.Text = item
            Lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
            Lbl.TextXAlignment = Enum.TextXAlignment.Left
            Lbl.Font = Enum.Font.Gotham
            Lbl.TextSize = 12
            Lbl.ZIndex = 7
        end
        Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y)
    end

    AddBtn.MouseButton1Click:Connect(function()
        if InputBox.Text ~= "" then
            table.insert(listTable, InputBox.Text)
            InputBox.Text = ""
            saveFunc()
            RefreshList()
        end
    end)

    RefreshList()
    return ManagerFrame
end

local AutoFarmButton = createButton(Frame2, "Auto Farm (Off)", UDim2.new(0, 10, 0, 10), Color3.fromRGB(180, 40, 40))

local GearButton = Instance.new("TextButton")
GearButton.Parent = Frame2
GearButton.Size = UDim2.new(0, 20, 0, 20)
GearButton.Position = UDim2.new(1, -25, 0, 175)
GearButton.Text = "⚙"
GearButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GearButton.BackgroundTransparency = 1
GearButton.TextColor3 = Color3.fromRGB(150, 150, 150)
GearButton.TextSize = 18
GearButton.Font = Enum.Font.GothamBold

GearButton.MouseButton1Click:Connect(function()
    SettingsFrame.Visible = not SettingsFrame.Visible
    DeletedViewFrame.Visible = false
end)

local CollectIntervalLabel = Instance.new("TextLabel")
CollectIntervalLabel.Parent = SettingsFrame
CollectIntervalLabel.Size = UDim2.new(0, 80, 0, 25)
CollectIntervalLabel.Position = UDim2.new(0, 5, 0, 15)
CollectIntervalLabel.Text = "Collect (s):"
CollectIntervalLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
CollectIntervalLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
CollectIntervalLabel.TextSize = 12
CollectIntervalLabel.TextXAlignment = Enum.TextXAlignment.Left
CollectIntervalLabel.BackgroundTransparency = 1
CollectIntervalLabel.Font = Enum.Font.Gotham

local CollectIntervalInput = Instance.new("TextBox")
CollectIntervalInput.Parent = SettingsFrame
CollectIntervalInput.Size = UDim2.new(0, 40, 0, 25)
CollectIntervalInput.Position = UDim2.new(0, 90, 0, 15)
CollectIntervalInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
CollectIntervalInput.BackgroundTransparency = 0.2
CollectIntervalInput.BorderSizePixel = 0
CollectIntervalInput.TextColor3 = Color3.fromRGB(255, 255, 255)
CollectIntervalInput.Text = tostring(Settings.CollectionInterval)
CollectIntervalInput.Font = Enum.Font.Gotham
CollectIntervalInput.TextSize = 12
CollectIntervalInput.ClearTextOnFocus = false
local cornerCollectInput = Instance.new("UICorner")
cornerCollectInput.CornerRadius = UDim.new(0, 4)
cornerCollectInput.Parent = CollectIntervalInput

CollectIntervalInput.FocusLost:Connect(function()
    local num = tonumber(CollectIntervalInput.Text)
    if num and num >= 0 then
        Settings.CollectionInterval = num
        SaveSettings()
        CollectIntervalInput.Text = tostring(num)
    else
        CollectIntervalInput.Text = tostring(Settings.CollectionInterval)
    end
end)

local TeleportIntervalLabel = Instance.new("TextLabel")
TeleportIntervalLabel.Parent = SettingsFrame
TeleportIntervalLabel.Size = UDim2.new(0, 80, 0, 25)
TeleportIntervalLabel.Position = UDim2.new(0, 5, 0, 50)
TeleportIntervalLabel.Text = "TP Delay (s):"
TeleportIntervalLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TeleportIntervalLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
TeleportIntervalLabel.TextSize = 12
TeleportIntervalLabel.TextXAlignment = Enum.TextXAlignment.Left
TeleportIntervalLabel.BackgroundTransparency = 1
TeleportIntervalLabel.Font = Enum.Font.Gotham

local TeleportIntervalInput = Instance.new("TextBox")
TeleportIntervalInput.Parent = SettingsFrame
TeleportIntervalInput.Size = UDim2.new(0, 40, 0, 25)
TeleportIntervalInput.Position = UDim2.new(0, 90, 0, 50)
TeleportIntervalInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
TeleportIntervalInput.BackgroundTransparency = 0.2
TeleportIntervalInput.BorderSizePixel = 0
TeleportIntervalInput.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportIntervalInput.Text = tostring(Settings.TeleportInterval)
TeleportIntervalInput.Font = Enum.Font.Gotham
TeleportIntervalInput.TextSize = 12
TeleportIntervalInput.ClearTextOnFocus = false
local cornerTeleportInput = Instance.new("UICorner")
cornerTeleportInput.CornerRadius = UDim.new(0, 4)
cornerTeleportInput.Parent = TeleportIntervalInput

TeleportIntervalInput.FocusLost:Connect(function()
    local num = tonumber(TeleportIntervalInput.Text)
    if num and num >= 0 then
        Settings.TeleportInterval = num
        SaveSettings()
        TeleportIntervalInput.Text = tostring(num)
    else
        TeleportIntervalInput.Text = tostring(Settings.TeleportInterval)
    end
end)

local SafeHeightLabel = Instance.new("TextLabel")
SafeHeightLabel.Parent = SettingsFrame
SafeHeightLabel.Size = UDim2.new(0, 80, 0, 25)
SafeHeightLabel.Position = UDim2.new(0, 5, 0, 85)
SafeHeightLabel.Text = "Safe Ht:"
SafeHeightLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SafeHeightLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
SafeHeightLabel.TextSize = 12
SafeHeightLabel.TextXAlignment = Enum.TextXAlignment.Left
SafeHeightLabel.BackgroundTransparency = 1
SafeHeightLabel.Font = Enum.Font.Gotham

local SafeHeightInput = Instance.new("TextBox")
SafeHeightInput.Parent = SettingsFrame
SafeHeightInput.Size = UDim2.new(0, 40, 0, 25)
SafeHeightInput.Position = UDim2.new(0, 90, 0, 85)
SafeHeightInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SafeHeightInput.BackgroundTransparency = 0.2
SafeHeightInput.BorderSizePixel = 0
SafeHeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SafeHeightInput.Text = tostring(Settings.SafeHeight)
SafeHeightInput.Font = Enum.Font.Gotham
SafeHeightInput.TextSize = 12
SafeHeightInput.ClearTextOnFocus = false
local cornerSafeHeightInput = Instance.new("UICorner")
cornerSafeHeightInput.CornerRadius = UDim.new(0, 4)
cornerSafeHeightInput.Parent = SafeHeightInput

SafeHeightInput.FocusLost:Connect(function()
    local num = tonumber(SafeHeightInput.Text)
    if num then
        Settings.SafeHeight = num
        SaveSettings()
        SafeHeightInput.Text = tostring(num)
    else
        SafeHeightInput.Text = tostring(Settings.SafeHeight)
    end
end)

local AutoDeleteButton = createButton(Frame2, "Auto Del (Off)", UDim2.new(0, 10, 0, 43), Color3.fromRGB(180, 40, 40), 100)

local EditDeleteButton = Instance.new("TextButton")
EditDeleteButton.Parent = Frame2
EditDeleteButton.Size = UDim2.new(0, 25, 0, 28)
EditDeleteButton.Position = UDim2.new(0, 115, 0, 43)
EditDeleteButton.Text = "..."
EditDeleteButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
EditDeleteButton.BackgroundTransparency = 0.3
EditDeleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
EditDeleteButton.Font = Enum.Font.GothamBold
local cEditDel = Instance.new("UICorner")
cEditDel.CornerRadius = UDim.new(0, 6)
cEditDel.Parent = EditDeleteButton

local ViewDeletedButton = Instance.new("TextButton")
ViewDeletedButton.Parent = Frame2
ViewDeletedButton.Size = UDim2.new(0, 25, 0, 28)
ViewDeletedButton.Position = UDim2.new(0, 145, 0, 43)
ViewDeletedButton.Text = "📋"
ViewDeletedButton.BackgroundColor3 = Color3.fromRGB(60, 100, 140)
ViewDeletedButton.BackgroundTransparency = 0.3
ViewDeletedButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ViewDeletedButton.Font = Enum.Font.GothamBold
ViewDeletedButton.TextSize = 14
local cViewDel = Instance.new("UICorner")
cViewDel.CornerRadius = UDim.new(0, 6)
cViewDel.Parent = ViewDeletedButton

ViewDeletedButton.MouseButton1Click:Connect(function()
    RefreshDeletedView()
    DeletedViewFrame.Visible = not DeletedViewFrame.Visible
    SettingsFrame.Visible = false
end)

local DeleteManager = createListManager(Frame2, Settings.DeleteList, SaveSettings)
EditDeleteButton.MouseButton1Click:Connect(function() DeleteManager.Visible = not DeleteManager.Visible end)

local FloatButton = createButton(Frame2, "Float (Off)", UDim2.new(0, 10, 0, 76), Color3.fromRGB(180, 40, 40))
local SafeModeButton = createButton(Frame2, "Safe Mode (Off)", UDim2.new(0, 10, 0, 109), Color3.fromRGB(180, 40, 40))
local NextPageButton = createButton(Frame2, "Next Page ->", UDim2.new(0, 10, 0, 142), Color3.fromRGB(60, 60, 60))

local AutoOpenButton = createButton(Frame3, "Auto Open (Off)", UDim2.new(0, 10, 0, 10), Color3.fromRGB(180, 40, 40), 130)
local EditOpenButton = Instance.new("TextButton")
EditOpenButton.Parent = Frame3
EditOpenButton.Size = UDim2.new(0, 25, 0, 28)
EditOpenButton.Position = UDim2.new(0, 145, 0, 10)
EditOpenButton.Text = "..."
EditOpenButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
EditOpenButton.BackgroundTransparency = 0.3
EditOpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
EditOpenButton.Font = Enum.Font.GothamBold
local cEditOpen = Instance.new("UICorner")
cEditOpen.CornerRadius = UDim.new(0, 6)
cEditOpen.Parent = EditOpenButton

local OpenManager = createListManager(Frame3, Settings.OpenList, SaveSettings)
EditOpenButton.MouseButton1Click:Connect(function() OpenManager.Visible = not OpenManager.Visible end)

local KillAllNPCsButton = createButton(Frame3, "Kill NPCs", UDim2.new(0, 10, 0, 43), Color3.fromRGB(60, 60, 60), 100)

local KillNPCsLoopButton = Instance.new("TextButton")
KillNPCsLoopButton.Parent = Frame3
KillNPCsLoopButton.Size = UDim2.new(0, 55, 0, 28)
KillNPCsLoopButton.Position = UDim2.new(0, 115, 0, 43)
KillNPCsLoopButton.Text = "Loop"
KillNPCsLoopButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
KillNPCsLoopButton.BackgroundTransparency = 0.3
KillNPCsLoopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
KillNPCsLoopButton.TextSize = 12
KillNPCsLoopButton.BorderSizePixel = 0
KillNPCsLoopButton.Font = Enum.Font.GothamBold
local cKillLoop = Instance.new("UICorner")
cKillLoop.CornerRadius = UDim.new(0, 6)
cKillLoop.Parent = KillNPCsLoopButton

local CanTouchButton = createButton(Frame3, "CanTouch (On)", UDim2.new(0, 10, 0, 76), Color3.fromRGB(40, 160, 40))
local GrabToolsButton = createButton(Frame3, "Grab Tools (Off)", UDim2.new(0, 10, 0, 109), Color3.fromRGB(180, 40, 40))
local BackButton = createButton(Frame3, "<- Back", UDim2.new(0, 10, 0, 142), Color3.fromRGB(60, 60, 60))

local function setCanTouch(enabled)
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanTouch = enabled end)
        end
    end
end

local function killNPCs()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Humanoid") and not game.Players:GetPlayerFromCharacter(v.Parent) then
            pcall(function() v.Health = 0 end)
        end
    end
end

local function killNPCsLoopFunction()
    while _G.KillNPCsLoop and _G.GuiAlive do
        killNPCs()
        wait(4)
    end
end

local function safeModeKillLoop()
    while _G.SafeMode and _G.GuiAlive do
        killNPCs()
        wait(8)
    end
end

local function autoFarmLoop()
    while _G.AutoFarm and _G.GuiAlive do
        local player = game.Players.LocalPlayer
        local character = player.Character
        if not character then wait(0.5) continue end
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then wait(0.5) continue end

        local chestsModel = workspace:FindFirstChild("chests")

        if chestsModel then
            local potentialTargets = {}

            for _, descendant in pairs(chestsModel:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    local prompt = descendant:FindFirstChildWhichIsA("ProximityPrompt")

                    if prompt and prompt.HoldDuration <= 25 then
                        local targetPos = descendant.Position
                        local dist = (humanoidRootPart.Position - targetPos).Magnitude
                        if dist <= 3000000 then
                            table.insert(potentialTargets, {
                                Prompt = prompt,
                                Position = targetPos,
                                Distance = dist
                            })
                        end
                    end
                end
            end

            table.sort(potentialTargets, function(a, b)
                return a.Distance < b.Distance
            end)

            if #potentialTargets > 0 then
                for _, targetData in ipairs(potentialTargets) do
                    if not _G.AutoFarm or not _G.GuiAlive then break end
                    
                    if targetData.Prompt and targetData.Prompt.Parent then
                        local tpOffset = Vector3.new(0, 3, 0)
                        if _G.SafeMode then
                            tpOffset = Vector3.new(0, Settings.SafeHeight, 0)
                        end
                        
                        humanoidRootPart.CFrame = CFrame.new(targetData.Position + tpOffset)
                        wait(Settings.TeleportInterval)

                        fireproximityprompt(targetData.Prompt)
                        wait(Settings.CollectionInterval)
                    end
                end
            elseif _G.SafeMode then
                if humanoidRootPart.Position.Y < 50000 then
                    humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position.X, 80000, humanoidRootPart.Position.Z)
                end
            end
        end
        wait(0.2)
    end
end

local function autoDeleteLoop()
    while _G.AutoDelete and _G.GuiAlive do
        local player = game.Players.LocalPlayer
        local backpack = player:FindFirstChild("Backpack")
        
        if backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and table.find(Settings.DeleteList, tool.Name) then
                    tool.Parent = DeleteCupsFolder
                end
            end
        end
        local character = player.Character
        if character then
            for _, tool in pairs(character:GetChildren()) do
                if tool:IsA("Tool") and table.find(Settings.DeleteList, tool.Name) then
                    tool.Parent = DeleteCupsFolder
                end
            end
        end
        wait(0.5)
    end
end

local function autoOpenLoop()
    while _G.AutoOpen and _G.GuiAlive do
        local player = game.Players.LocalPlayer
        local backpack = player.Backpack
        local character = player.Character
        if not character then wait(0.2) continue end

        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                for _, keyword in ipairs(Settings.OpenList) do
                    if string.find(string.lower(tool.Name), string.lower(keyword)) then
                        pcall(function()
                            tool.Parent = character
                            wait(0.05)
                            tool:Activate()
                            wait(0.1)
                            if tool.Parent == character then
                                tool.Parent = backpack
                            end
                        end)
                        break
                    end
                end
            end
        end
        wait(0.2)
    end
end

local function enableFloat()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not humanoidRootPart then return end
    
    humanoid.PlatformStand = true
    if not humanoidRootPart:FindFirstChild("BodyVelocity") then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
        bodyVelocity.P = 5000
        bodyVelocity.Parent = humanoidRootPart
    end
end

local function disableFloat()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoid then humanoid.PlatformStand = false end
    if humanoidRootPart and humanoidRootPart:FindFirstChild("BodyVelocity") then
        humanoidRootPart.BodyVelocity:Destroy()
    end
end

local function grabTool(child)
    local char = Players.LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and child:IsA("BackpackItem") and child:FindFirstChild("Handle") then
        pcall(function() hum:EquipTool(child) end)
    end
end

AutoFarmButton.MouseButton1Up:Connect(function()
    if not _G.AutoFarm then
        AutoFarmButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        AutoFarmButton.Text = "Auto Farm (On)"
        _G.AutoFarm = true
        spawn(autoFarmLoop)
    else
        AutoFarmButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        AutoFarmButton.Text = "Auto Farm (Off)"
        _G.AutoFarm = false
    end
end)

AutoDeleteButton.MouseButton1Up:Connect(function()
    if not _G.AutoDelete then
        AutoDeleteButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        AutoDeleteButton.Text = "Auto Del (On)"
        _G.AutoDelete = true
        spawn(autoDeleteLoop)
    else
        AutoDeleteButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        AutoDeleteButton.Text = "Auto Del (Off)"
        _G.AutoDelete = false
    end
end)

FloatButton.MouseButton1Up:Connect(function()
    if not _G.IsFloating then
        FloatButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        FloatButton.Text = "Float (On)"
        _G.IsFloating = true
        enableFloat()
    else
        FloatButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        FloatButton.Text = "Float (Off)"
        _G.IsFloating = false
        disableFloat()
    end
end)

SafeModeButton.MouseButton1Up:Connect(function()
    if not _G.SafeMode then
        SafeModeButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        SafeModeButton.Text = "Safe Mode (On)"
        _G.SafeMode = true
        EnableSafeMode()
        spawn(safeModeKillLoop)
        if _G.CanTouchEnabled then
            _G.CanTouchEnabled = false
            setCanTouch(false)
            CanTouchButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            CanTouchButton.Text = "CanTouch (Off)"
        end
    else
        SafeModeButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        SafeModeButton.Text = "Safe Mode (Off)"
        _G.SafeMode = false
        DisableSafeMode()
    end
end)

NextPageButton.MouseButton1Up:Connect(function()
    Frame2.Visible = false
    Frame3.Visible = true
    SettingsFrame.Visible = false
    DeletedViewFrame.Visible = false
end)

BackButton.MouseButton1Up:Connect(function()
    Frame3.Visible = false
    Frame2.Visible = true
    SettingsFrame.Visible = false
    DeletedViewFrame.Visible = false
end)

AutoOpenButton.MouseButton1Up:Connect(function()
    if not _G.AutoOpen then
        AutoOpenButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        AutoOpenButton.Text = "Auto Open (On)"
        _G.AutoOpen = true
        spawn(autoOpenLoop)
    else
        AutoOpenButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        AutoOpenButton.Text = "Auto Open (Off)"
        _G.AutoOpen = false
    end
end)

KillAllNPCsButton.MouseButton1Up:Connect(function()
    killNPCs()
end)

KillNPCsLoopButton.MouseButton1Up:Connect(function()
    if not _G.KillNPCsLoop then
        _G.KillNPCsLoop = true
        KillNPCsLoopButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        KillNPCsLoopButton.Text = "Loop ✓"
        spawn(killNPCsLoopFunction)
    else
        _G.KillNPCsLoop = false
        KillNPCsLoopButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        KillNPCsLoopButton.Text = "Loop"
    end
end)

CanTouchButton.MouseButton1Up:Connect(function()
    if _G.CanTouchEnabled then
        CanTouchButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        CanTouchButton.Text = "CanTouch (Off)"
        _G.CanTouchEnabled = false
        setCanTouch(false)
    else
        CanTouchButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        CanTouchButton.Text = "CanTouch (On)"
        _G.CanTouchEnabled = true
        setCanTouch(true)
    end
end)

GrabToolsButton.MouseButton1Up:Connect(function()
    if not _G.GrabTools then
        _G.GrabTools = true
        GrabToolsButton.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
        GrabToolsButton.Text = "Grab Tools (On)"
        
        local player = Players.LocalPlayer
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        local chestsModel = workspace:FindFirstChild("chests")
        
        if humanoid then
            if chestsModel then
                for _, child in ipairs(chestsModel:GetDescendants()) do
                    grabTool(child)
                end
            end
            
            for _, child in ipairs(workspace:GetChildren()) do
                grabTool(child)
            end
        end
        
        for _, conn in pairs(GrabToolsConnections) do
            if conn then conn:Disconnect() end
        end
        GrabToolsConnections = {}
        
        if chestsModel then
            GrabToolsConnections[1] = chestsModel.DescendantAdded:Connect(function(child)
                if _G.GrabTools and _G.GuiAlive then grabTool(child) end
            end)
        end
        
        GrabToolsConnections[2] = workspace.ChildAdded:Connect(function(child)
            if _G.GrabTools and _G.GuiAlive then grabTool(child) end
        end)
        
    else
        _G.GrabTools = false
        GrabToolsButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        GrabToolsButton.Text = "Grab Tools (Off)"
        for _, conn in pairs(GrabToolsConnections) do
            if conn then conn:Disconnect() end
        end
        GrabToolsConnections = {}
    end
end)

game.Players.LocalPlayer.CharacterAdded:Connect(function(character)
    wait(1)
    if not _G.GuiAlive then return end
    if _G.IsFloating then
        enableFloat()
    end
    if _G.SafeMode then
        EnableSafeMode()
    end
    setCanTouch(_G.CanTouchEnabled)
end)

if game.Players.LocalPlayer.Character then
    wait(1)
    if _G.IsFloating then
        enableFloat()
    end
    if _G.SafeMode then
        EnableSafeMode()
    end
    setCanTouch(_G.CanTouchEnabled)
end

local VirtualUser = game:GetService("VirtualUser")

Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
