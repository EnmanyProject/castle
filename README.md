# 🏰 Quiz Castle v3.2

Roblox 퀴즈 레이싱 게임

## 🚀 빠른 설치

### 1. Roblox Studio 열기
새 프로젝트 또는 기존 프로젝트 열기

### 2. 서버 스크립트 추가
1. `ServerScriptService` 우클릭 → Insert Object → Script
2. 이름: `Quizcastleserver` (소문자 권장)
3. `QuizCastleServer.lua` 내용 전체 복사 → 붙여넣기

### 3. 클라이언트 스크립트 추가
1. `StarterPlayer` → `StarterPlayerScripts` 우클릭 → Insert Object → LocalScript
2. 이름: `Quizcastleclient` (소문자 권장)
3. `QuizCastleClient.lua` 내용 전체 복사 → 붙여넣기

### 4. 테스트
F5 눌러서 플레이 테스트!

## 📁 파일 목록

| 파일 | 설명 |
|------|------|
| `QuizCastleServer.lua` | 서버 스크립트 |
| `QuizCastleClient.lua` | 클라이언트 스크립트 |
| `project.md` | 상세 프로젝트 문서 |
| `README.md` | 이 파일 |

## 🎮 조작법

- **WASD**: 이동
- **Space**: 점프
- **Q**: 아이템 사용

## ⚙️ 설정 변경

`QuizCastleServer.lua` 상단의 `Config` 테이블에서:
- `MIN_PLAYERS`: 최소 시작 인원 (기본: 1)
- `TRACK_LENGTH`: 트랙 길이 (기본: 2000)
- 각종 기믹 ON/OFF

## 📖 자세한 문서

`project.md` 파일 참고

---

*Made with Claude AI*
