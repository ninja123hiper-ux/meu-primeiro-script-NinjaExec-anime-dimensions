--[[
    ninjaExec | ULTIMATE (SLH Modified Structure)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local MainRemote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("MainRemoteEvent")

-- ==========================================
-- CONFIGURAÇÕES GLOBAIS (Settings)
-- ==========================================
getgenv().Settings = {
    -- Main / Farming
    MapSelection = "Death Dimension", SelectDifficulty = "Easy", WaitOnLobby = 10,
    AutoPlay = false, Hardcore = false, AutoReplay = false, FriendOnly = false, AutoSelectMap = false,
    -- Main / InGame (Antigo Config)
    Method = "Behind", ImportDistance = 10, TweenSpeed = 500,
    KillAura = false, Filter = "Todos os NPCs", FlyPos = "Centro (Hitbox)",
    AutoSkill = false, AutoAssistSkill = false, AutoFruitSkill = false,
    SelectAttackMethod = "Click", AutoMelee = false, AutoClick = false,
    Noclip = false, AutoDodge = false, SpyDash = false, InfiniteDash = false,
    -- More / JoiningCombo
    RaidSelection = "Auto", ExtremeDiff = "Extreme", ExtremeMinReward = 100, CooldownJoinRaid = 10,
    AutoRaid = false, FreeBossRush = false, BossRush = false, AutoSpeedRaid = false, AutoRaidChallenge = false,
    -- More / MoreFunction
    AutoDodgeSkill = false, AutoDeleteMap = false, AutoRedeemAllCode = false, BackToLobbyIfExploit = false,
    HideName = false, DashNoCooldown = false, AutoWalkBoss = false, AutoClaimQuest = false,
    GoLobbyMethod = "TeleportToLobby", BackToLobbyIfRaidOpen = false, StopReplayIfRaidOpen = false,
    -- Character
    AutoEquip = false, AutoResetMain = false, AutoResetAssist = false, SelectRarity = "Common", AutoSellCard = false,
    EquipBestCard = false, EquipBestCardMode = "Damage/Crit",
    -- Setting
    SizeDodgePart = 3.5, SizeDodgePartY = 100, TweenSpeedDodge = 0.15, DodgeTransparency = 0.9,
    GoAFK = false, SelectWaveToReset = 100, ResetINFMode = false,
    SkillFirst = 4, SkillSecond = 3, SkillThird = 5, SkillFourth = 1, SkillFifth = 2,
    -- Buy
    SelectMethodBuy = "Default", BuyRushTicket = false, Buy100RaidToken = false,
    -- Webhook
    WebhookUrl = "", SendDimensionDrops = false, SendRaidDrops = false,
    -- Misc
    Speed = 16, Jump = 50, WalkSpeed = false, JumpPower = false, CtrlClickTP = false, CloseGuiAfterExecute = false,
    StatGuiPosition = "Right", CreditGuiPosition = "Left", StatGui = false, CreditGui = false,
    RejoinIfKick = false, Whitescreen = false
}

local DashArgs, CurrentTarget, CurrentTargetModel, Tween = nil, nil, nil, nil
local isWhitescreen = false

LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)

-- ==========================================
-- SISTEMA DE ESPIONAGEM (SPY DASH)
-- ==========================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if getgenv().Settings.SpyDash and self == MainRemote and tostring(method) == "FireServer" then
        local cmd = tostring(args[1]):lower()
        if string.find(cmd, "dash") or string.find(cmd, "step") or string.find(cmd, "roll") then
            DashArgs = args
            getgenv().Settings.SpyDash = false
            getgenv().Settings.InfiniteDash = true
            StarterGui:SetCore("SendNotification", {Title="Dash Capturado!", Text="Ativado.", Duration=5})
        end
    end
    return oldNamecall(self, ...)
end)

-- ==========================================
-- FUNÇÕES BASE
-- ==========================================
local function GetRoot() 
    local c = LocalPlayer.Character 
    return c and c:FindFirstChild("HumanoidRootPart") 
end

local function IsBoss(obj)
    local name = string.lower(obj.Name)
    if string.find(name, "boss") or string.find(name, "raid") or string.find(name, "king") or string.find(name, "lord") then return true end
    local hrp = obj:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Size.Magnitude > 20 then return true end
    return false
end

