--[[
    NinjaExec Hub - V30 (Botão do Discord Integrado)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

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
    AutoReplay = false,
    InfiniteDash = false, 
    SpyDash = false,      

    FlyPosition = "Centro (Hitbox)", 
    FlyDistance = 10,
    FlyHeight = 5,
    TweenSpeed = 500,
    
    TargetFilter = "Todos os NPCs",
}

local DashArgs = nil 
local CurrentTargetModel = nil

-- Anti-AFK
LP.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ==========================================
-- SISTEMA DE ESPIONAGEM (SPY) DO DASH
-- ==========================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if Config.SpyDash and self == MainRemote and tostring(method) == "FireServer" then
        local cmd = tostring(args[1]):lower()
        if string.find(cmd, "dash") or string.find(cmd, "step") or string.find(cmd, "roll") then
            DashArgs = args
            Config.SpyDash = false 
            Config.InfiniteDash = true 
            
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "Dash Capturado!",
                    Text = "O Dash Infinito foi ativado automaticamente.",
                    Duration = 5
                })
            end)
        end
    end
    
    return oldNamecall(self, ...)
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

function Utils.NoclipTick()
    if not Config.Noclip or not LP.Character then return end
    for _, part in ipairs(LP.Character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

function Utils.IsBoss(model)
    local name = string.lower(model.Name)
    if string.find(name, "boss") or string.find(name, "raid") or string.find(name, "king") or string.find(name, "lord") or string.find(name, "elite") then
        return true
    end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Size.Magnitude > 20 then return true end
    return false
end

function Utils.GetNearestNPC()
    local myRoot = Utils.GetRoot()
    if not myRoot then return nil, nil end
    
    local nearest, shortest = nil, 300
    local nearestModel = nil

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LP.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")
            
            if hum and root and hum.Health > 0 and root.Position.Y > -50 then
                if Config.TargetFilter == "Apenas Boss" and not Utils.IsBoss(obj) then
                    continue
                end

                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < shortest then 
                    shortest = dist
                    nearest = root 
                    nearestModel = obj
                end
            end
        end
    end
    return nearest, nearestModel
end

function Utils.FlyToTarget()
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    
    local target, model = Utils.GetNearestNPC()
    if target then
        CurrentTarget = target
        CurrentTargetModel = model
        
        local targetCFrame = target.CFrame
        local finalPos

        if Config.FlyPosition == "Centro (Hitbox)" then
            finalPos = targetCFrame 
        elseif Config.FlyPosition == "Frente" then 
            finalPos = targetCFrame * CFrame.new(0, Config.FlyHeight, -Config.FlyDistance) 
        elseif Config.FlyPosition == "Atrás" then 
            finalPos = targetCFrame * CFrame.new(0, Config.FlyHeight, Config.FlyDistance) 
        elseif Config.FlyPosition == "Lado Direito" then 
            finalPos = targetCFrame * CFrame.new(Config.FlyDistance, Config.FlyHeight, 0) 
        elseif Config.FlyPosition == "Lado Esquerdo" then 
            finalPos = targetCFrame * CFrame.new(-Config.FlyDistance, Config.FlyHeight, 0) 
        elseif Config.FlyPosition == "Em Cima" then 
            finalPos = targetCFrame * CFrame.new(0, Config.FlyDistance + Config.FlyHeight, 0) 
        elseif Config.FlyPosition == "Em Baixo" then 
            finalPos = targetCFrame * CFrame.new(0, -Config.FlyDistance + Config.FlyHeight, 0) 
        end
        
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        
        if (myRoot.Position - finalPos.Position).Magnitude > 2 then
            if Tween then Tween:Cancel() end
            local tweenInfo = TweenInfo.new((myRoot.Position - finalPos.Position).Magnitude / Config.TweenSpeed, Enum.EasingStyle.Linear)
            Tween = TweenService:Create(myRoot, tweenInfo, {CFrame = finalPos})
            Tween:Play()
        else
            myRoot.CFrame = finalPos
        end
        
        myRoot.CFrame = CFrame.new(myRoot.Position, target.Position)
    else
        CurrentTargetModel = nil
    end
end

function Utils.StopFlight()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    if Tween then Tween:Cancel() end
    CurrentTarget = nil
    CurrentTargetModel = nil
end

function Utils.AutoReplayTick()
    if not Config.AutoReplay then return end
    local playerGui = LP:FindFirstChild("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                local nameLower = string.lower(gui.Name)
                local textLower = ""
                if gui:IsA("TextButton") then textLower = string.lower(gui.Text) end
                
                if string.find(nameLower, "replay") or string.find(nameLower, "retry") or string.find(nameLower, "again") or
                   string.find(textLower, "replay") or string.find(textLower, "retry") or string.find(textLower, "play again") then
                    if gui.Visible and gui.AbsoluteSize.Magnitude > 0 then
                        pcall(function() gui:Activate() end)
                        task.wait(2)
                        return
                    end
                end
            end
        end
    end
end

function Utils.UseSkill(skillNumber)
    local myRoot = Utils.GetRoot()
    if not myRoot then return end
    local aimCFrame = CurrentTarget and CFrame.new(myRoot.Position, CurrentTarget.Position) or myRoot.CFrame
    local args = { "UseSkill", { hrpCFrame = aimCFrame }, skillNumber }
    pcall(function() MainRemote:FireServer(unpack(args)) end)
end

function Utils.DoBasicAttack()
    if not Config.AutoClick then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(0, 0))
        task.wait(0.01)
        VirtualUser:Button1Up(Vector2.new(0, 0))
    end)
    pcall(function() MainRemote:FireServer("SetSkillIsInUse", false) end)
