-- 손님 NPC: 등장 → 진열대 구경 → 줄 서기 → 계산대 → 퇴장
-- 이상현상 손님을 계산해 주거나 무시하면 괴물로 변해 직원을 쫓는다.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NightShift"):WaitForChild("Config"))
local Anomalies = require(script.Parent:WaitForChild("Anomalies"))

export type Callbacks = {
	notice: (player: Player?, text: string, kind: string) -> (),
	bubble: (head: BasePart, text: string) -> (),
	reward: (player: Player, coins: number) -> (),
	sanity: (player: Player, delta: number) -> (),
	sanityAll: (delta: number) -> (),
	flickerLights: (duration: number) -> (),
	jumpscare: (player: Player) -> (),
	isActive: (player: Player) -> boolean, -- 근무 중이고 기절하지 않았는가
	record: (stat: string, detail: string?) -> (),
}

type Customer = {
	model: Model,
	template: string,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	anomaly: Anomalies.Anomaly?,
	alive: boolean,
	resolved: boolean,
	atCounter: boolean,
	serve: ProximityPrompt,
	report: ProximityPrompt,
}

local NORMAL_GREETINGS = {
	"안녕하세요~",
	"이거 계산이요.",
	"봉투 하나 주세요.",
	"카드 되죠?",
	"늦게까지 고생하시네요.",
	"삼각김밥 데워 주세요.",
	"컵라면 물 어디 있어요?",
	"영수증은 버려 주세요.",
}

local Customers = {}

local callbacks: Callbacks
local folder: Folder
local customers: { Customer } = {}
local queue: { Customer } = {}
local running = false
local night = 1

local ANIM_IDLE = "rbxassetid://507766388"
local ANIM_WALK = "rbxassetid://507777826"

---------------------------------------------------------------------
-- 맵 위치 찾기
---------------------------------------------------------------------
local function taggedParts(tag: string): { BasePart }
	local result = {}
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsA("BasePart") then
			table.insert(result, inst)
		end
	end
	return result
end

local function firstTagged(tag: string): BasePart?
	return taggedParts(tag)[1]
end

