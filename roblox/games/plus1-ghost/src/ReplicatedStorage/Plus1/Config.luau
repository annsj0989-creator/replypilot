-- +1 Speed 유령 탈출 - 공용 설정
-- 밸런스는 여기 숫자만 바꾸면 된다.
-- 게임 안 글자는 전 세계 유저(주 수익원: 미국)를 위해 영어로 쓴다. 한국어는 로블록스 자동 번역/Localization으로.

local Config = {}

-- 속도
Config.STEP_STUDS = 3 -- 이만큼 움직이면 "한 걸음" (+1)
Config.MAX_STEP_PER_TICK = 40 -- 순간이동 같은 비정상 이동은 무시 (0.2초당 최대 이동 스터드 x 여유)
Config.BASE_WALKSPEED = 16
Config.MAX_WALKSPEED = 300 -- 물리 안정성을 위한 상한
Config.WALKSPEED_CURVE = 1.5 -- 걷기속도 = 16 + sqrt(속도) x 이 값

-- 트랙
Config.ZONE_COUNT = 10
Config.ZONE_LENGTH = 500
Config.TRACK_WIDTH = 60
Config.ZONE_WINS = function(zone: number): number
	return zone * 2
end
Config.FINISH_WINS = 50

-- 유령 파도 (뒤에서 쫓아옴)
Config.GHOST_INTERVAL = 45 -- 몇 초마다 출발
Config.GHOST_BASE_SPEED = 26
Config.GHOST_SPEED_PER_ZONE = 22 -- 구역이 지날수록 빨라짐
Config.GHOST_WARNING = 5 -- 출발 몇 초 전에 경고
Config.GHOST_HEIGHT = 34

-- 3D 에셋을 넣었는데 앞뒤가 반대로 서 있으면 180으로 바꾼다
Config.ASSET_YAW_OFFSET = 0

-- 러닝머신: 필요 Wins, 초당 속도
Config.TREADMILLS = {
	{ wins = 0, perSecond = 1, color = Color3.fromRGB(120, 200, 255) },
	{ wins = 100, perSecond = 5, color = Color3.fromRGB(120, 255, 160) },
	{ wins = 1000, perSecond = 25, color = Color3.fromRGB(255, 220, 90) },
	{ wins = 10000, perSecond = 120, color = Color3.fromRGB(255, 120, 200) },
	{ wins = 100000, perSecond = 600, color = Color3.fromRGB(200, 120, 255) },
}

-- 환생
Config.REBIRTH_BASE_COST = 2500
Config.REBIRTH_COST_GROWTH = 3
Config.REBIRTH_BONUS = 0.5 -- 환생 1회당 +50% 배수

-- 유령 친구(펫): 알에서 뽑음. mult = 속도 배수
Config.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
	Secret = Color3.fromRGB(40, 255, 170),
}

Config.SPIRITS = {
	Wisp = { icon = "🔥", name = "Little Wisp", rarity = "Common", mult = 1.2 },
	Sheet = { icon = "👻", name = "Sheet Ghost", rarity = "Common", mult = 1.3 },
	Pumpkin = { icon = "🎃", name = "Pumpkin Ghost", rarity = "Rare", mult = 1.6 },
	Bat = { icon = "🦇", name = "Bat Ghost", rarity = "Rare", mult = 1.8 },
	Skull = { icon = "💀", name = "Skull Ghost", rarity = "Epic", mult = 2.5 },
	Witch = { icon = "🧙", name = "Witch Ghost", rarity = "Epic", mult = 3 },
	Reaper = { icon = "☠️", name = "Grim Reaper", rarity = "Legendary", mult = 5 },
	Lantern = { icon = "🏮", name = "Lantern Ghost", rarity = "Legendary", mult = 6 },
	Dokkaebi = { icon = "👹", name = "Golden Dokkaebi", rarity = "Mythic", mult = 12 },
	Moon = { icon = "🦊", name = "Moon Fox", rarity = "Secret", mult = 40 },
}

Config.EGGS = {
	{
		id = "Basic",
		name = "Wooden Coffin",
		cost = 50,
		odds = { { "Wisp", 45 }, { "Sheet", 30 }, { "Pumpkin", 17 }, { "Bat", 7 }, { "Skull", 1 } },
	},
	{
		id = "Haunted",
		name = "Cursed Coffin",
		cost = 1500,
		odds = { { "Pumpkin", 40 }, { "Bat", 30 }, { "Skull", 18 }, { "Witch", 10 }, { "Reaper", 2 } },
	},
	{
		id = "Royal",
		name = "Golden Coffin",
		cost = 40000,
		odds = { { "Witch", 45 }, { "Reaper", 32 }, { "Lantern", 18 }, { "Dokkaebi", 4.7 }, { "Moon", 0.3 } },
	},
}

Config.EQUIP_SLOTS = 3
Config.MAX_SPIRITS = 60 -- 넘으면 가장 약한 것부터 자동 정리

-- 수익화 (Creator Hub에서 만든 뒤 ID 입력, 0이면 꺼짐)
Config.PASS_2X_SPEED = 0
Config.PASS_EXTRA_SLOT = 0 -- 장착 칸 +2
Config.PASS_LUCKY = 0 -- 희귀 확률 2배
Config.PRODUCT_SPEED_PACK = 0 -- 즉시 속도 +(현재 속도의 25%, 최소 1000)

Config.DATASTORE_NAME = "Plus1Ghost_v1"

return Config
