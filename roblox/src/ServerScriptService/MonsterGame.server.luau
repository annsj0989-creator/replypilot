-- 몬스터 훔치기 (Steal a Monster) - 서버 스크립트
-- 위치: ServerScriptService 안에 "Script"로 넣기
-- 이 스크립트 하나가 맵(기지 8개, 컨베이어), 몬스터, 훔치기, 던지기, 저장을 전부 만든다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

---------------------------------------------------------------------
-- 설정 (숫자만 바꿔서 밸런스 조절)
---------------------------------------------------------------------
local CONFIG = {
	START_CASH = 100,
	SLOTS_PER_BASE = 8,
	SPAWN_INTERVAL = 2, -- 컨베이어에 몬스터가 나오는 간격(초)
	CONVEYOR_TIME = 25, -- 몬스터가 컨베이어 끝까지 가는 시간(초)
	LOCK_TIME = 30, -- 기지 잠금 유지 시간(초)
	LOCK_COOLDOWN = 30, -- 잠금이 끝난 뒤 다시 잠글 수 있을 때까지(초)
	THROW_RANGE = 10,
	THROW_COOLDOWN = 3,
	THROW_POWER = 90,
	THROW_ANYONE = false, -- true면 아무나 던질 수 있음(트롤 모드)
	CARRY_SPEED_MULT = 0.6, -- 몬스터를 들고 있을 때 속도 배수
	BASE_WALKSPEED = 16,
	SPEED_PER_LEVEL = 2,
	MAX_SPEED_LEVEL = 20,
	GAMEPASS_2X_CASH = 0, -- 게임패스를 만든 뒤 ID를 넣기 (0이면 꺼짐)
	DATASTORE_NAME = "MonsterGame_v1",
	AUTOSAVE_INTERVAL = 60,
}

local RARITIES = {
	{ name = "일반", weight = 60, color = Color3.fromRGB(200, 200, 200), stealHold = 1 },
	{ name = "희귀", weight = 25, color = Color3.fromRGB(80, 170, 255), stealHold = 1.5 },
	{ name = "에픽", weight = 10, color = Color3.fromRGB(180, 90, 255), stealHold = 2 },
	{ name = "전설", weight = 4, color = Color3.fromRGB(255, 190, 40), stealHold = 3 },
	{ name = "신화", weight = 0.9, color = Color3.fromRGB(255, 70, 70), stealHold = 4 },
	{ name = "SECRET", weight = 0.1, color = Color3.fromRGB(20, 255, 160), stealHold = 5 },
}

local MONSTERS = {
	{ name = "꼬마 슬라임", rarity = "일반", price = 50, income = 2, size = 2.5, color = Color3.fromRGB(120, 230, 120) },
	{ name = "호박 머리", rarity = "일반", price = 80, income = 3, size = 2.8, color = Color3.fromRGB(255, 140, 30) },
	{ name = "꼬마 유령", rarity = "일반", price = 120, income = 5, size = 2.6, color = Color3.fromRGB(240, 240, 255) },
	{ name = "박쥐 냥이", rarity = "희귀", price = 400, income = 12, size = 3, color = Color3.fromRGB(70, 60, 90) },
	{ name = "해골 강아지", rarity = "희귀", price = 600, income = 18, size = 3, color = Color3.fromRGB(230, 225, 200) },
	{ name = "젤리 좀비", rarity = "희귀", price = 900, income = 26, size = 3.2, color = Color3.fromRGB(110, 170, 90) },
	{ name = "마녀 고양이", rarity = "에픽", price = 2500, income = 60, size = 3.5, color = Color3.fromRGB(120, 40, 160) },
	{ name = "미라 펭귄", rarity = "에픽", price = 4000, income = 90, size = 3.5, color = Color3.fromRGB(220, 210, 170) },
	{ name = "늑대 소년", rarity = "에픽", price = 6000, income = 130, size = 3.8, color = Color3.fromRGB(120, 90, 70) },
	{ name = "드라큘라 백작", rarity = "전설", price = 15000, income = 300, size = 4.2, color = Color3.fromRGB(150, 0, 30) },
	{ name = "호박 기사", rarity = "전설", price = 25000, income = 480, size = 4.4, color = Color3.fromRGB(255, 110, 0) },
	{ name = "그림자 용", rarity = "신화", price = 90000, income = 1500, size = 5, color = Color3.fromRGB(30, 20, 50) },
	{ name = "달빛 리치", rarity = "신화", price = 140000, income = 2200, size = 5, color = Color3.fromRGB(140, 200, 255) },
	{ name = "황금 유령왕", rarity = "SECRET", price = 500000, income = 7000, size = 6, color = Color3.fromRGB(255, 215, 0) },
}

