local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/release.lua", true))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local statusBarFrame = nil
local statusBarEnabled = false
local omniSprintToggle = false
local autoFarmConnection = nil
local mouse = Players.LocalPlayer:GetMouse()
local fovUpdateConnection = nil
local ambientLoopEnabled = false
local ambientLoopConnection = nil
local currentAmbientColor = Lighting.Ambient
local speedhackEnabled = false
local speedhackConnection = nil

local autoFarmSettings = {
    Enabled = false,
    Speed = 0.3
}

local originalLighting = {
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    Ambient = Lighting.Ambient
}

local originalGraphics = {
    GraphicsQualityLevel = 5,
    MasterVolume = 0.5
}

local aimbotEnabled = false
local aimbotConnection = nil
local aimbotSettings = {
    Enabled = false,
    TargetPart = "HumanoidRootPart",
    FOV = 100,
    ShowFOV = false,
    Smoothing = 0.1,
    MaxDistance = 500,
    FOVColor = Color3.fromRGB(255, 255, 255)
}

local fovCircle = nil

pcall(function()
    if GameSettings and GameSettings.SavedQualityLevel then
        originalGraphics.GraphicsQualityLevel = GameSettings.SavedQualityLevel
    end
end)

pcall(function()
    if GameSettings and GameSettings.MasterVolume then
        originalGraphics.MasterVolume = GameSettings.MasterVolume
    end
end)

local ultraPerformanceEnabled = false

local function findZombieTargetsAlternative()
    local targets = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local zombieClasses = getZombieClasses()
            for _, className in ipairs(zombieClasses) do
                if obj.Name == className or obj.Name == "Model_" .. className then
                    local targetPart = obj:FindFirstChild(aimbotSettings.TargetPart)
                    if targetPart then
                        table.insert(targets, {
                            part = targetPart,
                            model = obj,
                            class = className
                        })
                    end
                end
            end
        end
    end
    
    if #targets == 0 and ReplicatedStorage:FindFirstChild("Assets") then
        local assets = ReplicatedStorage.Assets
        if assets:FindFirstChild("Zombies") then
            local zombies = assets.Zombies
            local zombieClasses = getZombieClasses()
            
            for _, className in ipairs(zombieClasses) do
                local classFolder = zombies:FindFirstChild(className)
                if classFolder then
                    local modelName = "Model_" .. className
                    local zombieModel = classFolder:FindFirstChild(modelName)
                    
                    if zombieModel then
                        local targetPart = zombieModel:FindFirstChild(aimbotSettings.TargetPart)
                        if targetPart then
                            table.insert(targets, {
                                part = targetPart,
                                model = zombieModel,
                                class = className
                            })
                        end
                    end
                end
            end
        end
    end
    
    return targets
end

local function getZombieClasses()
    local classes = {
        "ArmoredZombie", "Banker", "Captain", "Prescott", "Runner", 
        "Walker", "ZombieMiner", "ZombieRevolverOfficer", 
        "ZombieRevolverSoldier", "ZombieSheriff", "ZombieSwordOfficer", 
        "ZombieUnarmedSoldier"
    }
    return classes
end

local function findZombieTargets()
    local targets = {}

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:match("^Model_") then
            local className = obj.Name:gsub("^Model_", "")
            local zombieClasses = getZombieClasses()

            for _, validClass in ipairs(zombieClasses) do
                if className == validClass then
                    local targetPart = obj:FindFirstChild(aimbotSettings.TargetPart)
                    if targetPart then
                        table.insert(targets, {
                            part = targetPart,
                            model = obj,
                            class = className
                        })
                    end
                    break
                end
            end
        end
    end
    
    return targets
end

local function getClosestTarget()
    local targets = findZombieTargets()
    if #targets == 0 then return nil end
    
    local camera = workspace.CurrentCamera
    local player = Players.LocalPlayer
    
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local closestTarget = nil
    local closestDistance = math.huge
    
    for _, target in ipairs(targets) do
        local distance = (target.part.Position - playerPosition).Magnitude

        if distance <= aimbotSettings.MaxDistance then
            local screenPoint = camera:WorldToScreenPoint(target.part.Position)
            local mousePosition = Vector2.new(mouse.X, mouse.Y)
            local screenDistance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePosition).Magnitude
            
            if screenDistance <= aimbotSettings.FOV then
                if distance < closestDistance then
                    closestDistance = distance
                    closestTarget = target
                end
            end
        end
    end
    
    return closestTarget
