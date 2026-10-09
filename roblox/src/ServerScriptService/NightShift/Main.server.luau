-- 편의점 야간 알바 - 서버 메인
-- 로비 → 근무(밤 22:00~06:00) → 결과 → 로비 순서로 돈다.
-- 맵/손님 모델/UI는 스튜디오에서 만든 것을 태그와 이름으로 찾아 쓴다. (BUILD_GUIDE.md)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("NightShift"):WaitForChild("Config"))
local Customers = require(script.Parent:WaitForChild("Customers"))

---------------------------------------------------------------------
-- 리모트
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "NightShiftRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local NoticeRemote = remote("Notice")
local BubbleRemote = remote("Bubble")
local JumpscareRemote = remote("Jumpscare")
local ResultsRemote = remote("Results")
remotes.Parent = ReplicatedStorage

ReplicatedStorage:SetAttribute("ReviveProductId", Config.PRODUCT_REVIVE)
ReplicatedStorage:SetAttribute("Pass2xId", Config.GAMEPASS_2X_COINS)

---------------------------------------------------------------------
-- 상태
---------------------------------------------------------------------
local currentNight = 1
local has2x: { [Player]: boolean } = {}
local coffeeReadyAt: { [Player]: number } = {}
local earned: { [Player]: number } = {}
local loaded: { [Player]: boolean } = {}

local stats = { served = 0, caught = 0, wrongReports = 0, impatient = 0, missed = {} :: { string } }

local function setPhase(phase: string)
	workspace:SetAttribute("Phase", phase)
end
setPhase("Lobby")
workspace:SetAttribute("Night", currentNight)
workspace:SetAttribute("ClockMinutes", Config.SHIFT_START_MINUTE)
workspace:SetAttribute("Countdown", 0)

local function notice(player: Player?, text: string, kind: string)
	if player then
		NoticeRemote:FireClient(player, text, kind)
	else
		NoticeRemote:FireAllClients(text, kind)
	end
end

local function isOnShift(p: Player): boolean
	return p:GetAttribute("OnShift") == true
end

local function isActive(p: Player): boolean
	return workspace:GetAttribute("Phase") == "Shift" and isOnShift(p) and p:GetAttribute("Fainted") ~= true
end

