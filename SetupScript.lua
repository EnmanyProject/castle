-- ============================================
-- 🔧 QUIZ CASTLE SETUP SCRIPT
-- ============================================
-- 이 스크립트를 ServerScriptService에 넣고 게임을 실행하면
-- 필요한 모든 폴더와 이벤트가 자동으로 생성됩니다.
-- 설정 완료 후 이 스크립트는 삭제해도 됩니다.
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔧 Quiz Castle Setup Script Starting...")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ============================================
-- 1. Events 폴더 및 RemoteEvents 생성
-- ============================================
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
    eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "Events"
    eventsFolder.Parent = ReplicatedStorage
    print("📁 Created: ReplicatedStorage/Events")
else
    print("📁 Found existing: ReplicatedStorage/Events")
end

local eventNames = {
    -- 게임 이벤트
    "GameEvent",
    "RoundUpdate",
    "GateQuiz",
    "ItemEffect",
    "TimeUpdate",
    "LobbyUpdate",

    -- 레벨/XP 시스템
    "XPUpdate",
    "LevelUp",

    -- 아이템 시스템
    "UseItem",

    -- 관리자 시스템
    "AdminCommand",
    "ConfigUpdate"
}

local createdEvents = 0
local existingEvents = 0

for _, eventName in ipairs(eventNames) do
    if not eventsFolder:FindFirstChild(eventName) then
        local event = Instance.new("RemoteEvent")
        event.Name = eventName
        event.Parent = eventsFolder
        createdEvents = createdEvents + 1
    else
        existingEvents = existingEvents + 1
    end
end

print(string.format("📡 RemoteEvents: %d created, %d already existed", createdEvents, existingEvents))

-- ============================================
-- 2. CourseLibrary 폴더 생성
-- ============================================
local libraryFolder = ReplicatedStorage:FindFirstChild("CourseLibrary")
if not libraryFolder then
    libraryFolder = Instance.new("Folder")
    libraryFolder.Name = "CourseLibrary"
    libraryFolder.Parent = ReplicatedStorage
    print("📁 Created: ReplicatedStorage/CourseLibrary")
else
    print("📁 Found existing: ReplicatedStorage/CourseLibrary")
end

-- ============================================
-- 3. 게임 맵 기본 구조 생성
-- ============================================
local mapFolder = Workspace:FindFirstChild("Map")
if not mapFolder then
    mapFolder = Instance.new("Folder")
    mapFolder.Name = "Map"
    mapFolder.Parent = Workspace
    print("📁 Created: Workspace/Map")
end

-- 로비 영역
local lobby = mapFolder:FindFirstChild("Lobby")
if not lobby then
    lobby = Instance.new("Part")
    lobby.Name = "Lobby"
    lobby.Size = Vector3.new(60, 1, 60)
    lobby.Position = Vector3.new(0, 0, -50)
    lobby.Anchored = true
    lobby.BrickColor = BrickColor.new("Medium stone grey")
    lobby.Material = Enum.Material.SmoothPlastic
    lobby.Parent = mapFolder
    print("🏠 Created: Lobby platform")
end

-- 로비 스폰 위치
local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
if not lobbySpawn then
    lobbySpawn = Instance.new("SpawnLocation")
    lobbySpawn.Name = "LobbySpawn"
    lobbySpawn.Size = Vector3.new(6, 1, 6)
    lobbySpawn.Position = Vector3.new(0, 1, -50)
    lobbySpawn.Anchored = true
    lobbySpawn.Neutral = true
    lobbySpawn.Parent = Workspace
    print("🚩 Created: LobbySpawn")
end

-- 레이스 스타트 위치 (스폰이 아닌 일반 파트)
local raceStart = Workspace:FindFirstChild("RaceStart")
if not raceStart then
    raceStart = Instance.new("Part")
    raceStart.Name = "RaceStart"
    raceStart.Size = Vector3.new(30, 1, 10)
    raceStart.Position = Vector3.new(0, 0, 20)  -- 로비에서 떨어진 위치
    raceStart.Anchored = true
    raceStart.Transparency = 0.5
    raceStart.BrickColor = BrickColor.new("Bright green")
    raceStart.Material = Enum.Material.Neon
    raceStart.CanCollide = true
    raceStart.Parent = Workspace
    print("🏁 Created: RaceStart")
end

-- 기존 SpawnLocation 제거 (기본 스폰 제거)
for _, obj in ipairs(Workspace:GetChildren()) do
    if obj:IsA("SpawnLocation") and obj.Name ~= "LobbySpawn" then
        obj:Destroy()
        print("🗑️ Removed extra SpawnLocation:", obj.Name)
    end
end

-- 트랙 (기본 바닥)
local track = mapFolder:FindFirstChild("Track")
if not track then
    track = Instance.new("Part")
    track.Name = "Track"
    track.Size = Vector3.new(30, 1, 2000)
    track.Position = Vector3.new(0, -0.5, 1000)
    track.Anchored = true
    track.BrickColor = BrickColor.new("Dark stone grey")
    track.Material = Enum.Material.Concrete
    track.Parent = mapFolder
    print("🛤️ Created: Race track (2000 studs)")
end

-- 피니시 라인
local finishLine = Workspace:FindFirstChild("FinishLine")
if not finishLine then
    finishLine = Instance.new("Part")
    finishLine.Name = "FinishLine"
    finishLine.Size = Vector3.new(30, 10, 2)
    finishLine.Position = Vector3.new(0, 5, 2000)
    finishLine.Anchored = true
    finishLine.Transparency = 0.5
    finishLine.BrickColor = BrickColor.new("Bright yellow")
    finishLine.Material = Enum.Material.Neon
    finishLine.CanCollide = false
    finishLine.Parent = Workspace
    print("🎯 Created: FinishLine")
end

-- 기믹 폴더
local gimmicks = mapFolder:FindFirstChild("Gimmicks")
if not gimmicks then
    gimmicks = Instance.new("Folder")
    gimmicks.Name = "Gimmicks"
    gimmicks.Parent = mapFolder
    print("📁 Created: Workspace/Map/Gimmicks")
end

-- ============================================
-- 4. HttpService 확인
-- ============================================
local HttpService = game:GetService("HttpService")
local httpEnabled = false

local success, result = pcall(function()
    -- 테스트 요청 (실패해도 괜찮음)
    return HttpService.HttpEnabled
end)

if success then
    httpEnabled = result
end

if httpEnabled then
    print("🌐 HttpService: ENABLED ✅")
else
    warn("⚠️ HttpService: DISABLED")
    warn("   Game Settings → Security → Allow HTTP Requests 를 활성화하세요!")
end

-- ============================================
-- 5. 설정 완료 메시지
-- ============================================
print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ SETUP COMPLETE!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")
print("📋 생성된 구조:")
print("   ReplicatedStorage/")
print("   ├── Events/ (RemoteEvents)")
print("   └── CourseLibrary/")
print("")
print("   Workspace/")
print("   ├── Map/")
print("   │   ├── Lobby")
print("   │   ├── Track")
print("   │   └── Gimmicks/")
print("   ├── LobbySpawn")
print("   ├── RaceStart")
print("   └── FinishLine")
print("")
print("📝 다음 단계:")
print("   1. ServerScriptService에 QuizCastleServer 스크립트 추가")
print("   2. StarterPlayerScripts에 QuizCastleClient 스크립트 추가")
print("   3. HttpService 활성화 확인")
print("   4. 게임 실행 (F5)")
print("")
print("💡 이 SetupScript는 삭제해도 됩니다!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
