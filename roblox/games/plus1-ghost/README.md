# +1 Speed Ghost Escape (+1 스피드 유령 탈출)

첫 번째 "작게, 빨리, 숫자로 판단" 게임. 목표: 1주 안에 플레이 가능 → 2주 안에 출시.

## 게임 한 줄
걸을 때마다 속도 +1 → 유령 파도에게 잡히기 전에 10구역 트랙을 달려 Wins 획득 → 관을 열어 유령 친구(속도 배수) 뽑기 → 환생해서 더 빠르게.

## 넣는 법 (5분)
**Rojo:** `rojo serve roblox/games/plus1-ghost/default.project.json`

**직접:**
| 스튜디오 위치 | 종류 | 이름 | 파일 |
|---|---|---|---|
| ReplicatedStorage | Folder | `Plus1` | |
| ReplicatedStorage > Plus1 | ModuleScript | `Config` | `src/ReplicatedStorage/Plus1/Config.luau` |
| ServerScriptService | Folder | `Plus1` | |
| ServerScriptService > Plus1 | Script | `Main` | `src/ServerScriptService/Plus1/Main.server.luau` |
| ServerScriptService > Plus1 | ModuleScript | `Track` | `src/ServerScriptService/Plus1/Track.luau` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `Plus1Client` | `src/StarterPlayerScripts/Plus1Client.client.luau` |

빈 Baseplate에 넣고 ▶ Play. 맵·조명은 코드가 만든다 (기존 Baseplate는 지워도 됨).

## 들어있는 것
- 걸음마다 속도 +1 × 배수, 속도에 따라 걷기 속도 증가 (최대 300)
- 10구역 트랙, 구역 통과마다 Wins, 결승선 보너스
- 45초마다 유령 파도 출발 → 잡히면 로비로 (5초 전 경고)
- 러닝머신 5단계 (Wins로 해금, 서 있으면 자동으로 속도 증가)
- 관 3종 → 유령 친구 10종 (Common~Secret), 가장 센 3마리 자동 장착 + 따라다님
- 환생: 속도 초기화, 배수 +50%
- 게임패스 3개(속도 2배, 장착 칸 +2, 행운 2배) + 속도 팩 상품 — `Config.luau`에 ID만 넣으면 작동
- 자동 저장
- 손맛: +N 숫자 튀어오름, 속도에 따른 시야 확대, 바람 파티클, 유령 접근 시 화면 색 변화, 뽑기/잡힘 연출

## 사운드 (선택, SoundService > `Plus1Sounds` 폴더)
`Good`, `Warning`, `Rare`, `Hatch`, `Caught` — Creator Store에서 무료 효과음으로 넣으면 손맛이 크게 올라감.

## 테스트할 것 (사용자님 몫: "재밌다/별로다"만)
- [ ] 처음 30초 안에 뭘 해야 할지 알겠나?
- [ ] 1구역을 넘었을 때 기분 좋은가?
- [ ] 유령 파도가 쫓아올 때 긴장되나?
- [ ] 관을 열고 싶어지나? (Wins 모으는 속도가 적당한가?)
- [ ] 10분 하고 나서 더 하고 싶은가?

## 2주 계획
| 언제 | 할 일 |
|---|---|
| 1주차 | 스튜디오에서 플레이 → 피드백 → 밸런스·손맛 수정 |
| 2주차 초 | 썸네일·아이콘 (Blender 렌더로 제작 가능), 게임패스 등록, 출시 |
| 2주차 말 | 광고 소액 → D1 재방문율, 평균 플레이 시간, 썸네일 클릭률 확인 |