end

function Utils.DashTick()
    if not Config.InfiniteDash or not DashArgs then return end
    pcall(function() MainRemote:FireServer(unpack(DashArgs)) end)
end

function Utils.KillAuraTick()
    local myRoot = Utils.GetRoot()
    if not myRoot then return end

    if CurrentTargetModel then
        local humanoid = CurrentTargetModel:FindFirstChildOfClass("Humanoid")
        local mobRoot = CurrentTargetModel:FindFirstChild("HumanoidRootPart")
        
        if humanoid and mobRoot and humanoid.Health > 0 and mobRoot.Position.Y > -50 then
            pcall(function()
                firetouchinterest(myRoot, mobRoot, 0)
                task.wait(0.01)
                firetouchinterest(myRoot, mobRoot, 1)
            end)
            return
        end
    end

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {LP.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.MaxParts = 20
    local parts = Workspace:GetPartBoundsInRadius(myRoot.Position, Config.KillAuraRadius, params)
    
    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= LP.Character then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local mobRoot = model:FindFirstChild("HumanoidRootPart")
            if humanoid and mobRoot and humanoid.Health > 0 and mobRoot.Position.Y > -50 then
                if Config.TargetFilter == "Todos os NPCs" or (Config.TargetFilter == "Apenas Boss" and Utils.IsBoss(model)) then
                    pcall(function()
                        firetouchinterest(myRoot, mobRoot, 0)
                        task.wait(0.01)
                        firetouchinterest(myRoot, mobRoot, 1)
                    end)
                end
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
-- LOOPS DE AUTOMAÇÃO
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        local myRoot = Utils.GetRoot()
        if myRoot and myRoot.Position.Y < -50 then
            myRoot.CFrame = CFrame.new(0, 50, 0)
            Utils.StopFlight()
            task.wait(1)
        end

        if Config.Noclip then Utils.NoclipTick() end
        
        if Config.KillAura then 
            Utils.FlyToTarget()
            Utils.KillAuraTick() 
        else 
            Utils.StopFlight() 
        end

        if Config.AutoDodge then Utils.AutoDodgeTick() end
        if Config.AutoReplay then Utils.AutoReplayTick() end

        if Config.AutoSkill then
            for i = 1, 5 do 
                Utils.UseSkill(i)
                task.wait(0.1) 
            end
            task.wait(0.3)
        end
    end
end)