local MONSTER_BY_NAME = {}
for _, def in ipairs(MONSTERS) do
	MONSTER_BY_NAME[def.name] = def
end

local RARITY_BY_NAME = {}
for _, r in ipairs(RARITIES) do
	RARITY_BY_NAME[r.name] = r
end

---------------------------------------------------------------------
-- 리모트 (클라이언트 UI와 통신)
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "MonsterRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local NotifyRemote = makeRemote("Notify")
local SpeedRemote = makeRemote("RequestSpeed")
local LockRemote = makeRemote("RequestLock")

ReplicatedStorage:SetAttribute("Pass2xId", CONFIG.GAMEPASS_2X_CASH)

local function notify(player: Player, text: string, color: Color3?)
	NotifyRemote:FireClient(player, text, color or Color3.new(1, 1, 1))
end

local function notifyAll(text: string, color: Color3?)
	NotifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function now(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------
-- 맵 만들기
---------------------------------------------------------------------
local mapFolder = Instance.new("Folder")
mapFolder.Name = "MonsterMap"
mapFolder.Parent = workspace

local function makePart(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent or mapFolder
	return p
end

-- 바닥 (기존 Baseplate가 없어도 되게)
makePart({
	Name = "Ground",
	Size = Vector3.new(400, 1, 300),
	Position = Vector3.new(0, -0.5, 0),
	Color = Color3.fromRGB(45, 40, 60),
	Material = Enum.Material.Grass,
})

-- 컨베이어 벨트
local CONVEYOR_START_X, CONVEYOR_END_X = -150, 150
makePart({
	Name = "Conveyor",
	Size = Vector3.new(CONVEYOR_END_X - CONVEYOR_START_X + 10, 1, 10),
	Position = Vector3.new(0, 0.5, 0),
	Color = Color3.fromRGB(30, 30, 30),
	Material = Enum.Material.DiamondPlate,
})
for _, side in ipairs({ -1, 1 }) do
	makePart({
		Name = "ConveyorRail",
		Size = Vector3.new(CONVEYOR_END_X - CONVEYOR_START_X + 10, 1.5, 0.6),
		Position = Vector3.new(0, 1.25, side * 5.3),
		Color = Color3.fromRGB(255, 120, 0),
		Material = Enum.Material.Neon,
	})
end

local monstersFolder = Instance.new("Folder")
monstersFolder.Name = "ConveyorMonsters"
monstersFolder.Parent = workspace

type Slot = { name: string, model: Model?, stolen: boolean }
type Base = {
	index: number,
	pos: Vector3,
	facing: number,
	owner: Player?,
	slots: { [number]: Slot },
	slotCFrames: { CFrame },
	folder: Folder,
	signLabel: TextLabel,
	shield: Part,
	spawnCFrame: CFrame,
	lockedUntil: number,
	lockReadyAt: number,
}

local BASE_SIZE = 44
local HALF = BASE_SIZE / 2
local bases: { Base } = {}

local function buildBase(index: number, pos: Vector3, facing: number): Base
	local folder = Instance.new("Folder")
	folder.Name = "Base" .. index
	folder.Parent = mapFolder

	makePart({
		Name = "Floor",
		Size = Vector3.new(BASE_SIZE, 1, BASE_SIZE),
		Position = pos + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(70, 60, 90),
		Material = Enum.Material.WoodPlanks,
	}, folder)

	-- 벽: 뒤, 왼쪽, 오른쪽 (앞쪽은 컨베이어 방향으로 열려 있음)
	local wallColor = Color3.fromRGB(40, 30, 55)
	makePart({
		Name = "BackWall",
		Size = Vector3.new(BASE_SIZE, 8, 1),
		Position = pos + Vector3.new(0, 5, -facing * HALF),
		Color = wallColor,
	}, folder)
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "SideWall",
			Size = Vector3.new(1, 8, BASE_SIZE),
			Position = pos + Vector3.new(side * HALF, 5, 0),
			Color = wallColor,
		}, folder)
	end

	-- 주인 이름 표지판
	local signPart = makePart({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		Position = pos + Vector3.new(0, 14, -facing * HALF),
		Transparency = 1,
		CanCollide = false,
	}, folder)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(300, 60)
	billboard.MaxDistance = 200
	billboard.Parent = signPart
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextColor3 = Color3.new(1, 1, 1)
	signLabel.TextStrokeTransparency = 0
	signLabel.Text = "빈 기지"
	signLabel.Parent = billboard

	-- 잠금 보호막 (평소엔 투명)
	local shield = makePart({
		Name = "Shield",
		Size = Vector3.new(BASE_SIZE, 16, BASE_SIZE),
		Position = pos + Vector3.new(0, 8, 0),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	}, folder)

	-- 슬롯 2줄 x 4칸
	local slotCFrames = {}
	for row = 0, 1 do
		for col = 0, 3 do
			local x = -15 + col * 10
			local z = -facing * (14 - row * 10)
			local slotPos = pos + Vector3.new(x, 1.1, z)
			makePart({
				Name = "SlotPad",
				Size = Vector3.new(7, 0.2, 7),
				Position = slotPos,
				Color = Color3.fromRGB(110, 90, 140),
				Material = Enum.Material.Neon,
				Transparency = 0.6,
				CanCollide = false,
			}, folder)
			table.insert(slotCFrames, CFrame.lookAt(slotPos, slotPos + Vector3.new(0, 0, facing)))
		end
	end

	return {
		index = index,
		pos = pos,
		facing = facing,
		owner = nil,
		slots = {},
		slotCFrames = slotCFrames,
		folder = folder,
		signLabel = signLabel,
		shield = shield,
		spawnCFrame = CFrame.lookAt(pos + Vector3.new(0, 4, facing * 12), pos + Vector3.new(0, 4, facing * 30)),
		lockedUntil = 0,
		lockReadyAt = 0,
	}
