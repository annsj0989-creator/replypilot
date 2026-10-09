# 만드는 방법 (스튜디오 작업 가이드)

코드는 이미 완성돼 있다. 퀄리티를 결정하는 **맵, 손님 모델, UI**는 스튜디오에서 아래 규칙대로 만들면 코드가 자동으로 찾아서 쓴다.

---

## 0. 코드 넣기
**Rojo를 쓰는 경우:** `rojo serve roblox/default.project.json`

**직접 넣는 경우:**
| 스튜디오 위치 | 종류 | 이름 | 파일 |
|---|---|---|---|
| ReplicatedStorage | Folder | `NightShift` | |
| ReplicatedStorage > NightShift | ModuleScript | `Config` | `src/ReplicatedStorage/NightShift/Config.luau` |
| ServerScriptService | Folder | `NightShift` | |
| ServerScriptService > NightShift | Script | `Main` | `src/ServerScriptService/NightShift/Main.server.luau` |
| ServerScriptService > NightShift | ModuleScript | `Customers` | `src/ServerScriptService/NightShift/Customers.luau` |
| ServerScriptService > NightShift | ModuleScript | `Anomalies` | `src/ServerScriptService/NightShift/Anomalies.luau` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `NightShiftClient` | `src/StarterPlayerScripts/NightShiftClient.client.luau` |

---

## 1. 맵 (한국 편의점)
### 에셋 구하는 곳 (퀄리티 순)
1. **유료 맵 구매 또는 외주:** DevForum Talent Hub, BuiltByBit 등에서 "convenience store map"을 찾는다. 가장 빠르게 퀄리티를 올리는 방법이다.
2. **Creator Store(도구상자) 에셋 조합:** 검색어 `convenience store`, `store shelf`, `drink fridge`, `cash register`, `checkout counter`, `coffee machine`, `snack`, `cup noodle`, `fluorescent light`, `parasol table`.
   - 좋아요 비율이 높고 Script가 없는 것을 고른다.
   - 가져온 뒤 Explorer에서 `Script`를 검색해서 **전부 삭제**한다.
3. 한국 느낌 소품: 삼각김밥 진열대, 컵라면 온수기, 바나나우유 냉장고, 매장 밖 파라솔 테이블, 형광 간판.

### 구조
- **로비:** 직원 휴게실이나 매장 뒤 창고.
- **매장:** 유리 정면 출입문, 계산대 1개, 진열대 3~5줄, 냉장고 벽, 커피 머신.
- **휴게실:** 기절한 사람이 대기하는 곳. 매장이 CCTV 화면으로 보이면 좋다.
- **바깥:** 어두운 거리, 가로등 1~2개, 손님이 걸어오는 길.

### 태그 붙이기 (중요)
파트를 선택하고 **Properties → Tags**에 이름을 입력한다. 위치용 파트는 `Transparency 1`, `CanCollide false`, `Anchored true`로 둔다.

| 태그 | 개수 | 용도 |
|---|---|---|
| `LobbySpawn` | 1+ | 로비 대기 위치 |
| `ShiftSpawn` | 1+ | 근무 시작 위치 (계산대 뒤) |
| `BreakRoom` | 1+ | 기절한 사람 위치 |
| `CustomerSpawn` | 1 | 손님 등장 (매장 밖 길 끝) |
| `CustomerExit` | 1 | 손님 퇴장 위치 |
| `ShelfSpot` | 3~6 | 손님이 서서 구경하는 자리. **파트의 앞면(LookVector)이 진열대를 향하게** 놓는다 |
| `CounterSpot` | 1 | 계산대 앞 손님 자리. 앞면이 직원 쪽을 향하게 놓는다 |
| `QueueSpot` | 2~4 | 줄 서는 자리. Attributes에 `Order` 숫자(1, 2, 3...)를 넣는다 |
| `StoreLight` | 여러 개 | 깜빡일 형광등 (안에 PointLight/SurfaceLight가 있는 파트) |
| `CoffeeMachine` | 1+ | 커피 머신 모델이나 파트 |

손님이 다니는 길에는 문턱이나 계단이 없어야 한다(길찾기 실패 방지). 바닥은 평평하게 만든다.

### 조명 (Lighting)
- `Technology = Future`
- `Ambient`, `OutdoorAmbient` = 아주 어두운 남색 (예: 15, 15, 25)
- `ClockTime = 0` (밤), `Brightness = 0.5`
- **Atmosphere:** Density 0.35, Haze 2, Color 어두운 남색
- **Bloom:** Intensity 0.6, Threshold 1.5 (형광 간판이 번지게)
- **ColorCorrection:** 살짝 차갑게 (TintColor 230, 240, 255)
- 매장 형광등은 SurfaceLight를 쓴다(밝기 2~3, 하얀색에 아주 약간 초록빛).

