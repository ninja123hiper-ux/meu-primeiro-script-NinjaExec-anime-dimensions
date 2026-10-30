local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local MainRemote = game:GetService("ReplicatedStorage").RemoteEvents.MainRemoteEvent

local Config = {
    KillAura = false, AutoSkill = false, AutoClick = false, AutoDodge = false, 
    Noclip = false, AutoReplay = false, InfiniteDash = false, SpyDash = false, 
    FlyPos = "Centro (Hitbox)", Filter = "Todos os NPCs"
}
local DashArgs, CurrentTarget, Tween = nil, nil, nil

LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)

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
            StarterGui:SetCore("SendNotification", {Title="Dash Capturado!", Text="Ativado.", Duration=5})
        end
    end
    return oldNamecall(self, ...)
end)

local function GetRoot() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

local function IsBoss(obj)
    local name = string.lower(obj.Name)
    if string.find(name, "boss") or string.find(name, "raid") or string.find(name, "king") or string.find(name, "lord") then return true end
    local hrp = obj:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Size.Magnitude > 20 then return true end
    return false
end

local function GetNPC()
    local myRoot = GetRoot() if not myRoot then return end
    local nearest, shortest, nearestModel = nil, 300, nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 and root.Position.Y > -50 then
                if Config.Filter == "Boss" and not IsBoss(obj) then continue end
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < shortest then shortest = dist nearest = root nearestModel = obj end
            end
        end
    end
    return nearest, nearestModel
end

local function Fly()
    local myRoot = GetRoot() if not myRoot then return end
    local target, model = GetNPC()
    if target then
        CurrentTarget, CurrentTargetModel = target, model
        local cf = target.CFrame
        local fp
        if Config.FlyPos == "Centro (Hitbox)" then fp = cf
        elseif Config.FlyPos == "Frente" then fp = cf * CFrame.new(0, 5, -10)
        elseif Config.FlyPos == "Atrás" then fp = cf * CFrame.new(0, 5, 10)
        elseif Config.FlyPos == "Direita" then fp = cf * CFrame.new(10, 5, 0)
        elseif Config.FlyPos == "Esquerda" then fp = cf * CFrame.new(-10, 5, 0)
        elseif Config.FlyPos == "Cima" then fp = cf * CFrame.new(0, 15, 0)
        elseif Config.FlyPos == "Baixo" then fp = cf * CFrame.new(0, -5, 0) end
        
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        
        if (myRoot.Position - fp.Position).Magnitude > 2 then
            if Tween then Tween:Cancel() end
            Tween = TweenService:Create(myRoot, TweenInfo.new((myRoot.Position - fp.Position).Magnitude / 500), {CFrame = fp})
            Tween:Play()
        else
            myRoot.CFrame = fp
        end
        myRoot.CFrame = CFrame.new(myRoot.Position, target.Position)
    else
        CurrentTargetModel = nil
    end
end

local function StopFlight()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    if Tween then Tween:Cancel() end
    CurrentTarget, CurrentTargetModel = nil, nil
end

local function Aura()
    local myRoot = GetRoot() if not myRoot then return end
    if CurrentTargetModel then
        local hum = CurrentTargetModel:FindFirstChildOfClass("Humanoid")
        local root = CurrentTargetModel:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            firetouchinterest(myRoot, root, 0) task.wait(0.01) firetouchinterest(myRoot, root, 1)
            return
        end
    end
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.MaxParts = 20
    for _, v in ipairs(Workspace:GetPartBoundsInRadius(myRoot.Position, 30, params)) do
        local m = v:FindFirstAncestorOfClass("Model")
        if m and m ~= LocalPlayer.Character then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 and root.Position.Y > -50 then
                if Config.Filter == "Todos os NPCs" or (Config.Filter == "Boss" and IsBoss(m)) then
                    firetouchinterest(myRoot, root, 0) task.wait(0.01) firetouchinterest(myRoot, root, 1)
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        local myRoot = GetRoot()
        if myRoot and myRoot.Position.Y < -50 then
            myRoot.CFrame = CFrame.new(0, 50, 0) StopFlight()
        end
        if Config.Noclip then
            for _, pt in ipairs(LocalPlayer.Character:GetDescendants()) do
                if pt:IsA("BasePart") then pt.CanCollide = false end
            end
        end
        if Config.KillAura then Fly() Aura() else StopFlight() end
        if Config.AutoSkill then
            for i = 1, 5 do
                local aim = CurrentTarget and CFrame.new(GetRoot().Position, CurrentTarget.Position) or GetRoot().CFrame
                pcall(function() MainRemote:FireServer("UseSkill", {hrpCFrame = aim}, i) end)
                task.wait(0.1)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if Config.AutoClick then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(0, 0))
                task.wait(0.01)
                VirtualUser:Button1Up(Vector2.new(0, 0))
            end)
            pcall(function() MainRemote:FireServer("SetSkillIsInUse", false) end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.05) do
        if Config.InfiniteDash and DashArgs then
            pcall(function() MainRemote:FireServer(unpack(DashArgs)) end)
        end
    end
end)

-- ==========================================
-- INTERFACE GRÁFICA
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.IgnoreGuiInset = true

-- BOTÃO MINIMIZAR (Bolinha Premium)
local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0, 60, 0, 60)
MiniBtn.Position = UDim2.new(0, 20, 0.5, -30)
MiniBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
MiniBtn.Text = "N"
MiniBtn.TextColor3 = Color3.new(1, 1, 1)
MiniBtn.Font = Enum.Font.GothamBlack
MiniBtn.TextSize = 28
MiniBtn.Visible = false
MiniBtn.AutoButtonColor = false
MiniBtn.Parent = ScreenGui
Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(1, 0)