local function GetNPC()
    local myRoot = GetRoot() 
    if not myRoot then return end
    local nearest, shortest, nearestModel = nil, 300, nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 and root.Position.Y > -50 then
                if getgenv().Settings.Filter == "Boss" and not IsBoss(obj) then continue end
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < shortest then shortest = dist nearest = root nearestModel = obj end
            end
        end
    end
    return nearest, nearestModel
end

local function Fly()
    local myRoot = GetRoot() 
    if not myRoot then return end
    local target, model = GetNPC()
    if target then
        CurrentTarget, CurrentTargetModel = target, model
        local cf = target.CFrame
        local fp
        if getgenv().Settings.FlyPos == "Centro (Hitbox)" then fp = cf
        elseif getgenv().Settings.FlyPos == "Frente" then fp = cf * CFrame.new(0, 5, -10)
        elseif getgenv().Settings.FlyPos == "Atrás" then fp = cf * CFrame.new(0, 5, 10)
        elseif getgenv().Settings.FlyPos == "Direita" then fp = cf * CFrame.new(10, 5, 0)
        elseif getgenv().Settings.FlyPos == "Esquerda" then fp = cf * CFrame.new(-10, 5, 0)
        elseif getgenv().Settings.FlyPos == "Cima" then fp = cf * CFrame.new(0, 15, 0)
        elseif getgenv().Settings.FlyPos == "Baixo" then fp = cf * CFrame.new(0, -5, 0) end
        
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        
        if (myRoot.Position - fp.Position).Magnitude > 2 then
            if Tween then Tween:Cancel() end
            Tween = TweenService:Create(myRoot, TweenInfo.new((myRoot.Position - fp.Position).Magnitude / getgenv().Settings.TweenSpeed), {CFrame = fp})
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
    local myRoot = GetRoot() 
    if not myRoot then return end
    if CurrentTargetModel then
        local hum = CurrentTargetModel:FindFirstChildOfClass("Humanoid")
        local root = CurrentTargetModel:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            firetouchinterest(myRoot, root, 0) task.wait(0.01) firetouchinterest(myRoot, root, 1) return
        end
    end
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.MaxParts = 20
    for _, v in ipairs(Workspace:GetPartBoundsInRadius(myRoot.Position, getgenv().Settings.ImportDistance, params)) do
        local m = v:FindFirstAncestorOfClass("Model")
        if m and m ~= LocalPlayer.Character then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 and root.Position.Y > -50 then
                if getgenv().Settings.Filter == "Todos os NPCs" or (getgenv().Settings.Filter == "Boss" and IsBoss(m)) then
                    firetouchinterest(myRoot, root, 0) task.wait(0.01) firetouchinterest(myRoot, root, 1)
                end
            end
        end
    end
end

-- ==========================================
-- LOOPS DE AUTOMAÇÃO
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        local myRoot = GetRoot()
        if myRoot and myRoot.Position.Y < -50 then myRoot.CFrame = CFrame.new(0, 50, 0) StopFlight() end
        if getgenv().Settings.Noclip then
            for _, pt in ipairs(LocalPlayer.Character:GetDescendants()) do
                if pt:IsA("BasePart") then pt.CanCollide = false end
            end
        end
        if getgenv().Settings.KillAura or getgenv().Settings.AutoMob then Fly() Aura() else StopFlight() end
        if getgenv().Settings.AutoSkill then
            for i = 1, 5 do
                local aim = CurrentTarget and CFrame.new(GetRoot().Position, CurrentTarget.Position) or GetRoot().CFrame
                pcall(function() MainRemote:FireServer("UseSkill", {hrpCFrame = aim}, i) end)
                task.wait(0.1)
            end
        end
        if getgenv().Settings.AutoDodgeSkill then
            local myRoot = GetRoot()
            if myRoot then
                local parts = Workspace:GetPartBoundsInRadius(myRoot.Position, 20, OverlapParams.new())
                for _, part in ipairs(parts) do
                    if string.find(string.lower(part.Name), "telegraph") then
                        myRoot.CFrame = myRoot.CFrame + myRoot.CFrame.RightVector * 15
                        task.wait(0.3)
                        break
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if getgenv().Settings.AutoClick then
            pcall(function() VirtualUser:CaptureController() VirtualUser:Button1Down(Vector2.new(0, 0)) task.wait(0.01) VirtualUser:Button1Up(Vector2.new(0, 0)) end)
            pcall(function() MainRemote:FireServer("SetSkillIsInUse", false) end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.05) do
        if getgenv().Settings.InfiniteDash and DashArgs then
            pcall(function() MainRemote:FireServer(unpack(DashArgs)) end)
        end
    end
