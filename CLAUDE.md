# CLAUDE.md - Quiz Castle Project Context

## 프로젝트 요약
이 프로젝트는 **Roblox 퀴즈 레이싱 게임**입니다. 플레이어가 장애물 코스를 달리며 퀴즈 게이트를 통과하는 게임입니다.

## 파일 구조
```
castle/
├── QuizCastleServer.lua   # 서버 스크립트 (Roblox ServerScriptService)
├── QuizCastleClient.lua   # 클라이언트 스크립트 (Roblox StarterPlayerScripts)
├── project.md             # 상세 프로젝트 문서
├── README.md              # 설치 가이드
└── CLAUDE.md              # 이 파일
```

## 기술 스택
- **플랫폼**: Roblox
- **언어**: Lua (Luau)
- **아키텍처**: 서버-클라이언트 분리

## 핵심 개념

### RemoteEvents (서버↔클라이언트 통신)
- `GameEvent`: 게임 상태 이벤트
- `RoundUpdate`: 라운드 진행 (Countdown, RaceStart, RoundEnd)
- `GateQuiz`: 퀴즈 문제 전송
- `ItemEffect`: 아이템 효과
- `TimeUpdate`: 타이머 동기화
- `LobbyUpdate`: 로비 상태
- `XPUpdate`, `LevelUp`: 경험치/레벨

### 게임 플로우
`Waiting` → `Countdown` → `Racing` → `Ended` → `Waiting`

### 주요 기믹
1. **퀴즈 게이트**: 정답 문 통과 필요
2. **엘리베이터 퀴즈**: 정답 플랫폼이 빨리 올라감
3. **컨베이어 벨트**: 뒤로 밀림
4. **장애물들**: 스윙바, 펀칭글러브, 전기바닥, 바위, 용암

### 아이템 시스템
- Booster (속도 증가)
- Shield (보호막)
- Banana (함정)
- Lightning (전체 스턴)

## 코드 수정 시 주의

### 이벤트 형식 일치
서버에서 보내는 형식과 클라이언트에서 받는 형식이 일치해야 함:
```lua
-- 서버
Events.ItemEffect:FireClient(player, "GotItem", {itemType = "Booster"})

-- 클라이언트
Events.ItemEffect.OnClientEvent:Connect(function(action, data)
    if action == "GotItem" then
        -- data.itemType 사용
    end
end)
```

### UI 요소 참조
클라이언트에서 UI 요소들은 스크립트 상단에서 생성됨:
- `raceTimer`, `raceInfo`, `leaderboardFrame`
- `lobbyFrame`, `lobbyStatus`, `lobbyCountdown`
- `quizContainer`, `quizQuestion`, `quizOptions`
- `itemSlot`, `itemIcon`

## 자주 발생하는 버그 패턴

1. **이벤트 키 불일치**: 서버가 `playersInLobby` 보내는데 클라이언트가 `playerCount` 찾음
2. **nil 체크 누락**: `data.something` 접근 전 `data` 존재 확인 필요
3. **Visible 상태 관리**: UI 표시/숨김 타이밍 확인

## 테스트 방법
1. Roblox Studio에서 F5로 플레이 테스트
2. Output 창에서 로그 확인
3. 서버 로그: `🏰 Quiz Castle v3.2 Ready!`
4. 클라이언트 로그: `✅ Quiz Castle v3.2 Client Ready!`

## 문서 참조
더 자세한 정보는 `project.md` 파일 참고
