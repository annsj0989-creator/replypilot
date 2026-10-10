-- 편의점 야간 알바 - 공용 설정
-- 서버와 클라이언트가 같이 읽는다. 밸런스는 여기 숫자만 바꾸면 된다.

local Config = {}

Config.LOBBY_COUNTDOWN = 20 -- 로비에서 근무 시작까지(초)
Config.RESULTS_TIME = 12 -- 결과 화면 시간(초)
Config.MIN_PLAYERS = 1

-- 근무 시간: 게임 속 22:00 → 06:00 (8시간)을 실제 몇 초로 할지
Config.SHIFT_REAL_SECONDS = 360
Config.SHIFT_START_MINUTE = 22 * 60
Config.SHIFT_LENGTH_MINUTES = 8 * 60

Config.MAX_NIGHT = 5

-- 밤별 난이도: 손님 간격(초), 이상현상 확률, 동시에 매장에 있는 최대 손님 수
Config.NIGHTS = {
	[1] = { spawnInterval = 16, anomalyChance = 0.20, maxCustomers = 3 },
	[2] = { spawnInterval = 14, anomalyChance = 0.30, maxCustomers = 4 },
	[3] = { spawnInterval = 12, anomalyChance = 0.40, maxCustomers = 4 },
	[4] = { spawnInterval = 11, anomalyChance = 0.50, maxCustomers = 5 },
	[5] = { spawnInterval = 10, anomalyChance = 0.60, maxCustomers = 5 },
}

Config.CUSTOMER_PATIENCE = 45 -- 계산대에서 기다리는 시간(초). 넘기면 화내고 나감
Config.BROWSE_TIME = { 4, 9 } -- 진열대 구경 시간 범위(초)

-- 정신력
Config.MAX_SANITY = 100
Config.SANITY_DRAIN_PER_SEC = 0.15 -- 근무 중 자연 감소
Config.SANITY_WRONG_REPORT = 10 -- 정상 손님을 신고했을 때
Config.SANITY_ANOMALY_SERVED = 15 -- 이상현상을 계산해줬을 때 (매장 전체)
Config.SANITY_HUNTER_HIT = 35 -- 추격하는 괴물에게 잡혔을 때
Config.SANITY_IMPATIENT = 3 -- 손님이 화내고 나갔을 때
Config.COFFEE_RESTORE = 15
Config.COFFEE_COOLDOWN = 20

-- 괴물(계산해준 이상현상)이 추격하는 시간과 속도
Config.HUNTER_DURATION = 18
Config.HUNTER_SPEED = 20
Config.HUNTER_HIT_RANGE = 4

-- 보상 (코인)
Config.PAY_SERVE = 10
Config.PAY_REPORT_CORRECT = 25
Config.PAY_NIGHT_CLEAR = 150 -- 밤을 버티면 생존자 전원에게
Config.PAY_NIGHT_BONUS_PER_LEVEL = 50 -- 밤 번호 x 이 값 추가

-- 수익화 (Creator Hub에서 만든 뒤 ID 입력, 0이면 꺼짐)
Config.GAMEPASS_2X_COINS = 0
Config.PRODUCT_REVIVE = 0 -- 기절했을 때 즉시 부활 (개발자 상품)

Config.DATASTORE_NAME = "NightShift_v1"

-- 맵에서 찾는 태그 이름 (스튜디오 Properties > Tags 에 입력)
Config.TAGS = {
	LOBBY_SPAWN = "LobbySpawn",
	SHIFT_SPAWN = "ShiftSpawn",
	BREAK_ROOM = "BreakRoom", -- 기절한 사람이 가는 곳
	CUSTOMER_SPAWN = "CustomerSpawn", -- 손님이 들어오는 문 밖
	CUSTOMER_EXIT = "CustomerExit",
	SHELF_SPOT = "ShelfSpot", -- 손님이 구경하는 위치 (여러 개)
	COUNTER_SPOT = "CounterSpot", -- 계산대 앞 손님 자리 (1개)
	QUEUE_SPOT = "QueueSpot", -- 줄 서는 자리 (Order 속성 1,2,3...)
	STORE_LIGHT = "StoreLight", -- 깜빡일 조명 (안에 Light 들어있는 파트)
	COFFEE_MACHINE = "CoffeeMachine",
	STORE_AREA = "StoreArea", -- 매장 내부 영역 (투명 파트, 괴물 추격 범위)
}

return Config
