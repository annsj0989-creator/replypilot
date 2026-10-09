-- 이상현상 목록
-- 손님 모델(R15 리그)에 코드로 적용한다. 모델 자체의 퀄리티는 ServerStorage.Customers 에 넣은 리그가 결정한다.
-- tier 1 = 눈에 잘 띔, 2 = 집중해야 보임, 3 = 아주 미묘함

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Context = {
	say: (text: string) -> (),
	isAlive: () -> boolean,
}

export type Anomaly = {
	id: string,
	name: string,
	hint: string,
	tier: number,
	canApply: ((npc: Model) -> boolean)?,
	apply: ((npc: Model, ctx: Context) -> ())?,
	greeting: { string }?,
}

local function getHumanoid(npc: Model): Humanoid?
	return npc:FindFirstChildOfClass("Humanoid")
end

local function getNeck(npc: Model): Motor6D?
	local head = npc:FindFirstChild("Head")
	local neck = head and head:FindFirstChild("Neck")
	if neck and neck:IsA("Motor6D") then
		return neck
	end
	return nil
end

local function nearestPlayerHead(position: Vector3, maxDist: number): BasePart?
	local best, bestDist = nil, maxDist
	for _, p in ipairs(Players:GetPlayers()) do
		local head = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
		if head then
			local d = (head.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = head, d
			end
		end
	end
	return best
end

local SKIN_PARTS = {
	"Head",
	"LeftHand",
	"RightHand",
	"LeftLowerArm",
	"RightLowerArm",
}

local Anomalies: { Anomaly } = {
	{
		id = "HeadBackward",
		name = "머리가 뒤로 돌아감",
		hint = "손님의 얼굴 방향을 확인하세요.",
		tier = 1,
		canApply = function(npc)
			return getNeck(npc) ~= nil
		end,
		apply = function(npc)
			local neck = getNeck(npc) :: Motor6D
			neck.C0 = neck.C0 * CFrame.Angles(0, math.pi, 0)
		end,
	},
	{
		id = "TooTall",
		name = "키가 비정상적으로 큼",
		hint = "다른 손님과 키를 비교해 보세요.",
		tier = 1,
		apply = function(npc)
			npc:ScaleTo(1.3)
		end,
	},
	{
		id = "Flicker",
		name = "몸이 깜빡임",
		hint = "손님을 몇 초 동안 계속 지켜보세요.",
		tier = 1,
		apply = function(npc, ctx)
			task.spawn(function()
				while ctx.isAlive() do
					task.wait(math.random(25, 45) / 10)
					if not ctx.isAlive() then
						break
					end
					local saved = {}
					for _, part in ipairs(npc:GetDescendants()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							saved[part] = part.Transparency
							part.Transparency = 0.85
						end
					end
					task.wait(0.08)
					for part, t in pairs(saved) do
						if part.Parent then
							part.Transparency = t
						end
					end
				end
			end)
		end,
	},
	{
		id = "GlitchSpeech",
		name = "말이 이상함",
		hint = "손님이 하는 말을 잘 읽어 보세요.",
		tier = 1,
		greeting = {
			"안녕하세요요요요요요",
			"삼각김밥... 삼각김밥... 삼각김밥...",
			"계산해 주세요. 계산해 주세요. 계산해 주세요.",
			"오늘 밤은 길 거예요, 직원님.",
			"ㅇㅏㄴㄴㅕㅇㅎㅏㅅㅔㅇㅛ",
		},
	},
	{
		id = "Staring",
		name = "계속 직원을 쳐다봄",
		hint = "손님의 시선을 확인하세요.",
		tier = 2,
		canApply = function(npc)
			return getNeck(npc) ~= nil
		end,
		apply = function(npc, ctx)
			local neck = getNeck(npc) :: Motor6D
			local original = neck.C0
			local torso = npc:FindFirstChild("UpperTorso") :: BasePart?
			if not torso then
				return
			end
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function()
				if not ctx.isAlive() or not torso.Parent then
					conn:Disconnect()
					return
				end
				local target = nearestPlayerHead(torso.Position, 40)
				if target then
					local rel = torso.CFrame:PointToObjectSpace(target.Position)
					local yaw = math.atan2(-rel.X, -rel.Z)
					neck.C0 = original * CFrame.Angles(0, yaw, 0)
				end
			end)
		end,
	},
	{
		id = "Floating",
		name = "발이 땅에 닿지 않음",
		hint = "손님의 발밑을 보세요.",
		tier = 2,
		apply = function(npc)
			local hum = getHumanoid(npc)
			if hum then
				hum.HipHeight += 0.7
			end
		end,
	},
	{
		id = "NoFace",
		name = "얼굴이 없음",
		hint = "손님의 얼굴을 자세히 보세요.",
		tier = 2,
		canApply = function(npc)
			local head = npc:FindFirstChild("Head")
			return head ~= nil and head:FindFirstChildOfClass("Decal") ~= nil
		end,
		apply = function(npc)
			local head = npc:FindFirstChild("Head") :: BasePart
			for _, d in ipairs(head:GetChildren()) do
				if d:IsA("Decal") then
					d.Transparency = 1
				end
			end
		end,
	},
	{
		id = "BackwardWalk",
		name = "뒤로 걸음",
		hint = "손님이 걷는 모습을 보세요.",
		tier = 2,
		apply = function(npc, ctx)
			local hum = getHumanoid(npc)
			local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hum or not root then
				return
			end
			hum.AutoRotate = false
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function()
				if not ctx.isAlive() or not root.Parent then
					conn:Disconnect()
					return
				end
				local dir = hum.MoveDirection
				if dir.Magnitude > 0.1 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position - Vector3.new(dir.X, 0, dir.Z))
				end
			end)
		end,
	},
	{
		id = "RedEyes",
		name = "눈에서 빛이 남",
		hint = "어두운 곳에서 손님 얼굴을 보세요.",
		tier = 2,
		apply = function(npc)
			local head = npc:FindFirstChild("Head")
			if not head then
				return
			end
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 30, 30)
			light.Brightness = 2
			light.Range = 4
			light.Shadows = false
			light.Parent = head
		end,
	},
	{
		id = "NoShadow",
		name = "그림자가 없음",
		hint = "조명 아래에서 손님의 그림자를 보세요.",
		tier = 3,
		apply = function(npc)
			for _, part in ipairs(npc:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CastShadow = false
				end
			end
		end,
	},
	{
		id = "WrongSkin",
		name = "피부색이 창백함",
		hint = "손님의 손과 얼굴 색을 보세요.",
		tier = 3,
		apply = function(npc)
			for _, name in ipairs(SKIN_PARTS) do
				local part = npc:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					part.Color = part.Color:Lerp(Color3.fromRGB(150, 175, 160), 0.7)
				end
			end
		end,
	},
	{
		-- Customers 모듈이 특별 처리: 지금 매장에 있는 손님과 똑같은 모습으로 등장
		id = "Doppelganger",
		name = "똑같은 사람이 두 명",
		hint = "매장 안에 같은 사람이 있는지 보세요.",
		tier = 3,
	},
}

local byId: { [string]: Anomaly } = {}
for _, a in ipairs(Anomalies) do
	byId[a.id] = a
end

local module = {}
module.list = Anomalies
module.byId = byId

-- 밤 번호에 맞는 이상현상 하나를 고른다. 밤이 깊을수록 미묘한 것이 더 자주 나온다.
function module.pick(night: number, npc: Model?, allowDoppelganger: boolean): Anomaly?
	local maxTier = math.min(3, night)
	local pool = {}
	local total = 0
	for _, a in ipairs(Anomalies) do
		local ok = a.tier <= maxTier
		if a.id == "Doppelganger" then
			ok = ok and allowDoppelganger
		elseif ok and npc and a.canApply then
			ok = a.canApply(npc)
		end
		if ok then
			-- 높은 밤에는 tier 높은 것에 가중치
			local weight = 1 + (a.tier - 1) * (night - 1) * 0.5
			total += weight
			table.insert(pool, { a = a, w = weight })
		end
	end
	if #pool == 0 then
		return nil
	end
	local roll = math.random() * total
	for _, entry in ipairs(pool) do
		roll -= entry.w
		if roll <= 0 then
			return entry.a
		end
	end
	return pool[#pool].a
end

return module
