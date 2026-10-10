-- +1 Speed 유령 탈출 - 서버
-- 걸으면 속도 +1 → 트랙을 달려 구역마다 Wins → 관에서 유령 친구 뽑기(배수) → 환생(배수)
-- 뒤에서 유령 파도가 쫓아와서 잡히면 로비로 돌아간다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Plus1"):WaitForChild("Config"))
local Track = require(script.Parent:WaitForChild("Track"))

Track.build()

---------------------------------------------------------------------
-- 리모트
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Plus1Remotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local GainRemote = remote("Gain") -- (amount) 머리 위 +N 표시
local NoticeRemote = remote("Notice") -- (title, text, kind)
local HatchRemote = remote("Hatch") -- (spiritId) 뽑기 연출
local CaughtRemote = remote("Caught")
remotes.Parent = ReplicatedStorage

local function notice(player: Player?, title: string, text: string, kind: string?)
	if player then
		NoticeRemote:FireClient(player, title, text, kind or "info")
	else
		NoticeRemote:FireAllClients(title, text, kind or "info")
	end
end

---------------------------------------------------------------------
-- 플레이어 데이터
---------------------------------------------------------------------
type Data = {
	speed: number,
	wins: number,
	rebirths: number,
	spirits: { string },
}

type Session = {
	data: Data,
	lastPos: Vector3?,
	moved: number,
	pending: number, -- 화면에 보낼 +N 누적
	runBest: number, -- 이번 달리기에서 보상 받은 마지막 구역
	passes: { [string]: boolean },
	equipped: { string },
	followers: { BasePart },
	values: { speed: NumberValue, wins: NumberValue, rebirths: IntValue },
}

local sessions: { [Player]: Session } = {}
local store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)

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

local function spiritMultiplier(s: Session): number
	local total = 1
	for _, id in ipairs(s.equipped) do
		local def = Config.SPIRITS[id]
		if def then
			total += def.mult - 1
		end
	end
	return total
end

local function multiplier(s: Session): number
	local m = (1 + s.data.rebirths * Config.REBIRTH_BONUS) * spiritMultiplier(s)
	if s.passes.speed2x then
		m *= 2
	end
	return m
end

local function rebirthCost(s: Session): number
	return Config.REBIRTH_BASE_COST * Config.REBIRTH_COST_GROWTH ^ s.data.rebirths
end

local function slotCount(s: Session): number
	return Config.EQUIP_SLOTS + (s.passes.extraSlot and 2 or 0)
end

local function syncValues(player: Player, s: Session)
	s.values.speed.Value = math.floor(s.data.speed)
	s.values.wins.Value = math.floor(s.data.wins)
	s.values.rebirths.Value = s.data.rebirths
	player:SetAttribute("Multiplier", multiplier(s))
	player:SetAttribute("RebirthCost", rebirthCost(s))
	player:SetAttribute("SpeedText", formatNumber(s.data.speed))
	player:SetAttribute("WinsText", formatNumber(s.data.wins))
end

local function applyWalkSpeed(player: Player, s: Session)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local ws = Config.BASE_WALKSPEED + math.sqrt(s.data.speed) * Config.WALKSPEED_CURVE
		hum.WalkSpeed = math.min(ws, Config.MAX_WALKSPEED)
	end
end

