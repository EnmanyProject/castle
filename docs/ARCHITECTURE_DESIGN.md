# Quiz Castle - 대규모 멀티플레이어 아키텍처 설계

## 1. 인기 Roblox 게임 분석

### Tower of Hell (동시접속 50,000+)
```
구조: Hub 없음, 직접 게임 서버 입장
서버당: 20명
방식: Roblox 자동 서버 생성
특징: 단순함, 즉시 플레이
```

### Murder Mystery 2 (동시접속 100,000+)
```
구조: 로비 → 매치메이킹 → 게임
서버당: 12명
방식: TeleportService로 게임 서버 이동
특징: 라운드 기반, 자동 매칭
```

### Adopt Me (동시접속 500,000+)
```
구조: 단일 월드 서버
서버당: 48명
방식: Roblox 자동 서버 분리
특징: 영구 월드, 서버 간 데이터 동기화
```

### Jailbreak / Blox Fruits (동시접속 200,000+)
```
구조: 오픈 월드 + 이벤트
서버당: 25~30명
방식: 서버 리스트 / 친구 따라가기
특징: VIP 서버, 프라이빗 서버 옵션
```

---

## 2. Quiz Castle 권장 아키텍처

### 2.1 Hub + Game Server 모델 (권장)

```
┌─────────────────────────────────────────────────────────────────┐
│                        QUIZ CASTLE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────────┐                                              │
│   │   MAIN HUB   │  ← 플레이어 첫 입장 (최대 50명/서버)         │
│   │              │                                              │
│   │  - 캐릭터 커스텀  │                                          │
│   │  - 상점          │                                          │
│   │  - 리더보드      │                                          │
│   │  - 설정          │                                          │
│   │  - 친구 목록     │                                          │
│   │                  │                                          │
│   │  [🎮 PLAY 버튼]  │                                          │
│   └────────┬─────────┘                                          │
│            │                                                     │
│            │ TeleportService                                     │
│            ▼                                                     │
│   ┌─────────────────────────────────────────────────────┐       │
│   │              MATCHMAKING SYSTEM                      │       │
│   │                                                      │       │
│   │   Queue: [Player1, Player2, Player3, ...]           │       │
│   │                                                      │       │
│   │   8명 모이면 → Game Server 생성 및 텔레포트         │       │
│   └─────────────────────────────────────────────────────┘       │
│            │                                                     │
│            ▼                                                     │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│   │ GAME SERVER 1│  │ GAME SERVER 2│  │ GAME SERVER N│         │
│   │   8명 레이스  │  │   8명 레이스  │  │   8명 레이스  │         │
│   │              │  │              │  │              │         │
│   │  Race 1      │  │  Race 1      │  │  Race 1      │         │
│   │  Race 2      │  │  Race 2      │  │  Race 2      │         │
│   │  ...         │  │  ...         │  │  ...         │         │
│   └──────┬───────┘  └──────────────┘  └──────────────┘         │
│          │                                                       │
│          │ 레이스 종료 후                                        │
│          ▼                                                       │
│   ┌──────────────────────────────────────┐                      │
│   │  선택지:                              │                      │
│   │  [다음 레이스] [메인 허브로] [나가기] │                      │
│   └──────────────────────────────────────┘                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Place 구조 (Experience 설정)

### 3.1 필요한 Place들

```
Quiz Castle (Experience)
│
├── 🏠 MainHub (Start Place)
│   └── PlaceId: 자동 생성
│   └── 최대 인원: 50명
│   └── 역할: 로비, 상점, 커스텀, 매칭 대기
│
├── 🎮 RaceGame (추가 Place)
│   └── PlaceId: 별도 생성
│   └── 최대 인원: 16명 (8명 권장)
│   └── 역할: 실제 레이스 진행
│   └── Reserved Server로 생성
│
└── 📊 (선택) Spectate/Results
    └── 결과 화면, 관전 모드
```

### 3.2 Roblox Studio에서 설정

```
Game Settings → Places
  ├── MainHub (Start Place) ✓
  └── RaceGame (추가)
        └── Create New Place
```

---

## 4. 데이터 흐름

### 4.1 서버 간 데이터 전달

```lua
-- MainHub → RaceGame 텔레포트 시 데이터 전달
local teleportData = {
    odisplayName = player.DisplayName,
    odlevel = PlayerData.level,
    skin = PlayerData.selectedSkin,
    trail = PlayerData.selectedTrail,
    matchId = generatedMatchId
}

TeleportService:TeleportAsync(RaceGamePlaceId, players, teleportOptions)
```

### 4.2 영구 데이터 (DataStore)

```lua
-- 모든 서버에서 접근 가능
DataStore:
  ├── PlayerXP
  ├── PlayerLevel
  ├── PlayerWins
  ├── PlayerSkins (구매한 스킨)
  ├── PlayerSettings
  └── GlobalLeaderboard