end

local function createFOVCircle()
    if fovCircle then
        fovCircle:Remove()
    end

    if fovUpdateConnection then
        fovUpdateConnection:Disconnect()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotFOV"
    screenGui.Parent = game.CoreGui
    
    local circle = Instance.new("Frame")
    circle.Name = "FOVCircle"
    circle.Size = UDim2.new(0, aimbotSettings.FOV * 2, 0, aimbotSettings.FOV * 2)
    circle.Position = UDim2.new(0, mouse.X - aimbotSettings.FOV, 0, mouse.Y - aimbotSettings.FOV)
    circle.BackgroundTransparency = 1
    circle.Parent = screenGui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = circle
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = aimbotSettings.FOVColor
    uiStroke.Thickness = 6
    uiStroke.Transparency = 0.1
    uiStroke.Parent = circle
    
    fovCircle = screenGui
    

    fovUpdateConnection = RunService.RenderStepped:Connect(function()
        if fovCircle and aimbotSettings.ShowFOV then
            local circle = fovCircle:FindFirstChild("FOVCircle")
            if circle then
                circle.Position = UDim2.new(0, mouse.X - aimbotSettings.FOV, 0, mouse.Y - aimbotSettings.FOV)
            end
        end
    end)
end

local function updateFOVCircle()
    if fovCircle and aimbotSettings.ShowFOV then
        local circle = fovCircle:FindFirstChild("FOVCircle")
        if circle then
            circle.Size = UDim2.new(0, aimbotSettings.FOV * 2, 0, aimbotSettings.FOV * 2)
            circle.Position = UDim2.new(0, mouse.X - aimbotSettings.FOV, 0, mouse.Y - aimbotSettings.FOV)
            circle.Visible = true
            
            local uiStroke = circle:FindFirstChild("UIStroke")
            if uiStroke then
                uiStroke.Color = aimbotSettings.FOVColor
            end
        end
    elseif fovCircle then
        local circle = fovCircle:FindFirstChild("FOVCircle")
        if circle then
            circle.Visible = false
        end

        if fovUpdateConnection then
            fovUpdateConnection:Disconnect()
            fovUpdateConnection = nil
        end
    end
end

local function startAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
    end
    
    aimbotConnection = RunService.RenderStepped:Connect(function()
        if not aimbotSettings.Enabled then return end
        
        local target = getClosestTarget()
        if not target then return end
        
        local camera = workspace.CurrentCamera
        local player = Players.LocalPlayer

        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        
        local targetPosition = target.part.Position
        local cameraPosition = camera.CFrame.Position

        local direction = (targetPosition - cameraPosition).Unit

        if aimbotSettings.Smoothing > 0 then
            camera.CFrame = camera.CFrame:Lerp(newCFrame, aimbotSettings.Smoothing)
        else
            camera.CFrame = newCFrame
        end
    end)
end

local function stopAimbot()
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
end