---------------------------------------------------------------------
-- 유령 친구 (따라다니는 모습 + 자동 장착)
---------------------------------------------------------------------
local function refreshFollowers(player: Player, s: Session)
	for _, f in ipairs(s.followers) do
		f:Destroy()
	end
	table.clear(s.followers)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for i, id in ipairs(s.equipped) do
		local def = Config.SPIRITS[id]
		local orb = Instance.new("Part")
		orb.Name = "Spirit_" .. id
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(1.6, 1.6, 1.6)
		orb.Material = Enum.Material.Neon
		orb.Color = Config.RARITY_COLORS[def.rarity]
		orb.Transparency = 0.35
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Massless = true
		local angle = (i - 1) / math.max(#s.equipped, 1) * math.pi - math.pi / 2
		orb.CFrame = root.CFrame * CFrame.new(math.sin(angle) * 4, 2.5, 3 + math.cos(angle) * 1.5)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = orb
		weld.Parent = orb
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(60, 60)
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.MaxDistance = 60
		gui.Parent = orb
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Text = def.icon
		t.Parent = gui
		orb.Parent = player.Character
		table.insert(s.followers, orb)
	end
end

local function autoEquip(player: Player, s: Session)
	local sorted = table.clone(s.data.spirits)
	table.sort(sorted, function(a, b)
		return Config.SPIRITS[a].mult > Config.SPIRITS[b].mult
	end)
	-- 가장 약한 것부터 정리
	while #sorted > Config.MAX_SPIRITS do
		table.remove(sorted)
	end
	s.data.spirits = sorted
	s.equipped = {}
	for i = 1, math.min(slotCount(s), #sorted) do
		table.insert(s.equipped, sorted[i])
	end
	refreshFollowers(player, s)
	syncValues(player, s)
end

---------------------------------------------------------------------
-- 관 뽑기 / 환생
---------------------------------------------------------------------
local function roll(egg, lucky: boolean): string
	local total = 0
	local weights = {}
	for _, entry in ipairs(egg.odds) do
		local id, w = entry[1], entry[2]
		local rarity = Config.SPIRITS[id].rarity
		if lucky and rarity ~= "Common" and rarity ~= "Rare" then
			w *= 2
		end
		table.insert(weights, { id, w })
		total += w
	end
	local r = math.random() * total
	for _, e in ipairs(weights) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return weights[#weights][1]
end

for _, entry in ipairs(Track.eggs) do
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = entry.egg.name .. " (" .. entry.egg.cost .. " Wins)"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = entry.part
	prompt.Triggered:Connect(function(player)
		local s = sessions[player]
		if not s then
			return
		end
		if s.data.wins < entry.egg.cost then
			notice(player, "Not enough Wins", "Need " .. formatNumber(entry.egg.cost) .. " 🏆", "bad")
			return
		end
		s.data.wins -= entry.egg.cost
		local id = roll(entry.egg, s.passes.lucky == true)
		table.insert(s.data.spirits, id)
		autoEquip(player, s)
		HatchRemote:FireClient(player, id)
		local def = Config.SPIRITS[id]
		if def.rarity == "Mythic" or def.rarity == "Secret" then
			notice(nil, "🌟 " .. def.rarity .. "!", player.DisplayName .. " got " .. def.icon .. " " .. def.name .. "!", "rare")
		end
	end)
end

do
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Reset Speed for a bigger multiplier"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = Track.rebirthPart
	prompt.Triggered:Connect(function(player)
		local s = sessions[player]
		if not s then
			return
		end
		local cost = rebirthCost(s)
		if s.data.speed < cost then
			notice(player, "Not yet!", "Need " .. formatNumber(cost) .. " ⚡ Speed", "bad")
			return
		end
		s.data.speed = 0
		s.data.rebirths += 1
		syncValues(player, s)
		applyWalkSpeed(player, s)
		notice(player, "🔁 REBIRTH " .. s.data.rebirths, "Multiplier x" .. string.format("%.1f", multiplier(s)), "good")
	end)
end

---------------------------------------------------------------------
-- 이동 감지: 걸음 → 속도, 러닝머신, 구역 보상
---------------------------------------------------------------------
local function sendToLobby(player: Player)
	local char = player.Character
	if char then
		char:PivotTo(Track.spawnCFrame)
	end
	local s = sessions[player]
	if s then
		s.lastPos = nil
		s.runBest = 0
	end
end

local TICK = 0.2
task.spawn(function()
	while true do
		task.wait(TICK)
		for player, s in pairs(sessions) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local pos = root.Position
				local mult = multiplier(s)
				local gained = 0

				-- 걸음
				if s.lastPos then
					local d = Vector3.new(pos.X - s.lastPos.X, 0, pos.Z - s.lastPos.Z).Magnitude
					local limit = hum.WalkSpeed * TICK * 1.6 + Config.MAX_STEP_PER_TICK * 0.25
					if d <= limit and hum.FloorMaterial ~= Enum.Material.Air then
						s.moved += d
						local steps = math.floor(s.moved / Config.STEP_STUDS)
						if steps > 0 then
							s.moved -= steps * Config.STEP_STUDS
							gained += steps * mult
						end
					end
				end
				s.lastPos = pos

				-- 러닝머신
				for _, t in ipairs(Track.treadmills) do
					if Track.isOn(t.part, pos) then
						local tier = Config.TREADMILLS[t.tier]
						if s.data.wins >= tier.wins then
							gained += tier.perSecond * TICK * mult
						elseif math.random() < 0.05 then
							notice(player, "Locked", "Need " .. formatNumber(tier.wins) .. " 🏆 Wins", "bad")
						end
					end
				end

				if gained > 0 then
					s.data.speed += gained
					s.pending += gained
				end

				-- 구역 보상
				local zone = Track.zoneAt(pos.X)
				if pos.X < 0 then
					s.runBest = 0
				elseif zone > 1 and zone - 1 > s.runBest then
					for z = s.runBest + 1, zone - 1 do
						local w = Config.ZONE_WINS(z) * (1 + s.data.rebirths * Config.REBIRTH_BONUS)
						s.data.wins += w
						notice(player, "Zone " .. z .. " cleared!", "+" .. formatNumber(w) .. " 🏆", "good")
					end
					s.runBest = zone - 1
				end
				if pos.X >= Track.FINISH_X then
					local w = Config.FINISH_WINS * (1 + s.data.rebirths * Config.REBIRTH_BONUS)
					s.data.wins += w + Config.ZONE_WINS(Config.ZONE_COUNT)
					notice(player, "🏁 FINISHED!", "+" .. formatNumber(w) .. " 🏆", "rare")
					sendToLobby(player)
				end

				applyWalkSpeed(player, s)
				syncValues(player, s)
			end
		end
	end
end)

-- +N 표시는 0.5초마다 묶어서 보냄 (네트워크 절약)
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, s in pairs(sessions) do
			if s.pending > 0 then
				GainRemote:FireClient(player, s.pending)
				s.pending = 0
			end
		end
	end
end)

---------------------------------------------------------------------
-- 유령 파도
---------------------------------------------------------------------
local moveGhost = Track.makeGhost()
local ghostRunning = false
workspace:SetAttribute("GhostX", -1000)

-- 대기 중엔 출발선 뒤에서 둥실둥실
task.spawn(function()
	while true do
		if not ghostRunning then
			moveGhost(Track.GHOST_IDLE_X, os.clock(), false)
		end
		task.wait(1 / 20)
	end
end)

task.spawn(function()
	local reach = Config.GHOST_HEIGHT * 0.35 -- 유령 몸 앞쪽까지 거리
	while true do
		task.wait(Config.GHOST_INTERVAL - Config.GHOST_WARNING)
		notice(nil, "👻 GHOST WAVE", "Coming in " .. Config.GHOST_WARNING .. " seconds! RUN!", "danger")
		task.wait(Config.GHOST_WARNING)
		ghostRunning = true
		local x = Track.GHOST_IDLE_X
		local last = os.clock()
		while x < Track.FINISH_X + 40 do
			task.wait()
			local now = os.clock()
			local dt = now - last
			last = now
			local zone = math.max(1, Track.zoneAt(x))
			x += (Config.GHOST_BASE_SPEED + (zone - 1) * Config.GHOST_SPEED_PER_ZONE) * dt
			moveGhost(x, now, true)
			workspace:SetAttribute("GhostX", x + reach)
			for player in pairs(sessions) do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and root.Position.X > 0 and root.Position.X < x + reach and root.Position.X > x - 60 then
					CaughtRemote:FireClient(player)
					notice(player, "👻 Caught!", "Get faster and try again!", "danger")
					sendToLobby(player)
				end
			end
		end
		ghostRunning = false
		workspace:SetAttribute("GhostX", -1000)
	end
end)

---------------------------------------------------------------------
-- 입장 / 저장
---------------------------------------------------------------------
local function ownsPass(player: Player, id: number): boolean
	if id == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and owns == true
end

local function onPlayerAdded(player: Player)
	local ok, saved = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if not ok then
		warn("[Plus1] 불러오기 실패 (Studio: Game Settings > Security > API Services 켜기)", saved)
		saved = nil
	end
	if player.Parent == nil then
		return
	end

	local data: Data = { speed = 0, wins = 0, rebirths = 0, spirits = {} }
	if type(saved) == "table" then
		data.speed = tonumber(saved.speed) or 0
		data.wins = tonumber(saved.wins) or 0
		data.rebirths = tonumber(saved.rebirths) or 0
		if type(saved.spirits) == "table" then
			for _, id in ipairs(saved.spirits) do
				if Config.SPIRITS[id] then
					table.insert(data.spirits, id)
				end
			end
		end
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local speedV = Instance.new("NumberValue")
	speedV.Name = "⚡ Speed"
	speedV.Parent = ls
	local winsV = Instance.new("NumberValue")
	winsV.Name = "🏆 Wins"
	winsV.Parent = ls
	local rebV = Instance.new("IntValue")
	rebV.Name = "🔁 Rebirths"
	rebV.Parent = ls
	ls.Parent = player

	local s: Session = {
		data = data,
		lastPos = nil,
		moved = 0,
		pending = 0,
		runBest = 0,
		passes = {
			speed2x = ownsPass(player, Config.PASS_2X_SPEED),
			extraSlot = ownsPass(player, Config.PASS_EXTRA_SLOT),
			lucky = ownsPass(player, Config.PASS_LUCKY),
		},
		equipped = {},
		followers = {},
		values = { speed = speedV, wins = winsV, rebirths = rebV },
	}
	sessions[player] = s

	local function onCharacter(char: Model)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		s.lastPos = nil
		s.runBest = 0
		char:PivotTo(Track.spawnCFrame)
		applyWalkSpeed(player, s)
		refreshFollowers(player, s)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	autoEquip(player, s)
end

local function save(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, s.data)
	end)
	if not ok then
		warn("[Plus1] 저장 실패", player.Name, err)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		save(p)
	end
end)
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(save, p)
		end
	end
