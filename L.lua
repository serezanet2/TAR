-- Создание главного GUI
local ScreenGui = Instance.new("ScreenGui")
local CopyButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")
local UIStroke = Instance.new("UIStroke")

ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

-- Кнопка копирования
CopyButton.Name = "CopyLightingBtn"
CopyButton.Parent = ScreenGui
CopyButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
CopyButton.Position = UDim2.new(0.02, 0, 0.4, 0)
CopyButton.Size = UDim2.new(0, 150, 0, 45)
CopyButton.Font = Enum.Font.SourceSansBold
CopyButton.Text = "Скопировать Свет"
CopyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyButton.TextSize = 16.000

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = CopyButton

UIStroke.Color = Color3.fromRGB(255, 85, 85)
UIStroke.Thickness = 2
UIStroke.Parent = CopyButton

-- Функция для создания резервного текстового окна при ошибке
local function createFallbackTextBox(textData)
    -- Проверяем, нет ли уже открытого окна
    if ScreenGui:FindFirstChild("FallbackFrame") then
        ScreenGui.FallbackFrame:Destroy()
    end

    local Frame = Instance.new("Frame")
    local TextBox = Instance.new("TextBox")
    local CloseButton = Instance.new("TextButton")
    local FrameCorner = Instance.new("UICorner")
    local CloseCorner = Instance.new("UICorner")

    Frame.Name = "FallbackFrame"
    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Frame.Position = UDim2.new(0.3, 0, 0.2, 0)
    Frame.Size = UDim2.new(0, 400, 0, 300)
    
    FrameCorner.CornerRadius = UDim.new(0, 10)
    FrameCorner.Parent = Frame

    -- Текстовое поле, откуда можно копировать вручную
    TextBox.Parent = Frame
    TextBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    TextBox.Position = UDim2.new(0.05, 0, 0.05, 0)
    TextBox.Size = UDim2.new(0.9, 0, 0.75, 0)
    TextBox.ClearTextOnFocus = false
    TextBox.Font = Enum.Font.Code
    TextBox.MultiLine = true
    TextBox.Text = textData
    TextBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    TextBox.TextSize = 12.000
    TextBox.TextXAlignment = Enum.TextXAlignment.Left
    TextBox.TextYAlignment = Enum.TextYAlignment.Top

    -- Кнопка закрытия окна
    CloseButton.Parent = Frame
    CloseButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    CloseButton.Position = UDim2.new(0.05, 0, 0.85, 0)
    CloseButton.Size = UDim2.new(0.9, 0, 0.1, 0)
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.Text = "Закрыть окно"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 14.000
    
    CloseCorner.CornerRadius = UDim.new(0, 5)
    CloseCorner.Parent = CloseButton

    CloseButton.MouseButton1Click:Connect(function()
        Frame:Destroy()
    end)
end

-- Основная логика сбора данных
CopyButton.MouseButton1Click:Connect(function()
    CopyButton.Text = "Сканирование..."
    CopyButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    
    local allowedEffects = {
        ["ColorCorrectionEffect"] = true, ["BloomEffect"] = true, 
        ["BlurEffect"] = true, ["SunRaysEffect"] = true, 
        ["Atmosphere"] = true, ["Sky"] = true, ["Clouds"] = true
    }

    local lightingProperties = {
        "Ambient", "OutdoorAmbient", "ColorShift_Bottom", "ColorShift_Top",
        "Brightness", "ClockTime", "GeographicLatitude", "ExposureCompensation",
        "ShadowSoftness", "EnvironmentColor", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
        "GlobalShadows", "FogColor", "FogEnd", "FogStart"
    }

    local terrainProperties = {
        "WaterColor", "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed"
    }

    local output = "-- СКРИПТ ДЛЯ ROBLOX STUDIO: ПЕРЕНОС ОСВЕЩЕНИЯ\n"
    output = output .. "local Lighting = game:GetService('Lighting')\n"
    output = output .. "local Terrain = workspace:WaitForChild('Terrain')\n\n"
    output = output .. "-- 1. Очистка старого освещения\n"
    output = output .. "Lighting:ClearAllChildren()\n\n"

    output = output .. "-- 2. Применение глобальных настроек Lighting\n"
    for _, prop in ipairs(lightingProperties) do
        pcall(function()
            local val = game.Lighting[prop]
            if typeof(val) == "Color3" then
                output = output .. string.format("Lighting.%s = Color3.fromRGB(%d, %d, %d)\n", prop, val.R*255, val.G*255, val.B*255)
            elseif typeof(val) == "boolean" or typeof(val) == "number" then
                output = output .. string.format("Lighting.%s = %s\n", prop, tostring(val))
            end
        end)
    end

    output = output .. "\n-- 3. Применение настроек воды и ландшафта Terrain\n"
    for _, prop in ipairs(terrainProperties) do
        pcall(function()
            local val = game.Workspace.Terrain[prop]
            if typeof(val) == "Color3" then
                output = output .. string.format("Terrain.%s = Color3.fromRGB(%d, %d, %d)\n", prop, val.R*255, val.G*255, val.B*255)
            elseif typeof(val) == "number" then
                output = output .. string.format("Terrain.%s = %s\n", prop, tostring(val))
            end
        end)
    end

    output = output .. "\n-- 4. Создание эффектов освещения (цветокоррекция, атмосфера)\n"
    for _, child in ipairs(game.Lighting:GetChildren()) do
        if allowedEffects[child.ClassName] then
            output = output .. string.format("\nlocal effect = Instance.new('%s', Lighting)\n", child.ClassName)
            output = output .. string.format("effect.Name = '%s'\n", child.Name)
            
            local commonProps = {"Brightness", "Contrast", "Saturation", "Tint", "Size", "Intensity", "Density", "Offset", "Color", "Glare", "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId"}
            for _, p in ipairs(commonProps) do
                pcall(function()
                    local v = child[p]
                    if typeof(v) == "Color3" then
                        output = output .. string.format("effect.%s = Color3.fromRGB(%d, %d, %d)\n", p, v.R*255, v.G*255, v.B*255)
                    elseif typeof(v) == "string" then
                        output = output .. string.format("effect.%s = '%s'\n", p, v)
                    elseif typeof(v) == "number" or typeof(v) == "boolean" then
                        output = output .. string.format("effect.%s = %s\n", p, tostring(v))
                    end
                end)
            end
        end
    end

    -- Пробуем скопировать в буфер обмена
    local copied = false
    if setclipboard then
        pcall(function() setclipboard(output) copied = true end)
    elseif toclipboard then
        pcall(function() toclipboard(output) copied = true end)
    end

    -- Проверяем результат копирования
    if copied then
        CopyButton.Text = "Успешно скопировано!"
        CopyButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113) -- Зеленый цвет
    else
        CopyButton.Text = "Копируй из окна!"
        CopyButton.BackgroundColor3 = Color3.fromRGB(230, 126, 34) -- Оранжевый (предупреждение)
        createFallbackTextBox(output) -- Открываем текстовое поле на экране
    end
    
    -- Сброс состояния кнопки через 3 секунды
    task.wait(3)
    CopyButton.Text = "Скопировать Свет"
    CopyButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
end)
