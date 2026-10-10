-- 맵 생성: 로비(러닝머신, 관, 환생 석상) + 10구역 직선 트랙 + 결승선
-- 이 장르는 단순한 블록 트랙이 표준 스타일이라 코드로 만든다.
-- 대신 색 팔레트를 통일하고(밤 보라 + 네온), 조명/안개/블룸으로 분위기를 잡는다.

local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Plus1"):WaitForChild("Config"))

local Track = {}

local L = Config.ZONE_LENGTH
local W = Config.TRACK_WIDTH
Track.FINISH_X = Config.ZONE_COUNT * L
Track.LOBBY_MIN_X = -170

local folder = Instance.new("Folder")
folder.Name = "Plus1Map"

local PALETTE = {
	lobby = Color3.fromRGB(38, 28, 58),
	lobbyEdge = Color3.fromRGB(150, 90, 255),
	rail = Color3.fromRGB(120, 255, 200),
	stone = Color3.fromRGB(70, 66, 82),
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

local function label(parent: BasePart, text: string, color: Color3, size: UDim2, offset: Vector3, maxDist: number?): TextLabel
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
	-- 보라 -> 청록 -> 주황 으로 구역마다 색이 바뀜
	local h = (0.75 - (zone - 1) / Config.ZONE_COUNT * 0.65) % 1
	return Color3.fromHSV(h, 0.55, 0.55)
end

---------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.5
	Lighting.Ambient = Color3.fromRGB(70, 60, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 80, 130)
	Lighting.GlobalShadows = true
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Haze = 1.5
	atm.Color = Color3.fromRGB(120, 100, 170)
	atm.Decay = Color3.fromRGB(60, 40, 100)
	atm.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChild("Plus1Color") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Plus1Color"
	;(cc :: ColorCorrectionEffect).Saturation = 0.15
	;(cc :: ColorCorrectionEffect).Contrast = 0.08
	cc.Parent = Lighting
end

---------------------------------------------------------------------
-- 로비
---------------------------------------------------------------------
Track.treadmills = {} :: { { part: BasePart, tier: number } }
Track.eggs = {} :: { { part: BasePart, egg: any } }
Track.rebirthPart = nil :: BasePart?
Track.spawnCFrame = CFrame.new(-60, 4, 0)

local function buildLobby()
	part({ Name = "LobbyFloor", Size = Vector3.new(180, 2, 170), Position = Vector3.new(-80, -1, 0), Color = PALETTE.lobby })
	for _, z in ipairs({ -85, 85 }) do
		part({ Name = "LobbyEdge", Size = Vector3.new(180, 1, 1), Position = Vector3.new(-80, 0.5, z), Color = PALETTE.lobbyEdge, Material = Enum.Material.Neon })
	end
	part({ Name = "LobbyBackWall", Size = Vector3.new(2, 30, 170), Position = Vector3.new(-171, 14, 0), Color = PALETTE.stone, Material = Enum.Material.Slate })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(-60, 0.5, 0)
	spawn.Color = PALETTE.lobbyEdge
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Duration = 0
	spawn.Parent = folder
	Track.spawnCFrame = CFrame.new(-60, 4, 0) * CFrame.Angles(0, -math.pi / 2, 0)

	-- 러닝머신 (왼쪽 줄)
	for i, tier in ipairs(Config.TREADMILLS) do
		local z = -70 + (i - 1) * 16
		local base = part({ Name = "Treadmill" .. i, Size = Vector3.new(22, 1, 12), Position = Vector3.new(-130, 0.5, z), Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.DiamondPlate })
		part({ Name = "TreadmillGlow", Size = Vector3.new(22.4, 0.4, 12.4), Position = Vector3.new(-130, 0.1, z), Color = tier.color, Material = Enum.Material.Neon })
		local sign = part({ Name = "TreadmillSign", Size = Vector3.new(1, 1, 1), Position = Vector3.new(-130, 6, z), Transparency = 1, CanCollide = false })
		label(sign, string.format("+%d Speed/s\n%s", tier.perSecond, tier.wins > 0 and ("🏆 " .. tier.wins .. " Wins") or "FREE"), tier.color, UDim2.fromOffset(180, 70), Vector3.zero, 90)
		table.insert(Track.treadmills, { part = base, tier = i })
	end

	-- 관 (알) - 오른쪽 줄
	for i, egg in ipairs(Config.EGGS) do
		local z = -45 + (i - 1) * 45
		local pos = Vector3.new(-95, 0, z)
		local tint = ({ Color3.fromRGB(120, 80, 50), Color3.fromRGB(90, 40, 140), Color3.fromRGB(230, 180, 60) })[i]
		part({ Name = "EggStand", Size = Vector3.new(14, 1.5, 14), Position = pos + Vector3.new(0, 0.75, 0), Color = PALETTE.stone, Material = Enum.Material.Slate })
		local coffin = part({ Name = egg.id .. "Coffin", Size = Vector3.new(5, 9, 3), Position = pos + Vector3.new(0, 6.5, 0), Color = tint, Material = i == 3 and Enum.Material.Foil or Enum.Material.Wood })
		part({ Name = "CoffinCrossV", Size = Vector3.new(0.6, 4, 0.4), Position = coffin.Position + Vector3.new(0, 1, -1.6), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.Neon })
		part({ Name = "CoffinCrossH", Size = Vector3.new(2.6, 0.6, 0.4), Position = coffin.Position + Vector3.new(0, 1.8, -1.6), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color = tint
		light.Range = 14
		light.Brightness = 2
		light.Parent = coffin
		label(coffin, egg.name .. "\n🏆 " .. egg.cost .. " Wins", Color3.fromRGB(255, 240, 200), UDim2.fromOffset(200, 70), Vector3.new(0, 7.5, 0), 90)
		table.insert(Track.eggs, { part = coffin, egg = egg })
	end

	-- 환생 석상
	local statue = part({ Name = "RebirthStatue", Size = Vector3.new(8, 22, 8), Position = Vector3.new(-155, 11, 0), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon })
	part({ Name = "RebirthBase", Size = Vector3.new(16, 2, 16), Position = Vector3.new(-155, 1, 0), Color = PALETTE.stone, Material = Enum.Material.Slate })
	label(statue, "🔁 REBIRTH", Color3.fromRGB(255, 230, 140), UDim2.fromOffset(220, 60), Vector3.new(0, 14, 0), 120)
	Track.rebirthPart = statue

	-- 출발선
	local gate = part({ Name = "StartGate", Size = Vector3.new(2, 24, W + 8), Position = Vector3.new(0, 12, 0), Color = PALETTE.rail, Material = Enum.Material.ForceField, CanCollide = false, Transparency = 0.4 })
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
		-- 바닥 줄무늬 (속도감)
		for s = 0, L - 1, 25 do
			part({ Name = "Stripe", Size = Vector3.new(3, 0.1, W - 6), Position = Vector3.new(x0 + s + 12, 0.05, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.35), CanCollide = false })
		end
		-- 양쪽 네온 레일
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Rail", Size = Vector3.new(L, 3, 1.5), Position = Vector3.new(x0 + L / 2, 1.5, side * (W / 2 + 0.75)), Color = PALETTE.rail, Material = Enum.Material.Neon })
			-- 비석 장식
			for _ = 1, 6 do
				local x = x0 + rng:NextNumber(10, L - 10)
				local z = side * rng:NextNumber(W / 2 + 8, W / 2 + 40)
				part({ Name = "Tomb", Size = Vector3.new(3, rng:NextNumber(4, 7), 1.2), Position = Vector3.new(x, 2.5, z), Color = PALETTE.stone, Material = Enum.Material.Slate, Orientation = Vector3.new(0, rng:NextNumber(-15, 15), rng:NextNumber(-8, 8)) })
			end
		end
		part({ Name = "Grass", Size = Vector3.new(L, 1, 120), Position = Vector3.new(x0 + L / 2, -1.5, 0), Color = Color3.fromRGB(28, 34, 40), Material = Enum.Material.Grass })

		-- 구역 끝 아치
		local ax = x0 + L
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "ArchPillar", Size = Vector3.new(4, 30, 4), Position = Vector3.new(ax, 15, side * (W / 2 + 2)), Color = color, Material = Enum.Material.Neon })
		end
		local top = part({ Name = "ArchTop", Size = Vector3.new(4, 6, W + 8), Position = Vector3.new(ax, 30, 0), Color = Color3.fromRGB(25, 20, 35) })
		local text = zone == Config.ZONE_COUNT and "🏁 FINISH" or string.format("ZONE %d  ·  +%d 🏆", zone + 1, Config.ZONE_WINS(zone))
		surfaceText(top, Enum.NormalId.Left, text, color:Lerp(Color3.new(1, 1, 1), 0.5))
	end

	-- 결승 플랫폼
	local fx = Track.FINISH_X
	part({ Name = "FinishPad", Size = Vector3.new(80, 2, W + 20), Position = Vector3.new(fx + 40, -1, 0), Color = Color3.fromRGB(255, 215, 90), Material = Enum.Material.Foil })
	local trophy = part({ Name = "Trophy", Size = Vector3.new(14, 6, 6), Position = Vector3.new(fx + 60, 7, 0), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon, Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
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

function Track.isOn(part: BasePart, position: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and rel.Y > 0 and rel.Y < 8
end

-- 유령 파도 모델
function Track.makeGhostWall(): BasePart
	local wall = part({
		Name = "GhostWave",
		Size = Vector3.new(14, 46, W + 10),
		Position = Vector3.new(-40, 22, 0),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.15,
		CanCollide = false,
		CanQuery = false,
	}, workspace)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 220, 255)
	light.Range = 60
	light.Brightness = 3
	light.Parent = wall
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.Parent = wall
	local face = Instance.new("TextLabel")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.TextScaled = true
	face.Text = "👻"
	face.Parent = gui
	return wall
end

return Track
