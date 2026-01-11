# Quiz Castle - 개발 변경 로그

## v3.2.1 (2026-01-12)

### 스폰 시스템 전면 재설계
기존의 워크어라운드 코드를 제거하고 Roblox 네이티브 SpawnLocation 시스템을 제대로 활용하도록 재설계

#### 변경된 맵 레이아웃
```
기존: Lobby(Z=0) → 100스터드 터널 → Course(Z=100+)
변경: Lobby(Z=-30) → Gate(Z=25) → Course(Z=30+)
```

#### 주요 변경사항
- **COURSE_OFFSET**: 100 → 30으로 축소
- **TeleportToRace 함수 제거**: 플레이어가 직접 이동
- **CharacterAdded 스폰 보정 코드 제거**: RespawnLocation 시스템 신뢰
- **EntranceBridge 완전 제거**: 불필요한 다리 구조물 삭제
- **BRIDGE_START_Z, BRIDGE_END_Z 상수 제거**

### 세션 잠금 시스템 추가
- 카운트다운 시작 후 5초 경과 시 세션 잠금
- `GameState.sessionLocked` 플래그 추가
- 잠금 후 새 플레이어 레이스 참가 차단

### 기존 플레이어 처리 개선
- 서버 시작 시 이미 존재하는 플레이어 처리 로직 추가
- `SetupPlayer` 함수로 초기화 로직 통합

### 버그 수정

#### XPUpdate 이벤트 형식 수정
```lua
-- 기존 (잘못됨)
Events.XPUpdate:FireClient(player, pData.xp, pData.level)

-- 수정 후
Events.XPUpdate:FireClient(player, {
    xp = pData.xp,
    level = pData.level,
    xpForNext = XPForLevel(pData.level + 1),
    xpForCurrent = XPForLevel(pData.level)
})
```

#### 바닥 Z-fighting 수정
- LobbyFloor와 LobbySpawn이 Y=0에서 겹쳐서 깜빡임 발생
- LobbyFloor: Y=-0.5 (높이 1), LobbySpawn: Y=0.1로 분리

#### 진행도 바 수정
- 서버에서 progress 데이터 전송하지 않던 문제 수정
- Z 위치 기반 진행률 계산 후 TimeUpdate로 전송

---

## v3.2.0 (이전 버전)

### 기믹 모듈화 시스템
- GimmickRegistry 시스템 도입
- CourseEngine으로 데이터 기반 코스 생성
- 10개 기믹 모듈화 완료:
  1. RotatingBar (회전 막대)
  2. JumpPad (점프 패드)
  3. SlimeZone (슬라임 구간)
  4. PunchingCorridor (펀칭 복도)
  5. QuizGate (퀴즈 게이트)
  6. Elevator (엘리베이터)
  7. DisappearingBridge (사라지는 다리)
  8. ConveyorBelt (컨베이어 벨트)
  9. ElectricFloor (전기 바닥)
  10. RollingBoulder (구르는 바위)

### 아이템 시스템
- Booster: 3초간 속도 5% 증가
- Shield: 5초간 보호막
- Banana: 함정 설치
- Lightning: 전체 스턴

### XP/레벨 시스템
- 레이스 완주 시 XP 획득
- 순위별 차등 XP 지급
- 레벨업 시 알림

---

## 파일 구조

```
castle/
├── src/
│   ├── server/
│   │   └── QuizCastleServer.server.lua  # 메인 서버 로직
│   ├── client/
│   │   └── QuizCastleClient.client.lua  # UI 및 클라이언트 로직
│   └── shared/                          # 공용 모듈
├── docs/
│   ├── ARCHITECTURE_DESIGN.md           # 아키텍처 설계 문서
│   └── CHANGELOG.md                     # 이 파일
├── default.project.json                 # Rojo 프로젝트 설정
├── SetupScript.lua                      # Studio 초기 설정 스크립트
├── CLAUDE.md                            # AI 개발 컨텍스트
└── README.md                            # 설치 가이드
```

---

## 개발 환경 설정

### 필수 도구
1. **Roblox Studio**
2. **Rojo** (v7.4.1+)
3. **Aftman** (선택, Rojo 설치용)

### 시작하기
```bash
# 프로젝트 클론
git clone https://github.com/EnmanyProject/castle.git
cd castle

# Rojo 서버 시작
rojo serve default.project.json

# Roblox Studio에서 Rojo 플러그인으로 Connect
```

---

## 알려진 이슈
- 속도 부스트(5%)가 체감상 과하게 느껴질 수 있음 (3%로 조정 검토 중)