local Grad = Instance.new("UIGradient", MiniBtn)
Grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 0, 200))}
Grad.Rotation = 45

local Stroke = Instance.new("UIStroke", MiniBtn)
Stroke.Color = Color3.fromRGB(220, 150, 255)
Stroke.Thickness = 2.5

-- Lógica de Arrastar (Só abre se clicar rápido)
local dragging, dragStart, startPos, moved = false, nil, nil, false

MiniBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        moved = false
        dragStart = input.Position
        startPos = MiniBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then moved = true end
        if moved then
            MiniBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- MENU PRINCIPAL
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 420, 0, 600)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -300)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(130, 0, 255)

MiniBtn.MouseButton1Click:Connect(function()
    if not moved then
        MainFrame.Visible = true
        MiniBtn.Visible = false
    end
end)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ninjaExec | ULTIMATE"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 25, 0, 25)
MinBtn.Position = UDim2.new(1, -60, 0, 7)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Arrastar Menu Principal
local mdrag, mdIn, mdSt, msP
TitleBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mdrag = true mdSt = i.Position msP = MainFrame.Position i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then mdrag = false end end) end end)
UserInputService.InputChanged:Connect(function(i) if mdrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - mdSt MainFrame.Position = UDim2.new(msP.X.Scale, msP.X.Offset + d.X, msP.Y.Scale, msP.Y.Offset + d.Y) end end)

MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false MiniBtn.Visible = true end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -55)
Content.Position = UDim2.new(0, 8, 0, 45)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function AddToggle(txt, key, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    b.Text = "  " .. txt
    b.TextColor3 = Color3.fromRGB(200, 200, 210)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, 14, 0, 14)
    ind.Position = UDim2.new(1, -20, 0.5, -7)
    ind.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    ind.Parent = b
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    
    b.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        ind.BackgroundColor3 = Config[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(60, 60, 70)
    end)
end

local function AddDropdown(txt, opts, key, y)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 55)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    f.Parent = Content
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 20)
    l.Position = UDim2.new(0, 5, 0, 2)
    l.BackgroundTransparency = 1
    l.Text = txt .. ": " .. opts[1]
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -10, 0, 25)
    b.Position = UDim2.new(0, 5, 0, 22)
    b.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    b.Text = opts[1]
    b.TextColor3 = Color3.fromRGB(0, 255, 150)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    
    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, -10, 0, #opts * 25)
    list.Position = UDim2.new(0, 5, 0, 50)
    list.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    list.Visible = false
    list.ZIndex = 10
    list.Parent = f
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 4)
    
    b.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        f.Size = list.Visible and UDim2.new(1, 0, 0, 55 + #opts * 25) or UDim2.new(1, 0, 0, 55)
    end)
    
    for i, v in ipairs(opts) do
        local ob = Instance.new("TextButton")
        ob.Size = UDim2.new(1, 0, 0, 25)
        ob.Position = UDim2.new(0, 0, 0, (i-1)*25)
        ob.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        ob.Text = v
        ob.TextColor3 = Color3.fromRGB(200, 200, 210)
        ob.Font = Enum.Font.Gotham
        ob.TextSize = 11
        ob.ZIndex = 11
        ob.Parent = list
        ob.MouseButton1Click:Connect(function()
            Config[key] = v
            b.Text = v
            l.Text = txt .. ": " .. v
            list.Visible = false
            f.Size = UDim2.new(1, 0, 0, 55)
        end)
    end
end

AddToggle("🔥 Kill Aura", "KillAura", 0)
AddToggle("⚡ Auto Skill", "AutoSkill", 35)
AddToggle("👊 Auto Click", "AutoClick", 70)
AddToggle("💨 Auto Dodge", "AutoDodge", 105)
AddToggle("👻 Noclip", "Noclip", 140)
AddToggle("🔄 Auto Replay", "AutoReplay", 175)
AddToggle("⚡ Spy Dash", "SpyDash", 210)
AddToggle("⚡ Dash Infinito", "InfiniteDash", 245)

AddDropdown("Voo", {"Centro (Hitbox)", "Frente", "Atrás", "Direita", "Esquerda", "Cima", "Baixo"}, "FlyPos", 285)
AddDropdown("Alvo", {"Todos os NPCs", "Boss"}, "Filter", 350)

-- Rodapé
local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, -16, 0, 45)
Footer.Position = UDim2.new(0, 8, 1, -55)
Footer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Footer.Parent = MainFrame
Instance.new("UICorner", Footer).CornerRadius = UDim.new(0, 8)

local FText = Instance.new("TextLabel")
FText.Size = UDim2.new(0.5, 0, 1, 0)
FText.Position = UDim2.new(0, 10, 0, 0)
FText.BackgroundTransparency = 1
FText.Text = "Criado por: ninjaExec"
FText.TextColor3 = Color3.fromRGB(150, 150, 160)
FText.Font = Enum.Font.GothamSemibold
FText.TextSize = 12
FText.TextXAlignment = Enum.TextXAlignment.Left
FText.Parent = Footer

local DBtn = Instance.new("TextButton")
DBtn.Size = UDim2.new(0, 130, 0, 30)
DBtn.Position = UDim2.new(1, -140, 0.5, -15)
DBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
DBtn.Text = "Entrar no Discord"
DBtn.TextColor3 = Color3.new(1, 1, 1)
DBtn.Font = Enum.Font.GothamBold
DBtn.TextSize = 12
DBtn.Parent = Footer
Instance.new("UICorner", DBtn).CornerRadius = UDim.new(0, 6)

DBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard("https://discord.gg/PfCsn6Quv") end)
    pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/PfCsn6Quv") end)
    StarterGui:SetCore("SendNotification", {Title="Discord", Text="Link copiado!", Duration=5})
end)