local function CreateStatusBar()
    local playerGui = player:WaitForChild("PlayerGui")

    if playerGui:FindFirstChild("StatusBar") then
        playerGui:FindFirstChild("StatusBar"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StatusBar"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 40)
    frame.Position = UDim2.new(0.5, 0, 0, 5)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = frame
    
    local accentColor = Color3.fromRGB(240, 240, 255)

    local aLabel = Instance.new("TextLabel")
    aLabel.Size = UDim2.new(0, 32, 1, 0)
    aLabel.Position = UDim2.new(0, 12, 0, 0)
    aLabel.BackgroundTransparency = 1
    aLabel.TextColor3 = accentColor
    aLabel.Font = Enum.Font.SourceSansBold
    aLabel.TextSize = 26
    aLabel.Text = "A"
    aLabel.TextXAlignment = Enum.TextXAlignment.Center
    aLabel.TextYAlignment = Enum.TextYAlignment.Center
    aLabel.Rotation = -12
    aLabel.Parent = frame

    local function createSeparator(xPos)
        local sep = Instance.new("Frame")
        sep.Size = UDim2.new(0, 2, 0, 24)
        sep.Position = UDim2.new(0, xPos, 0, 8)
        sep.BackgroundColor3 = accentColor
        sep.BackgroundTransparency = 0.6
        sep.BorderSizePixel = 0
        sep.Parent = frame
        return sep
    end
    
    createSeparator(62)
    createSeparator(174)
    
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0, 100, 1, 0)
    fpsLabel.Position = UDim2.new(0, 70, 0, 0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    fpsLabel.Font = Enum.Font.SourceSans
    fpsLabel.TextSize = 20
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Center
    fpsLabel.TextYAlignment = Enum.TextYAlignment.Center
    fpsLabel.Text = "FPS: 0"
    fpsLabel.Parent = frame

    local pingLabel = Instance.new("TextLabel")
    pingLabel.Size = UDim2.new(0, 80, 1, 0)
    pingLabel.Position = UDim2.new(0, 200, 0, 0)
    pingLabel.BackgroundTransparency = 1
    pingLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    pingLabel.Font = Enum.Font.SourceSans
    pingLabel.TextSize = 20
    pingLabel.TextXAlignment = Enum.TextXAlignment.Center
    pingLabel.TextYAlignment = Enum.TextYAlignment.Center
    pingLabel.Text = "Ping: 0 ms"
    pingLabel.Parent = frame

    local fps = 0
    local frameCount = 0
    local lastTime = tick()
    
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTime >= 1 then
            fps = frameCount / (now - lastTime)
            frameCount = 0
            lastTime = now
            fpsLabel.Text = string.format("FPS: %d", math.floor(fps))
        end
    end)

    coroutine.wrap(function()
        while true do
            local ping = player:GetNetworkPing() * 1000
            pingLabel.Text = string.format("Ping: %d ms", math.floor(ping))
            wait(1)
        end
    end)()
    
    return frame
end
local function startAmbientLoop()
    if ambientLoopConnection then
        ambientLoopConnection:Disconnect()
    end
    
    ambientLoopConnection = RunService.Heartbeat:Connect(function()
        if ambientLoopEnabled then
            Lighting.Ambient = currentAmbientColor
        end
    end)
end

local function stopAmbientLoop()
    if ambientLoopConnection then
        ambientLoopConnection:Disconnect()
        ambientLoopConnection = nil
    end
end

local function startSpeedhack()
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local uis = game:GetService("UserInputService")

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    local keys = {
        W = false,
        A = false,
        S = false,
        D = false
    }

    local speed = 23

    uis.InputBegan:Connect(function(input, gp)
        if gp then return end
        local key = input.KeyCode.Name
        if keys[key] ~= nil then
            keys[key] = true
        end
    end)

    uis.InputEnded:Connect(function(input, gp)
        if gp then return end
        local key = input.KeyCode.Name
        if keys[key] ~= nil then
            keys[key] = false
        end
    end)

    speedhackConnection = RunService.RenderStepped:Connect(function()
        if not speedhackEnabled then return end
        local moveDir = Vector3.zero
        local cam = workspace.CurrentCamera
        local cf = cam.CFrame

        if keys.W then moveDir += cf.LookVector end
        if keys.S then moveDir -= cf.LookVector end
        if keys.A then moveDir -= cf.RightVector end
        if keys.D then moveDir += cf.RightVector end

        moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
        if moveDir.Magnitude > 0 then
            hrp.Velocity = moveDir.Unit * speed + Vector3.new(0, hrp.Velocity.Y, 0)
        end
    end)
end

local function stopSpeedhack()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.WalkSpeed = 16
end
local function startAutoFarm()
    if autoFarmConnection then
        autoFarmConnection:Disconnect()
    end
    
    autoFarmConnection = RunService.Heartbeat:Connect(function()
        if autoFarmSettings.Enabled then
            -- TODO: ADD AUTOFARM LOGIC HERE
            
            wait(autoFarmSettings.Speed)
        end
    end)
