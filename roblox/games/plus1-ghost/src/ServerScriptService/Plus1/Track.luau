-- 맵 생성: 로비(러닝머신, 관, 환생 석상) + 10구역 직선 트랙 + 결승선
-- 3D 에셋(블렌더 제작, roblox/games/plus1-ghost/assets)이 ServerStorage.Plus1Assets 에 있으면 그걸 쓰고,
-- 없으면 기본 블록으로 대신한다. 트랙 바닥 자체는 장르 표준인 블록 스타일.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Plus1"):WaitForChild("Config"))

local Track = {}

local L = Config.ZONE_LENGTH
local W = Config.TRACK_WIDTH
Track.FINISH_X = Config.ZONE_COUNT * L

local folder = Instance.new("Folder")
folder.Name = "Plus1Map"

local PALETTE = {
	ground = Color3.fromRGB(34, 38, 44),
	path = Color3.fromRGB(86, 82, 96),
	stone = Color3.fromRGB(70, 66, 82),
	rail = Color3.fromRGB(140, 255, 210),
	lantern = Color3.fromRGB(255, 185, 120),
}

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent or folder
	return p
end

local function label(parent: Instance, text: string, color: Color3, size: UDim2, offset: Vector3, maxDist: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDist or 150
	gui.LightInfluence = 0
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = gui
	return t
end

local function surfaceText(p: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = gui
end

local function zoneColor(zone: number): Color3
	local h = (0.75 - (zone - 1) / Config.ZONE_COUNT * 0.65) % 1
	return Color3.fromHSV(h, 0.45, 0.42)
end

---------------------------------------------------------------------
-- 에셋
---------------------------------------------------------------------
local warned = false
local function asset(name: string): Model?
	local src = ServerStorage:FindFirstChild("Plus1Assets")
	local a = src and src:FindFirstChild(name)
	if not a then
		if not warned then
			warned = true
			warn("[Plus1] ServerStorage.Plus1Assets 에 3D 에셋이 없어서 기본 블록으로 대신해요. (assets/README.md 참고)")
		end
		return nil
	end
	local c = a:Clone()
	local model: Model
	if c:IsA("Model") then
		model = c
	else
		model = Instance.new("Model")
		model.Name = name
		c.Parent = model
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model
end

-- 바닥 위치에 높이 height로 맞춰 세우고, face 방향을 바라보게 한다
local function place(model: Model, ground: Vector3, height: number, face: Vector3?, parent: Instance?): Model
	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
	end
	local rot = CFrame.new()
	if face and face.Magnitude > 0 then
		rot = CFrame.lookAt(Vector3.zero, Vector3.new(face.X, 0, face.Z)) * CFrame.Angles(0, math.rad(Config.ASSET_YAW_OFFSET), 0)
	end
	model:PivotTo(CFrame.new(model:GetPivot().Position) * rot)
	local bb, sz = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (ground - Vector3.new(bb.X, bb.Y - sz.Y / 2, bb.Z)))
	model.Parent = parent or folder
	return model
end

local function lanternLight(model: Instance, at: Vector3)
	local holder = part({ Name = "LanternLight", Size = Vector3.new(0.5, 0.5, 0.5), Position = at, Transparency = 1, CanCollide = false, CanQuery = false }, model)
	local l = Instance.new("PointLight")
	l.Color = PALETTE.lantern
	l.Range = 16
	l.Brightness = 0.7
	l.Shadows = false
	l.Parent = holder
end

local function decor(name: string, ground: Vector3, height: number, face: Vector3?)
	local m = asset(name)
	if m then
		place(m, ground, height, face)
		if name == "LanternPost" then
			-- 등불은 기둥 꼭대기 가운데 (높이의 약 82%)
			local bb, sz = m:GetBoundingBox()
			local at = Vector3.new(bb.X, bb.Y - sz.Y / 2 + sz.Y * 0.82, bb.Z)
			part({ Name = "LanternGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * sz.Y * 0.2, Position = at, Color = PALETTE.lantern, Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false, CanQuery = false }, m)
			lanternLight(m, at)
		end
		return
	end
	-- 기본 블록 대체
	if name == "Tombstone" then
		part({ Name = "Tomb", Size = Vector3.new(3, height, 1.2), Position = ground + Vector3.new(0, height / 2, 0), Color = PALETTE.stone, Material = Enum.Material.Slate })
	elseif name == "LanternPost" then
		part({ Name = "Post", Size = Vector3.new(0.6, height, 0.6), Position = ground + Vector3.new(0, height / 2, 0), Color = Color3.fromRGB(74, 51, 38) })
		local lamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = ground + Vector3.new(0, height, 0), Color = PALETTE.lantern, Material = Enum.Material.Neon })
		lanternLight(lamp, lamp.Position)
	elseif name == "DeadTree" then
		part({ Name = "Trunk", Size = Vector3.new(1.5, height, 1.5), Position = ground + Vector3.new(0, height / 2, 0), Color = Color3.fromRGB(58, 44, 40), Material = Enum.Material.Wood })
	end
end

---------------------------------------------------------------------
-- 조명: 달빛(차가움) + 등불(따뜻함) 대비. 전체를 파랗게 띄우지 않는다.
---------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(28, 26, 36)
	Lighting.OutdoorAmbient = Color3.fromRGB(62, 58, 80)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.1
	atm.Haze = 1
	atm.Glare = 0
	atm.Color = Color3.fromRGB(92, 86, 120)
	atm.Decay = Color3.fromRGB(40, 32, 62)
	atm.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChild("Plus1Color") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Plus1Color"
	;(cc :: ColorCorrectionEffect).Saturation = 0.08
	;(cc :: ColorCorrectionEffect).Contrast = 0.12
	;(cc :: ColorCorrectionEffect).TintColor = Color3.fromRGB(255, 248, 240)
	cc.Parent = Lighting
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.StarCount = 3000
		sky.MoonAngularSize = 14
		sky.Parent = Lighting
	end
end

---------------------------------------------------------------------
-- 로비: 스폰 → 정면 길 → 출발선. 오른쪽 관, 왼쪽 러닝머신, 뒤쪽 환생 석상
---------------------------------------------------------------------
Track.treadmills = {} :: { { part: BasePart, tier: number } }
Track.eggs = {} :: { { part: BasePart, egg: any } }
Track.rebirthPart = nil :: BasePart?
Track.spawnCFrame = CFrame.new(-120, 4, 0) * CFrame.Angles(0, -math.pi / 2, 0)

local function buildLobby()
	part({ Name = "LobbyGround", Size = Vector3.new(200, 2, 200), Position = Vector3.new(-90, -1, 0), Color = PALETTE.ground, Material = Enum.Material.Grass })
	part({ Name = "LobbyPath", Size = Vector3.new(150, 0.2, 16), Position = Vector3.new(-75, 0.1, 0), Color = PALETTE.path, Material = Enum.Material.Cobblestone })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 0.6, 14)
	spawn.Position = Vector3.new(-120, 0.3, 0)
	spawn.Orientation = Vector3.new(0, -90, 0)
	spawn.Color = PALETTE.path
	spawn.Material = Enum.Material.Cobblestone
	spawn.Duration = 0
	spawn.Parent = folder

	-- 관 (오른쪽, 길을 바라봄)
	for i, egg in ipairs(Config.EGGS) do
		local ground = Vector3.new(-100 + (i - 1) * 32, 0, 36)
		local stand = part({ Name = "EggStand", Size = Vector3.new(14, 1, 14), Position = ground + Vector3.new(0, 0.5, 0), Color = PALETTE.stone, Material = Enum.Material.Slate })
		local name = ({ "CoffinWood", "CoffinCursed", "CoffinGold" })[i]
		local m = asset(name)
		local anchorPart: BasePart
		if m then
			place(m, ground + Vector3.new(0, 1, 0), 13, Vector3.new(0, 0, -1))
			anchorPart = m.PrimaryPart :: BasePart
		else
			local tint = ({ Color3.fromRGB(120, 80, 50), Color3.fromRGB(90, 40, 140), Color3.fromRGB(230, 180, 60) })[i]
			anchorPart = part({ Name = egg.id .. "Coffin", Size = Vector3.new(5, 10, 3), Position = ground + Vector3.new(0, 6, 0), Color = tint, Material = Enum.Material.Wood })
		end
		local glow = Instance.new("PointLight")
		glow.Color = ({ PALETTE.lantern, Color3.fromRGB(150, 255, 190), Color3.fromRGB(255, 220, 120) })[i]
		glow.Range = 14
		glow.Brightness = 0.8
		glow.Parent = stand
		label(stand, egg.name .. "\n🏆 " .. egg.cost .. " Wins", Color3.fromRGB(255, 240, 200), UDim2.fromOffset(150, 46), Vector3.new(0, 15, 0), 70)
		table.insert(Track.eggs, { part = anchorPart, egg = egg })
	end

	-- 러닝머신 (왼쪽)
	for i, tier in ipairs(Config.TREADMILLS) do
		local ground = Vector3.new(-125 + (i - 1) * 27, 0, -38)
		local hit = part({ Name = "Treadmill" .. i, Size = Vector3.new(22, 1.4, 12), Position = ground + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.DiamondPlate })
		local m = asset("Treadmill")
		if m then
			hit.Transparency = 1
			place(m, ground, 4.6, Vector3.new(0, 0, 1))
		end
		part({ Name = "TierStrip", Size = Vector3.new(22, 0.3, 0.8), Position = ground + Vector3.new(0, 1.5, 6.6), Color = tier.color, Material = Enum.Material.Neon })
		label(hit, string.format("+%d ⚡/s\n%s", tier.perSecond, tier.wins > 0 and ("🏆 " .. tier.wins) or "FREE"), tier.color, UDim2.fromOffset(150, 56), Vector3.new(0, 7, 0), 90)
		table.insert(Track.treadmills, { part = hit, tier = i })
	end

	-- 환생 석상 (스폰 뒤)
	local statueGround = Vector3.new(-165, 0, 0)
	local m = asset("RebirthStatue")
	local statueAnchor: BasePart
	if m then
		place(m, statueGround, 26, Vector3.new(1, 0, 0))
		statueAnchor = m.PrimaryPart :: BasePart
	else
		statueAnchor = part({ Name = "RebirthStatue", Size = Vector3.new(6, 22, 6), Position = statueGround + Vector3.new(0, 11, 0), Color = Color3.fromRGB(110, 106, 124), Material = Enum.Material.Slate })
	end
	local moonLight = part({ Name = "RebirthLight", Size = Vector3.new(1, 1, 1), Position = statueGround + Vector3.new(4, 22, 0), Transparency = 1, CanCollide = false }, folder)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 225, 140)
	pl.Range = 24
	pl.Brightness = 1
	pl.Parent = moonLight
	label(moonLight, "🔁 REBIRTH", Color3.fromRGB(255, 230, 140), UDim2.fromOffset(220, 56), Vector3.new(0, 8, 0), 140)
	Track.rebirthPart = statueAnchor

	-- 로비 장식: 등불, 나무, 비석
	for i = 0, 3 do
		decor("LanternPost", Vector3.new(-140 + i * 40, 0, 11), 8, Vector3.new(0, 0, -1))
		decor("LanternPost", Vector3.new(-140 + i * 40, 0, -11), 8, Vector3.new(0, 0, 1))
	end
	local rng = Random.new(3)
	for _ = 1, 14 do
		local edge = rng:NextInteger(0, 1) == 0 and -1 or 1
		decor("DeadTree", Vector3.new(rng:NextNumber(-185, 0), 0, edge * rng:NextNumber(60, 95)), rng:NextNumber(12, 20), Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
	end
	for _ = 1, 12 do
		decor("Tombstone", Vector3.new(rng:NextNumber(-180, -10), 0, rng:NextNumber(55, 90) * (rng:NextInteger(0, 1) == 0 and -1 or 1)), rng:NextNumber(4, 6), Vector3.new(0, 0, rng:NextNumber(-1, 1)))
	end

	-- 출발선
	local gate = part({ Name = "StartGate", Size = Vector3.new(1, 22, W + 4), Position = Vector3.new(0, 11, 0), Color = PALETTE.rail, Material = Enum.Material.Glass, CanCollide = false, Transparency = 0.75 })
	surfaceText(gate, Enum.NormalId.Left, "RUN! 👻", Color3.new(1, 1, 1))
end

---------------------------------------------------------------------
-- 트랙
---------------------------------------------------------------------
local function buildTrack()
	local rng = Random.new(7)
	for zone = 1, Config.ZONE_COUNT do
		local x0 = (zone - 1) * L
		local color = zoneColor(zone)
		part({ Name = "Zone" .. zone, Size = Vector3.new(L, 2, W), Position = Vector3.new(x0 + L / 2, -1, 0), Color = color, Material = Enum.Material.Slate })
		for s = 0, L - 1, 25 do
			part({ Name = "Stripe", Size = Vector3.new(2, 0.1, W - 8), Position = Vector3.new(x0 + s + 12, 0.05, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.25), CanCollide = false })
		end
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Rail", Size = Vector3.new(L, 1.2, 1), Position = Vector3.new(x0 + L / 2, 0.6, side * (W / 2 + 0.5)), Color = PALETTE.rail, Material = Enum.Material.Neon })
			for k = 0, 3 do
				decor("LanternPost", Vector3.new(x0 + 60 + k * 125, 0, side * (W / 2 + 6)), 9, Vector3.new(0, 0, -side))
			end
			for _ = 1, 5 do
				decor("Tombstone", Vector3.new(x0 + rng:NextNumber(10, L - 10), 0, side * rng:NextNumber(W / 2 + 12, W / 2 + 45)), rng:NextNumber(4, 6.5), Vector3.new(rng:NextNumber(-0.3, 0.3), 0, -side))
			end
			for _ = 1, 2 do
				decor("DeadTree", Vector3.new(x0 + rng:NextNumber(10, L - 10), 0, side * rng:NextNumber(W / 2 + 25, W / 2 + 70)), rng:NextNumber(14, 22), Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
			end
		end
		part({ Name = "Grass", Size = Vector3.new(L, 1, 180), Position = Vector3.new(x0 + L / 2, -1.6, 0), Color = PALETTE.ground, Material = Enum.Material.Grass })

		local ax = x0 + L
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "ArchPillar", Size = Vector3.new(4, 30, 4), Position = Vector3.new(ax, 15, side * (W / 2 + 2)), Color = Color3.fromRGB(58, 52, 72), Material = Enum.Material.Slate })
			part({ Name = "ArchGlow", Size = Vector3.new(4.4, 1, 4.4), Position = Vector3.new(ax, 28, side * (W / 2 + 2)), Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Neon })
		end
		local top = part({ Name = "ArchTop", Size = Vector3.new(4, 6, W + 8), Position = Vector3.new(ax, 31, 0), Color = Color3.fromRGB(30, 26, 40), Material = Enum.Material.Slate })
		local text = zone == Config.ZONE_COUNT and "🏁 FINISH" or string.format("ZONE %d  ·  +%d 🏆", zone + 1, Config.ZONE_WINS(zone))
		surfaceText(top, Enum.NormalId.Left, text, color:Lerp(Color3.new(1, 1, 1), 0.6))
	end

	local fx = Track.FINISH_X
	part({ Name = "FinishPad", Size = Vector3.new(80, 2, W + 20), Position = Vector3.new(fx + 40, -1, 0), Color = Color3.fromRGB(230, 190, 80), Material = Enum.Material.Foil })
	local trophy = part({ Name = "Trophy", Size = Vector3.new(14, 6, 6), Position = Vector3.new(fx + 60, 7, 0), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Foil, Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
	label(trophy, "🏆 +" .. Config.FINISH_WINS .. " Wins", Color3.fromRGB(255, 240, 160), UDim2.fromOffset(220, 60), Vector3.new(0, 11, 0), 200)
end

---------------------------------------------------------------------
function Track.build()
	setupLighting()
	buildLobby()
	buildTrack()
	folder.Parent = workspace
end

function Track.zoneAt(x: number): number
	if x < 0 then
		return 0
	end
	return math.min(Config.ZONE_COUNT, math.floor(x / L) + 1)
end

function Track.isOn(p: BasePart, position: Vector3): boolean
	local rel = p.CFrame:PointToObjectSpace(position)
	local half = p.Size / 2
	return math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and rel.Y > 0 and rel.Y < 8
end

---------------------------------------------------------------------
-- 추격 유령: 출발 전엔 출발선 뒤에서 둥둥 떠서 대기, 출발하면 트랙을 따라 이동
---------------------------------------------------------------------
Track.GHOST_IDLE_X = -30

function Track.makeGhost(): (number, number, boolean) -> ()
	local model = asset("GhostChaser")
	if model then
		place(model, Vector3.new(Track.GHOST_IDLE_X, 2, 0), Config.GHOST_HEIGHT, Vector3.new(1, 0, 0), workspace)
	else
		-- 블록 대체: 흰 몸통 + 까만 눈 (잘 보이도록 불투명)
		model = Instance.new("Model")
		model.Name = "GhostChaser"
		local h = Config.GHOST_HEIGHT
		local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.8, h * 0.8, h * 0.8), Position = Vector3.new(Track.GHOST_IDLE_X, h * 0.6, 0), Color = Color3.fromRGB(200, 212, 232), CanCollide = false }, model)
		part({ Name = "Skirt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.5, h * 0.8, h * 0.8), Position = Vector3.new(Track.GHOST_IDLE_X, h * 0.3, 0), Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(200, 212, 232), CanCollide = false }, model)
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.08, h * 0.16, h * 0.12), Position = Vector3.new(Track.GHOST_IDLE_X + h * 0.38, h * 0.68, side * h * 0.12), Color = Color3.fromRGB(20, 18, 28), CanCollide = false }, model)
		end
		model.PrimaryPart = body
		model.Parent = workspace
	end
	local glowPart = model.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 220, 255)
	light.Range = 28
	light.Brightness = 0.6
	light.Parent = glowPart
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	local runBase = model:GetPivot()
	local center = model:GetBoundingBox().Position
	-- 대기 자세: 몸 중심을 기준으로 180도 돌아 로비를 바라봄
	local idleBase = (CFrame.new(center) * CFrame.Angles(0, math.pi, 0) * CFrame.new(center):Inverse()) * runBase
	-- x 위치, 시간(둥실둥실), 달리는 중인지를 받아 이동
	return function(x: number, t: number, running: boolean)
		local bob = math.sin(t * 2) * 1.5
		local base = running and runBase or idleBase
		local lift = running and 0 or 6
		model:PivotTo(base + Vector3.new(x - Track.GHOST_IDLE_X, bob + lift, 0))
	end
end

return Track