---------------------------------------------------------------------
-- 이동
---------------------------------------------------------------------
local function teleportToTag(player: Player, tag: string)
	local spots = CollectionService:GetTagged(tag)
	local char = player.Character
	if #spots == 0 or not char then
		return
	end
	local spot = spots[math.random(1, #spots)]
	if spot:IsA("BasePart") then
		char:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
	end
end

local function placeByState(player: Player)
	if workspace:GetAttribute("Phase") == "Shift" and isOnShift(player) then
		if player:GetAttribute("Fainted") then
			teleportToTag(player, Config.TAGS.BREAK_ROOM)
		else
			teleportToTag(player, Config.TAGS.SHIFT_SPAWN)
		end
	else
		teleportToTag(player, Config.TAGS.LOBBY_SPAWN)
	end
end

---------------------------------------------------------------------
-- 코인 / 정신력
---------------------------------------------------------------------
local function coinsValue(player: Player): IntValue?
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("코인") :: IntValue?
end

local function reward(player: Player, coins: number)
	local v = coinsValue(player)
	if not v then
		return
	end
	local amount = has2x[player] and coins * 2 or coins
	v.Value += amount
	earned[player] = (earned[player] or 0) + amount
end

local checkShiftFailed -- 아래 정의

local function faint(player: Player)
	if player:GetAttribute("Fainted") then
		return
	end
	player:SetAttribute("Fainted", true)
	notice(player, "정신을 잃었어요... 휴게실에서 깨어났어요.", "danger")
	notice(nil, player.DisplayName .. "님이 기절했어요!", "bad")
	teleportToTag(player, Config.TAGS.BREAK_ROOM)
	checkShiftFailed()
end

local function changeSanity(player: Player, delta: number)
	if not isActive(player) then
		return
	end
	local s = math.clamp((player:GetAttribute("Sanity") or Config.MAX_SANITY) + delta, 0, Config.MAX_SANITY)
	player:SetAttribute("Sanity", s)
	if s <= 0 then
		faint(player)
	end
end

local function changeSanityAll(delta: number)
	for _, p in ipairs(Players:GetPlayers()) do
		changeSanity(p, delta)
	end
end

---------------------------------------------------------------------
-- 조명 깜빡임
---------------------------------------------------------------------
local flickerUntil = 0
local flickering = false

local function storeLights(): { Light }
	local lights = {}
	for _, inst in ipairs(CollectionService:GetTagged(Config.TAGS.STORE_LIGHT)) do
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("Light") then
				table.insert(lights, d)
			end
		end
		if inst:IsA("Light") then
			table.insert(lights, inst)
		end
	end
	return lights
end

local function flickerLights(duration: number)
	flickerUntil = math.max(flickerUntil, os.clock() + duration)
	if flickering then
		return
	end
	flickering = true
	task.spawn(function()
		local lights = storeLights()
		while os.clock() < flickerUntil do
			for _, l in ipairs(lights) do
				l.Enabled = math.random() > 0.55
			end
			task.wait(math.random(5, 25) / 100)
		end
		for _, l in ipairs(lights) do
			l.Enabled = true
		end
		flickering = false
	end)
end

---------------------------------------------------------------------
-- 손님 시스템 연결
---------------------------------------------------------------------
Customers.init({
	notice = notice,
	bubble = function(head, text)
		BubbleRemote:FireAllClients(head, text)
	end,
	reward = reward,
	sanity = changeSanity,
	sanityAll = changeSanityAll,
	flickerLights = flickerLights,
	jumpscare = function(player)
		JumpscareRemote:FireClient(player)
	end,
	isActive = isActive,
	record = function(stat, detail)
		if stat == "served" then
			stats.served += 1
		elseif stat == "caught" then
			stats.caught += 1
		elseif stat == "wrong_report" then
			stats.wrongReports += 1
		elseif stat == "impatient" then
			stats.impatient += 1
		elseif (stat == "served_anomaly" or stat == "ignored_anomaly") and detail then
			table.insert(stats.missed, detail)
		end
	end,
})

---------------------------------------------------------------------
-- 커피 머신
---------------------------------------------------------------------
local function setupCoffee(machine: Instance)
	local parent = machine:IsA("BasePart") and machine or machine:FindFirstChildWhichIsA("BasePart", true)
	if not parent then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "커피 마시기"
	prompt.ObjectText = "커피 머신"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 8
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player)
		if not isActive(player) then
			return
		end
		local t = os.clock()
		if t < (coffeeReadyAt[player] or 0) then
			notice(player, "아직 커피를 또 마실 수 없어요 (" .. math.ceil(coffeeReadyAt[player] - t) .. "초)", "info")
			return
		end
		coffeeReadyAt[player] = t + Config.COFFEE_COOLDOWN
		changeSanity(player, Config.COFFEE_RESTORE)
		notice(player, "☕ 정신이 조금 맑아졌어요", "good")
	end)
end
for _, m in ipairs(CollectionService:GetTagged(Config.TAGS.COFFEE_MACHINE)) do
	setupCoffee(m)
end
CollectionService:GetInstanceAddedSignal(Config.TAGS.COFFEE_MACHINE):Connect(setupCoffee)

---------------------------------------------------------------------
-- 근무 진행
---------------------------------------------------------------------
local shiftFailed = false

checkShiftFailed = function()
	if workspace:GetAttribute("Phase") ~= "Shift" then
		return
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if isActive(p) then
			return
		end
	end
	shiftFailed = true
end