end

for i = 0, 3 do
	local x = -102 + i * 68
	table.insert(bases, buildBase(#bases + 1, Vector3.new(x, 0, -60), 1))
	table.insert(bases, buildBase(#bases + 1, Vector3.new(x, 0, 60), -1))
end

local function isInsideBase(base: Base, position: Vector3): boolean
	return math.abs(position.X - base.pos.X) < HALF
		and math.abs(position.Z - base.pos.Z) < HALF
		and position.Y < base.pos.Y + 30
end

---------------------------------------------------------------------
-- 플레이어 상태
---------------------------------------------------------------------
local playerBase: { [Player]: Base } = {}
local loaded: { [Player]: boolean } = {}
local has2x: { [Player]: boolean } = {}
local throwReadyAt: { [Player]: number } = {}

type Carry = { name: string, fromBase: Base, slotIndex: number, record: Slot, model: Model }
local carrying: { [Player]: Carry } = {}

local function getCashValue(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("돈") :: IntValue?
end

local function getCash(player: Player): number
	local v = getCashValue(player)
	return v and v.Value or 0
end

local function addCash(player: Player, amount: number)
	local v = getCashValue(player)
	if v then
		v.Value += amount
	end
end

local function getRoot(player: Player): (BasePart?, Humanoid?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return nil, nil
	end
	return root, hum
end

local function speedCost(level: number): number
	return math.floor(150 * 1.7 ^ level)
end

local function updateSpeed(player: Player)
	local _, hum = getRoot(player)
	if not hum then
		return
	end
	local level = player:GetAttribute("SpeedLevel") or 0
	local speed = CONFIG.BASE_WALKSPEED + level * CONFIG.SPEED_PER_LEVEL
	if carrying[player] then
		speed *= CONFIG.CARRY_SPEED_MULT
	end
	hum.WalkSpeed = speed
end

local function push(player: Player, direction: Vector3, power: number)
	local root = getRoot(player)
	if not root then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(1, 0, 0)
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = flat.Unit * power + Vector3.new(0, power * 0.6, 0)
	lv.Parent = root
	Debris:AddItem(lv, 0.2)
	Debris:AddItem(att, 0.2)
end

---------------------------------------------------------------------
-- 몬스터 모델
---------------------------------------------------------------------
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

local function makeMonsterModel(def, showPrice: boolean): Model
	local rarity = RARITY_BY_NAME[def.rarity]
	local model = Instance.new("Model")
	model.Name = def.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * def.size
	body.Color = def.color
	body.Material = (def.rarity == "SECRET" or def.rarity == "신화") and Enum.Material.Neon or Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * def.size * 0.3
		eye.Color = Color3.new(1, 1, 1)
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(side * def.size * 0.2, def.size * 0.15, -def.size * 0.4)
		eye.Parent = model
		local pupil = Instance.new("Part")
		pupil.Name = "Pupil"
		pupil.Shape = Enum.PartType.Ball
		pupil.Size = Vector3.one * def.size * 0.14
		pupil.Color = Color3.new(0, 0, 0)
		pupil.CanCollide = false
		pupil.Massless = true
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -def.size * 0.1)
		pupil.Parent = model
		for _, part in ipairs({ eye, pupil }) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, def.size / 2 + 2, 0)
	gui.MaxDistance = 70
	gui.Parent = body

	local lines = {
		{ text = def.rarity, color = rarity.color },
		{ text = def.name, color = Color3.new(1, 1, 1) },
		{ text = "$" .. formatNumber(def.income) .. "/초", color = Color3.fromRGB(120, 255, 120) },
	}
	if showPrice then
		table.insert(lines, { text = "가격 $" .. formatNumber(def.price), color = Color3.fromRGB(255, 230, 90) })
	end
	for i, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1 / #lines, 0)
		label.Position = UDim2.new(0, 0, (i - 1) / #lines, 0)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = line.color
		label.TextStrokeTransparency = 0
		label.Text = line.text
		label.Parent = gui
	end

	model.PrimaryPart = body
	return model
end

---------------------------------------------------------------------
-- 슬롯 / 훔치기
---------------------------------------------------------------------
local onSteal -- 아래에서 정의

local function freeSlot(base: Base): number?
	for i = 1, CONFIG.SLOTS_PER_BASE do
		if base.slots[i] == nil then
			return i
		end
	end
	return nil
end

local function placeInSlot(base: Base, slotIndex: number, monsterName: string)
	local def = MONSTER_BY_NAME[monsterName]
	local owner = base.owner
	if not def or not owner then
		return
	end
	local old = base.slots[slotIndex]
	if old and old.model then
		old.model:Destroy()
	end

	local model = makeMonsterModel(def, false)
	model:PivotTo(base.slotCFrames[slotIndex] * CFrame.new(0, def.size / 2 + 0.2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "훔치기"
	prompt.ObjectText = def.name
	prompt.HoldDuration = RARITY_BY_NAME[def.rarity].stealHold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerId", owner.UserId) -- 클라이언트가 자기 몬스터의 훔치기 버튼을 숨김
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		onSteal(player, base, slotIndex)
	end)

	model.Parent = base.folder
	base.slots[slotIndex] = { name = monsterName, model = model, stolen = false }
end

local function failCarry(thief: Player)
	local c = carrying[thief]
	if not c then
		return
	end
	carrying[thief] = nil
	if c.model.Parent then
		c.model:Destroy()
	end
	-- 원래 주인 기지로 돌려놓기
	if c.fromBase.owner and c.fromBase.slots[c.slotIndex] == c.record then
		placeInSlot(c.fromBase, c.slotIndex, c.name)
	end
	updateSpeed(thief)
end

local function deliver(thief: Player, myBase: Base)
	local c = carrying[thief]
	if not c then
		return
	end
	local slot = freeSlot(myBase)
	if not slot then
		notify(thief, "기지가 꽉 찼어요! 몬스터를 돌려보냈어요.", Color3.fromRGB(255, 120, 120))
		failCarry(thief)
		return
	end
	carrying[thief] = nil
	c.model:Destroy()
	if c.fromBase.slots[c.slotIndex] == c.record then
		c.fromBase.slots[c.slotIndex] = nil
	end
	placeInSlot(myBase, slot, c.name)
	updateSpeed(thief)
	notify(thief, "🎉 " .. c.name .. " 훔치기 성공!", Color3.fromRGB(120, 255, 120))
	if c.fromBase.owner then
		notify(c.fromBase.owner, "😭 " .. thief.DisplayName .. "님이 " .. c.name .. "을(를) 훔쳐갔어요!", Color3.fromRGB(255, 90, 90))
	end
end

onSteal = function(thief: Player, base: Base, slotIndex: number)
	local slot = base.slots[slotIndex]
	local owner = base.owner
	if not slot or slot.stolen or not owner or thief == owner then
		return
	end
	if not playerBase[thief] then
		return
	end
	if now() < base.lockedUntil then
		notify(thief, "🔒 이 기지는 잠겨 있어요!", Color3.fromRGB(255, 120, 120))
		return
	end
	if carrying[thief] then
		notify(thief, "이미 몬스터를 들고 있어요!")
		return
	end
	local root = getRoot(thief)
	if not root or not thief.Character then
		return
	end

	local def = MONSTER_BY_NAME[slot.name]
	slot.stolen = true
	if slot.model then
		slot.model:Destroy()
		slot.model = nil
	end

	-- 도둑 머리 위에 몬스터 올리기
	local carried = makeMonsterModel(def, false)
	local body = carried.PrimaryPart :: BasePart
	for _, part in ipairs(carried:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
		end
	end
	carried:PivotTo(root.CFrame * CFrame.new(0, 3 + def.size / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	carried.Parent = thief.Character

	carrying[thief] = { name = slot.name, fromBase = base, slotIndex = slotIndex, record = slot, model = carried }
	updateSpeed(thief)
	notify(thief, "자기 기지로 도망쳐요! 🏃", Color3.fromRGB(255, 230, 90))
	notify(owner, "⚠️ " .. thief.DisplayName .. "님이 " .. slot.name .. "을(를) 훔쳐가고 있어요! 잡아서 던지세요!", Color3.fromRGB(255, 90, 90))
end

---------------------------------------------------------------------
-- 컨베이어 몬스터 구매
---------------------------------------------------------------------
local totalWeight = 0
for _, r in ipairs(RARITIES) do
	totalWeight += r.weight
end

local function pickMonster()
	local roll = math.random() * totalWeight
	local rarityName = RARITIES[1].name
	for _, r in ipairs(RARITIES) do
		roll -= r.weight
		if roll <= 0 then
			rarityName = r.name
			break
		end
	end
	local pool = {}
	for _, def in ipairs(MONSTERS) do
		if def.rarity == rarityName then
			table.insert(pool, def)
		end
	end
	return pool[math.random(1, #pool)]
end

local function spawnConveyorMonster()
	local def = pickMonster()
	local model = makeMonsterModel(def, true)
	local body = model.PrimaryPart :: BasePart
	local y = 1 + def.size / 2
	local startCF = CFrame.lookAt(Vector3.new(CONVEYOR_START_X, y, 0), Vector3.new(CONVEYOR_START_X, y, 1))
	model:PivotTo(startCF)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "구매"
	prompt.ObjectText = def.name .. " ($" .. formatNumber(def.price) .. ")"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.Parent = monstersFolder

	local tween = TweenService:Create(
		body,
		TweenInfo.new(CONFIG.CONVEYOR_TIME, Enum.EasingStyle.Linear),
		{ CFrame = startCF + Vector3.new(CONVEYOR_END_X - CONVEYOR_START_X, 0, 0) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		if model.Parent then
			model:Destroy()
		end
	end)

	local sold = false
	prompt.Triggered:Connect(function(player)
		if sold then
			return
		end
		local base = playerBase[player]
		if not base then
			return
		end
		if getCash(player) < def.price then
			notify(player, "돈이 부족해요! ($" .. formatNumber(def.price) .. " 필요)", Color3.fromRGB(255, 120, 120))
			return
		end
		local slot = freeSlot(base)
		if not slot then
			notify(player, "기지가 꽉 찼어요!", Color3.fromRGB(255, 120, 120))
			return
		end
		sold = true
		addCash(player, -def.price)
		tween:Cancel()
		model:Destroy()
		placeInSlot(base, slot, def.name)
		notify(player, def.name .. " 구매 완료!", RARITY_BY_NAME[def.rarity].color)
	end)

	if def.rarity == "신화" or def.rarity == "SECRET" then
		notifyAll("🌟 " .. def.rarity .. " 몬스터 [" .. def.name .. "] 등장! 컨베이어로 달려가세요!", RARITY_BY_NAME[def.rarity].color)
	end
end

---------------------------------------------------------------------
-- 던지기 도구
---------------------------------------------------------------------
local function onThrow(player: Player)
	local t = now()
	if t < (throwReadyAt[player] or 0) then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	local myBase = playerBase[player]

	local target: Player? = nil
	local bestDist = CONFIG.THROW_RANGE
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = getRoot(other)
			if otherRoot then
				local dist = (otherRoot.Position - root.Position).Magnitude
				local allowed = CONFIG.THROW_ANYONE
					or carrying[other] ~= nil
					or (myBase ~= nil and isInsideBase(myBase, otherRoot.Position))
				if dist < bestDist and allowed then
					bestDist = dist
					target = other
				end
			end
		end
	end

	if not target then
		notify(player, "근처에 던질 도둑이 없어요!")
		return
	end

	throwReadyAt[player] = t + CONFIG.THROW_COOLDOWN
	local targetRoot = getRoot(target) :: BasePart
	local wasCarrying = carrying[target] ~= nil
	failCarry(target)
	push(target, targetRoot.Position - root.Position, CONFIG.THROW_POWER)
	notify(target, "💥 " .. player.DisplayName .. "님에게 던져졌어요!", Color3.fromRGB(255, 120, 120))
	notify(player, wasCarrying and "도둑을 던져버렸어요! 몬스터를 되찾았어요!" or "던져버렸어요!", Color3.fromRGB(120, 255, 120))
end

local function giveThrowTool(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or backpack:FindFirstChild("잡아 던지기") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "잡아 던지기"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "도둑을 잡아서 던져요!"
	tool.Activated:Connect(function()
		onThrow(player)
	end)
	tool.Parent = backpack
end

---------------------------------------------------------------------
-- 업그레이드 / 잠금
---------------------------------------------------------------------
SpeedRemote.OnServerEvent:Connect(function(player)
	if not loaded[player] then
		return
	end
	local level = player:GetAttribute("SpeedLevel") or 0
	if level >= CONFIG.MAX_SPEED_LEVEL then
		notify(player, "속도가 최대예요!")
		return
	end
	local cost = speedCost(level)
	if getCash(player) < cost then
		notify(player, "돈이 부족해요! ($" .. formatNumber(cost) .. " 필요)", Color3.fromRGB(255, 120, 120))
		return
	end
	addCash(player, -cost)
	player:SetAttribute("SpeedLevel", level + 1)
	player:SetAttribute("SpeedCost", speedCost(level + 1))
	updateSpeed(player)
	notify(player, "⚡ 속도 레벨 " .. (level + 1) .. "!", Color3.fromRGB(120, 200, 255))
end)

LockRemote.OnServerEvent:Connect(function(player)
	local base = playerBase[player]
	if not base then
		return
	end
	local t = now()
	if t < base.lockReadyAt then
		notify(player, "잠금 준비 중... " .. math.ceil(base.lockReadyAt - t) .. "초")
		return
	end
	base.lockedUntil = t + CONFIG.LOCK_TIME
	base.lockReadyAt = t + CONFIG.LOCK_TIME + CONFIG.LOCK_COOLDOWN
	player:SetAttribute("LockedUntil", base.lockedUntil)
	player:SetAttribute("LockReadyAt", base.lockReadyAt)
	notify(player, "🔒 기지 잠금! (" .. CONFIG.LOCK_TIME .. "초)", Color3.fromRGB(120, 200, 255))
end)

---------------------------------------------------------------------
-- 저장 / 불러오기
---------------------------------------------------------------------
local store = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)

local function savePlayer(player: Player)
	if not loaded[player] then
		return
	end
	local base = playerBase[player]
	local monsters = {}
	if base then
		for i, slot in pairs(base.slots) do
			monsters[tostring(i)] = slot.name -- 도둑맞는 중인 몬스터도 아직 내 것
		end
	end
	local data = {
		cash = getCash(player),
		speedLevel = player:GetAttribute("SpeedLevel") or 0,
		monsters = monsters,
	}
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
	if not ok then
		warn("저장 실패", player.Name, err)
	end
end

local function loadPlayer(player: Player)
	local ok, data = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if not ok then
		warn("불러오기 실패 (Studio라면 Game Settings > Security > API Services를 켜세요)", data)
		data = nil
	end
	return data
end

---------------------------------------------------------------------
-- 입장 / 퇴장
---------------------------------------------------------------------
local function onCharacterAdded(player: Player, char: Model)
	local base = playerBase[player]
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.1)
	if base and char.Parent then
		char:PivotTo(base.spawnCFrame)
	end
	updateSpeed(player)
	giveThrowTool(player)
end

local function onPlayerAdded(player: Player)
	local base: Base? = nil
	for _, b in ipairs(bases) do
		if not b.owner then
			base = b
			break
		end
	end
	if not base then
		player:Kick("서버가 꽉 찼어요. 다른 서버로 들어가 주세요!")
		return
	end
	base.owner = player
	base.slots = {}
	base.lockedUntil = 0
	base.lockReadyAt = 0
	base.signLabel.Text = player.DisplayName .. "의 기지"
	playerBase[player] = base

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "돈"
	cash.Value = CONFIG.START_CASH
	cash.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	local data = loadPlayer(player)
	if player.Parent == nil then
		return
	end
	local level = 0
	if type(data) == "table" then
		cash.Value = tonumber(data.cash) or CONFIG.START_CASH
		level = tonumber(data.speedLevel) or 0
		if type(data.monsters) == "table" then
			for key, name in pairs(data.monsters) do
				local i = tonumber(key)
				if i and i >= 1 and i <= CONFIG.SLOTS_PER_BASE and MONSTER_BY_NAME[name] then
					placeInSlot(base, i, name)
				end
			end
		end
	end
	player:SetAttribute("SpeedLevel", level)
	player:SetAttribute("SpeedCost", speedCost(level))
	player:SetAttribute("LockedUntil", 0)
	player:SetAttribute("LockReadyAt", 0)
	updateSpeed(player)

	if CONFIG.GAMEPASS_2X_CASH ~= 0 then
		local passOk, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.GAMEPASS_2X_CASH)
		end)
		has2x[player] = passOk and owns or false
	end

	loaded[player] = true
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == CONFIG.GAMEPASS_2X_CASH then
		has2x[player] = true
		notify(player, "💰 2배 돈 활성화! 감사합니다!", Color3.fromRGB(255, 230, 90))
	end
end)

local function onPlayerRemoving(player: Player)
	-- 이 플레이어가 훔치던 몬스터는 주인에게 돌려줌
	failCarry(player)
	savePlayer(player)

	local base = playerBase[player]
	if base then
		-- 이 플레이어 기지에서 훔쳐가던 몬스터는 사라짐 (주인 데이터엔 이미 저장됨)
		for thief, c in pairs(carrying) do
			if c.fromBase == base then
				carrying[thief] = nil
				c.model:Destroy()
				updateSpeed(thief)
				notify(thief, "주인이 나가서 몬스터가 사라졌어요!")
			end
		end
		for _, slot in pairs(base.slots) do
			if slot.model then
				slot.model:Destroy()
			end
		end
		base.slots = {}
		base.owner = nil
		base.lockedUntil = 0
		base.shield.Transparency = 1
		base.signLabel.Text = "빈 기지"
	end
	playerBase[player] = nil
	loaded[player] = nil
	has2x[player] = nil
	throwReadyAt[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		savePlayer(p)
	end
end)

---------------------------------------------------------------------
-- 반복 루프
---------------------------------------------------------------------
-- 컨베이어
task.spawn(function()
	while true do
		task.wait(CONFIG.SPAWN_INTERVAL)
		spawnConveyorMonster()
	end
end)

-- 초당 수입
task.spawn(function()
	while true do
		task.wait(1)
		for player, base in pairs(playerBase) do
			if loaded[player] then
				local income = 0
				for _, slot in pairs(base.slots) do
					if not slot.stolen then
						income += MONSTER_BY_NAME[slot.name].income
					end
				end
				if has2x[player] then
					income *= 2
				end
				addCash(player, income)
				player:SetAttribute("Income", income)
			end
		end
	end
end)

-- 배달 확인, 잠금 보호막
task.spawn(function()
	while true do
		task.wait(0.2)
		for thief, c in pairs(carrying) do
			local root = getRoot(thief)
			local myBase = playerBase[thief]
			if not root or not c.model.Parent then
				failCarry(thief)
			elseif myBase and isInsideBase(myBase, root.Position) then
				deliver(thief, myBase)
			end
		end

		local t = now()
		for _, base in ipairs(bases) do
			local locked = base.owner ~= nil and t < base.lockedUntil
			base.shield.Transparency = locked and 0.6 or 1
			if locked then
				for _, other in ipairs(Players:GetPlayers()) do
					if other ~= base.owner then
						local root = getRoot(other)
						if root and isInsideBase(base, root.Position) then
							push(other, root.Position - base.pos, 60)
						end
					end
				end
			end
		end
	end
end)

-- 자동 저장
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTOSAVE_INTERVAL)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(savePlayer, p)
		end
	end
end)
