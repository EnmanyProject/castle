# 🏰 Quiz Castle v3.2 - Roblox Game Project

## 📋 프로젝트 개요

**Quiz Castle**은 Roblox 플랫폼용 퀴즈 레이싱 게임입니다. 플레이어들이 장애물 코스를 달리면서 퀴즈 게이트를 통과하고, 정답을 맞춰야 빠르게 진행할 수 있습니다.

### 게임 컨셉
- **장르**: Racing + Trivia + Obby
- **플레이어 수**: 1~20명
- **게임 방식**: 시간 제한 없이 결승선까지 도달하는 레이스
- **핵심 기믹**: 퀴즈 게이트 (정답 문으로 통과해야 함)

---

## 📁 파일 구조

```
C:\Users\dosik\castle\
├── project.md              # 이 문서 (프로젝트 설명)
├── QuizCastleServer.lua    # 서버 스크립트 (ServerScriptService)
├── QuizCastleClient.lua    # 클라이언트 스크립트 (StarterPlayerScripts)
└── README.md               # 간단한 설치 가이드
```

### Roblox Studio 배치 위치
| 파일 | Roblox Studio 위치 |
|------|-------------------|
| `QuizCastleServer.lua` | `ServerScriptService` → Script |
| `QuizCastleClient.lua` | `StarterPlayer` → `StarterPlayerScripts` → LocalScript |

---

## 🖥️ 서버 스크립트 (QuizCastleServer.lua)

### 주요 기능

#### 1. 설정 (Config)
```lua
local Config = {
    TRACK_LENGTH = 2000,        -- 트랙 총 길이
    TRACK_WIDTH = 40,           -- 트랙 너비
    MIN_PLAYERS = 1,            -- 최소 시작 인원
    LOBBY_COUNTDOWN = 10,       -- 로비 카운트다운(초)
    
    -- 기믹 ON/OFF
    EnableQuizGates = true,     -- 퀴즈 게이트
    EnableElevators = true,     -- 엘리베이터 퀴즈
    EnableMovingObstacles = true,
    EnableSwingingBars = true,
    EnablePunchingGloves = true,
    EnableConveyorBelt = true,
    EnableElectricFloor = true,
    EnableFallingBoulders = true,
    EnableLavaZone = true,
    EnableItemBoxes = true,
}
```

#### 2. XP & 레벨 시스템
- 10단계 레벨 (Rookie → Legend)
- 퀴즈 정답: +15 XP
- 레이스 완주: +50 XP
- 1등: +100 XP
- 레벨별 트레일 이펙트 (먼지, 별, 불꽃, 번개, 무지개 등)

#### 3. RemoteEvents (서버 ↔ 클라이언트 통신)
```lua
-- 서버가 생성하는 이벤트들
RemoteEvents/
├── GameEvent       -- 일반 게임 이벤트 (InitPlayer, Finished 등)
├── TimeUpdate      -- 타이머 업데이트
├── LeaderboardUpdate -- 순위표 업데이트
├── GateQuiz        -- 퀴즈 문제 전송
├── UseItem         -- 아이템 사용 요청 (클라→서버)
├── ItemEffect      -- 아이템 효과 (서버→클라)
├── RoundUpdate     -- 라운드 상태 (Countdown, RaceStart, RoundEnd)
├── LobbyUpdate     -- 로비 상태 (플레이어 수, 페이즈)
├── XPUpdate        -- XP 변경 알림
├── LevelUp         -- 레벨업 알림
└── TrailUpdate     -- 트레일 변경
```

#### 4. 게임 기믹들

##### 퀴즈 게이트 (CreateQuizGate)
- 2~4개 선택지 문제
- 색상별 게이트 (빨강, 파랑, 초록, 노랑)
- 정답 게이트: 통과 + XP
- 오답 게이트: 뒤로 밀려남 + 1.2초 스턴

##### 엘리베이터 퀴즈 (CreateElevator)
- 3~4개 플랫폼 중 정답 선택
- 정답 플랫폼: 빠르게 상승 (1.5초)
- 오답 플랫폼: 느리게 상승 (4초)
- 5초 대기 후 플랫폼 작동

##### 기타 장애물
- **SwingingBars**: 좌우로 흔들리는 막대
- **PunchingGloves**: 주기적으로 펀치하는 글러브
- **ConveyorBelt**: 뒤로 밀리는 컨베이어 (속도: 0.02/프레임)
- **ElectricFloor**: 주기적으로 전기 충격
- **FallingBoulders**: 떨어지는 바위
- **LavaZone**: 용암 낙하 구간

##### 아이템 박스
- **Booster**: 4.5초 속도 증가
- **Shield**: 14초 보호막
- **Banana**: 뒤에 설치, 밟으면 스턴
- **Lightning**: 다른 플레이어 전원 스턴