---

## 2. 손님 모델 (8개 이상)
- **ServerStorage**에 `Customers` 폴더를 만들고, 그 안에 R15 리그 모델을 **8개 이상** 넣는다. 매장에 동시에 있는 손님끼리는 겹치지 않아야 "똑같은 사람" 이상현상이 성립한다.
- 만드는 법: **Avatar → Rig Builder → R15**로 리그를 만들고, 옷과 머리와 액세서리를 입힌다. 아바타 에디터 플러그인을 쓰거나 Creator Store에서 "R15 NPC"를 검색해도 된다.
- 직장인, 학생, 할머니, 배달기사, 커플 등 **한눈에 구별되는** 모습으로 만든다.
- 얼굴은 Decal 방식을 쓴다. 그래야 "얼굴 없음" 이상현상이 적용된다.
- 모델 안의 Script는 지운다. 걷기 애니메이션은 코드가 넣는다.

---

## 3. UI (StarterGui → `HUD` ScreenGui)
코드는 UI를 만들지 않는다. 아래 **이름**대로 만들어 두면 코드가 값을 채운다. 없는 건 건너뛴다.

| 이름 (경로) | 종류 | 코드가 하는 일 |
|---|---|---|
| `HUD.Clock` | TextLabel | "2:30 AM" 표시 (근무 중에만 보임) |
| `HUD.Night` | TextLabel | "3번째 밤" |
| `HUD.Coins` | TextLabel | 코인 숫자 |
| `HUD.Sanity` | Frame | 정신력 바 배경 (근무 중에만 보임) |
| `HUD.Sanity.Fill` | Frame | 정신력만큼 가로 길이가 줄어듦 (Size X Scale 사용) |
| `HUD.Notice` | TextLabel | 알림 문구 (색은 코드가 바꿈) |
| `HUD.Countdown` | TextLabel | "근무 시작까지 12초" |
| `HUD.Jumpscare` | ImageLabel | 점프스케어 이미지. 평소에는 `Visible = false` |
| `HUD.Fainted` | Frame | 기절 화면 |
| `HUD.Fainted.ReviveButton` | ImageButton/TextButton | 부활 구매 버튼 |
| `HUD.Results` | Frame | 결과 창. 평소에는 `Visible = false` |
| `HUD.Results.Title` | TextLabel | "3번째 밤 생존!" |
| `HUD.Results.Body` | TextLabel | 통계 + 놓친 이상현상 목록 |

퀄리티 팁:
- **UI 키트를 쓴다:** Creator Store나 BuiltByBit에서 "horror UI kit", "UI pack"을 찾아 쓴다. 직접 그린다면 Figma에서 PNG로 내보내 ImageLabel로 넣는다.
- 모든 크기는 **Scale**로 잡고 `UIAspectRatioConstraint`를 붙인다. 휴대폰과 PC에서 둘 다 확인한다.
- 근무 수칙과 매뉴얼은 화면 UI 대신 **매장 벽 포스터(SurfaceGui)**로 만든다.

---

## 4. 사운드 (SoundService → `NightShiftSounds` 폴더)
| 이름 | 용도 |
|---|---|
| `Jumpscare` | 괴물에게 잡혔을 때 |
| `Danger` | 이상현상을 놓쳤을 때 |
| `Good` | 신고 성공 |
| `Clear` / `Fail` | 결과 화면 |

배경 소리(형광등 웅웅거림, 냉장고 소리, 밖의 바람)는 매장 안 파트에 `Sound`를 넣는다. `Looped`를 켜고 `RollOffMaxDistance`를 조절한다.

---

## 5. 테스트 체크리스트
- [ ] Output 창에 `[NightShift]` 경고가 없다 (태그나 모델 누락)
- [ ] 손님이 문 → 진열대 → 줄 → 계산대로 막힘 없이 걷는다
- [ ] E로 계산, Q로 신고가 된다
- [ ] 이상현상을 계산하면 조명이 깜빡이고 괴물이 쫓아온다
- [ ] 커피를 마시면 정신력이 회복된다
- [ ] 06:00이 되면 결과 창이 뜨고 다음 밤으로 넘어간다
- [ ] 휴대폰 화면(Device Emulator)에서 UI가 잘리지 않는다
- [ ] 저장: Game Settings → Security → API Services를 켜고, 나갔다 들어와도 코인이 유지된다
