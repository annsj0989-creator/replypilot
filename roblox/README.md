# 몬스터 훔치기 (Steal a Monster) — MVP

## 스튜디오에 넣는 법 (복사-붙여넣기)
1. 새 Baseplate 플레이스 열기
2. **ServerScriptService** 우클릭 → Insert Object → **Script** → 이름 `MonsterGame` → `src/ServerScriptService/MonsterGame.server.luau` 내용 전체 붙여넣기
3. **StarterPlayer > StarterPlayerScripts** 우클릭 → Insert Object → **LocalScript** → 이름 `MonsterClient` → `src/StarterPlayerScripts/MonsterClient.client.luau` 내용 붙여넣기
4. 저장 기능 테스트: Game Settings → Security → **Enable Studio Access to API Services** 켜기 (게임을 한 번 Publish 해야 함)
5. 서버 최대 인원: Game Settings → Places → Max Players **8** (기지가 8개)
6. ▶ Play

## 들어있는 것
- 기지 8개 자동 생성 (입장하면 하나 배정, 이름 표지판)
- 컨베이어: 2초마다 몬스터 등장, 6개 등급(일반~SECRET), 신화/SECRET 등장 시 전체 알림
- 구매 → 기지 슬롯(8칸)에 배치 → 초당 돈
- 훔치기: 남의 몬스터 길게 눌러 훔치기 → 머리에 들고 느려짐 → 자기 기지에 들어가면 성공, 죽으면 원래 주인에게 돌아감
- 잡아 던지기 도구: 도둑 또는 내 기지 침입자를 날려버림 (도둑이면 몬스터 되찾음)
- 기지 잠금 30초 (쿨타임 30초), 잠긴 기지에 들어오면 튕겨냄
- 속도 업그레이드 (최대 20레벨)
- 돈 2배 게임패스 (CONFIG.GAMEPASS_2X_CASH에 ID 넣으면 버튼 나타남)
- 자동 저장 (돈, 속도, 몬스터)

## 밸런스 조절
`MonsterGame` 스크립트 맨 위 `CONFIG`, `RARITIES`, `MONSTERS` 표의 숫자만 바꾸면 됨.

## Rojo 사용 시
`default.project.json` 사용: `rojo serve roblox/default.project.json`