#### 5. 게임 플로우
```
Waiting (로비 대기)
    ↓ (MIN_PLAYERS 이상)
Countdown (10초 카운트다운)
    ↓
Racing (레이스 진행)
    ↓ (모든 플레이어 완주 또는 제한시간)
Ended (결과 표시)
    ↓ (5초 후)
Waiting (다시 로비)
```

#### 6. 플레이어 데이터 (PlayerData)
```lua
PlayerData[player] = {
    bestTime = nil,           -- 최고 기록
    wins = 0,                 -- 승리 횟수
    xp = 0,                   -- 현재 XP
    level = 1,                -- 현재 레벨
    currentItem = nil,        -- 보유 아이템
    lastRaceTime = nil,       -- 최근 레이스 시간
    lastSafePosition = nil,   -- 마지막 안전 위치 (리스폰용)
    isInvincible = false,     -- 무적 상태
}
```

#### 7. Out of Bounds 시스템
- Y < -50 또는 트랙 범위 이탈 시 감지
- 마지막 안전 위치로 리스폰
- 2초 무적 시간 부여

---

## 🎮 클라이언트 스크립트 (QuizCastleClient.lua)

### 주요 기능

#### 1. UI 요소들
```
ScreenGui/
├── LevelFrame (좌상단)
│   ├── 레벨 아이콘
│   ├── 레벨 이름
│   └── XP 바
│
├── RaceTimer (상단 중앙)
│   └── ⏱️ 00:00.00
│
├── RaceInfo (타이머 아래)
│   └── 🏃 1st | 📍 0%
│
├── LeaderboardFrame (우측)
│   └── 🏆 TOP 10 순위표
│
├── LobbyFrame (중앙, 대기 시)
│   ├── QUIZ CASTLE 타이틀
│   ├── Waiting for players...
│   ├── 카운트다운
│   └── 👥 Players: N
│
├── QuizContainer (중앙, 퀴즈 시)
│   ├── 문제 텍스트
│   └── 선택지 버튼들 (색상별)
│
├── ProgressContainer (하단)
│   └── 진행도 바
│
├── ItemSlot (좌하단)
│   ├── 아이템 아이콘
│   └── [Q] 힌트
│
├── EffectMessage (중앙)
│   └── 이펙트 메시지 (CORRECT!, WRONG! 등)
│
└── TitleBanner (상단)
    └── 배너 메시지 (GO!, RACE COMPLETE! 등)
```

#### 2. 이벤트 핸들러

##### GameEvent
- `InitPlayer`: 초기화 (레벨, XP, 설정 등)
- `Finished`: 완주 시 결과 표시
- `GateCorrect/GateWrong`: 퀴즈 정답/오답
- `Stunned/Slowed/SpeedBoost`: 상태 효과

##### RoundUpdate
- `Countdown`: 카운트다운 표시
- `RaceStart`: 레이스 시작 (UI 전환)
- `RoundEnd`: 레이스 종료
- `PlayerFinished`: 다른 플레이어 완주 알림

##### GateQuiz
- 퀴즈 문제 수신 및 UI 표시
- `data.question`: 문제 텍스트
- `data.options`: 선택지 배열
- `data.colors`: 게이트 색상 배열

##### ItemEffect
- `GotItem`: 아이템 획득
- `ItemUsed`: 아이템 사용됨
- `SpeedBoost/Shielded`: 버프 효과
- `Stun/LightningHit`: 디버프 효과

##### TimeUpdate
- 숫자 또는 테이블 형태로 시간 수신
- 타이머 UI 업데이트

##### LobbyUpdate
- `playersInLobby`: 현재 대기 인원
- `phase`: 게임 페이즈
- `countdown`: 카운트다운

#### 3. 입력 처리
- **Q키**: 아이템 사용

#### 4. UI 스타일
- 배경 투명화 (BackgroundTransparency)
- 텍스트 외곽선 (TextStrokeTransparency = 0)
- 최소한의 프레임/박스
- 게임 화면이 잘 보이도록 설계

---

## 🧩 퀴즈 데이터 구조

### 퀴즈 형식
```lua
{
    q = "문제 텍스트",
    o = {"선택지1", "선택지2", "선택지3", "선택지4"},
    a = 정답_인덱스  -- 1~4
}
```

### 예시
```lua
{q = "대한민국의 수도는?", o = {"부산", "서울", "대구", "인천"}, a = 2}
{q = "1 + 1 = ?", o = {"1", "2", "3"}, a = 2}
{q = "태양계에서 가장 큰 행성은?", o = {"지구", "화성", "목성", "토성"}, a = 3}
```

### 퀴즈 카테고리 (서버 내장)
- 수학 문제
- 상식 문제
- 과학 문제
- 한국어/영어 문제

---

## 🎨 색상 체계