local function runShift()
	shiftFailed = false
	stats = { served = 0, caught = 0, wrongReports = 0, impatient = 0, missed = {} }
	table.clear(earned)

	for _, p in ipairs(Players:GetPlayers()) do
		if loaded[p] then
			p:SetAttribute("OnShift", true)
			p:SetAttribute("Fainted", false)
			p:SetAttribute("Sanity", Config.MAX_SANITY)
		end
	end
	workspace:SetAttribute("Night", currentNight)
	setPhase("Shift")
	for _, p in ipairs(Players:GetPlayers()) do
		placeByState(p)
	end
	notice(nil, currentNight .. "번째 밤. 근무 시작!", "info")
	Customers.startNight(currentNight)

	local start = os.clock()
	while true do
		local elapsed = os.clock() - start
		local minutes = Config.SHIFT_START_MINUTE + (elapsed / Config.SHIFT_REAL_SECONDS) * Config.SHIFT_LENGTH_MINUTES
		workspace:SetAttribute("ClockMinutes", math.floor(minutes) % (24 * 60))
		if elapsed >= Config.SHIFT_REAL_SECONDS or shiftFailed then
			break
		end
		for _, p in ipairs(Players:GetPlayers()) do
			changeSanity(p, -Config.SANITY_DRAIN_PER_SEC)
		end
		task.wait(1)
	end

	Customers.stop()
	local survivors = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if isActive(p) then
			table.insert(survivors, p)
		end
	end
	local cleared = not shiftFailed and #survivors > 0
	if cleared then
		for _, p in ipairs(survivors) do
			reward(p, Config.PAY_NIGHT_CLEAR + currentNight * Config.PAY_NIGHT_BONUS_PER_LEVEL)
			if (p:GetAttribute("BestNight") or 0) < currentNight then
				p:SetAttribute("BestNight", currentNight)
			end
		end
	end

	setPhase("Results")
	for _, p in ipairs(Players:GetPlayers()) do
		ResultsRemote:FireClient(p, {
			night = currentNight,
			cleared = cleared,
			served = stats.served,
			caught = stats.caught,
			wrongReports = stats.wrongReports,
			impatient = stats.impatient,
			missed = stats.missed,
			coins = earned[p] or 0,
		})
	end

	if cleared then
		currentNight = currentNight >= Config.MAX_NIGHT and 1 or currentNight + 1
	else
		currentNight = 1
	end
	task.wait(Config.RESULTS_TIME)

	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("OnShift", false)
		p:SetAttribute("Fainted", false)
	end
	workspace:SetAttribute("Night", currentNight)
	setPhase("Lobby")
	for _, p in ipairs(Players:GetPlayers()) do
		placeByState(p)
	end
end

task.spawn(function()
	while true do
		local count = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if loaded[p] then
				count += 1
			end
		end
		if count >= Config.MIN_PLAYERS then
			for i = Config.LOBBY_COUNTDOWN, 1, -1 do
				workspace:SetAttribute("Countdown", i)
				task.wait(1)
			end
			workspace:SetAttribute("Countdown", 0)
			runShift()
		else
			task.wait(1)
		end
	end
end)

---------------------------------------------------------------------
-- 저장
---------------------------------------------------------------------
local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

local function save(player: Player)
	if not loaded[player] then
		return
	end
	local v = coinsValue(player)
	local data = { coins = v and v.Value or 0, bestNight = player:GetAttribute("BestNight") or 0 }
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, data)
	end)
	if not ok then
		warn("[NightShift] 저장 실패", player.Name, err)
	end
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "코인"
	coins.Parent = ls
	ls.Parent = player

	player:SetAttribute("OnShift", false)
	player:SetAttribute("Fainted", false)
	player:SetAttribute("Sanity", Config.MAX_SANITY)

	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		placeByState(player)
	end)

	local ok, data = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if not ok then
		warn("[NightShift] 불러오기 실패 (Studio: Game Settings > Security > API Services 켜기)", data)
	end
	if player.Parent == nil then
		return
	end
	if type(data) == "table" then
		coins.Value = tonumber(data.coins) or 0
		player:SetAttribute("BestNight", tonumber(data.bestNight) or 0)
	end

	if Config.GAMEPASS_2X_COINS ~= 0 then
		local passOk, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.GAMEPASS_2X_COINS)
		end)
		has2x[player] = passOk and owns or false
	end
	loaded[player] = true
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	loaded[player] = nil
	has2x[player] = nil
	coffeeReadyAt[player] = nil
	earned[player] = nil
	checkShiftFailed()
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		save(p)
	end
end)

task.spawn(function()
	while true do
		task.wait(90)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(save, p)
		end
	end
end)

---------------------------------------------------------------------
-- 결제
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.GAMEPASS_2X_COINS then
		has2x[player] = true
		notice(player, "💰 코인 2배 활성화!", "good")
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.ProductId == Config.PRODUCT_REVIVE then
		if workspace:GetAttribute("Phase") == "Shift" and isOnShift(player) and player:GetAttribute("Fainted") then
			player:SetAttribute("Fainted", false)
			player:SetAttribute("Sanity", Config.MAX_SANITY * 0.5)
			teleportToTag(player, Config.TAGS.SHIFT_SPAWN)
			notice(player, "부활! 다시 근무하러 가요.", "good")
		else
			reward(player, 100) -- 부활할 상황이 아니면 코인으로 보상
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
