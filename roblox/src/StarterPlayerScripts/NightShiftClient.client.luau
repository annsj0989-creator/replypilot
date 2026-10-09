-- 편의점 야간 알바 - 클라이언트
-- UI는 코드로 만들지 않는다. StarterGui 에 디자인해 둔 "HUD" ScreenGui 안의 요소를 이름으로 찾아서 값만 채운다.
-- 없는 요소는 건너뛰므로, UI를 만드는 중에도 게임은 돌아간다. (BUILD_GUIDE.md 의 UI 목록 참고)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("NightShift"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("NightShiftRemotes")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD", 10)
if not hud then
	warn("[NightShift] StarterGui 에 'HUD' ScreenGui 가 없어요. (BUILD_GUIDE.md 참고)")
end

local function ui(path: string): Instance?
	if not hud then
		return nil
	end
	local node: Instance? = hud
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function setText(path: string, text: string)
	local label = ui(path)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = text
	end
end

local function setVisible(path: string, visible: boolean)
	local node = ui(path)
	if node and node:IsA("GuiObject") then
		node.Visible = visible
	end
end

local function playSound(name: string)
	local folder = SoundService:FindFirstChild("NightShiftSounds")
	local sound = folder and folder:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		SoundService:PlayLocalSound(sound)
	end
end

local function formatClock(minutes: number): string
	local h = math.floor(minutes / 60) % 24
	local m = math.floor(minutes % 60)
	local suffix = h >= 12 and "PM" or "AM"
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, m, suffix)
end

---------------------------------------------------------------------
-- 화면 효과 (UI가 아니라 Lighting 후처리)
---------------------------------------------------------------------
local cc = Lighting:FindFirstChild("SanityColor") :: ColorCorrectionEffect?
if not cc then
	local created = Instance.new("ColorCorrectionEffect")
	created.Name = "SanityColor"
	created.Parent = Lighting
	cc = created
end
local blur = Lighting:FindFirstChild("SanityBlur") :: BlurEffect?
if not blur then
	local created = Instance.new("BlurEffect")
	created.Name = "SanityBlur"
	created.Size = 0
	created.Parent = Lighting
	blur = created
end

local shakeUntil = 0
local shakePower = 0
RunService:BindToRenderStep("NightShiftShake", Enum.RenderPriority.Camera.Value + 1, function()
	local t = os.clock()
	if t < shakeUntil then
		local p = shakePower * ((shakeUntil - t) / 0.6)
		camera.CFrame = camera.CFrame
			* CFrame.Angles(math.rad((math.random() - 0.5) * p), math.rad((math.random() - 0.5) * p), 0)
	end
end)

---------------------------------------------------------------------
-- 알림
---------------------------------------------------------------------
local NOTICE_COLORS = {
	good = Color3.fromRGB(120, 255, 150),
	bad = Color3.fromRGB(255, 170, 90),
	danger = Color3.fromRGB(255, 70, 70),
	info = Color3.fromRGB(235, 235, 235),
}
local noticeToken = 0
remotes:WaitForChild("Notice").OnClientEvent:Connect(function(text: string, kind: string)
	local label = ui("Notice")
	if not label or not label:IsA("TextLabel") then
		return
	end
	noticeToken += 1
	local token = noticeToken
	label.Text = text
	label.TextColor3 = NOTICE_COLORS[kind] or NOTICE_COLORS.info
	label.TextTransparency = 0
	label.Visible = true
	if kind == "danger" then
		playSound("Danger")
	elseif kind == "good" then
		playSound("Good")
	end
	task.delay(2.8, function()
		if token == noticeToken then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end)

-- 손님 말풍선 (Roblox 기본 말풍선 사용)
remotes:WaitForChild("Bubble").OnClientEvent:Connect(function(head: BasePart, text: string)
	if head and head.Parent then
		pcall(function()
			TextChatService:DisplayBubble(head, text)
		end)
	end
end)

-- 점프스케어
remotes:WaitForChild("Jumpscare").OnClientEvent:Connect(function()
	playSound("Jumpscare")
	shakePower = 6
	shakeUntil = os.clock() + 0.6
	local img = ui("Jumpscare")
	if img and img:IsA("GuiObject") then
		img.Visible = true
		task.delay(0.7, function()
			img.Visible = false
		end)
	end
end)

-- 결과
remotes:WaitForChild("Results").OnClientEvent:Connect(function(r)
	setText("Results.Title", r.cleared and (r.night .. "번째 밤 생존!") or (r.night .. "번째 밤 실패..."))
	local lines = {
		"계산한 손님: " .. r.served,
		"잡아낸 이상현상: " .. r.caught,
		"잘못 신고: " .. r.wrongReports,
		"번 코인: " .. r.coins,
	}
	if #r.missed > 0 then
		table.insert(lines, "놓친 이상현상: " .. table.concat(r.missed, ", "))
	end
	setText("Results.Body", table.concat(lines, "\n"))
	setVisible("Results", true)
	playSound(r.cleared and "Clear" or "Fail")
	task.delay(Config.RESULTS_TIME - 0.5, function()
		setVisible("Results", false)
	end)
end)

-- 부활 버튼
local reviveButton = ui("Fainted.ReviveButton")
if reviveButton and reviveButton:IsA("GuiButton") then
	reviveButton.Activated:Connect(function()
		local id = ReplicatedStorage:GetAttribute("ReviveProductId")
		if typeof(id) == "number" and id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
end

---------------------------------------------------------------------
-- 매 프레임 갱신
---------------------------------------------------------------------
local lastSanity = Config.MAX_SANITY
RunService.Heartbeat:Connect(function()
	local phase = workspace:GetAttribute("Phase")
	local onShift = phase == "Shift" and player:GetAttribute("OnShift") == true
	local fainted = player:GetAttribute("Fainted") == true

	setText("Clock", formatClock(workspace:GetAttribute("ClockMinutes") or 0))
	setText("Night", (workspace:GetAttribute("Night") or 1) .. "번째 밤")
	setVisible("Clock", phase == "Shift")
	setVisible("Sanity", onShift)

	local countdown = workspace:GetAttribute("Countdown") or 0
	setVisible("Countdown", phase == "Lobby" and countdown > 0)
	setText("Countdown", "근무 시작까지 " .. countdown .. "초")

	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("코인") :: IntValue?
	setText("Coins", tostring(coins and coins.Value or 0))

	local reviveId = ReplicatedStorage:GetAttribute("ReviveProductId")
	setVisible("Fainted", onShift and fainted)
	setVisible("Fainted.ReviveButton", typeof(reviveId) == "number" and reviveId ~= 0)

	local sanity = onShift and (player:GetAttribute("Sanity") or Config.MAX_SANITY) or Config.MAX_SANITY
	local ratio = sanity / Config.MAX_SANITY
	local fill = ui("Sanity.Fill")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.new(ratio, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
	end

	-- 정신력이 낮을수록 화면이 탁해지고 흐려진다
	local danger = math.clamp(1 - ratio / 0.5, 0, 1)
	if cc then
		cc.Saturation = -0.7 * danger
		cc.Contrast = 0.15 * danger
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 200, 200), danger)
	end
	if blur then
		blur.Size = danger * 6 + (math.sin(os.clock() * 2) + 1) * danger * 2
	end
	if sanity < lastSanity - 8 then
		shakePower = 3
		shakeUntil = os.clock() + 0.4
	end
	lastSanity = sanity
end)