### 퀴즈 게이트 색상
```lua
local gateColors = {
    Color3.fromRGB(255, 80, 80),   -- [1] 빨강
    Color3.fromRGB(80, 150, 255),  -- [2] 파랑
    Color3.fromRGB(80, 255, 80),   -- [3] 초록
    Color3.fromRGB(255, 255, 80),  -- [4] 노랑
}
```

### 레벨 색상
| 레벨 | 이름 | 아이콘 | 트레일 |
|------|------|--------|--------|
| 1 | Rookie | ⬜ | 없음 |
| 2 | Runner | 💨 | 먼지 |
| 3 | Star Walker | ⭐ | 별 |
| 4 | Sparkle | ✨ | 반짝임 |
| 5 | Blazer | 🔥 | 불꽃 |
| 6 | Frost | ❄️ | 얼음 |
| 7 | Thunder | ⚡ | 번개 |
| 8 | Rainbow | 🌈 | 무지개 |
| 9 | Royal | 👑 | 로열 |
| 10 | Legend | 🐉 | 레전드 |

---

## 🗺️ 트랙 레이아웃

```
Z 좌표 기준 (시작 0 → 끝 2000)

0-100:      로비 영역 (Z = -100)
0-400:      첫 번째 구간 (장애물 없음)
400-600:    퀴즈 게이트 #1 (2지선다)
600-700:    엘리베이터 #1 (3지선다)
700-1000:   장애물 구간 (Swinging Bars, Punching Gloves)
1000-1100:  컨베이어 벨트
1100-1300:  퀴즈 게이트 #2 (3지선다)
1300-1500:  전기 바닥 + 떨어지는 바위
1500-1600:  엘리베이터 #2 (4지선다)
1600-1800:  용암 구간
1800-1900:  퀴즈 게이트 #3 (4지선다)
1900-2000:  결승선
```

---

## 🐛 알려진 이슈 및 해결 상태

| 이슈 | 상태 | 설명 |
|------|------|------|
| 이중 클라이언트 | ✅ 해결 | 스크립트 이름 통일 필요 |
| TimeUpdate 에러 | ✅ 해결 | 숫자/테이블 둘 다 처리 |
| Players: 0 | ✅ 해결 | playersInLobby 키 사용 |
| 퀴즈 안 나옴 | ✅ 해결 | data.question 체크 |
| 카운트다운 중복 | ✅ 해결 | ShowBanner 제거 |
| 아이템 UI | ✅ 해결 | GotItem/ItemUsed 이벤트 |
| 컨베이어 너무 빠름 | ✅ 해결 | 속도 0.02로 감소 |

---

## 🚀 향후 개선 아이디어

### 기능 추가
- [ ] 커스텀 퀴즈 추가 기능
- [ ] 멀티플레이어 대전 모드
- [ ] 일일 챌린지
- [ ] 스킨/코스튬 시스템
- [ ] 친구 초대 보너스

### UI 개선
- [ ] 설정 메뉴
- [ ] 사운드 ON/OFF
- [ ] 언어 선택 (한국어/영어)

### 밸런스
- [ ] 장애물 난이도 조절
- [ ] XP 획득량 조절
- [ ] 아이템 밸런스

---

## 📝 코드 수정 시 주의사항

### 서버 스크립트 수정 시
1. RemoteEvent 이름 변경 시 클라이언트도 함께 수정
2. 이벤트 데이터 형식 변경 시 클라이언트 핸들러 확인
3. Config 변경은 게임 밸런스에 직접 영향

### 클라이언트 스크립트 수정 시
1. UI 요소 이름/위치 변경 시 참조 확인
2. 이벤트 핸들러 수정 시 서버 전송 형식 확인
3. Visible 상태 관리 주의

### 퀴즈 추가 시
```lua
-- QuizData 테이블에 추가
table.insert(QuizData, {
    q = "새 문제",
    o = {"선택지1", "선택지2", "선택지3"},
    a = 정답번호
})
```

---

## 🔧 디버깅 팁

### 서버 로그 확인
```
🏰 Quiz Castle v3.2 Loading...
✅ RemoteEvents Created
🏰 Building Quiz Castle v3.2...
🏰 Quiz Castle v3.2 Ready!
```

### 클라이언트 로그 확인
```
🎮 Quiz Castle Client: Waiting for server...
🎮 Quiz Castle v3.2 Client Loading...
✅ Quiz Castle v3.2 Client Ready!
```

### 이벤트 디버깅
서버에서 print 추가:
```lua
print("Sending GateQuiz to", player.Name, "gateId:", gateId)
```

클라이언트에서 print 추가:
```lua
print("Received GateQuiz:", data.question)
```

---

## 📞 문의 및 지원

이 프로젝트는 Claude AI와 함께 개발되었습니다.
추가 기능이나 버그 수정이 필요하면 대화를 통해 요청하세요!

---

*최종 업데이트: 2026-01-09*
*버전: 3.2*