```

### 4.3 실시간 데이터 (MemoryStore)

```lua
-- 매치메이킹 큐 (서버 간 공유)
MemoryStoreService:
  ├── MatchmakingQueue (대기 중인 플레이어)
  ├── ActiveMatches (진행 중인 매치)
  └── ServerStatus (각 서버 상태)
```

---

## 5. 매치메이킹 시스템

### 5.1 흐름

```
1. 플레이어가 MainHub에서 [PLAY] 클릭
2. MemoryStore 큐에 플레이어 추가
3. 8명 모이면:
   a. Reserved Server 생성 (RaceGame Place)
   b. 8명 모두 해당 서버로 텔레포트
   c. 큐에서 제거
4. 30초 대기 후 인원 미달 시:
   a. 현재 인원으로 시작 (최소 2명)
   b. 또는 대기 계속
```

### 5.2 매칭 옵션

```lua
MatchmakingOptions = {
    -- 일반 매칭
    Normal = {
        minPlayers = 2,
        maxPlayers = 8,
        waitTime = 30
    },

    -- 랭크 매칭 (레벨 기반)
    Ranked = {
        minPlayers = 4,
        maxPlayers = 8,
        waitTime = 60,
        levelRange = 5  -- 내 레벨 ±5 범위
    },

    -- 프라이빗 매칭
    Private = {
        code = "ABC123",
        minPlayers = 2,
        maxPlayers = 8
    }
}
```

---

## 6. 파일 구조 (리팩토링)

### 6.1 새로운 구조

```
castle/
├── src/
│   ├── hub/                    # MainHub 전용
│   │   ├── HubServer.server.lua
│   │   ├── HubClient.client.lua
│   │   ├── Matchmaking.lua
│   │   ├── Shop.lua
│   │   └── Customization.lua
│   │
│   ├── race/                   # RaceGame 전용
│   │   ├── RaceServer.server.lua
│   │   ├── RaceClient.client.lua
│   │   ├── CourseManager.lua
│   │   ├── GimmickRegistry.lua
│   │   └── ItemSystem.lua
│   │
│   └── shared/                 # 공통 모듈
│       ├── PlayerData.lua
│       ├── Constants.lua
│       ├── Utils.lua
│       └── NetworkEvents.lua
│
├── hub.project.json            # MainHub용 Rojo 프로젝트
├── race.project.json           # RaceGame용 Rojo 프로젝트
└── docs/
    └── ARCHITECTURE_DESIGN.md
```

---

## 7. 구현 단계

### Phase 1: 기본 구조 (1주)
- [ ] MainHub Place 생성
- [ ] RaceGame Place 분리
- [ ] TeleportService 기본 연동
- [ ] 단순 [PLAY] → 텔레포트 구현

### Phase 2: 매치메이킹 (1주)
- [ ] MemoryStoreService 큐 시스템
- [ ] Reserved Server 생성
- [ ] 그룹 텔레포트
- [ ] 대기 UI

### Phase 3: MainHub 콘텐츠 (1주)
- [ ] 상점 시스템
- [ ] 캐릭터 커스터마이징
- [ ] 리더보드 UI
- [ ] 친구 초대 시스템

### Phase 4: 고급 기능 (1주)
- [ ] 랭크 매칭
- [ ] 프라이빗 매치 코드
- [ ] 시즌/배틀패스
- [ ] VIP 서버

---

## 8. 용량 계산

### 동시접속 10,000명 기준

```
MainHub 서버: 10,000 ÷ 50 = 200개 서버
RaceGame 서버: (활성 매치 수) × 1개

예상 활성 매치:
- 평균 레이스 시간: 3분
- 동시 레이싱 비율: 60%
- 레이싱 인원: 6,000명
- 매치당 인원: 8명
- 필요 서버: 6,000 ÷ 8 = 750개 Game Server

총 서버: 200 (Hub) + 750 (Game) = 950개 서버
→ Roblox가 자동 관리 ✓
```

---

## 9. 비용 고려

### Roblox 서버 비용
- **무료**: Roblox가 서버 호스팅 담당
- **개발자 부담**: 없음

### MemoryStoreService 제한
- 요청: 1000 + 100×(동접) 요청/분
- 10,000명: 1,001,000 요청/분 가능 ✓

### DataStoreService 제한
- 요청: 60 + 10×(동접) 요청/분
- 10,000명: 100,060 요청/분 가능 ✓

---

## 10. 결론 및 권장사항

### 즉시 구현 (현재 구조 유지)
```
현재: 단일 서버, 라운드 기반
장점: 단순함, 빠른 개발
단점: 서버당 50명 제한

→ 소규모 테스트에 적합
```

### 확장 구현 (Hub + Game Server)
```
목표: Hub + Reserved Game Servers
장점: 무한 확장, 전문적
단점: 개발 시간 필요 (2-4주)

→ 10,000+ 동접 목표 시 필수
```

### 권장 순서
1. 현재 구조로 게임 완성 및 테스트
2. 유저 피드백 수집
3. 인기 상승 시 Hub 구조로 마이그레이션