local function queueSpots(): { BasePart }
	local spots = taggedParts(Config.TAGS.QUEUE_SPOT)
	table.sort(spots, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	return spots
end

local function templates(): { Model }
	local source = ServerStorage:FindFirstChild("Customers")
	local list = {}
	if source then
		for _, m in ipairs(source:GetChildren()) do
			if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
				table.insert(list, m)
			end
		end
	end
	return list
end

---------------------------------------------------------------------
-- 이동 / 애니메이션
---------------------------------------------------------------------
local function setupAnimations(c: Customer)
	local animator = c.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = c.humanoid
	end
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = ANIM_IDLE
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = ANIM_WALK
	local idle = (animator :: Animator):LoadAnimation(idleAnim)
	local walk = (animator :: Animator):LoadAnimation(walkAnim)
	idle.Looped = true
	walk.Looped = true
	idle:Play()
	local walking = false
	c.humanoid.Running:Connect(function(speed)
		local nowWalking = speed > 0.5
		if nowWalking ~= walking then
			walking = nowWalking
			if walking then
				walk:Play(0.2)
				walk:AdjustSpeed(c.humanoid.WalkSpeed / 12)
			else
				walk:Stop(0.2)
			end
		end
	end)
end

-- leaving=true 이면 이미 처리된(계산/신고된) 손님도 계속 걷는다 (퇴장할 때)
local function stillWalking(c: Customer, leaving: boolean?): boolean
	return c.alive and (leaving == true or not c.resolved)
end

local function moveToWait(c: Customer, pos: Vector3, timeout: number, leaving: boolean?)
	if not stillWalking(c, leaving) then
		return
	end
	local done = false
	local conn = c.humanoid.MoveToFinished:Connect(function()
		done = true
	end)
	c.humanoid:MoveTo(pos)
	local start = os.clock()
	while stillWalking(c, leaving) and not done and os.clock() - start < timeout do
		task.wait(0.1)
	end
	conn:Disconnect()
end

local function walkTo(c: Customer, pos: Vector3, leaving: boolean?)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local ok = pcall(function()
		path:ComputeAsync(c.root.Position, pos)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			if not stillWalking(c, leaving) then
				return
			end
			moveToWait(c, wp.Position, 4, leaving)
		end
	else
		moveToWait(c, pos, 12, leaving)
	end
end

local function faceTowards(c: Customer, pos: Vector3)
	if not c.alive or c.humanoid.AutoRotate == false then
		return
	end
	local flat = Vector3.new(pos.X, c.root.Position.Y, pos.Z)
	if (flat - c.root.Position).Magnitude > 0.1 then
		c.root.CFrame = CFrame.lookAt(c.root.Position, flat)
	end
end

---------------------------------------------------------------------
-- 생성 / 제거
---------------------------------------------------------------------
local function say(c: Customer, text: string)
	if c.alive and c.head.Parent then
		callbacks.bubble(c.head, text)
	end
end

local function removeFromQueue(c: Customer)
	local idx = table.find(queue, c)
	if idx then
		table.remove(queue, idx)
	end
end

local function despawn(c: Customer, fade: boolean)
	if not c.alive then
		return
	end
	c.alive = false
	removeFromQueue(c)
	local idx = table.find(customers, c)
	if idx then
		table.remove(customers, idx)
	end
	if fade then
		for _, part in ipairs(c.model:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.7, function()
			c.model:Destroy()
		end)
	else
		c.model:Destroy()
	end
end

local function leave(c: Customer)
	c.resolved = true
	c.serve.Enabled = false
	c.report.Enabled = false
	removeFromQueue(c)
	local exit = firstTagged(Config.TAGS.CUSTOMER_EXIT) or firstTagged(Config.TAGS.CUSTOMER_SPAWN)
	if exit then
		walkTo(c, exit.Position, true)
	end
	despawn(c, true)
end

---------------------------------------------------------------------
-- 괴물 추격
---------------------------------------------------------------------
local function becomeHunter(c: Customer)
	c.resolved = true
	c.serve.Enabled = false
	c.report.Enabled = false
	removeFromQueue(c)
	callbacks.flickerLights(Config.HUNTER_DURATION)
	callbacks.sanityAll(-Config.SANITY_ANOMALY_SERVED)
	callbacks.notice(nil, "무언가 잘못됐다... 도망쳐!", "danger")
	callbacks.record("hunter", c.anomaly and c.anomaly.name)

	c.humanoid.WalkSpeed = Config.HUNTER_SPEED
	c.humanoid.AutoRotate = true
	local start = os.clock()
	while c.alive and os.clock() - start < Config.HUNTER_DURATION do
		local target: Player? = nil
		local targetRoot: BasePart? = nil
		local best = math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			if callbacks.isActive(p) then
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r then
					local d = (r.Position - c.root.Position).Magnitude
					if d < best then
						best, target, targetRoot = d, p, r
					end
				end
			end
		end
		if not target or not targetRoot then
			break
		end
		if best < Config.HUNTER_HIT_RANGE then
			callbacks.sanity(target, -Config.SANITY_HUNTER_HIT)
			callbacks.jumpscare(target)
			break
		end
		c.humanoid:MoveTo(targetRoot.Position)
		task.wait(0.15)
	end
	despawn(c, true)
end

---------------------------------------------------------------------
-- 계산 / 신고
---------------------------------------------------------------------
local function onServe(c: Customer, player: Player)
	if c.resolved or not c.atCounter or not callbacks.isActive(player) then
		return
	end
	if c.anomaly then
		callbacks.record("served_anomaly", c.anomaly.name)
		task.spawn(becomeHunter, c)
	else
		c.resolved = true
		callbacks.reward(player, Config.PAY_SERVE)
		callbacks.record("served", nil)
		say(c, "감사합니다~")
		task.spawn(leave, c)
	end
end

local function onReport(c: Customer, player: Player)
	if c.resolved or not callbacks.isActive(player) then
		return
	end
	c.resolved = true
	c.serve.Enabled = false
	c.report.Enabled = false
	if c.anomaly then
		callbacks.reward(player, Config.PAY_REPORT_CORRECT)
		callbacks.record("caught", c.anomaly.name)
		callbacks.notice(player, "이상현상 제거! (" .. c.anomaly.name .. ")", "good")
		removeFromQueue(c)
		despawn(c, true)
	else
		callbacks.sanity(player, -Config.SANITY_WRONG_REPORT)
		callbacks.record("wrong_report", nil)
		callbacks.notice(player, "정상 손님이었어요...", "bad")
		say(c, "뭐야 이 가게?!")
		task.spawn(leave, c)
	end
end

---------------------------------------------------------------------
-- 손님 한 명의 행동
---------------------------------------------------------------------
local function counterSpotFor(index: number): BasePart?
	if index == 1 then
		return firstTagged(Config.TAGS.COUNTER_SPOT)
	end
	return queueSpots()[index - 1]
end

local function runCustomer(c: Customer)
	-- 1. 진열대 구경 (1~2곳)
	local shelves = taggedParts(Config.TAGS.SHELF_SPOT)
	for _ = 1, math.random(1, 2) do
		if not c.alive or c.resolved or #shelves == 0 then
			break
		end
		local shelf = shelves[math.random(1, #shelves)]
		walkTo(c, shelf.Position)
		faceTowards(c, shelf.Position + shelf.CFrame.LookVector * 5)
		local t = math.random(Config.BROWSE_TIME[1] * 10, Config.BROWSE_TIME[2] * 10) / 10
		local start = os.clock()
		while c.alive and not c.resolved and os.clock() - start < t do
			task.wait(0.2)
		end
	end
	if not c.alive or c.resolved then
		return
	end

	-- 2. 줄 서기
	table.insert(queue, c)
	local currentSpot: BasePart? = nil
	while c.alive and not c.resolved do
		local index = table.find(queue, c) or 1
		local spot = counterSpotFor(index)
		if spot and spot ~= currentSpot then
			currentSpot = spot
			walkTo(c, spot.Position)
			if not c.alive or c.resolved then
				return
			end
			faceTowards(c, spot.Position + spot.CFrame.LookVector * 5)
		end
		if index == 1 and spot then
			break
		end
		task.wait(0.3)
	end
	if not c.alive or c.resolved then
		return
	end

	-- 3. 계산대
	c.atCounter = true
	c.serve.Enabled = true
	local greet = (c.anomaly and c.anomaly.greeting) or NORMAL_GREETINGS
	say(c, greet[math.random(1, #greet)])

	local start = os.clock()
	while c.alive and not c.resolved and os.clock() - start < Config.CUSTOMER_PATIENCE do
		task.wait(0.25)
	end
	if not c.alive or c.resolved then
		return
	end

	-- 4. 아무도 응대 안 함
	if c.anomaly then
		callbacks.record("ignored_anomaly", c.anomaly.name)
		becomeHunter(c)
	else
		callbacks.sanityAll(-Config.SANITY_IMPATIENT)
		callbacks.record("impatient", nil)
		callbacks.notice(nil, "손님이 화내고 나갔어요!", "bad")
		say(c, "아니 왜 계산을 안 해줘요?!")
		leave(c)
	end
end

local function makePrompt(parent: Instance, action: string, key: Enum.KeyCode, order: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = "손님"
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, order * 72)
	prompt.Parent = parent
	return prompt
end

local function spawnCustomer()
	local spawnPart = firstTagged(Config.TAGS.CUSTOMER_SPAWN)
	local pool = templates()
	if not spawnPart or #pool == 0 then
		return
	end

	local inStore: { [string]: Customer } = {}
	for _, other in ipairs(customers) do
		if other.alive and not other.anomaly then
			inStore[other.template] = other
		end
	end

	local settings = Config.NIGHTS[night] or Config.NIGHTS[#Config.NIGHTS]
	local isAnomaly = math.random() < settings.anomalyChance
	-- 같은 모습의 손님이 두 명 있으면 그 자체가 이상현상이므로, 정상 손님은 겹치지 않게 고른다
	local free = {}
	for _, t in ipairs(pool) do
		if not inStore[t.Name] then
			table.insert(free, t)
		end
	end
	local canDouble = next(inStore) ~= nil

	local anomaly: Anomalies.Anomaly? = nil
	local template: Model
	if isAnomaly then
		anomaly = Anomalies.pick(night, nil, canDouble)
	end
	if anomaly and anomaly.id == "Doppelganger" then
		local names = {}
		for name in pairs(inStore) do
			table.insert(names, name)
		end
		local source = ServerStorage.Customers :: Folder
		template = source:FindFirstChild(names[math.random(1, #names)]) :: Model
	else
		if #free == 0 then
			return -- 모델 종류가 부족하면 이번엔 손님을 안 보냄
		end
		template = free[math.random(1, #free)]
	end

	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = (model:FindFirstChild("Head") or root) :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = 9
	humanoid.BreakJointsOnDeath = false

	-- canApply 확인이 필요한 이상현상은 실제 모델로 다시 고른다
	if anomaly and anomaly.canApply and not anomaly.canApply(model) then
		anomaly = Anomalies.pick(night, model, false)
	end

	local c: Customer = {
		model = model,
		template = template.Name,
		humanoid = humanoid,
		root = root,
		head = head,
		anomaly = anomaly,
		alive = true,
		resolved = false,
		atCounter = false,
		serve = makePrompt(root, "계산하기", Enum.KeyCode.E, 0),
		report = makePrompt(root, "이상현상 신고", Enum.KeyCode.Q, 1),
	}
	c.serve.Enabled = false
	c.serve.Triggered:Connect(function(p)
		onServe(c, p)
	end)
	c.report.Triggered:Connect(function(p)
		onReport(c, p)
	end)

	model:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	model.Parent = folder
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	root:SetNetworkOwner(nil)
	setupAnimations(c)

	if anomaly and anomaly.apply then
		anomaly.apply(model, {
			say = function(text)
				say(c, text)
			end,
			isAlive = function()
				return c.alive
			end,
		})
	end

	table.insert(customers, c)
	task.spawn(runCustomer, c)
end

---------------------------------------------------------------------
-- 외부에서 쓰는 함수
---------------------------------------------------------------------
function Customers.init(cb: Callbacks)
	callbacks = cb
	folder = Instance.new("Folder")
	folder.Name = "NightShiftCustomers"
	folder.Parent = workspace

	local missing = {}
	for _, tag in ipairs({ Config.TAGS.CUSTOMER_SPAWN, Config.TAGS.COUNTER_SPOT, Config.TAGS.SHELF_SPOT }) do
		if #taggedParts(tag) == 0 then
			table.insert(missing, tag)
		end
	end
	if #missing > 0 then
		warn("[NightShift] 맵에 태그가 없어요: " .. table.concat(missing, ", ") .. " (BUILD_GUIDE.md 참고)")
	end
	local count = #templates()
	if count < 6 then
		warn("[NightShift] ServerStorage.Customers 에 손님 모델이 " .. count .. "개뿐이에요. 8개 이상 넣어 주세요.")
	end
end

function Customers.startNight(n: number)
	night = n
	running = true
	task.spawn(function()
		while running do
			local settings = Config.NIGHTS[night] or Config.NIGHTS[#Config.NIGHTS]
			if #customers < settings.maxCustomers then
				spawnCustomer()
			end
			local waitFor = settings.spawnInterval * (0.75 + math.random() * 0.5)
			local start = os.clock()
			while running and os.clock() - start < waitFor do
				task.wait(0.25)
			end
		end
	end)
end

function Customers.stop()
	running = false
	for _, c in ipairs(table.clone(customers)) do
		despawn(c, true)
	end
	table.clear(queue)
end

return Customers