end)

---------------------------------------------------------------------
-- 결제
---------------------------------------------------------------------
ReplicatedStorage:SetAttribute("PassSpeed2x", Config.PASS_2X_SPEED)
ReplicatedStorage:SetAttribute("PassExtraSlot", Config.PASS_EXTRA_SLOT)
ReplicatedStorage:SetAttribute("PassLucky", Config.PASS_LUCKY)
ReplicatedStorage:SetAttribute("ProductSpeedPack", Config.PRODUCT_SPEED_PACK)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local s = sessions[player]
	if not purchased or not s then
		return
	end
	if passId == Config.PASS_2X_SPEED then
		s.passes.speed2x = true
	elseif passId == Config.PASS_EXTRA_SLOT then
		s.passes.extraSlot = true
		autoEquip(player, s)
	elseif passId == Config.PASS_LUCKY then
		s.passes.lucky = true
	end
	syncValues(player, s)
	notice(player, "Thank you! 💜", "Pass activated", "good")
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local s = player and sessions[player]
	if not player or not s then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.ProductId == Config.PRODUCT_SPEED_PACK then
		local add = math.max(1000, s.data.speed * 0.25)
		s.data.speed += add
		syncValues(player, s)
		applyWalkSpeed(player, s)
		notice(player, "⚡ Speed Pack!", "+" .. formatNumber(add) .. " Speed", "good")
		task.spawn(save, player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