end)

-- ==========================================
-- FUNÇÕES UNIVERSAIS (MISC)
-- ==========================================
local function UpdateCharacterStats()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            if getgenv().Settings.WalkSpeed then hum.WalkSpeed = getgenv().Settings.Speed end
            if getgenv().Settings.JumpPower then hum.JumpPower = getgenv().Settings.Jump; hum.UseJumpPower = true end
        end
    end
end
RunService.Heartbeat:Connect(UpdateCharacterStats)

local function SendWebhook(title, desc)
    if getgenv().Settings.WebhookUrl == "" then return end
    local data = {["embeds"] = {{["title"] = title, ["description"] = desc, ["color"] = 16711680}}}
    pcall(function() HttpService:PostAsync(getgenv().Settings.WebhookUrl, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson) end)
end

-- ==========================================
-- INTERFACE GRÁFICA (7 ABAS)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.IgnoreGuiInset = true

-- Bolinha Premium
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
local Stroke = Instance.new("UIStroke", MiniBtn)
Stroke.Color = Color3.fromRGB(220, 150, 255)
Stroke.Thickness = 2.5

local dragging, dragStart, startPos, moved = false, nil, nil, false
MiniBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true moved = false dragStart = input.Position startPos = MiniBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then moved = true end
        if moved then MiniBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

-- Menu Principal
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 450, 0, 650)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -325)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(130, 0, 255)

MiniBtn.MouseButton1Click:Connect(function() if not moved then MainFrame.Visible = true MiniBtn.Visible = false end end)

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
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local mdrag, mdIn, mdSt, msP
TitleBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then mdrag = true mdSt = i.Position msP = MainFrame.Position end end)
UserInputService.InputChanged:Connect(function(i) if mdrag and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - mdSt MainFrame.Position = UDim2.new(msP.X.Scale, msP.X.Offset + d.X, msP.Y.Scale, msP.Y.Offset + d.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then mdrag = false end end)

MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false MiniBtn.Visible = true end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Área das Abas (Tabs)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 45)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
TabBar.Parent = MainFrame
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 6)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -130)
Content.Position = UDim2.new(0, 8, 0, 80)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame
local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1,0,1,0)
ContentScroll.BackgroundTransparency = 1
ContentScroll.ScrollBarThickness = 4
ContentScroll.Parent = Content

-- Criador de Elementos
local function AddToggle(txt, key, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -5, 0, 30)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    b.Text = "  " .. txt
    b.TextColor3 = Color3.fromRGB(200, 200, 210)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = ContentScroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local ind = Instance.new("Frame")
    ind.Size = UDim2.new(0, 14, 0, 14)
    ind.Position = UDim2.new(1, -20, 0.5, -7)
    ind.BackgroundColor3 = getgenv().Settings[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(60, 60, 70)
    ind.Parent = b
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    b.MouseButton1Click:Connect(function()
        getgenv().Settings[key] = not getgenv().Settings[key]
        ind.BackgroundColor3 = getgenv().Settings[key] and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(60, 60, 70)
    end)
end

local function AddDropdown(txt, opts, key, y)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -5, 0, 50)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    f.Parent = ContentScroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 20)
    l.Position = UDim2.new(0, 5, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt .. ": " .. getgenv().Settings[key]
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -10, 0, 25)
    b.Position = UDim2.new(0, 5, 0, 22)
    b.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    b.Text = getgenv().Settings[key]
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
    b.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
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
            getgenv().Settings[key] = v b.Text = v l.Text = txt .. ": " .. v list.Visible = false
        end)
    end
end

local function AddTextBox(txt, key, y, isNum)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -5, 0, 45)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    f.Parent = ContentScroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 20)
    l.Position = UDim2.new(0, 5, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(1, -10, 0, 20)
    b.Position = UDim2.new(0, 5, 0, 20)
    b.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    b.Text = tostring(getgenv().Settings[key])
    b.TextColor3 = Color3.fromRGB(0, 255, 150)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = f
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.FocusLost:Connect(function()
        if isNum then getgenv().Settings[key] = tonumber(b.Text) or 0 else getgenv().Settings[key] = b.Text end
    end)
end

local function AddButton(txt, key, y, func)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -5, 0, 30)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(130, 0, 255)
    b.Text = txt
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = ContentScroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(func)
end