task.spawn(function() while task.wait(0.1) do Utils.DoBasicAttack() end end)
task.spawn(function() while task.wait(0.05) do Utils.DashTick() end end)

-- ==========================================
-- INTERFACE GRÁFICA PREMIUM (V30)
-- ==========================================
local function CreateWindow()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NinjaExec_Premium"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LP:WaitForChild("PlayerGui")

    local MiniBtn = Instance.new("TextButton")
    MiniBtn.Size = UDim2.new(0, 50, 0, 50)
    MiniBtn.Position = UDim2.new(0, 20, 0.5, -25)
    MiniBtn.BackgroundColor3 = Color3.fromRGB(130, 0, 255)
    MiniBtn.Text = "N"
    MiniBtn.TextColor3 = Color3.new(1,1,1)
    MiniBtn.Font = Enum.Font.GothamBlack
    MiniBtn.TextSize = 24
    MiniBtn.Visible = false
    MiniBtn.Parent = ScreenGui
    Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(1, 0)
    
    local MiniStroke = Instance.new("UIStroke", MiniBtn)
    MiniStroke.Color = Color3.fromRGB(255, 255, 255)
    MiniStroke.Thickness = 2

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 600, 0, 880) 
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -440)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Color3.fromRGB(130, 0, 255)
    MainStroke.Thickness = 2
    MainStroke.Transparency = 0.2

    local BgGradient = Instance.new("UIGradient", MainFrame)
    BgGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 15))
    }
    BgGradient.Rotation = 45

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 45)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    TitleBar.BackgroundTransparency = 0.5
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

    local TitleLine = Instance.new("Frame")
    TitleLine.Size = UDim2.new(1, 0, 0, 2)
    TitleLine.Position = UDim2.new(0, 0, 1, -2)
    TitleLine.BackgroundColor3 = Color3.fromRGB(130, 0, 255)
    TitleLine.BorderSizePixel = 0
    TitleLine.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "ninjaExec | ULTIMATE HUB"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 30, 0, 30)
    MinBtn.Position = UDim2.new(1, -40, 0, 7)
    MinBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.new(1,1,1)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 20
    MinBtn.Parent = TitleBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -75, 0, 7)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = TitleBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

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

    local miniDragging, miniDragStart, miniStartPos
    MiniBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            miniDragging = true; miniDragStart = input.Position; miniStartPos = MiniBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then miniDragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if miniDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - miniDragStart
            MiniBtn.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
        end
    end)

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniBtn.Visible = true
    end)

    MiniBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        MiniBtn.Visible = false
    end)

    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -20, 1, -120) 
    ContentFrame.Position = UDim2.new(0, 10, 0, 50)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame

    local function AddModernToggle(parent, text, key, default, yPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.Position = UDim2.new(0, 0, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        btn.BackgroundTransparency = 0.3
        btn.Text = "  " .. text
        btn.TextColor3 = Color3.fromRGB(200, 200, 210)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(60, 60, 80)
        stroke.Thickness = 1

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 16, 0, 16)
        indicator.Position = UDim2.new(1, -25, 0.5, -8)
        indicator.BackgroundColor3 = default and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(60, 60, 70)
        indicator.Parent = btn
        Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(130, 0, 255)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(60, 60, 80)}):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            if Config[key] then
                TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 255, 150)}):Play()
                TweenService:Create(btn, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
            else
                TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
                TweenService:Create(btn, TweenInfo.new(0.1), {TextColor3 = Color3.fromRGB(200, 200, 210)}):Play()
            end
        end)
    end

    local function AddModernDropdown(parent, text, options, key, default, yPos)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 65)
        frame.Position = UDim2.new(0, 0, 0, yPos)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
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

    AddModernToggle(ContentFrame, "🔥 Kill Aura (Voo Tático + Touch)", "KillAura", false, 0)
    AddModernToggle(ContentFrame, "⚡ Auto Skill (1-5)", "AutoSkill", false, 50)
    AddModernToggle(ContentFrame, "👊 Auto Click (Virtual M1)", "AutoClick", false, 100)
    AddModernToggle(ContentFrame, "💨 Auto Dodge", "AutoDodge", false, 150)
    AddModernToggle(ContentFrame, "👻 Noclip", "Noclip", false, 200)
    AddModernToggle(ContentFrame, "🔄 Auto Replay", "AutoReplay", false, 250)
    AddModernToggle(ContentFrame, "⚡ Ativar Dash (Espião)", "SpyDash", false, 300)
    AddModernToggle(ContentFrame, "⚡ Dash Infinito (Após Espiar)", "InfiniteDash", false, 350)

    AddModernDropdown(ContentFrame, "Posição do Voo", {
        "Centro (Hitbox)",
        "Frente", 
        "Atrás", 
        "Lado Direito", 
        "Lado Esquerdo", 
        "Em Cima", 
        "Em Baixo"
    }, "FlyPosition", "Centro (Hitbox)", 400)

    AddModernDropdown(ContentFrame, "Alvo de Foco", {
        "Todos os NPCs",
        "Apenas Boss"
    }, "TargetFilter", "Todos os NPCs", 475)

    -- ==========================================
    -- RODAPÉ COM BOTÃO DO DISCORD
    -- ==========================================
    local Footer = Instance.new("Frame")
    Footer.Size = UDim2.new(1, -20, 0, 40)
    Footer.Position = UDim2.new(0, 10, 1, -50)
    Footer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    Footer.BackgroundTransparency = 0.5
    Footer.BorderSizePixel = 0
    Footer.Parent = MainFrame
    Instance.new("UICorner", Footer).CornerRadius = UDim.new(0, 8)

    local FooterText = Instance.new("TextLabel")
    FooterText.Size = UDim2.new(0.5, 0, 1, 0)
    FooterText.Position = UDim2.new(0, 10, 0, 0)
    FooterText.BackgroundTransparency = 1
    FooterText.Text = "Criado por: ninjaExec"
    FooterText.TextColor3 = Color3.fromRGB(150, 150, 160)
    FooterText.Font = Enum.Font.GothamSemibold
    FooterText.TextSize = 13
    FooterText.TextXAlignment = Enum.TextXAlignment.Left
    FooterText.Parent = Footer

    -- BOTÃO DO DISCORD CLICÁVEL
    local DiscordBtn = Instance.new("TextButton")
    DiscordBtn.Size = UDim2.new(0, 140, 0, 26)
    DiscordBtn.Position = UDim2.new(1, -150, 0.5, -13)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242) -- Cor oficial do Discord
    DiscordBtn.Text = "Entrar no Discord"
    DiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DiscordBtn.Font = Enum.Font.GothamBold
    DiscordBtn.TextSize = 12
    DiscordBtn.AutoButtonColor = false
    DiscordBtn.Parent = Footer
    Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 6)

    -- Animação Hover do Botão do Discord
    DiscordBtn.MouseEnter:Connect(function()
        TweenService:Create(DiscordBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(110, 120, 255)}):Play()
    end)
    DiscordBtn.MouseLeave:Connect(function()
        TweenService:Create(DiscordBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(88, 101, 242)}):Play()
    end)

    -- Ação de clicar no botão
    DiscordBtn.MouseButton1Click:Connect(function()
        local link = "https://discord.gg/PfCsn6Quv"
        pcall(function()
            setclipboard(link) -- Copia o link para a área de transferência
        end)
        pcall(function()
            -- Tenta abrir o link no navegador/celular
            game:GetService("GuiService"):OpenBrowserWindow(link)
        end)
        
        StarterGui:SetCore("SendNotification", {
            Title = "Discord",
            Text = "Link copiado! Se não abriu, cole no seu navegador.",
            Duration = 5
        })
    end)
end

pcall(CreateWindow)
