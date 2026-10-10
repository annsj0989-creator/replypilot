-- +1 Speed 유령 탈출 - 클라이언트 (손맛 담당)
-- 화면 UI를 따로 만들지 않는다: 숫자는 leaderstats, 알림은 로블록스 기본 알림, 나머지는 3D/카메라 효과.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Plus1"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Plus1Remotes")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function playSound(name: string)
	local folder = SoundService:FindFirstChild("Plus1Sounds")
	local s = folder and folder:FindFirstChild(name)
	if s and s:IsA("Sound") then
		SoundService:PlayLocalSound(s)
	end
end

local function formatNumber(n: number): string
	local units = { "", "K", "M", "B", "T", "Qd", "Qn" }
	local i = 1
	while n >= 1000 and i < #units do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format(n < 10 and "%.2f%s" or n < 100 and "%.1f%s" or "%.0f%s", n, units[i])
end

---------------------------------------------------------------------
-- 알림 (로블록스 기본 알림창)
---------------------------------------------------------------------
local ICONS = { good = "✅", bad = "⛔", danger = "👻", rare = "🌟", info = "ℹ️" }
local function notify(title: string, text: string, kind: string)
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = (ICONS[kind] or "") .. " " .. title,
				Text = text,
				Duration = kind == "rare" and 6 or 3,
			})
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end
remotes:WaitForChild("Notice").OnClientEvent:Connect(function(title, text, kind)
	notify(title, text, kind)
	if kind == "danger" then
		playSound("Warning")
	elseif kind == "good" then
		playSound("Good")
	elseif kind == "rare" then
		playSound("Rare")
	end
end)

---------------------------------------------------------------------
-- 머리 위 +N 숫자
---------------------------------------------------------------------
remotes:WaitForChild("Gain").OnClientEvent:Connect(function(amount: number)
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(120, 255, 200)
	t.TextStrokeTransparency = 0
	t.Text = "+" .. formatNumber(amount) .. " ⚡"
	t.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(t, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		gui:Destroy()
	end)
end)

---------------------------------------------------------------------
-- 뽑기 연출
---------------------------------------------------------------------
remotes:WaitForChild("Hatch").OnClientEvent:Connect(function(id: string)
	local def = Config.SPIRITS[id]
	if not def then
		return
	end
	local big = def.rarity == "Legendary" or def.rarity == "Mythic" or def.rarity == "Secret"
	playSound(big and "Rare" or "Hatch")
	notify(def.icon .. " " .. def.name, def.rarity .. "  ·  x" .. def.mult .. " Speed", big and "rare" or "good")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = Config.RARITY_COLORS[def.rarity]
	cc.Brightness = big and 0.4 or 0.15
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(big and 1.2 or 0.5), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(1.3, function()
		cc:Destroy()
	end)
end)

---------------------------------------------------------------------
-- 잡혔을 때
---------------------------------------------------------------------
local shakeUntil = 0
remotes:WaitForChild("Caught").OnClientEvent:Connect(function()
	playSound("Caught")
	shakeUntil = os.clock() + 0.5
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = Color3.fromRGB(170, 210, 255)
	cc.Brightness = 0.6
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.8), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(0.9, function()
		cc:Destroy()
	end)
end)

---------------------------------------------------------------------
-- 속도감: 시야(FOV), 바람 파티클, 유령 접근 경고
---------------------------------------------------------------------
local wind: ParticleEmitter? = nil
local function attachWind(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1, -6)
	att.Parent = root
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	p.LightEmission = 1
	p.Transparency = NumberSequence.new(0.6, 1)
	p.Size = NumberSequence.new(0.15, 0)
	p.Lifetime = NumberRange.new(0.25, 0.4)
	p.Speed = NumberRange.new(60, 90)
	p.SpreadAngle = Vector2.new(25, 25)
	p.EmissionDirection = Enum.NormalId.Back
	p.Rate = 0
	p.Parent = att
	wind = p
end
player.CharacterAdded:Connect(attachWind)
if player.Character then
	task.spawn(attachWind, player.Character)
end

local ghostTint = Instance.new("ColorCorrectionEffect")
ghostTint.Name = "GhostNear"
ghostTint.Parent = Lighting

RunService:BindToRenderStep("Plus1Feel", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end

	-- 빠를수록 시야가 넓어짐
	local moving = hum.MoveDirection.Magnitude > 0.1
	local speedRatio = math.clamp((hum.WalkSpeed - Config.BASE_WALKSPEED) / (Config.MAX_WALKSPEED - Config.BASE_WALKSPEED), 0, 1)
	local targetFov = 70 + (moving and speedRatio * 30 or 0)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 6)

	if wind then
		wind.Rate = moving and speedRatio * 120 or 0
	end

	-- 유령이 뒤에 가까우면 화면이 차가워짐
	local gx = workspace:GetAttribute("GhostX") or -1000
	local gap = root.Position.X - gx
	local danger = (root.Position.X > 0 and gap > 0) and math.clamp(1 - gap / 150, 0, 1) or 0
	ghostTint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(170, 200, 255), danger)
	ghostTint.Saturation = -0.4 * danger

	if os.clock() < shakeUntil then
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * 4), math.rad((math.random() - 0.5) * 4), 0)
	end
end)