-- SISTEMA DE ABAS
local Tabs = {"Main", "More", "Character", "Setting", "Buy", "Webhook", "Misc"}
local CurrentTab = "Main"

local function RefreshUI()
    for _, v in ipairs(ContentScroll:GetChildren()) do
        if v:IsA("GuiObject") then v:Destroy() end
    end
    local y = 0
    if CurrentTab == "Main" then
        AddDropdown("Mapa", {"Death Dimension", "Auto"}, "MapSelection", y) y = y + 55
        AddDropdown("Dificuldade", {"Easy", "Hard", "Nightmare"}, "SelectDifficulty", y) y = y + 55
        AddTextBox("Espera Lobby", "WaitOnLobby", y, true) y = y + 50
        AddToggle("Auto Play", "AutoPlay", y) y = y + 35
        AddToggle("Hardcore", "Hardcore", y) y = y + 35
        AddToggle("Auto Replay", "AutoReplay", y) y = y + 35
        AddDropdown("Posição do Voo", {"Centro (Hitbox)", "Frente", "Atrás", "Direita", "Esquerda", "Cima", "Baixo"}, "FlyPos", y) y = y + 55
        AddDropdown("Filtro Alvo", {"Todos os NPCs", "Boss"}, "Filter", y) y = y + 55
        AddToggle("Kill Aura", "KillAura", y) y = y + 35
        AddToggle("Auto Click", "AutoClick", y) y = y + 35
        AddToggle("Auto Skill", "AutoSkill", y) y = y + 35
        AddToggle("Noclip", "Noclip", y) y = y + 35
        AddToggle("Spy Dash", "SpyDash", y) y = y + 35
        AddToggle("Dash Infinito", "InfiniteDash", y)
    elseif CurrentTab == "More" then
        AddDropdown("Raid Selection", {"Auto"}, "RaidSelection", y) y = y + 55
        AddDropdown("Extreme Diff", {"Extreme"}, "ExtremeDiff", y) y = y + 55
        AddTextBox("Min Reward", "ExtremeMinReward", y, true) y = y + 50
        AddToggle("Auto Raid", "AutoRaid", y) y = y + 35
        AddToggle("Free Boss Rush", "FreeBossRush", y) y = y + 35
        AddToggle("Boss Rush", "BossRush", y) y = y + 35
        AddToggle("Auto Dodge Skill", "AutoDodgeSkill", y) y = y + 35
        AddButton("Return To Lobby", "", y, function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId) end) end) y = y + 35
    elseif CurrentTab == "Character" then
        AddToggle("Auto Equip", "AutoEquip", y) y = y + 35
        AddToggle("Auto Reset Main", "AutoResetMain", y) y = y + 35
        AddToggle("Auto Reset Assist", "AutoResetAssist", y) y = y + 35
        AddButton("Save Character", "", y, function() end) y = y + 35
        AddDropdown("Select Rarity", {"Common", "Rare", "Legendary"}, "SelectRarity", y) y = y + 55
        AddToggle("Auto Sell Card", "AutoSellCard", y) y = y + 35
        AddToggle("Equip Best Card", "EquipBestCard", y) y = y + 35
        AddDropdown("Mode", {"Damage/Crit"}, "EquipBestCardMode", y)
    elseif CurrentTab == "Setting" then
        AddTextBox("Size Dodge", "SizeDodgePart", y, true) y = y + 50
        AddTextBox("Size Dodge Y", "SizeDodgePartY", y, true) y = y + 50
        AddTextBox("Tween Speed Dodge", "TweenSpeedDodge", y, true) y = y + 50
        AddTextBox("Transparency", "DodgeTransparency", y, true) y = y + 50
        AddToggle("Go AFK", "GoAFK", y) y = y + 35
        AddTextBox("Select Wave", "SelectWaveToReset", y, true) y = y + 50
        AddToggle("Reset INF Mode", "ResetINFMode", y)
    elseif CurrentTab == "Buy" then
        AddDropdown("Method Buy", {"Default"}, "SelectMethodBuy", y) y = y + 55
        AddToggle("Buy Rush Ticket", "BuyRushTicket", y) y = y + 35
        AddToggle("Buy 100 Raid Token", "Buy100RaidToken", y)
    elseif CurrentTab == "Webhook" then
        AddTextBox("URL Webhook", "WebhookUrl", y, false) y = y + 50
        AddToggle("Send Dimension Drops", "SendDimensionDrops", y) y = y + 35
        AddToggle("Send Raid Drops", "SendRaidDrops", y) y = y + 35
        AddButton("Testar Webhook", "", y, function() SendWebhook("Teste", "O Webhook do ninjaExec está funcionando!") end)
    elseif CurrentTab == "Misc" then
        AddTextBox("Speed", "Speed", y, true) y = y + 50
        AddTextBox("Jump", "Jump", y, true) y = y + 50
        AddToggle("WalkSpeed", "WalkSpeed", y) y = y + 35
        AddToggle("JumpPower", "JumpPower", y) y = y + 35
        AddButton("Rejoin", "", y, function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId) end) end) y = y + 35
        AddButton("Whitescreen", "", y, function() 
            isWhitescreen = not isWhitescreen 
            RunService:Set3dRenderingEnabled(not isWhitescreen) 
        end) y = y + 35
        AddButton("Copy Discord Link", "", y, function() 
            pcall(function() setclipboard("https://discord.gg/PfCsn6Quv") end)
            StarterGui:SetCore("SendNotification", {Title="Discord", Text="Link copiado!", Duration=5})
        end) y = y + 35
        AddToggle("Rejoin If Kick", "RejoinIfKick", y) y = y + 35
        AddToggle("Stat GUI", "StatGui", y) y = y + 35
        AddToggle("Credit GUI", "CreditGui", y)
    end
    
    ContentScroll.CanvasSize = U UDim2.new(0, 0, 0, y + 60)
