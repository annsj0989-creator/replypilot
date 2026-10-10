# 3D 에셋 (블렌더 제작)

| 이름 | 용도 | 삼각형 |
|---|---|---|
| CoffinWood / CoffinCursed / CoffinGold | 관 3종 (뽑기) | 4~6천 |
| GhostChaser | 추격 유령 | 1.7만 |
| Tombstone | 비석 장식 | 3.5천 |
| LanternPost | 등불 (코드가 빛나는 구슬+조명 추가) | 1.6천 |
| DeadTree | 죽은 나무 | 6천 |
| RebirthStatue | 환생 석상 | 2.6천 |
| Treadmill | 러닝머신 | 2천 |

## 스튜디오에 넣는 법 (2분)
1. **ServerStorage** 에 Folder 만들고 이름을 `Plus1Assets` 로
2. 상단 **Home → Import 3D** (또는 Asset Manager → Bulk Import) 에서 `fbx/` 폴더의 FBX 9개 선택 → Import
3. Workspace에 생긴 9개를 전부 `Plus1Assets` 폴더로 드래그. **이름이 위 표와 정확히 같아야 함**
4. ▶ Play. 코드가 알아서 크기·방향·위치를 맞춰 배치함 (에셋이 없으면 기본 블록으로 대체)

- 텍스처가 안 입혀졌으면: 해당 MeshPart에 `SurfaceAppearance` 넣고 ColorMap에 `fbx/<이름>_Color.png`
- 관이 뒤돌아 서 있으면: `Config.luau`의 `ASSET_YAW_OFFSET = 180`

## 다시 만들기
`kit.py -- <출력폴더> export` (Blender 5.2 Python). 미리보기: `kit.py -- <폴더> preview`, 로비 배치 확인: `lobby_mock.py -- <폴더>`
