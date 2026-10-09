-- 몬스터 훔치기 - 클라이언트 UI
-- 위치: StarterPlayer > StarterPlayerScripts 안에 "LocalScript"로 넣기

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MonsterRemotes")
local NotifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
local SpeedRemote = remotes:WaitForChild("RequestSpeed") :: RemoteEvent
local LockRemote = remotes:WaitForChild("RequestLock") :: RemoteEvent

local function formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

---------------------------------------------------------------------
-- 내 몬스터의 "훔치기" 버튼 숨기기
---------------------------------------------------------------------
local function hideOwnPrompt(inst: Instance)
	if inst:IsA("ProximityPrompt") and inst:GetAttribute("OwnerId") == player.UserId then
		inst.Enabled = false
	end
end
for _, inst in ipairs(workspace:GetDescendants()) do
	hideOwnPrompt(inst)
end
workspace.DescendantAdded:Connect(hideOwnPrompt)

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MonsterUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- 상단: 돈 / 초당 수입
local topLabel = Instance.new("TextLabel")
topLabel.AnchorPoint = Vector2.new(0.5, 0)
topLabel.Position = UDim2.new(0.5, 0, 0, 10)
topLabel.Size = UDim2.fromOffset(320, 44)
topLabel.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
topLabel.BackgroundTransparency = 0.25
topLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
topLabel.Font = Enum.Font.FredokaOne
topLabel.TextScaled = true
topLabel.Text = "$0"
topLabel.Parent = gui
corner(topLabel, 12)

-- 알림
local notifyLabel = Instance.new("TextLabel")
notifyLabel.AnchorPoint = Vector2.new(0.5, 0)
notifyLabel.Position = UDim2.new(0.5, 0, 0, 62)
notifyLabel.Size = UDim2.new(0.8, 0, 0, 36)
notifyLabel.BackgroundTransparency = 1
notifyLabel.Font = Enum.Font.FredokaOne
notifyLabel.TextScaled = true
notifyLabel.TextTransparency = 1
notifyLabel.TextStrokeTransparency = 1
notifyLabel.Parent = gui

local notifyToken = 0
NotifyRemote.OnClientEvent:Connect(function(text: string, color: Color3)
	notifyToken += 1
	local myToken = notifyToken
	notifyLabel.Text = text
	notifyLabel.TextColor3 = color
	notifyLabel.TextTransparency = 0
	notifyLabel.TextStrokeTransparency = 0
	task.delay(2.5, function()
		if myToken ~= notifyToken then
			return
		end
		TweenService:Create(notifyLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end)

-- 하단 버튼들
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.fromOffset(540, 56)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.Parent = bar

local function makeButton(color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(170, 56)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = bar
	corner(b, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

local speedButton = makeButton(Color3.fromRGB(40, 120, 255))
local lockButton = makeButton(Color3.fromRGB(230, 70, 70))
local passButton = makeButton(Color3.fromRGB(240, 170, 20))
passButton.Text = "💰 돈 2배"

speedButton.Activated:Connect(function()
	SpeedRemote:FireServer()
end)
lockButton.Activated:Connect(function()
	LockRemote:FireServer()
end)
passButton.Activated:Connect(function()
	local passId = ReplicatedStorage:GetAttribute("Pass2xId")
	if typeof(passId) == "number" and passId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end
end)

-- 화면 갱신
while true do
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("돈") :: IntValue?
	local income = player:GetAttribute("Income") or 0
	topLabel.Text = "$" .. formatNumber(cash and cash.Value or 0) .. "   (+$" .. formatNumber(income) .. "/초)"

	local cost = player:GetAttribute("SpeedCost") or 0
	local level = player:GetAttribute("SpeedLevel") or 0
	speedButton.Text = "⚡ 속도 Lv." .. level .. " ($" .. formatNumber(cost) .. ")"

	local t = workspace:GetServerTimeNow()
	local lockedUntil = player:GetAttribute("LockedUntil") or 0
	local readyAt = player:GetAttribute("LockReadyAt") or 0
	if t < lockedUntil then
		lockButton.Text = "🔒 잠김 " .. math.ceil(lockedUntil - t) .. "초"
	elseif t < readyAt then
		lockButton.Text = "⏳ 대기 " .. math.ceil(readyAt - t) .. "초"
	else
		lockButton.Text = "🔒 기지 잠금"
	end

	local passId = ReplicatedStorage:GetAttribute("Pass2xId")
	passButton.Visible = typeof(passId) == "number" and passId ~= 0

	task.wait(0.2)
end