end

-- Criar os botões das Abas (Tabs)
local tabButtons = {}
local tabX = 0
for _, tabName in ipairs(Tabs) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(1/#Tabs, -2, 1, 0)
    tb.Position = UDim2.new(tabX, 0, 0, 0)
    tb.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    tb.Text = tabName
    tb.TextColor3 = Color3.fromRGB(200, 200, 210)
    tb.Font = Enum.Font.GothamBold
    tb.TextSize = 11
    tb.Parent = TabBar
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
    
    tb.MouseButton1Click:Connect(function()
        CurrentTab = tabName
        for _, other in pairs(tabButtons) do
            other.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        end
        tb.BackgroundColor3 = Color3.fromRGB(130, 0, 255)
        RefreshUI()
    end)
    
    tabButtons[tabName] = tb
    tabX = tabX + (1/#Tabs)
end

-- Inicializa a primeira aba
tabButtons["Main"].BackgroundColor3 = Color3.fromRGB(130, 0, 255)
RefreshUI()

-- ==========================================
-- RODAPÉ COM BOTÃO DO DISCORD
-- ==========================================
local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, -16, 0, 40)
Footer.Position = UDim2.new(0, 8, 1, -50)
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
FText.TextSize = 11
FText.TextXAlignment = Enum.TextXAlignment.Left
FText.Parent = Footer

local DBtn = Instance.new("TextButton")
DBtn.Size = UDim2.new(0, 120, 0, 26)
DBtn.Position = UDim2.new(1, -130, 0.5, -13)
DBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
DBtn.Text = "Discord"
DBtn.TextColor3 = Color3.new(1, 1, 1)
DBtn.Font = Enum.Font.GothamBold
DBtn.TextSize = 11
DBtn.AutoButtonColor = false
DBtn.Parent = Footer
Instance.new("UICorner", DBtn).CornerRadius = UDim.new(0, 6)

DBtn.MouseEnter:Connect(function()
    TweenService:Create(DBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(110, 120, 255)}):Play()
end)
DBtn.MouseLeave:Connect(function()
    TweenService:Create(DBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(88, 101, 242)}):Play()
end)

DBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard("https://discord.gg/PfCsn6Quv") end)
    pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/PfCsn6Quv") end)
    StarterGui:SetCore("SendNotification", {Title="Discord", Text="Link copiado! Cole no navegador se não abrir.", Duration=5})
end)