end

local function stopAutoFarm()
    if autoFarmConnection then
        autoFarmConnection:Disconnect()
        autoFarmConnection = nil
    end
end

local function startOmniSprint()
    coroutine.wrap(function()
        while omniSprintToggle do
            wait(0.02)
            local args = {true}
            if ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("RequestSprint") then
                ReplicatedStorage.Remotes.RequestSprint:FireServer(unpack(args))
            end
        end
    end)()
end

local function enableUltraPerformance()
    pcall(function()
        GameSettings.SavedQualityLevel = 1
    end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100
    Lighting.FogStart = 0
    Lighting.Brightness = 0
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("ParticleEmitter") then
            obj.Enabled = false
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            obj.Brightness = 0
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("MeshPart") then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
        elseif obj:IsA("Part") then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
        end
    end
    
    ultraPerformanceEnabled = true
end

local function disableUltraPerformance()
    pcall(function()
        GameSettings.SavedQualityLevel = originalGraphics.GraphicsQualityLevel or 5
    end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)

    Lighting.GlobalShadows = true
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.FogStart = originalLighting.FogStart
    Lighting.Brightness = 2
    Lighting.Ambient = originalLighting.Ambient

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("ParticleEmitter") then
            obj.Enabled = true
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            obj.Brightness = 1
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 0
        end
    end
    
    ultraPerformanceEnabled = false
end

local quotes = {
    " - BobDaHacker",
    " - Cultivating unemployment",
    " - builder.ai skid 2025 no way",
    " - Probably gonna get banned lol",
    " - Touching grass is overrated anyway",
    " - WARNING: May cause vitamin D deficiency",
    " - Now with 50% more spaghetti code",
    " - Breaking tos since 1900 BC",
    " - Trust me bro, it's legit",
    " - Speedrunning a ban any%",
    " - Warning: Side effects may include skill issues",
    " - Probably violating several laws of physics",
    " - Why wda_excludefromcapture not work???"
}

local function getRandomQuote()
    return quotes[math.random(1, #quotes)]
end

local Window = Fluent:CreateWindow({
    Title = "Acid " .. getRandomQuote(),
    TabWidth = 160,
    Size = UDim2.fromOffset(720, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift,
})

local Tabs = {
    Credits = Window:AddTab({ Title = "Credits", Icon = "" }),
    AutoFarm = Window:AddTab({ Title = "Autofarm", Icon = "" }),
    Aimbot = Window:AddTab({ Title = "Aimbot", Icon = "" }),
    Modulation = Window:AddTab({ Title = "Modulation", Icon = "" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "" }),
}

Tabs.Credits:AddParagraph({
    Title = "klyte",
    Content = "_klyte_"
})

local autoFarmToggle = Tabs.AutoFarm:AddToggle("AutoFarmToggle", {
    Title = "AutoFarm",
    Description = "Bonds autofarm",
    Default = false,
})

autoFarmToggle:OnChanged(function(val)
    autoFarmSettings.Enabled = val
    if val then
        startAutoFarm()
    else
        stopAutoFarm()
    end
end)

Tabs.AutoFarm:AddSlider("AutoFarmSpeed", {
    Title = "AutoFarm Speed",
    Description = "Adjust the speed of autofarming (lower = faster)",
    Min = 0.01,
    Max = 2.0,
    Default = 0.3,
    Rounding = 2,
    Callback = function(val)
        autoFarmSettings.Speed = val
    end,
})

local aimbotToggle = Tabs.Aimbot:AddToggle("AimbotToggle", {
    Title = "Zombiebot",
    Description = "Automatically aim at zombie targets",
    Default = false,
})

aimbotToggle:OnChanged(function(val)
    aimbotSettings.Enabled = val
    if val then
        startAimbot()
    else
        stopAimbot()
    end
end)

Tabs.Aimbot:AddDropdown("TargetPart", {
    Title = "Target Part",
    Description = "Choose which part of the zombie to target",
    Values = {"HumanoidRootPart", "Head"},
    Multi = false,
    Default = "HumanoidRootPart",
}):OnChanged(function(val)
    aimbotSettings.TargetPart = val
end)

Tabs.Aimbot:AddToggle("ShowFOV", {
    Title = "Show FOV Circle",
    Description = "Display the FOV circle on screen",
    Default = false,
}):OnChanged(function(val)
    aimbotSettings.ShowFOV = val
    if val then
        createFOVCircle()
    end
    updateFOVCircle()
end)

Tabs.Aimbot:AddColorpicker("FOVColor", {
    Title = "FOV Circle Color",
    Description = "Change the color of the FOV circle",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        aimbotSettings.FOVColor = color
        updateFOVCircle()
    end,
})

Tabs.Aimbot:AddSlider("FOVSlider", {
    Title = "FOV Size",
    Description = "Adjust the field of view for target detection",
    Min = 10,
    Max = 500,
    Default = 100,
    Rounding = 0,
    Callback = function(val)
        aimbotSettings.FOV = val
        updateFOVCircle()
    end,
})

Tabs.Aimbot:AddSlider("SmoothingSlider", {
    Title = "Smoothing",
    Description = "Adjust aim smoothing (0 = instant, higher = smoother)",
    Min = 0,
    Max = 1,
    Default = 0.1,
    Rounding = 3,
    Callback = function(val)
        aimbotSettings.Smoothing = val
    end,
})

Tabs.Aimbot:AddSlider("MaxDistanceSlider", {
    Title = "Max Distance",
    Description = "Maximum distance to target zombies",
    Min = 50,
    Max = 1000,
    Default = 500,
    Rounding = 0,
    Callback = function(val)
        aimbotSettings.MaxDistance = val
    end,
})

local envSection = Tabs.Modulation:AddSection("Environment Controls")

envSection:AddToggle("AmbientLoop", {
    Title = "Lock Ambient Color",
    Description = "Continuously apply ambient color (will cause flickering here and there)",
    Default = false,
}):OnChanged(function(val)
    ambientLoopEnabled = val
    if val then
        startAmbientLoop()
    else
        stopAmbientLoop()
    end
end)

envSection:AddColorpicker("AmbientColor", {
    Title = "Ambient Color",
    Description = "Change the ambient lighting color",
    Default = originalLighting.Ambient,
    Callback = function(color)
        currentAmbientColor = color
        Lighting.Ambient = color
    end,
})

envSection:AddButton({
    Title = "Reset to Normal",
    Description = "Reset all lighting settings to original values",
    Callback = function()
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
        Lighting.Ambient = originalLighting.Ambient
    end,
})

local performanceSection = Tabs.Modulation:AddSection("Performance")

performanceSection:AddToggle("UltraPerformance", {
    Title = "Ultra Performance Mode",
    Description = "Reduces graphics to bare minimum for maximum FPS (WARNING : You cannot revert this action unless u rejoin)",
    Default = false,
}):OnChanged(function(val)
    if val then
        enableUltraPerformance()
    else
        disableUltraPerformance()
    end
end)

performanceSection:AddButton({
    Title = "Force Low Quality",
    Description = "Manually set graphics quality to lowest possible",
    Callback = function()
        pcall(function()
            GameSettings.SavedQualityLevel = 1
        end)
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
    end,
})

local statusBarToggle = Tabs.Misc:AddToggle("StatusBarToggle", {
    Title = "Show Status Bar",
    Description = "Display FPS and ping information at the top of screen",
    Default = false,
})

statusBarToggle:OnChanged(function(val)
    statusBarEnabled = val
    if val then
        if not statusBarFrame then
            statusBarFrame = CreateStatusBar()
        end
        statusBarFrame.Visible = true
    else
        if statusBarFrame then
            statusBarFrame.Visible = false
        end
    end
end)

local themeColors = {
    Dark = Color3.fromRGB(40, 40, 40),
    Darker = Color3.fromRGB(20, 20, 20),
    Amoled = Color3.fromRGB(0, 0, 0),
    Light = Color3.fromRGB(240, 240, 240),
    Balloon = Color3.fromRGB(218, 239, 255),
    SoftCream = Color3.fromRGB(248, 238, 214),
    Aqua = Color3.fromRGB(25, 90, 103),
    Amethyst = Color3.fromRGB(40, 21, 62),
    Rose = Color3.fromRGB(56, 28, 42),
    Midnight = Color3.fromRGB(11, 11, 36),
    Forest = Color3.fromRGB(22, 38, 27),
    Sunset = Color3.fromRGB(54, 30, 23),
    Ocean = Color3.fromRGB(19, 27, 44),
    Emerald = Color3.fromRGB(22, 47, 40),
    Sapphire = Color3.fromRGB(13, 24, 61),
    Cloud = Color3.fromRGB(23, 61, 75),
    Grape = Color3.fromRGB(12, 6, 24),
}

Tabs.Misc:AddDropdown("ThemeSelector", {
    Title = "Status Bar Theme",
    Description = "Choose the background color theme for the status bar",
    Values = {"Dark", "Darker", "Amoled", "Light", "Balloon", "SoftCream", "Aqua", "Amethyst", "Rose", "Midnight", "Forest", "Sunset", "Ocean", "Emerald", "Sapphire", "Cloud", "Grape"},
    Multi = false,
    Default = "Dark",
}):OnChanged(function(themeName)
    if statusBarFrame and themeColors[themeName] then
        local color = themeColors[themeName]
        statusBarFrame.BackgroundColor3 = color
        
        local textColor = Color3.fromRGB(230, 230, 230)
        if themeName == "Light" or themeName == "SoftCream" or themeName == "Balloon" then
            textColor = Color3.fromRGB(0, 0, 0)
        end
        
        for _, child in ipairs(statusBarFrame:GetChildren()) do
            if child:IsA("TextLabel") and child.Name ~= "A" then
                child.TextColor3 = textColor
            end
        end
    end
end)

Tabs.Misc:AddSlider("StatusBarTransparency", {
    Title = "Status Bar Transparency",
    Description = "Adjust the background transparency of the status bar",
    Min = 0,
    Max = 1,
    Default = 0.3,
    Rounding = 2,
    Callback = function(val)
        if statusBarFrame then
            statusBarFrame.BackgroundTransparency = val
        end
    end,
})

Tabs.Misc:AddSlider("StatusBarPosX", {
    Title = "Status Bar X Position",
    Description = "Adjust the horizontal (X) position of the status bar",
    Min = -800,
    Max = 800,
    Default = 0,
    Rounding = 0,
    Callback = function(xOffset)
        if statusBarFrame then
            statusBarFrame.Position = UDim2.new(0.5, xOffset, statusBarFrame.Position.Y.Scale, statusBarFrame.Position.Y.Offset)
        end
    end,
})

Tabs.Misc:AddSlider("StatusBarPosY", {
    Title = "Status Bar Y Position",
    Description = "Adjust the vertical (Y) position of the status bar",
    Min = -61,
    Max = 921,
    Default = 5,
    Rounding = 0,
    Callback = function(yOffset)
        if statusBarFrame then
            statusBarFrame.Position = UDim2.new(statusBarFrame.Position.X.Scale, statusBarFrame.Position.X.Offset, 0, yOffset)
        end
    end,
})

local randomSection = Tabs.Misc:AddSection("Random")

randomSection:AddToggle("Speedhack", {
    Title = "Speedhack",
    Description = "gotta go fast",
    Default = false,
}):OnChanged(function(val)
    speedhackEnabled = val
    if val then
        startSpeedhack()
    else
        stopSpeedhack()
    end
end)

randomSection:AddToggle("OmniSprint", {
    Title = "Omni-Sprint",
    Description = "Sprints for you in all directions",
    Default = false,
}):OnChanged(function(val)
    omniSprintToggle = val
    if val then
        startOmniSprint()
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("AcidHub")
SaveManager:SetFolder("AcidHub/DeadRails")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

game:GetService("Players").PlayerRemoving:Connect(function(plr)
    if plr == Players.LocalPlayer then
        stopAimbot()
        stopAmbientLoop()
        stopSpeedhack()
        if fovCircle then
            fovCircle:Remove()
        end
        if fovUpdateConnection then
            fovUpdateConnection:Disconnect()
        end
    end
end)
