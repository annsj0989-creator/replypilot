# UNBURY A LOST CITY! — PHASE 0 (발굴 테스트)

사막에 묻힌 고대 도시를 발굴하는 Roblox 게임의 **PHASE 0: 기술 설계와 발굴 테스트** 빌드입니다.

- 결과 보고서: [`docs/PHASE0_REPORT.md`](docs/PHASE0_REPORT.md)
- 발굴 방식 비교와 구조: [`docs/DIG_SYSTEM_DESIGN.md`](docs/DIG_SYSTEM_DESIGN.md)

## 바로 실행하기 (Rojo 없이)

1. `build/UnburyALostCity_Phase0.rbxl` 을 Roblox Studio에서 엽니다.
2. **Play(F5)** 를 누릅니다. 지형과 캠프는 서버 시작 시 코드로 생성됩니다(편집 모드에서는 빈 맵으로 보이는 것이 정상).
3. 내 발굴 구역 앞에서 시작합니다. 노란 "여기를 파세요" 표시 아래를 파면 유물이 나옵니다.

| 조작 | PC | 모바일 | 게임패드 |
|---|---|---|---|
| 발굴 | 왼쪽 마우스 버튼을 누르고 있기 | **파기** 버튼을 누르고 있기 | R2 누르고 있기 |
| 조준 | 마우스 커서 위치 | 캐릭터 앞 / 모래를 탭한 위치 | 캐릭터 앞 |

Studio 전용 테스트 키: **F2** 도구 Lv1↔Lv2 전환 · **F3** 성능 표시(FPS, 메모리, 서버 발굴 비용) · **F4** 내 발굴 구역 초기화.

권장 게임 설정: Max Players = 6(서버당 개인 발굴 구역 6개).

## 개발 환경 (Rojo)

```bash
rojo serve                 # Studio의 Rojo 플러그인과 실시간 동기화
rojo build default.project.json -o build/UnburyALostCity_Phase0.rbxl
```

도구 버전(이 빌드를 검증한 버전): Rojo 7.7.1, Lune 0.10.5, Selene 0.31.0, StyLua 2.6.0, luau-lsp(소스 빌드).

## 테스트 (Studio 없이 실행 가능한 범위)

```bash
lune run tests/run                                   # 순수 로직 단위 테스트
lune run tests/simulate                              # 발굴 페이싱 시뮬레이션 + CPU 비용
lune run tests/verify_place build/UnburyALostCity_Phase0.rbxl   # 빌드된 place 구조 검사
selene src                                           # 린트 (roblox std 필요)
stylua --check src tests                             # 포맷
```

`tests/Loader.luau`가 Roblox식 `require(script.Parent.X)`를 파일 경로로 연결하므로, 게임 코드와 **같은 파일**을 수정 없이 테스트합니다. Roblox 서비스에 의존하는 코드는 luau-lsp 타입 검사와 Studio 플레이 테스트로만 확인할 수 있습니다.

## 폴더 구조

```
src/shared/            ReplicatedStorage.Shared — 서버·클라이언트 공용(순수 로직)
  Config/GameConfig    발굴 감각을 결정하는 모든 수치
  Config/SoundConfig   사운드 목록(검증된 에셋만, 없으면 무음)
  DigGrid              발굴 상태(높이맵), 모래 흘러내림, 노출도, 저장 인코딩
  TerrainVoxels        높이맵 → WriteVoxels 배열
  DigValidation        발굴 요청 검증 규칙(클라이언트 사전 검사 + 서버 판정)
  Zone, Strings
src/server/            ServerScriptService.Server
  Services/            WorldBuilder, PlotService, DigService, ArtifactService,
                       ArtifactFactory, TerrainRenderer, ToolService, PlayerService, DebugService
  Util/RateLimiter
src/client/            StarterPlayerScripts.Client
  Controllers/         DigController, AimIndicator, Effects, Sounds, Hud, Markers,
                       PlotWatcher, DebugOverlay
tests/                 Lune 테스트
```

## 고품질 모델로 교체하기

`ServerStorage/ArtifactTemplates` 폴더에 유물 Id와 같은 이름(예: `SunIdol`)의 Model을 넣으면 코드의 임시 모델 대신 사용합니다.
- 피벗: 받침대 바닥 중앙, 정면: -Z
- 이름이 `Gem`인 파트(+ 안의 PointLight)가 있으면 발견 시 빛납니다.
- 모델 안의 스크립트는 자동으로 제거됩니다.
