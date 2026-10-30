--[[
    NinjaExec Hub - V15 (Auto Replay + Aimbot Tronco + Noclip)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local MainRemote = RemoteEvents:WaitForChild("MainRemoteEvent")

-- ==========================================
-- CONFIGURAÇÕES GLOBAIS
-- ==========================================
local Config = {
    KillAura = false, 
    KillAuraRadius = 30,
    AutoSkill = false,
    AutoClick = false,
    AutoDodge = false,
    DodgeRadius = 20,
    Noclip = false,
    AutoReplay = false, -- NOVO
    
    Float_Method = "Behind", 
    Float_Distance = 10,
    Float_HeightOffset = 5,
    TweenSpeed = 500,
}

-- Anti-AFK
LP.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- MÓDULO DE UTILIDADES
-- ==========================================
local Utils = {}
local CurrentTarget = nil
local Tween = nil

function Utils.GetRoot()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Noclip
function Utils.NoclipTick()
    if not Config.Noclip or not LP.Character then return end
    for _, part in ipairs(LP.Character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

-- Encontra o NPC mais próximo
function Utils.GetNearestNPC()
    local myRoot = Utils.GetRoot()
    if not myRoot then return nil end
    
    local nearest, shortest = nil, 300
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < shortest then shortest = dist; nearest = root end
            end
        end
    end
    return nearest
end

-- Voo Suave
function Utils.FlyToTarget()
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    
    local target = Utils.GetNearestNPC()
    if target then
        CurrentTarget = target
        local targetCFrame = target.CFrame
        local finalPos
        
        if Config.Float_Method == "Behind" then finalPos = targetCFrame * CFrame.new(0, 0, Config.Float_Distance)
        elseif Config.Float_Method == "Front" then finalPos = targetCFrame * CFrame.new(0, 0, -Config.Float_Distance)
        elseif Config.Float_Method == "Over" then finalPos = targetCFrame * CFrame.new(0, Config.Float_Distance, 0)
        elseif Config.Float_Method == "Under" then finalPos = targetCFrame * CFrame.new(0, -Config.Float_Distance, 0) end
        
        finalPos = finalPos + Vector3.new(0, Config.Float_HeightOffset, 0)
        
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        
        if (myRoot.Position - finalPos.Position).Magnitude > 5 then
            if Tween then Tween:Cancel() end
            local tweenInfo = TweenInfo.new((myRoot.Position - finalPos.Position).Magnitude / Config.TweenSpeed, Enum.EasingStyle.Linear)
            Tween = TweenService:Create(myRoot, tweenInfo, {CFrame = finalPos})
            Tween:Play()
        end
        myRoot.CFrame = CFrame.new(myRoot.Position, target.Position)
    end
end

function Utils.StopFlight()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    if Tween then Tween:Cancel() end
    CurrentTarget = nil
end

-- ==========================================
-- AUTO REPLAY (NOVO)
-- ==========================================
function Utils.AutoReplayTick()
    if not Config.AutoReplay then return end
    
    -- Procura por botões de Replay/Retry na tela (PlayerGui)
    local playerGui = LP:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                local nameLower = string.lower(gui.Name)
                local textLower = ""
                if gui:IsA("TextButton") then textLower = string.lower(gui.Text) end
                
                -- Verifica se o nome ou texto do botão indica reinício
                if string.find(nameLower, "replay") or string.find(nameLower, "retry") or string.find(nameLower, "again") or
                   string.find(textLower, "replay") or string.find(textLower, "retry") or string.find(textLower, "play again") then
                    -- Se o botão estiver visível, clica nele
                    if gui.Visible and gui.AbsoluteSize.Magnitude > 0 then
                        pcall(function()
                            gui:Activate() -- Simula o clique
                        end)
                        task.wait(2) -- Espera um pouco para não spammar
                        return
                    end
                end
            end
        end
    end
end

-- ==========================================
-- COMBATE
-- ==========================================
function Utils.UseSkill(skillNumber)
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    local aimCFrame = CurrentTarget and CFrame.new(myRoot.Position, CurrentTarget.Position) or myRoot.CFrame
    local args = { "UseSkill", { hrpCFrame = aimCFrame }, skillNumber }
    pcall(function() MainRemote:FireServer(unpack(args)) end)
end

function Utils.DoBasicAttack()
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    local aimCFrame = CurrentTarget and CFrame.new(myRoot.Position, CurrentTarget.Position) or myRoot.CFrame
    local args = { "UseSkill", { attackNumber = 1, hrpCFrame = aimCFrame }, "BasicAttack" }
    pcall(function() MainRemote:FireServer(unpack(args)) end)
end

function Utils.KillAuraTick()
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {LP.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.MaxParts = 50
    local parts = Workspace:GetPartBoundsInRadius(myRoot.Position, Config.KillAuraRadius, params)
    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= LP.Character then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                pcall(function() humanoid.Health = 0 end)
            end
        end
    end
end

function Utils.AutoDodgeTick()
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {LP.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.MaxParts = 50
    local parts = Workspace:GetPartBoundsInRadius(myRoot.Position, Config.DodgeRadius, params)
    for _, part in ipairs(parts) do
        if string.find(string.lower(part.Name), "telegraph") then
            local dodgeDir = myRoot.CFrame.RightVector * 15
            myRoot.CFrame = myRoot.CFrame + dodgeDir
            task.wait(0.4)
            break
        end
    end
end

-- ==========================================
-- LOOP DE AUTOMAÇÃO
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        if Config.Noclip then Utils.NoclipTick() end
        
        if Config.KillAura then 
            Utils.FlyToTarget()
            Utils.KillAuraTick() 
        else
            Utils.StopFlight()
        end
        
        if Config.AutoDodge then Utils.AutoDodgeTick() end
        if Config.AutoReplay then Utils.AutoReplayTick() end -- NOVO
        
        if Config.AutoSkill then
            for i = 1, 5 do
                Utils.UseSkill(i)
                task.wait(0.1) 
            end
            task.wait(0.3)
        end
        
        if Config.AutoClick then
            Utils.DoBasicAttack()
            task.wait(0.2)
        end
    end
end)

-- ==========================================
-- INTERFACE GRÁFICA
-- ==========================================
local function CreateWindow()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NinjaExec_V15"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LP:WaitForChild("PlayerGui")

    local MiniBtn = Instance.new("TextButton")
    MiniBtn.Size = UDim2.new(0, 50, 0, 50)
    MiniBtn.Position = UDim2.new(0, 20, 0.5, -25)
    MiniBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 255)
    MiniBtn.Text = "N"
    MiniBtn.TextColor3 = Color3.new(1,1,1)
    MiniBtn.Font = Enum.Font.GothamBlack
    MiniBtn.TextSize = 24
    MiniBtn.Visible = false
    MiniBtn.Parent = ScreenGui
    Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(1, 0)
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 620, 0, 580) 
    MainFrame.Position = UDim2.new(0.5, -310, 0.5, -290)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BackgroundTransparency = 0.2 
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
    
    local Stroke = Instance.new("UIStroke", MainFrame)
    Stroke.Color = Color3.fromRGB(150, 0, 255)
    Stroke.Thickness = 2
    Stroke.Transparency = 0.2

    local BgImage = Instance.new("ImageLabel")
    BgImage.Size = UDim2.new(1, 0, 1, 0)
    BgImage.BackgroundTransparency = 1
    BgImage.Image = "rbxassetid://1316045217"
    BgImage.ImageTransparency = 0.8
    BgImage.ScaleType = Enum.ScaleType.Crop
    BgImage.Parent = MainFrame
    Instance.new("UICorner", BgImage).CornerRadius = UDim.new(0, 12)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    TitleBar.BackgroundTransparency = 0.4
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "NinjaExec | Ultimate V15"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    MinimizeBtn.Position = UDim2.new(1, -70, 0, 5)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    MinimizeBtn.Text = "-"
    MinimizeBtn.TextColor3 = Color3.new(1,1,1)
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.TextSize = 20
    MinimizeBtn.Parent = TitleBar
    Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 8)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

    MinimizeBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniBtn.Visible = true
    end)

    MiniBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        MiniBtn.Visible = false
    end)

    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    local dragging, dragInput, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -20, 1, -60)
    ContentFrame.Position = UDim2.new(0, 10, 0, 50)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame

    local function AddModernToggle(parent, text, key, default, yPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.Position = UDim2.new(0, 0, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.BackgroundTransparency = 0.3
        btn.Text = "  " .. text
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 16, 0, 16)
        indicator.Position = UDim2.new(1, -25, 0.5, -8)
        indicator.BackgroundColor3 = default and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(80, 80, 90)
        indicator.Parent = btn
        Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
        
        btn.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            indicator.BackgroundColor3 = Config[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(80, 80, 90)
        end)
    end

    local function AddModernTextBox(parent, text, key, default, yPos)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.Position = UDim2.new(0, 0, 0, yPos)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        frame.BackgroundTransparency = 0.3
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(200, 200, 210)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -20, 0, 22)
        box.Position = UDim2.new(0, 10, 0, 24)
        box.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        box.BackgroundTransparency = 0.5
        box.Text = tostring(default)
        box.TextColor3 = Color3.fromRGB(0, 255, 150)
        box.Font = Enum.Font.GothamBold
        box.TextSize = 13
        box.Parent = frame
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
        
        box.FocusLost:Connect(function()
            local num = tonumber(box.Text)
            if num then Config[key] = num
            else box.Text = tostring(Config[key]) end
        end)
    end

    local function AddModernDropdown(parent, text, options, key, default, yPos)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 65)
        frame.Position = UDim2.new(0, 0, 0, yPos)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        frame.BackgroundTransparency = 0.3
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = text .. " (Atual: " .. default .. ")"
        label.TextColor3 = Color3.fromRGB(200, 200, 210)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 25)
        btn.Position = UDim2.new(0, 10, 0, 25)
        btn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        btn.BackgroundTransparency = 0.5
        btn.Text = default
        btn.TextColor3 = Color3.fromRGB(0, 255, 150)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        local list = Instance.new("Frame")
        list.Size = UDim2.new(1, -20, 0, #options * 25)
        list.Position = UDim2.new(0, 10, 0, 55)
        list.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        list.Visible = false
        list.ZIndex = 10
        list.Parent = frame
        Instance.new("UICorner", list).CornerRadius = UDim.new(0, 6)
        
        btn.MouseButton1Click:Connect(function()
            list.Visible = not list.Visible
            frame.Size = list.Visible and UDim2.new(1, 0, 0, 65 + #options * 25) or UDim2.new(1, 0, 0, 65)
        end)
        
        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 25)
            optBtn.Position = UDim2.new(0, 0, 0, (i-1)*25)
            optBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
            optBtn.Text = opt
            optBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.ZIndex = 11
            optBtn.Parent = list
            optBtn.MouseButton1Click:Connect(function()
                Config[key] = opt
                btn.Text = opt
                label.Text = text .. " (Atual: " .. opt .. ")"
                list.Visible = false
                frame.Size = UDim2.new(1, 0, 0, 65)
            end)
        end
    end

    -- Adicionando Controles
    AddModernToggle(ContentFrame, "🔥 Kill Aura (Voo + Aimbot no Tronco)", "KillAura", false, 0)
    AddModernToggle(ContentFrame, "⚡ Auto Skill (1-5)", "AutoSkill", false, 40)
    AddModernToggle(ContentFrame, "👊 Auto Click (Basic)", "AutoClick", false, 80)
    AddModernToggle(ContentFrame, "💨 Auto Dodge (Voada Lateral)", "AutoDodge", false, 120)
    AddModernToggle(ContentFrame, "👻 Noclip (Atravessar Paredes)", "Noclip", false, 160)
    AddModernToggle(ContentFrame, "🔄 Auto Replay (Reiniciar Dungeon)", "AutoReplay", false, 200)
    
    AddModernDropdown(ContentFrame, "Posição de Voo", {"Behind", "Front", "Over", "Under"}, "Float_Method", "Behind", 240)
    AddModernTextBox(ContentFrame, "Distância do Voo", "Float_Distance", 10, 315)
    AddModernTextBox(ContentFrame, "Altura Extra (Y)", "Float_HeightOffset", 5, 365)
    AddModernTextBox(ContentFrame, "TweenSpeed (Velocidade)", "TweenSpeed", 500, 415)
end

pcall(CreateWindow)
