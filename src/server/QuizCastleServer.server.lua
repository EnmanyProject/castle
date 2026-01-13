--[[
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🏰 QUIZ CASTLE v3.2 - SERVER SCRIPT                         ║
║                                                                                ║
║  📁 ServerScriptService에 "Script"로 넣으세요!                                  ║
║                                                                                ║
║  🆕 v3.2 CHANGES:                                                              ║
║     - 엘리베이터: 5초 대기 (퀴즈 확인 시간)                                      ║
║     - 2층 바닥: 틈 없이 완전히 막음                                              ║
║     - 펀칭 글러브: 속도 감소 효과 (번개처럼)                                     ║
║     - 리스폰 시스템: 트랙 이탈 시 자동 복귀                                       ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
]]

-- 서비스 안전하게 로드
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- 서비스 로드 확인
if not ReplicatedStorage then
    warn("⚠️ ReplicatedStorage not found!")
    return
end

print("🏰 Quiz Castle v3.2 Loading...")

-- ============================================
-- 🗑️ Roblox 기본 SpawnLocation 즉시 삭제!
-- ============================================
local Workspace = game:GetService("Workspace")

-- 기존 SpawnLocation 모두 제거 (우리가 만드는 것 제외)
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("SpawnLocation") then
        print("🗑️ Removing default SpawnLocation:", obj.Name, "at", obj.Position)
        obj:Destroy()
    end
end

-- 새로 생기는 SpawnLocation 감시 및 제거 (LobbySpawn 제외)
Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("SpawnLocation") and obj.Name ~= "LobbySpawn" then
        task.defer(function()
            if obj and obj.Parent then
                print("🗑️ Auto-removing SpawnLocation:", obj.Name)
                obj:Destroy()
            end
        end)
    end
end)

-- ============================================
-- 🎯 스폰 시스템 (근본적 재설계)
-- ============================================
-- 🗺️ 맵 레이아웃 (재설계 v2)
-- 로비(스폰) → 출발게이트 → 레이스코스
-- ============================================

-- 레이아웃 상수
local LOBBY_Z = -30         -- 로비/스폰 중심
local GATE_Z = 25           -- 출발 게이트 위치
local COURSE_START_Z = 30   -- 코스 시작 Z 위치
local COURSE_OFFSET = 30    -- 기믹 Z 좌표에 더해질 오프셋

print("✅ Layout: Lobby(Z=-30) → Gate(Z=25) → Course(Z=30+)")

local BestTimeStore, LeaderboardStore, WinsStore, XPStore
pcall(function()
    BestTimeStore = DataStoreService:GetDataStore("QuizCastleV3_BestTimes")
    LeaderboardStore = DataStoreService:GetOrderedDataStore("QuizCastleV3_Leaderboard")
    WinsStore = DataStoreService:GetDataStore("QuizCastleV3_Wins")
    XPStore = DataStoreService:GetDataStore("QuizCastleV3_XP")
end)

-- ============================================
-- 📚 COURSE MANAGER SYSTEM
-- ============================================
local CourseManager = {
    currentCourse = nil,
    courseLibrary = {},

    -- GitHub Pages URL (웹 에디터에서 만든 코스 로드)
    GITHUB_BASE_URL = "https://enmanyproject.github.io/castle/courses/",
    COURSES_INDEX_URL = "https://enmanyproject.github.io/castle/courses.json",

    -- Auto-sync settings
    autoSyncEnabled = true,
    pollInterval = 30,  -- seconds
    lastKnownVersion = nil,
    lastCheckedTime = 0,
    isPolling = false
}

-- 로컬 라이브러리에서 코스 로드
function CourseManager:LoadLibrary()
    local libraryFolder = ReplicatedStorage:FindFirstChild("CourseLibrary")
    if not libraryFolder then
        warn("📚 CourseLibrary folder not found in ReplicatedStorage")
        return
    end

    for _, module in ipairs(libraryFolder:GetChildren()) do
        if module:IsA("ModuleScript") then
            local success, courseData = pcall(function()
                return require(module)
            end)

            if success and courseData and courseData.metadata then
                local id = courseData.metadata.id or module.Name
                self.courseLibrary[id] = courseData
                print(string.format("📚 Loaded course: %s (%s)", courseData.metadata.name, id))
            else
                warn("📚 Failed to load course module:", module.Name)
            end
        end
    end
end

-- 라이브러리에서 코스 가져오기
function CourseManager:GetCourse(courseId)
    return self.courseLibrary[courseId]
end

-- 사용 가능한 코스 목록
function CourseManager:GetAvailableCourses()
    local courses = {}
    for id, course in pairs(self.courseLibrary) do
        table.insert(courses, {
            id = id,
            name = course.metadata.name,
            author = course.metadata.author,
            difficulty = course.metadata.difficulty,
            description = course.metadata.description or ""
        })
    end
    return courses
end

-- GitHub에서 코스 로드 (JSON)
function CourseManager:LoadFromGitHub(courseId)
    local url = self.GITHUB_BASE_URL .. courseId .. ".json"

    local success, result = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if not success then
        warn("🌐 Failed to fetch course from GitHub:", result)
        return nil
    end

    local parseSuccess, courseData = pcall(function()
        return HttpService:JSONDecode(result)
    end)

    if not parseSuccess then
        warn("🌐 Failed to parse course JSON:", parseSuccess)
        return nil
    end

    print(string.format("🌐 Loaded course from GitHub: %s", courseData.metadata.name))
    return courseData
end

-- GitHub에서 코스 목록 가져오기
function CourseManager:FetchGitHubCourseList()
    local success, result = pcall(function()
        return HttpService:GetAsync(self.COURSES_INDEX_URL)
    end)

    if not success then
        warn("🌐 Failed to fetch course list:", result)
        return nil
    end

    local parseSuccess, indexData = pcall(function()
        return HttpService:JSONDecode(result)
    end)

    if parseSuccess and indexData then
        return indexData.webCourses or {}
    end

    return nil
end

-- 현재 코스 설정
function CourseManager:SetCurrentCourse(courseId, source)
    source = source or "library"

    if source == "library" then
        local course = self:GetCourse(courseId)
        if course then
            self.currentCourse = course
            print(string.format("✅ Course set: %s (from library)", course.metadata.name))
            return true
        end
    elseif source == "github" then
        local course = self:LoadFromGitHub(courseId)
        if course then
            self.currentCourse = course
            print(string.format("✅ Course set: %s (from GitHub)", course.metadata.name))
            return true
        end
    end

    warn("❌ Failed to set course:", courseId)
    return false
end

-- 현재 코스 가져오기 (없으면 기본 코스)
function CourseManager:GetCurrentCourse()
    if self.currentCourse then
        return self.currentCourse
    end

    -- 기본 코스 (classic)
    return self:GetCourse("classic")
end

-- GitHub 업데이트 확인
function CourseManager:CheckForUpdates()
    local success, result = pcall(function()
        return HttpService:GetAsync(self.COURSES_INDEX_URL .. "?t=" .. os.time())
    end)

    if not success then
        return false, nil
    end

    local parseSuccess, indexData = pcall(function()
        return HttpService:JSONDecode(result)
    end)

    if not parseSuccess or not indexData then
        return false, nil
    end

    local currentVersion = indexData.lastUpdated or indexData.version or "unknown"

    -- 첫 체크인 경우 버전만 저장
    if not self.lastKnownVersion then
        self.lastKnownVersion = currentVersion
        print("🔄 Auto-sync initialized. Version:", currentVersion)
        return false, nil
    end

    -- 버전이 변경됨
    if currentVersion ~= self.lastKnownVersion then
        local oldVersion = self.lastKnownVersion
        self.lastKnownVersion = currentVersion
        print(string.format("🔄 Update detected! %s → %s", oldVersion, currentVersion))
        return true, indexData
    end

    return false, nil
end

-- 업데이트 시 코스 새로고침
function CourseManager:ApplyUpdate(indexData)
    local updatedCourses = {}

    -- webCourses에서 변경된 코스 로드
    if indexData.webCourses then
        for _, webCourse in ipairs(indexData.webCourses) do
            local courseData = self:LoadFromGitHub(webCourse.id)
            if courseData then
                self.courseLibrary[webCourse.id] = courseData
                table.insert(updatedCourses, webCourse.id)
            end
        end
    end

    return updatedCourses
end

-- 관리자들에게 알림 전송
function CourseManager:NotifyAdmins(message, data)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == game.CreatorId or table.find(Admins, player.UserId) then
            Events.AdminCommand:FireClient(player, "AutoSyncNotify", {
                message = message,
                data = data,
                timestamp = os.time()
            })
        end
    end
end

-- 자동 동기화 시작
function CourseManager:StartAutoSync()
    if self.isPolling then
        return
    end

    self.isPolling = true
    print("🔄 Auto-sync started (interval: " .. self.pollInterval .. "s)")

    task.spawn(function()
        while self.isPolling and self.autoSyncEnabled do
            task.wait(self.pollInterval)

            local hasUpdate, indexData = self:CheckForUpdates()

            if hasUpdate and indexData then
                local updatedCourses = self:ApplyUpdate(indexData)

                if #updatedCourses > 0 then
                    local message = string.format("🔄 GitHub에서 %d개 코스 업데이트됨: %s",
                        #updatedCourses, table.concat(updatedCourses, ", "))
                    print(message)
                    self:NotifyAdmins(message, {
                        courses = updatedCourses,
                        version = self.lastKnownVersion
                    })
                end
            end

            self.lastCheckedTime = os.time()
        end
    end)
end

-- 자동 동기화 중지
function CourseManager:StopAutoSync()
    self.isPolling = false
    print("🔄 Auto-sync stopped")
end

-- 자동 동기화 상태 토글
function CourseManager:ToggleAutoSync()
    if self.autoSyncEnabled then
        self.autoSyncEnabled = false
        self:StopAutoSync()
    else
        self.autoSyncEnabled = true
        self:StartAutoSync()
    end
    return self.autoSyncEnabled
end

-- ============================================
-- ⭐ LEVEL SYSTEM CONFIGURATION
-- ============================================
local LevelConfig = {
    [1]  = {xp = 0,    name = "Rookie",      icon = "⬜", trailType = "None"},
    [2]  = {xp = 100,  name = "Runner",      icon = "💨", trailType = "Dust"},
    [3]  = {xp = 300,  name = "Star Walker", icon = "⭐", trailType = "Stars"},
    [4]  = {xp = 600,  name = "Sparkle",     icon = "✨", trailType = "Sparkle"},
    [5]  = {xp = 1000, name = "Blazer",      icon = "🔥", trailType = "Fire"},
    [6]  = {xp = 1500, name = "Frost",       icon = "❄️", trailType = "Ice"},
    [7]  = {xp = 2200, name = "Thunder",     icon = "⚡", trailType = "Lightning"},
    [8]  = {xp = 3000, name = "Rainbow",     icon = "🌈", trailType = "Rainbow"},
    [9]  = {xp = 4000, name = "Royal",       icon = "👑", trailType = "Royal"},
    [10] = {xp = 5500, name = "Legend",      icon = "🐉", trailType = "Legend"},
}

local XPRewards = {
    RaceComplete = 30,
    FirstPlace = 100,
    SecondPlace = 50,
    ThirdPlace = 25,
    QuizCorrect = 5,
    DailyFirst = 50,
    StreakBonus = 30,
}

-- ============================================
-- 🎛️ GAME CONFIGURATION
-- ============================================
local Config = {
    TRACK_LENGTH = 2000,
    TRACK_WIDTH = 40,
    MIN_PLAYERS = 1,
    MAX_PLAYERS = 50,
    LOBBY_COUNTDOWN = 15,
    INTERMISSION = 20,
    
    EnableRotatingBars = true,
    EnableJumpPads = true,
    EnableSlime = true,
    EnablePunchingGloves = true,
    EnableQuizGates = true,
    EnableElevators = true,
    EnableDisappearingBridge = true,
    EnableConveyorBelt = true,
    EnableElectricFloor = true,
    EnableRollingBoulder = true,
    EnableSequencePuzzle = false,
    
    ObstacleSpeed = 1.0,
    SlimeSlowFactor = 0.4,
}

local Admins = {}

local GameState = {
    phase = "Waiting",
    roundNumber = 0,
    playersInRace = {},
    finishedPlayers = {},
    countdown = 0,
    raceStartTime = 0,
    sessionLocked = false,  -- 5초 후 새 입장 차단
}

local PlayerData = {}
local PlayerGateAnswers = {}
local ActiveGimmicks = {}
local PlayerStreaks = {}

-- ============================================
-- 🚀 RACE SPEED BOOST SYSTEM
-- ============================================
local PlayerSpeedBoost = {}  -- 플레이어별 속도 배율 (100 = 기본, 110 = +10%, etc.)
local BASE_WALK_SPEED = 16   -- Roblox 기본 WalkSpeed

-- 속도 배율 적용 함수
local function ApplySpeedBoost(player, deltaPercent)
    if not PlayerSpeedBoost[player] then
        PlayerSpeedBoost[player] = 100
    end

    local newBoost = PlayerSpeedBoost[player] + deltaPercent

    -- 100% 이하로 내려가지 않음
    if newBoost < 100 then
        newBoost = 100
    end

    -- 최대 200%까지
    if newBoost > 200 then
        newBoost = 200
    end

    PlayerSpeedBoost[player] = newBoost

    -- 실제 WalkSpeed 적용
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = BASE_WALK_SPEED * (newBoost / 100)
        end
    end

    return newBoost
end

-- 속도 배율 리셋 함수
local function ResetSpeedBoost(player)
    PlayerSpeedBoost[player] = 100
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = BASE_WALK_SPEED
        end
    end
end

-- 현재 속도 배율 가져오기
local function GetSpeedBoost(player)
    return PlayerSpeedBoost[player] or 100
end

-- ============================================
-- 🔄 PERFORMANCE: 중앙 집중식 회전 오브젝트 관리
-- ============================================
local RotatingObjects = {}  -- {part, speed, rotation, rotationType}
local ItemBoxes = {}  -- {part, rotation}

-- ============================================
-- 🧩 GIMMICK REGISTRY SYSTEM
-- ============================================
local GimmickRegistry = {
    builders = {},   -- 기믹 생성 함수
    schemas = {},    -- 기믹 파라미터 스키마
    metadata = {}    -- 기믹 메타데이터 (이름, 아이콘, 난이도 등)
}

function GimmickRegistry:Register(config)
    local name = config.name
    self.schemas[name] = config.schema
    self.builders[name] = config.builder
    self.metadata[name] = {
        displayName = config.displayName or name,
        icon = config.icon or "❓",
        difficulty = config.difficulty or "medium",
        description = config.description or ""
    }
end

function GimmickRegistry:Build(gimmickType, parent, data)
    local builder = self.builders[gimmickType]
    if builder then
        return builder(parent, data)
    else
        warn("[GimmickRegistry] Unknown type:", gimmickType)
        return nil
    end
end

function GimmickRegistry:GetSchema(gimmickType)
    return self.schemas[gimmickType]
end

function GimmickRegistry:GetAllTypes()
    local types = {}
    for name, _ in pairs(self.builders) do
        table.insert(types, name)
    end
    return types
end

-- ============================================
-- REMOTE EVENTS
-- ============================================
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if remoteFolder then remoteFolder:Destroy() end
remoteFolder = Instance.new("Folder")
remoteFolder.Name = "RemoteEvents"
remoteFolder.Parent = ReplicatedStorage

local eventNames = {
    "GameEvent", "TimeUpdate", "LeaderboardUpdate", "GateQuiz",
    "UseItem", "ItemEffect", "AdminCommand", "ConfigUpdate",
    "RoundUpdate", "LobbyUpdate", "XPUpdate", "LevelUp", "TrailUpdate"
}

for _, name in ipairs(eventNames) do
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = remoteFolder
end

local Events = remoteFolder
print("✅ RemoteEvents Created")

-- ============================================
-- ⭐ XP & LEVEL FUNCTIONS
-- ============================================
local function GetLevelFromXP(xp)
    local level = 1
    for lv = 10, 1, -1 do
        if xp >= LevelConfig[lv].xp then
            level = lv
            break
        end
    end
    return level
end

local function GetLevelProgress(xp, level)
    if level >= 10 then return 1, 0, 0 end
    local currentLevelXP = LevelConfig[level].xp
    local nextLevelXP = LevelConfig[level + 1].xp
    local xpInLevel = xp - currentLevelXP
    local xpNeeded = nextLevelXP - currentLevelXP
    local progress = xpInLevel / xpNeeded
    return progress, xpInLevel, xpNeeded
end

local function SavePlayerXP(player, xp)
    pcall(function()
        if XPStore then XPStore:SetAsync(tostring(player.UserId), xp) end
    end)
end

local function LoadPlayerXP(player)
    local xp = 0
    pcall(function()
        if XPStore then xp = XPStore:GetAsync(tostring(player.UserId)) or 0 end
    end)
    return xp
end

local function AwardXP(player, amount, reason)
    if not PlayerData[player] then return end
    
    local oldXP = PlayerData[player].xp or 0
    local oldLevel = GetLevelFromXP(oldXP)
    
    local newXP = oldXP + amount
    PlayerData[player].xp = newXP
    
    local newLevel = GetLevelFromXP(newXP)
    PlayerData[player].level = newLevel
    
    local progress, xpInLevel, xpNeeded = GetLevelProgress(newXP, newLevel)
    Events.XPUpdate:FireClient(player, {
        xp = newXP,
        level = newLevel,
        levelName = LevelConfig[newLevel].name,
        levelIcon = LevelConfig[newLevel].icon,
        trailType = LevelConfig[newLevel].trailType,
        progress = progress,
        xpInLevel = xpInLevel,
        xpNeeded = xpNeeded,
        xpGained = amount,
        reason = reason
    })
    
    if newLevel > oldLevel then
        local levelInfo = LevelConfig[newLevel]
        Events.LevelUp:FireClient(player, {
            newLevel = newLevel,
            levelName = levelInfo.name,
            levelIcon = levelInfo.icon,
            trailType = levelInfo.trailType
        })
        
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                Events.GameEvent:FireClient(otherPlayer, "PlayerLevelUp", {
                    playerName = player.Name,
                    newLevel = newLevel,
                    levelIcon = levelInfo.icon
                })
            end
        end
        
        Events.TrailUpdate:FireAllClients({
            playerName = player.Name,
            trailType = levelInfo.trailType,
            level = newLevel
        })
    end
    
    task.spawn(function()
        SavePlayerXP(player, newXP)
    end)
    
    return newXP, newLevel
end

-- ============================================
-- DATA FUNCTIONS
-- ============================================
local function SavePlayerStats(player, time, rank)
    pcall(function()
        if not BestTimeStore then return end
        local timeMs = math.floor(time * 1000)
        local currentBest = BestTimeStore:GetAsync(tostring(player.UserId))
        if not currentBest or timeMs < currentBest then
            BestTimeStore:SetAsync(tostring(player.UserId), timeMs)
        end
        if LeaderboardStore then
            LeaderboardStore:SetAsync(tostring(player.UserId) .. "_" .. player.Name, timeMs)
        end
        if rank == 1 and WinsStore then
            local wins = WinsStore:GetAsync(tostring(player.UserId)) or 0
            WinsStore:SetAsync(tostring(player.UserId), wins + 1)
        end
    end)
end

local function GetPlayerStats(player)
    local stats = {bestTime = nil, wins = 0, xp = 0}
    pcall(function()
        if BestTimeStore then
            local timeMs = BestTimeStore:GetAsync(tostring(player.UserId))
            stats.bestTime = timeMs and timeMs/1000 or nil
        end
        if WinsStore then
            stats.wins = WinsStore:GetAsync(tostring(player.UserId)) or 0
        end
        if XPStore then
            stats.xp = XPStore:GetAsync(tostring(player.UserId)) or 0
        end
    end)
    return stats
end

local function GetLeaderboard()
    local lb = {}
    pcall(function()
        if not LeaderboardStore then return end
        local pages = LeaderboardStore:GetSortedAsync(true, 10)
        for rank, entry in ipairs(pages:GetCurrentPage()) do
            table.insert(lb, {rank = rank, name = entry.key:match("_(.+)") or "?", time = entry.value/1000})
        end
    end)
    return lb
end

-- ============================================
-- QUIZ DATABASE
-- ============================================
local GateQuizzes = {
    {q = "Is Earth round?", o = {"Yes", "No"}, a = 1},
    {q = "Is fire cold?", o = {"Yes", "No"}, a = 2},
    {q = "Can birds fly?", o = {"Yes", "No"}, a = 1},
    {q = "Is ice hot?", o = {"Yes", "No"}, a = 2},
    {q = "Do fish swim?", o = {"Yes", "No"}, a = 1},
    {q = "Is moon a star?", o = {"Yes", "No"}, a = 2},
    {q = "Sky color?", o = {"Red", "Blue", "Green"}, a = 2},
    {q = "Cat legs?", o = {"2", "4", "6"}, a = 2},
    {q = "5 + 5?", o = {"8", "10", "12"}, a = 2},
    {q = "Water formula?", o = {"H2O", "CO2", "O2"}, a = 1},
    {q = "Sun is a?", o = {"Planet", "Star", "Moon"}, a = 2},
    {q = "2 + 3?", o = {"3", "4", "5", "6"}, a = 3},
    {q = "Grass color?", o = {"Red", "Blue", "Green", "Yellow"}, a = 3},
    {q = "Days in week?", o = {"5", "6", "7", "8"}, a = 3},
    {q = "3 x 3?", o = {"6", "7", "8", "9"}, a = 4},
    {q = "Spider legs?", o = {"4", "6", "8", "10"}, a = 3},
    {q = "Biggest planet?", o = {"Earth", "Mars", "Jupiter", "Venus"}, a = 3},
}

-- 코스별 퀴즈 풀 또는 기본 퀴즈 풀에서 랜덤 선택
local function GetQuizByOptionCount(count)
    local pool = GateQuizzes  -- 기본 풀

    -- 현재 코스에 quizPool이 있으면 해당 풀 사용
    local currentCourse = CourseManager.currentCourse
    if currentCourse and currentCourse.quizPool and #currentCourse.quizPool > 0 then
        pool = currentCourse.quizPool
    end

    -- 옵션 수에 맞는 퀴즈 필터링
    local filtered = {}
    for _, q in ipairs(pool) do
        if #q.o == count then
            table.insert(filtered, q)
        end
    end

    -- 코스 풀에서 찾았으면 반환
    if #filtered > 0 then
        return filtered[math.random(#filtered)]
    end

    -- 코스 풀에 해당 옵션 수 퀴즈가 없으면 기본 풀에서 찾기 (Fallback)
    if pool ~= GateQuizzes then
        local defaultFiltered = {}
        for _, q in ipairs(GateQuizzes) do
            if #q.o == count then
                table.insert(defaultFiltered, q)
            end
        end
        if #defaultFiltered > 0 then
            return defaultFiltered[math.random(#defaultFiltered)]
        end
    end

    -- 최후 fallback
    return GateQuizzes[1]
end

local gateColors = {
    Color3.fromRGB(255, 80, 80),
    Color3.fromRGB(80, 150, 255),
    Color3.fromRGB(255, 220, 80),
    Color3.fromRGB(80, 220, 80)
}

-- ============================================
-- 🧩 GIMMICK REGISTRATIONS
-- ============================================

-- 🔄 RotatingBar
GimmickRegistry:Register({
    name = "RotatingBar",
    displayName = "회전 막대",
    icon = "🔄",
    difficulty = "easy",
    description = "회전하는 막대 - 틈새로 통과하거나 점프/숙여서 피하기",
    schema = {
        z = {type = "number", min = 0, max = 2000, default = 100, label = "위치 (Z)"},
        width = {type = "number", min = 10, max = 50, default = 28, label = "너비"},
        height = {type = "number", min = 1, max = 10, default = 3, label = "높이"},
        speed = {type = "number", min = 0.5, max = 5, default = 1.5, label = "회전 속도"},
        gapSize = {type = "number", min = 0, max = 10, default = 6, label = "틈새 크기 (0=없음)"},
        barType = {type = "string", default = "normal", label = "타입 (normal/low/high)"}
    },
    builder = function(parent, data)
        if not Config.EnableRotatingBars then return end

        local totalWidth = data.width or 28
        local gapSize = data.gapSize or 6
        local barHeight = data.height or 3
        local barType = data.barType or "normal"
        local actualSpeed = (data.speed or 2) * Config.ObstacleSpeed

        -- 바 타입에 따른 높이 조정 (스킬 요소)
        -- low: 점프로 넘기 (높이 1.5)
        -- high: 숙여서 통과 (높이 5)
        -- normal: 기본 (높이 3)
        if barType == "low" then
            barHeight = 1.5
        elseif barType == "high" then
            barHeight = 5
        end

        local bars = {}
        local db = {}

        local function setupBarTouch(bar)
            bar.Touched:Connect(function(hit)
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if player and not db[player] then
                    db[player] = true
                    local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
                    if rp then
                        local newSpeed = ApplySpeedBoost(player, -5)
                        Events.ItemEffect:FireClient(player, "SpeedDown", {
                            speedPercent = newSpeed,
                            message = "💥 감속! -5%",
                            direction = (rp.Position - bar.Position).Unit * 35 + Vector3.new(0, 18, 0)
                        })
                    end
                    task.delay(0.5, function() db[player] = nil end)
                end
            end)
        end

        -- 틈새가 있으면 두 개로 분리, 없으면 하나
        if gapSize > 0 then
            local sideWidth = (totalWidth - gapSize) / 2

            -- 왼쪽 바
            local barLeft = Instance.new("Part")
            barLeft.Size = Vector3.new(sideWidth, 2, 2)
            barLeft.Position = Vector3.new(-(sideWidth/2 + gapSize/2), barHeight, data.z)
            barLeft.Anchored = true
            barLeft.BrickColor = BrickColor.new("Bright red")
            barLeft.Material = Enum.Material.Metal
            barLeft.Parent = parent
            setupBarTouch(barLeft)
            table.insert(bars, barLeft)
            table.insert(ActiveGimmicks, barLeft)

            -- 오른쪽 바
            local barRight = Instance.new("Part")
            barRight.Size = Vector3.new(sideWidth, 2, 2)
            barRight.Position = Vector3.new(sideWidth/2 + gapSize/2, barHeight, data.z)
            barRight.Anchored = true
            barRight.BrickColor = BrickColor.new("Bright red")
            barRight.Material = Enum.Material.Metal
            barRight.Parent = parent
            setupBarTouch(barRight)
            table.insert(bars, barRight)
            table.insert(ActiveGimmicks, barRight)

            -- 틈새 표시 (초록색 바닥 가이드)
            local gapGuide = Instance.new("Part")
            gapGuide.Size = Vector3.new(gapSize, 0.2, 4)
            gapGuide.Position = Vector3.new(0, 0.1, data.z)
            gapGuide.Anchored = true
            gapGuide.CanCollide = false
            gapGuide.BrickColor = BrickColor.new("Lime green")
            gapGuide.Material = Enum.Material.Neon
            gapGuide.Transparency = 0.5
            gapGuide.Parent = parent
            table.insert(ActiveGimmicks, gapGuide)

            -- 회전 (두 바를 함께 회전시키는 피벗)
            local pivotRotation = math.random(0, 360)
            table.insert(RotatingObjects, {
                parts = bars,
                pivotZ = data.z,
                pivotY = barHeight,
                speed = actualSpeed,
                rotation = pivotRotation,
                rotationType = "pivot"
            })
        else
            -- 틈새 없는 기본 바
            local bar = Instance.new("Part")
            bar.Size = Vector3.new(totalWidth, 2, 2)
            bar.Position = Vector3.new(0, barHeight, data.z)
            bar.Anchored = true
            bar.BrickColor = BrickColor.new("Bright red")
            bar.Material = Enum.Material.Metal
            bar.Parent = parent
            setupBarTouch(bar)
            table.insert(ActiveGimmicks, bar)

            table.insert(RotatingObjects, {
                part = bar,
                speed = actualSpeed,
                rotation = math.random(0, 360),
                rotationType = "Y"
            })
        end

        return bars[1]
    end
})

-- 🔺 JumpPad (업그레이드: 좌우 이동 + 하이점프 보상)
GimmickRegistry:Register({
    name = "JumpPad",
    displayName = "점프 패드",
    icon = "🔺",
    difficulty = "easy",
    description = "밟으면 점프, 아이템 타이밍 맞추면 하이점프 + 보상!",
    schema = {
        x = {type = "number", min = -20, max = 20, default = 0, label = "X 위치"},
        y = {type = "number", min = 0, max = 10, default = 0.5, label = "Y 위치"},
        z = {type = "number", min = 0, max = 2000, default = 100, label = "Z 위치"},
        moveRange = {type = "number", min = 0, max = 15, default = 10, label = "이동 범위"},
        moveSpeed = {type = "number", min = 0.5, max = 3, default = 1.5, label = "이동 속도"}
    },
    builder = function(parent, data)
        if not Config.EnableJumpPads then return end
        local TW = Config.TRACK_WIDTH
        local baseX = data.x or 0
        local baseY = data.y or 0.5
        local baseZ = data.z
        local moveRange = data.moveRange or 10
        local moveSpeed = data.moveSpeed or 1.5

        -- 점프 패드 생성
        local pad = Instance.new("Part")
        pad.Name = "JumpPad"
        pad.Size = Vector3.new(8, 1, 8)
        pad.Position = Vector3.new(baseX, baseY, baseZ)
        pad.Anchored = true
        pad.BrickColor = BrickColor.new("Lime green")
        pad.Material = Enum.Material.Neon
        pad.Parent = parent

        local springGui = Instance.new("SurfaceGui")
        springGui.Face = Enum.NormalId.Top
        springGui.Parent = pad
        local springLabel = Instance.new("TextLabel")
        springLabel.Size = UDim2.new(1, 0, 1, 0)
        springLabel.BackgroundTransparency = 1
        springLabel.Text = "🔺\n⬆️"
        springLabel.TextColor3 = Color3.new(1, 1, 1)
        springLabel.TextScaled = true
        springLabel.Font = Enum.Font.GothamBold
        springLabel.Parent = springGui

        -- 벽 장애물
        local wall = Instance.new("Part")
        wall.Name = "JumpWall"
        wall.Size = Vector3.new(TW, 12, 3)
        wall.Position = Vector3.new(0, 6, baseZ + 6)
        wall.Anchored = true
        wall.BrickColor = BrickColor.new("Medium stone grey")
        wall.Material = Enum.Material.Brick
        wall.Parent = parent

        local wallGui = Instance.new("SurfaceGui")
        wallGui.Face = Enum.NormalId.Back
        wallGui.Parent = wall
        local wallLabel = Instance.new("TextLabel")
        wallLabel.Size = UDim2.new(1, 0, 1, 0)
        wallLabel.BackgroundTransparency = 1
        wallLabel.Text = "⬆️ JUMP! ⬆️"
        wallLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        wallLabel.TextScaled = true
        wallLabel.Font = Enum.Font.GothamBold
        wallLabel.Parent = wallGui

        -- 🌟 하이점프 보상 (높은 곳에 아이템 박스)
        local rewardHeight = 15  -- 도달 가능한 높이
        local rewardBox = Instance.new("Part")
        rewardBox.Name = "HighJumpReward"
        rewardBox.Size = Vector3.new(8, 8, 8)  -- 더 큰 크기
        rewardBox.Position = Vector3.new(baseX, baseY + rewardHeight, baseZ)
        rewardBox.Anchored = true
        rewardBox.CanCollide = false
        rewardBox.BrickColor = BrickColor.new("Bright yellow")
        rewardBox.Material = Enum.Material.Neon
        rewardBox.Transparency = 0.3
        rewardBox.Parent = parent

        local rewardGui = Instance.new("SurfaceGui")
        rewardGui.Face = Enum.NormalId.Front
        rewardGui.Parent = rewardBox
        local rewardLabel = Instance.new("TextLabel")
        rewardLabel.Size = UDim2.new(1, 0, 1, 0)
        rewardLabel.BackgroundTransparency = 1
        rewardLabel.Text = "⭐"
        rewardLabel.TextColor3 = Color3.new(1, 1, 1)
        rewardLabel.TextScaled = true
        rewardLabel.Font = Enum.Font.GothamBold
        rewardLabel.Parent = rewardGui

        -- 🔄 통합 애니메이션 (이동 + 회전)
        task.spawn(function()
            local direction = 1
            local currentX = baseX
            local rotation = 0

            while pad and pad.Parent and rewardBox and rewardBox.Parent do
                rotation = rotation + 3

                -- 좌우 이동
                if moveRange > 0 then
                    currentX = currentX + (direction * moveSpeed * 0.1)
                    if currentX > baseX + moveRange then
                        currentX = baseX + moveRange
                        direction = -1
                    elseif currentX < baseX - moveRange then
                        currentX = baseX - moveRange
                        direction = 1
                    end
                    pad.Position = Vector3.new(currentX, baseY, baseZ)
                end

                -- 보상 박스: 이동 + 회전 동시 적용
                rewardBox.CFrame = CFrame.new(currentX, baseY + rewardHeight, baseZ)
                    * CFrame.Angles(0, math.rad(rotation), 0)

                task.wait(0.03)
            end
        end)

        -- 점프 처리
        local db = {}
        local rewardDb = {}

        pad.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            local hum = hit.Parent:FindFirstChild("Humanoid")
            local rp = hit.Parent:FindFirstChild("HumanoidRootPart")

            if hum and rp and player and not db[hit.Parent] then
                db[hit.Parent] = true

                -- 🚀 하이점프 조건: Booster 아이템 사용 중이면 하이점프
                local isHighJump = false
                if hum.WalkSpeed > 16 * 1.3 then  -- Booster 사용 중 (속도 증가 상태)
                    isHighJump = true
                end

                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(0, 100000, 0)

                if isHighJump then
                    bv.Velocity = Vector3.new(0, 150, 0)  -- 하이점프!
                    Events.ItemEffect:FireClient(player, "HighJump", {message = "🚀 HIGH JUMP!"})
                else
                    bv.Velocity = Vector3.new(0, 90, 0)  -- 일반 점프
                end

                bv.Parent = rp
                Debris:AddItem(bv, 0.2)
                task.delay(0.5, function() db[hit.Parent] = nil end)
            end
        end)

        -- 🌟 보상 박스 터치 처리
        rewardBox.Touched:Connect(function(hit)
            local char = hit.Parent
            if not char then return end
            local player = Players:GetPlayerFromCharacter(char)
            if not player then
                -- 캐릭터 부모가 아닐 수 있음 (액세서리 등)
                char = hit.Parent.Parent
                player = Players:GetPlayerFromCharacter(char)
            end

            if player and not rewardDb[player] then
                rewardDb[player] = true
                print("⭐ High Jump Reward touched by:", player.Name)

                -- 보상: XP
                local pData = PlayerData[player]
                if pData then
                    local bonusXP = 50
                    pData.xp = (pData.xp or 0) + bonusXP
                    local level = pData.level or 1
                    local progress, xpInLevel, xpNeeded = GetLevelProgress(pData.xp, level)
                    Events.XPUpdate:FireClient(player, {
                        xp = pData.xp,
                        xpGained = bonusXP,
                        reason = "High Jump Bonus",
                        level = level,
                        levelName = LevelConfig[level].name,
                        levelIcon = LevelConfig[level].icon,
                        trailType = LevelConfig[level].trailType,
                        progress = progress,
                        xpInLevel = xpInLevel,
                        xpNeeded = xpNeeded
                    })
                    Events.ItemEffect:FireClient(player, "Reward", {
                        message = "⭐ HIGH JUMP BONUS! +" .. bonusXP .. " XP"
                    })
                end

                -- 시각 효과: 박스 축소 후 복구
                local origSize = rewardBox.Size
                rewardBox.Size = Vector3.new(1, 1, 1)
                rewardBox.Transparency = 0.8
                rewardBox.BrickColor = BrickColor.new("White")

                task.delay(5, function()
                    if rewardBox and rewardBox.Parent then
                        rewardBox.Size = origSize
                        rewardBox.Transparency = 0.3
                        rewardBox.BrickColor = BrickColor.new("Bright yellow")
                        rewardDb[player] = nil
                    end
                end)
            end
        end)

        table.insert(ActiveGimmicks, pad)
        table.insert(ActiveGimmicks, wall)
        table.insert(ActiveGimmicks, rewardBox)
        return pad
    end
})

-- 👻 SlimeZone
GimmickRegistry:Register({
    name = "SlimeZone",
    displayName = "슬라임 구역",
    icon = "👻",
    difficulty = "easy",
    description = "밟으면 느려지는 구역, 안전 경로 있음",
    schema = {
        z = {type = "number", min = 0, max = 2000, default = 100, label = "시작 위치 (Z)"},
        length = {type = "number", min = 20, max = 200, default = 80, label = "길이"}
    },
    builder = function(parent, data)
        if not Config.EnableSlime then return end
        local TW = Config.TRACK_WIDTH
        local zStart = data.z
        local length = data.length or 80
        local slimeBase = Instance.new("Part")
        slimeBase.Size = Vector3.new(TW, 0.5, length)
        slimeBase.Position = Vector3.new(0, 0.25, zStart + length/2)
        slimeBase.Anchored = true
        slimeBase.BrickColor = BrickColor.new("Lime green")
        slimeBase.Material = Enum.Material.Marble
        slimeBase.Transparency = 0.3
        slimeBase.Parent = parent
        for i = 1, math.floor(length / 15) do
            local ghostPart = Instance.new("Part")
            ghostPart.Size = Vector3.new(6, 0.1, 6)
            ghostPart.Position = Vector3.new(math.random(-10, 10), 0.35, zStart + i * 15)
            ghostPart.Anchored = true
            ghostPart.CanCollide = false
            ghostPart.Transparency = 1
            ghostPart.Parent = parent
            local ghostGui = Instance.new("SurfaceGui")
            ghostGui.Face = Enum.NormalId.Top
            ghostGui.Parent = ghostPart
            local ghostLabel = Instance.new("TextLabel")
            ghostLabel.Size = UDim2.new(1, 0, 1, 0)
            ghostLabel.BackgroundTransparency = 1
            ghostLabel.Text = "👻"
            ghostLabel.TextScaled = true
            ghostLabel.Parent = ghostGui
            table.insert(ActiveGimmicks, ghostPart)
        end
        local pathWidth = 6
        local numPaths = math.floor(length / 20)
        for i = 1, numPaths do
            local xPos = (i % 2 == 0) and 10 or -10
            local safePath = Instance.new("Part")
            safePath.Name = "SafePath"
            safePath.Size = Vector3.new(pathWidth, 0.6, 12)
            safePath.Position = Vector3.new(xPos, 0.3, zStart + (i - 0.5) * (length / numPaths))
            safePath.Anchored = true
            safePath.BrickColor = BrickColor.new("Bright yellow")
            safePath.Material = Enum.Material.Cobblestone
            safePath.Parent = parent
            table.insert(ActiveGimmicks, safePath)
        end
        local inSlime = {}
        local safePaths = {}
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "SafePath" then
                child.Touched:Connect(function(hit)
                    local char = hit.Parent
                    if char:FindFirstChild("Humanoid") then
                        safePaths[char] = true
                    end
                end)
                child.TouchEnded:Connect(function(hit)
                    local char = hit.Parent
                    safePaths[char] = nil
                end)
            end
        end
        slimeBase.Touched:Connect(function(hit)
            if not hit or not hit.Parent then return end
            local hum = hit.Parent:FindFirstChild("Humanoid")
            if hum and not inSlime[hit.Parent] and not safePaths[hit.Parent] then
                inSlime[hit.Parent] = hum.WalkSpeed
                hum.WalkSpeed = hum.WalkSpeed * Config.SlimeSlowFactor
            end
        end)
        slimeBase.TouchEnded:Connect(function(hit)
            if not hit or not hit.Parent then return end
            local hum = hit.Parent:FindFirstChild("Humanoid")
            if hum and inSlime[hit.Parent] then
                hum.WalkSpeed = inSlime[hit.Parent]
                inSlime[hit.Parent] = nil
            end
        end)
        table.insert(ActiveGimmicks, slimeBase)
        return slimeBase
    end
})

-- 🥊 PunchingCorridor (스킬 업그레이드: 3레인 시스템 + 레인별 공격 패턴)
GimmickRegistry:Register({
    name = "PunchingCorridor",
    displayName = "펀칭 복도",
    icon = "🥊",
    difficulty = "medium",
    description = "3레인 복도 - 글러브 패턴 보고 안전 레인으로 이동!",
    schema = {
        z = {type = "number", min = 0, max = 2000, default = 100, label = "시작 위치 (Z)"},
        length = {type = "number", min = 50, max = 200, default = 100, label = "길이"},
        laneCount = {type = "number", min = 2, max = 3, default = 3, label = "레인 수"}
    },
    builder = function(parent, data)
        if not Config.EnablePunchingGloves then return end
        local zStart = data.z
        local length = data.length or 100
        local TW = Config.TRACK_WIDTH
        local laneCount = data.laneCount or 3
        local corridorWidth = TW - 8  -- 넓은 복도
        local laneWidth = corridorWidth / laneCount

        -- 양쪽 벽
        for _, side in ipairs({-1, 1}) do
            local wall = Instance.new("Part")
            wall.Size = Vector3.new(4, 10, length)
            wall.Position = Vector3.new(side * (corridorWidth/2 + 2), 5, zStart + length/2)
            wall.Anchored = true
            wall.BrickColor = BrickColor.new("Dark stone grey")
            wall.Material = Enum.Material.Brick
            wall.Parent = parent
            table.insert(ActiveGimmicks, wall)
        end

        -- 레인 구분선 (바닥)
        for i = 1, laneCount do
            local xPos = -corridorWidth/2 + (i - 0.5) * laneWidth
            local laneLine = Instance.new("Part")
            laneLine.Size = Vector3.new(laneWidth - 1, 0.2, length)
            laneLine.Position = Vector3.new(xPos, 0.1, zStart + length/2)
            laneLine.Anchored = true
            laneLine.CanCollide = false
            laneLine.BrickColor = (i == 2) and BrickColor.new("Lime green") or BrickColor.new("Medium stone grey")
            laneLine.Material = Enum.Material.SmoothPlastic
            laneLine.Transparency = 0.5
            laneLine.Parent = parent
            table.insert(ActiveGimmicks, laneLine)
        end

        -- 안내 표지판
        local signPart = Instance.new("Part")
        signPart.Size = Vector3.new(16, 6, 1)
        signPart.Position = Vector3.new(0, 6, zStart - 5)
        signPart.Anchored = true
        signPart.CanCollide = false
        signPart.BrickColor = BrickColor.new("Bright yellow")
        signPart.Parent = parent
        local signGui = Instance.new("SurfaceGui")
        signGui.Face = Enum.NormalId.Front
        signGui.Parent = signPart
        local signLabel = Instance.new("TextLabel")
        signLabel.Size = UDim2.new(1, 0, 1, 0)
        signLabel.BackgroundTransparency = 1
        signLabel.Text = "🥊 펀칭 복도 🥊\n⚠️ 노란색 레인 피하기!"
        signLabel.TextColor3 = Color3.new(0, 0, 0)
        signLabel.TextScaled = true
        signLabel.Font = Enum.Font.GothamBold
        signLabel.Parent = signGui
        table.insert(ActiveGimmicks, signPart)

        -- 글러브 세트 (각 열에 laneCount개 글러브)
        local numRows = math.floor(length / 30)
        local gloveRows = {}

        for row = 1, numRows do
            local zPos = zStart + row * (length / (numRows + 1))
            local rowGloves = {}

            for lane = 1, laneCount do
                local xPos = -corridorWidth/2 + (lane - 0.5) * laneWidth
                local glove = Instance.new("Part")
                glove.Name = "PunchingGlove_R" .. row .. "_L" .. lane
                glove.Size = Vector3.new(laneWidth * 0.6, 4, 4)
                glove.Position = Vector3.new(xPos, 8, zPos)  -- 위에서 대기
                glove.Anchored = true
                glove.BrickColor = BrickColor.new("Bright red")
                glove.Material = Enum.Material.SmoothPlastic
                glove.Transparency = 0.3
                glove.Parent = parent

                local gloveGui = Instance.new("SurfaceGui")
                gloveGui.Face = Enum.NormalId.Front
                gloveGui.Parent = glove
                local gloveLabel = Instance.new("TextLabel")
                gloveLabel.Size = UDim2.new(1, 0, 1, 0)
                gloveLabel.BackgroundTransparency = 1
                gloveLabel.Text = "🥊"
                gloveLabel.TextScaled = true
                gloveLabel.Parent = gloveGui

                -- 레인 바닥 경고 표시
                local warnFloor = Instance.new("Part")
                warnFloor.Name = "WarnFloor_R" .. row .. "_L" .. lane
                warnFloor.Size = Vector3.new(laneWidth - 2, 0.3, 6)
                warnFloor.Position = Vector3.new(xPos, 0.15, zPos)
                warnFloor.Anchored = true
                warnFloor.CanCollide = false
                warnFloor.BrickColor = BrickColor.new("Medium stone grey")
                warnFloor.Material = Enum.Material.SmoothPlastic
                warnFloor.Transparency = 0.3
                warnFloor.Parent = parent

                local db = {}
                glove.Touched:Connect(function(hit)
                    local player = Players:GetPlayerFromCharacter(hit.Parent)
                    local hum = hit.Parent:FindFirstChild("Humanoid")
                    if player and hum and not db[player] then
                        db[player] = true
                        local newSpeed = ApplySpeedBoost(player, -5)
                        local origJump = hum.JumpPower
                        hum.WalkSpeed = BASE_WALK_SPEED * 0.3
                        hum.JumpPower = 0
                        Events.ItemEffect:FireClient(player, "SpeedDown", {
                            speedPercent = newSpeed,
                            message = "👊 감속! -5%",
                            stun = true
                        })
                        task.delay(1.5, function()
                            if hum then
                                hum.WalkSpeed = BASE_WALK_SPEED * (GetSpeedBoost(player) / 100)
                                hum.JumpPower = origJump
                            end
                            db[player] = nil
                        end)
                    end
                end)

                table.insert(rowGloves, {glove = glove, warnFloor = warnFloor, xPos = xPos, zPos = zPos})
                table.insert(ActiveGimmicks, glove)
                table.insert(ActiveGimmicks, warnFloor)
            end

            table.insert(gloveRows, rowGloves)
        end

        -- 패턴 기반 공격 로직 (각 열마다 1~2개 레인만 공격)
        task.spawn(function()
            while gloveRows[1] and gloveRows[1][1].glove.Parent do
                for rowIdx, rowGloves in ipairs(gloveRows) do
                    -- 랜덤하게 1~2개 레인 선택 (최소 1개는 안전)
                    local attackLanes = {}
                    local safeCount = math.random(1, laneCount - 1)
                    for i = 1, laneCount do
                        if i <= laneCount - safeCount then
                            table.insert(attackLanes, i)
                        end
                    end
                    -- 셔플
                    for i = #attackLanes, 2, -1 do
                        local j = math.random(1, i)
                        attackLanes[i], attackLanes[j] = attackLanes[j], attackLanes[i]
                    end

                    -- 경고 표시 (노란색)
                    for lane, gloveData in ipairs(rowGloves) do
                        local isAttacking = false
                        for _, aLane in ipairs(attackLanes) do
                            if aLane == lane then isAttacking = true break end
                        end
                        if isAttacking then
                            gloveData.warnFloor.BrickColor = BrickColor.new("Bright yellow")
                            gloveData.glove.Transparency = 0
                        else
                            gloveData.warnFloor.BrickColor = BrickColor.new("Lime green")
                            gloveData.glove.Transparency = 0.7
                        end
                    end

                    task.wait(0.8)  -- 경고 시간

                    -- 공격!
                    for lane, gloveData in ipairs(rowGloves) do
                        local isAttacking = false
                        for _, aLane in ipairs(attackLanes) do
                            if aLane == lane then isAttacking = true break end
                        end
                        if isAttacking then
                            gloveData.warnFloor.BrickColor = BrickColor.new("Really red")
                            local downPos = Vector3.new(gloveData.xPos, 3, gloveData.zPos)
                            local upPos = Vector3.new(gloveData.xPos, 8, gloveData.zPos)
                            TweenService:Create(gloveData.glove, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Position = downPos}):Play()
                            task.delay(0.3, function()
                                TweenService:Create(gloveData.glove, TweenInfo.new(0.3), {Position = upPos}):Play()
                                gloveData.warnFloor.BrickColor = BrickColor.new("Medium stone grey")
                            end)
                        end
                    end

                    task.wait(0.5)
                end
                task.wait(1.0)  -- 사이클 간 휴식
            end
        end)
    end
})

-- 🚪 QuizGate
GimmickRegistry:Register({
    name = "QuizGate",
    displayName = "퀴즈 게이트",
    icon = "🚪",
    difficulty = "medium",
    description = "퀴즈 정답 문으로 통과",
    schema = {
        id = {type = "number", min = 1, max = 100, default = 1, label = "게이트 ID"},
        triggerZ = {type = "number", min = 0, max = 2000, default = 150, label = "트리거 위치"},
        gateZ = {type = "number", min = 0, max = 2000, default = 180, label = "게이트 위치"},
        options = {type = "number", min = 2, max = 4, default = 2, label = "선택지 수"}
    },
    builder = function(parent, data)
        if not Config.EnableQuizGates then return end
        local gateId = data.id
        local triggerZ = data.triggerZ
        local gateZ = data.gateZ
        local optionCount = data.options or 2
        local quiz = GetQuizByOptionCount(optionCount)
        local TW = Config.TRACK_WIDTH
        local trigger = Instance.new("Part")
        trigger.Size = Vector3.new(TW, 10, 5)
        trigger.Position = Vector3.new(0, 5, triggerZ)
        trigger.Anchored = true
        trigger.CanCollide = false
        trigger.Transparency = 1
        trigger.Parent = parent
        local triggerFloor = Instance.new("Part")
        triggerFloor.Size = Vector3.new(TW, 0.5, 5)
        triggerFloor.Position = Vector3.new(0, 0.25, triggerZ)
        triggerFloor.Anchored = true
        triggerFloor.CanCollide = false
        triggerFloor.BrickColor = BrickColor.new("Bright violet")
        triggerFloor.Material = Enum.Material.Neon
        triggerFloor.Transparency = 0.5
        triggerFloor.Parent = parent
        local gateWidth = TW / optionCount
        for i = 1, optionCount do
            local xPos = -TW/2 + gateWidth/2 + (i-1) * gateWidth
            local gate = Instance.new("Part")
            gate.Name = "Gate" .. gateId .. "_" .. i
            gate.Size = Vector3.new(gateWidth - 1, 14, 3)
            gate.Position = Vector3.new(xPos, 7, gateZ)
            gate.Anchored = true
            gate.CanCollide = false
            gate.Color = gateColors[i]
            gate.Material = Enum.Material.Neon
            gate.Transparency = 0.2
            gate.Parent = parent
            local outline = Instance.new("SelectionBox")
            outline.Adornee = gate
            outline.Color3 = gateColors[i]
            outline.LineThickness = 0.05
            outline.Parent = gate
            local gui = Instance.new("SurfaceGui")
            gui.Face = Enum.NormalId.Back
            gui.Parent = gate
            local num = Instance.new("TextLabel")
            num.Size = UDim2.new(1,0,0.35,0)
            num.BackgroundTransparency = 1
            num.Text = "[" .. i .. "]"
            num.TextColor3 = Color3.new(1,1,1)
            num.TextScaled = true
            num.Font = Enum.Font.GothamBold
            num.Parent = gui
            local opt = Instance.new("TextLabel")
            opt.Size = UDim2.new(0.9,0,0.55,0)
            opt.Position = UDim2.new(0.05,0,0.4,0)
            opt.BackgroundTransparency = 1
            opt.Text = quiz.o[i]
            opt.TextColor3 = Color3.new(1,1,1)
            opt.TextScaled = true
            opt.Font = Enum.Font.GothamBold
            opt.Parent = gui
            local db = {}
            gate.Touched:Connect(function(hit)
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if not player or db[player] then return end
                local answer = PlayerGateAnswers[player] and PlayerGateAnswers[player][gateId]
                if answer == i then
                    -- 정답: +5% 속도 부스트!
                    local newSpeed = ApplySpeedBoost(player, 5)
                    Events.ItemEffect:FireClient(player, "SpeedUp", {
                        speedPercent = newSpeed,
                        message = "🚀 가속! +5%"
                    })
                else
                    db[player] = true
                    local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
                    local hum = hit.Parent:FindFirstChild("Humanoid")
                    if hum and rp then
                        local origSpeed = hum.WalkSpeed
                        local origJump = hum.JumpPower
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                        local bv = Instance.new("BodyVelocity")
                        bv.MaxForce = Vector3.new(50000,50000,50000)
                        bv.Velocity = Vector3.new(0, 22, -50)
                        bv.Parent = rp
                        Debris:AddItem(bv, 0.3)
                        Events.ItemEffect:FireClient(player, "GateWrong", {duration = 1.2})
                        task.delay(1.2, function()
                            if hum then hum.WalkSpeed = origSpeed; hum.JumpPower = origJump end
                            db[player] = nil
                        end)
                    end
                end
            end)
            table.insert(ActiveGimmicks, gate)
        end
        local triggered = {}
        trigger.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if not player or triggered[player] then return end
            triggered[player] = true
            if not PlayerGateAnswers[player] then PlayerGateAnswers[player] = {} end
            PlayerGateAnswers[player][gateId] = quiz.a
            Events.GateQuiz:FireClient(player, {
                gateId = gateId,
                question = quiz.q,
                options = quiz.o,
                optionCount = optionCount,
                colors = gateColors
            })
            task.delay(20, function() triggered[player] = nil end)
        end)
        table.insert(ActiveGimmicks, trigger)
    end
})

-- 🛗 Elevator
GimmickRegistry:Register({
    name = "Elevator",
    displayName = "엘리베이터 퀴즈",
    icon = "🛗",
    difficulty = "hard",
    description = "정답 플랫폼이 빨리 올라감",
    schema = {
        id = {type = "number", min = 1, max = 100, default = 1, label = "엘리베이터 ID"},
        triggerZ = {type = "number", min = 0, max = 2000, default = 620, label = "트리거 위치"},
        elevZ = {type = "number", min = 0, max = 2000, default = 670, label = "엘리베이터 위치"},
        options = {type = "number", min = 2, max = 4, default = 3, label = "선택지 수"}
    },
    builder = function(parent, data)
        if not Config.EnableElevators then return end
        local elevId = data.id
        local triggerZ = data.triggerZ
        local elevZ = data.elevZ
        local optionCount = data.options or 3
        local quiz = GetQuizByOptionCount(optionCount)
        local TW = Config.TRACK_WIDTH
        local platformLength = 22
        local elevationHeight = 15
        local startY = 1
        local hole = Instance.new("Part")
        hole.Size = Vector3.new(TW, 1, platformLength + 4)
        hole.Position = Vector3.new(0, -0.5, elevZ)
        hole.Anchored = true
        hole.CanCollide = false
        hole.BrickColor = BrickColor.new("Really black")
        hole.Parent = parent
        local trigger = Instance.new("Part")
        trigger.Size = Vector3.new(TW, 15, 8)  -- 더 큰 감지 영역
        trigger.Position = Vector3.new(0, 7, triggerZ)
        trigger.Anchored = true
        trigger.CanCollide = false
        trigger.Transparency = 0.9  -- 약간 보이게 (디버그용)
        trigger.BrickColor = BrickColor.new("Magenta")
        trigger.Parent = parent
        print("🛗 Elevator", elevId, "trigger created at Z:", triggerZ)
        local triggerFloor = Instance.new("Part")
        triggerFloor.Size = Vector3.new(TW, 0.5, 5)
        triggerFloor.Position = Vector3.new(0, 0.25, triggerZ)
        triggerFloor.Anchored = true
        triggerFloor.CanCollide = false
        triggerFloor.BrickColor = BrickColor.new("Cyan")
        triggerFloor.Material = Enum.Material.Neon
        triggerFloor.Transparency = 0.5
        triggerFloor.Parent = parent
        local platWidth = TW / optionCount
        local platforms = {}
        for i = 1, optionCount do
            local xPos = -TW/2 + platWidth/2 + (i-1) * platWidth
            local plat = Instance.new("Part")
            plat.Size = Vector3.new(platWidth - 1, 4, platformLength)
            plat.Position = Vector3.new(xPos, startY, elevZ)
            plat.Anchored = true
            plat.BrickColor = BrickColor.new("Medium stone grey")
            plat.Material = Enum.Material.Concrete
            plat.Parent = parent
            local colorTop = Instance.new("Part")
            colorTop.Size = Vector3.new(platWidth - 1, 0.5, platformLength)
            colorTop.Position = Vector3.new(xPos, startY + 2.25, elevZ)
            colorTop.Anchored = true
            colorTop.Color = gateColors[i]
            colorTop.Material = Enum.Material.Neon
            colorTop.Parent = parent
            local numPart = Instance.new("Part")
            numPart.Size = Vector3.new(platWidth - 2, 5, 1)
            numPart.Position = Vector3.new(xPos, startY + 5, elevZ - platformLength/2 + 1)
            numPart.Anchored = true
            numPart.CanCollide = false
            numPart.Transparency = 1
            numPart.Parent = parent
            local gui = Instance.new("SurfaceGui")
            gui.Face = Enum.NormalId.Front
            gui.Parent = numPart
            local num = Instance.new("TextLabel")
            num.Size = UDim2.new(1,0,0.5,0)
            num.BackgroundTransparency = 1
            num.Text = "[" .. i .. "]"
            num.TextColor3 = Color3.new(1,1,1)
            num.TextScaled = true
            num.Font = Enum.Font.GothamBold
            num.Parent = gui
            local opt = Instance.new("TextLabel")
            opt.Size = UDim2.new(1,0,0.5,0)
            opt.Position = UDim2.new(0,0,0.5,0)
            opt.BackgroundTransparency = 1
            opt.Text = quiz.o[i]
            opt.TextColor3 = Color3.new(1,1,1)
            opt.TextScaled = true
            opt.Font = Enum.Font.GothamBold
            opt.Parent = gui
            platforms[i] = {
                plat = plat,
                colorTop = colorTop,
                numPart = numPart,
                correct = (i == quiz.a),
                startY = startY,
                targetY = elevationHeight + startY
            }
            local platDb = {}
            plat.Touched:Connect(function(hit)
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if not player or platDb[player] then return end
                platDb[player] = true
                if i == quiz.a then
                    -- 정답: +5% 속도 부스트!
                    local newSpeed = ApplySpeedBoost(player, 5)
                    Events.ItemEffect:FireClient(player, "SpeedUp", {
                        speedPercent = newSpeed,
                        message = "🚀 가속! +5%"
                    })
                else
                    Events.ItemEffect:FireClient(player, "GateWrong", {})
                end
                task.delay(3, function() platDb[player] = nil end)
            end)
            table.insert(ActiveGimmicks, plat)
        end
        local upperFloorY = elevationHeight + startY + 1
        local upperFloor = Instance.new("Part")
        upperFloor.Size = Vector3.new(TW, 3, platformLength + 10)
        upperFloor.Position = Vector3.new(0, upperFloorY, elevZ + platformLength)
        upperFloor.Anchored = true
        upperFloor.BrickColor = BrickColor.new("Brick yellow")
        upperFloor.Material = Enum.Material.Cobblestone
        upperFloor.Parent = parent
        local bridge = Instance.new("Part")
        bridge.Size = Vector3.new(TW, 1, 5)
        bridge.Position = Vector3.new(0, upperFloorY - 1, elevZ + platformLength/2 + 2)
        bridge.Anchored = true
        bridge.BrickColor = BrickColor.new("Brick yellow")
        bridge.Material = Enum.Material.Cobblestone
        bridge.Parent = parent
        local underFloor = Instance.new("Part")
        underFloor.Size = Vector3.new(TW + 10, 10, 100)
        underFloor.Position = Vector3.new(0, -10, elevZ + platformLength + 30)
        underFloor.Anchored = true
        underFloor.BrickColor = BrickColor.new("Dark stone grey")
        underFloor.Material = Enum.Material.Brick
        underFloor.Parent = parent
        local ramp = Instance.new("Part")
        ramp.Size = Vector3.new(TW, 3, 50)
        local rampZ = elevZ + platformLength + platformLength/2 + 30
        ramp.Position = Vector3.new(0, upperFloorY/2, rampZ)
        ramp.Anchored = true
        ramp.BrickColor = BrickColor.new("Brick yellow")
        ramp.Material = Enum.Material.Cobblestone
        ramp.CFrame = CFrame.new(ramp.Position) * CFrame.Angles(math.rad(18), 0, 0)
        ramp.Parent = parent
        local rampSupport = Instance.new("Part")
        rampSupport.Size = Vector3.new(TW, upperFloorY, 50)
        rampSupport.Position = Vector3.new(0, -3, rampZ)
        rampSupport.Anchored = true
        rampSupport.BrickColor = BrickColor.new("Dark stone grey")
        rampSupport.Material = Enum.Material.Brick
        rampSupport.Parent = parent
        local triggered = {}
        trigger.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if not player or triggered[player] then return end
            triggered[player] = true
            print("🛗 Elevator triggered by", player.Name, "- Quiz shown, platforms will move in 5s")
            Events.GateQuiz:FireClient(player, {
                gateId = "elev" .. elevId,
                question = quiz.q,
                options = quiz.o,
                optionCount = optionCount,
                isElevator = true,
                colors = gateColors
            })
            task.delay(5, function()
                print("🛗 [ELEV", elevId, "] Platforms starting to move! Count:", #platforms)
                if #platforms == 0 then
                    print("⚠️ [ELEV", elevId, "] No platforms to move!")
                    return
                end
                for idx, p in ipairs(platforms) do
                    if p and p.plat and p.plat.Parent then
                        local riseTime = p.correct and 1.5 or 4
                        local targetY = p.targetY
                        local currentPos = p.plat.Position
                        print("🛗 [ELEV", elevId, "] Platform", idx, "moving from Y:", currentPos.Y, "to Y:", targetY, "in", riseTime, "sec")
                        TweenService:Create(p.plat, TweenInfo.new(riseTime, Enum.EasingStyle.Quad), {
                            Position = Vector3.new(currentPos.X, targetY, currentPos.Z)
                        }):Play()
                        TweenService:Create(p.colorTop, TweenInfo.new(riseTime, Enum.EasingStyle.Quad), {
                            Position = Vector3.new(p.colorTop.Position.X, targetY + 2.25, p.colorTop.Position.Z)
                        }):Play()
                        TweenService:Create(p.numPart, TweenInfo.new(riseTime, Enum.EasingStyle.Quad), {
                            Position = Vector3.new(p.numPart.Position.X, targetY + 5, p.numPart.Position.Z)
                        }):Play()
                    else
                        print("⚠️ [ELEV", elevId, "] Platform", idx, "is missing or destroyed!")
                    end
                end
            end)
            task.delay(25, function()
                for _, p in ipairs(platforms) do
                    TweenService:Create(p.plat, TweenInfo.new(2), {Position = Vector3.new(p.plat.Position.X, p.startY, p.plat.Position.Z)}):Play()
                    TweenService:Create(p.colorTop, TweenInfo.new(2), {Position = Vector3.new(p.colorTop.Position.X, p.startY + 2.25, p.colorTop.Position.Z)}):Play()
                    TweenService:Create(p.numPart, TweenInfo.new(2), {Position = Vector3.new(p.numPart.Position.X, p.startY + 5, p.numPart.Position.Z)}):Play()
                end
                triggered[player] = nil
            end)
        end)
        table.insert(ActiveGimmicks, trigger)
        table.insert(ActiveGimmicks, upperFloor)
        table.insert(ActiveGimmicks, underFloor)
        table.insert(ActiveGimmicks, ramp)
        table.insert(ActiveGimmicks, rampSupport)
    end
})

-- ⬅️ ConveyorBelt (스킬 업그레이드: 사이드 안전 레인)
GimmickRegistry:Register({
    name = "ConveyorBelt",
    displayName = "컨베이어 벨트",
    icon = "⬅️",
    difficulty = "medium",
    description = "뒤로 밀리는 바닥 - 양쪽 가장자리 안전 레인으로 통과!",
    schema = {
        z = {type = "number", min = 0, max = 2000, default = 100, label = "시작 위치 (Z)"},
        length = {type = "number", min = 20, max = 200, default = 60, label = "길이"},
        direction = {type = "number", min = -1, max = 1, default = -1, label = "방향 (-1: 뒤로)"},
        safeLaneWidth = {type = "number", min = 2, max = 6, default = 4, label = "안전 레인 너비"}
    },
    builder = function(parent, data)
        if not Config.EnableConveyorBelt then return end
        local zStart = data.z
        local length = data.length or 60
        local direction = data.direction or -1
        local TW = Config.TRACK_WIDTH
        local safeLaneWidth = data.safeLaneWidth or 4

        -- 중앙 컨베이어 벨트 (밀리는 구역)
        local beltWidth = TW - 4 - (safeLaneWidth * 2)
        local belt = Instance.new("Part")
        belt.Name = "ConveyorBelt"
        belt.Size = Vector3.new(beltWidth, 1, length)
        belt.Position = Vector3.new(0, 0.5, zStart + length/2)
        belt.Anchored = true
        belt.BrickColor = BrickColor.new("Dark stone grey")
        belt.Material = Enum.Material.DiamondPlate
        belt.Parent = parent

        -- 왼쪽 안전 레인 (초록)
        local leftLane = Instance.new("Part")
        leftLane.Name = "SafeLane_Left"
        leftLane.Size = Vector3.new(safeLaneWidth, 1, length)
        leftLane.Position = Vector3.new(-(beltWidth/2 + safeLaneWidth/2), 0.5, zStart + length/2)
        leftLane.Anchored = true
        leftLane.BrickColor = BrickColor.new("Lime green")
        leftLane.Material = Enum.Material.SmoothPlastic
        leftLane.Parent = parent
        table.insert(ActiveGimmicks, leftLane)

        -- 오른쪽 안전 레인 (초록)
        local rightLane = Instance.new("Part")
        rightLane.Name = "SafeLane_Right"
        rightLane.Size = Vector3.new(safeLaneWidth, 1, length)
        rightLane.Position = Vector3.new(beltWidth/2 + safeLaneWidth/2, 0.5, zStart + length/2)
        rightLane.Anchored = true
        rightLane.BrickColor = BrickColor.new("Lime green")
        rightLane.Material = Enum.Material.SmoothPlastic
        rightLane.Parent = parent
        table.insert(ActiveGimmicks, rightLane)

        -- 경고 표지판
        local signPart = Instance.new("Part")
        signPart.Size = Vector3.new(14, 5, 1)
        signPart.Position = Vector3.new(0, 5, zStart - 3)
        signPart.Anchored = true
        signPart.CanCollide = false
        signPart.Transparency = 0.5
        signPart.BrickColor = BrickColor.new("Bright yellow")
        signPart.Parent = parent
        local signGui = Instance.new("SurfaceGui")
        signGui.Face = Enum.NormalId.Front
        signGui.Parent = signPart
        local signLabel = Instance.new("TextLabel")
        signLabel.Size = UDim2.new(1, 0, 1, 0)
        signLabel.BackgroundTransparency = 1
        signLabel.Text = "⬅️ CONVEYOR\n🟢 가장자리 = 안전!"
        signLabel.TextColor3 = Color3.new(0, 0, 0)
        signLabel.TextScaled = true
        signLabel.Font = Enum.Font.GothamBold
        signLabel.Parent = signGui

        -- 컨베이어 밀기 로직 (중앙 벨트만)
        local playersOnBelt = {}
        belt.Touched:Connect(function(hit)
            local rp = hit.Parent:FindFirstChild("HumanoidRootPart")
            if rp then playersOnBelt[hit.Parent] = true end
        end)
        belt.TouchEnded:Connect(function(hit) playersOnBelt[hit.Parent] = nil end)

        local beltSpeed = 0.3 * (direction or -1)
        task.spawn(function()
            while belt and belt.Parent do
                for char, _ in pairs(playersOnBelt) do
                    local rp = char:FindFirstChild("HumanoidRootPart")
                    if rp then
                        local currentVel = rp.AssemblyLinearVelocity
                        rp.AssemblyLinearVelocity = Vector3.new(
                            currentVel.X,
                            currentVel.Y,
                            currentVel.Z + beltSpeed
                        )
                    end
                end
                task.wait(0.05)
            end
        end)

        table.insert(ActiveGimmicks, belt)
        table.insert(ActiveGimmicks, signPart)
        return belt
    end
})

-- ⚡ ElectricFloor (스킬 업그레이드: 3레인 순차 감전, 안전 지대)
GimmickRegistry:Register({
    name = "ElectricFloor",
    displayName = "전기 바닥",
    icon = "⚡",
    difficulty = "medium",
    description = "3레인 순차 감전 - 안전한 레인으로 이동하며 통과!",
    schema = {
        z = {type = "number", min = 0, max = 2000, default = 100, label = "시작 위치 (Z)"},
        length = {type = "number", min = 20, max = 200, default = 60, label = "길이"},
        laneCount = {type = "number", min = 2, max = 4, default = 3, label = "레인 수"}
    },
    builder = function(parent, data)
        if not Config.EnableElectricFloor then return end
        local zStart = data.z
        local length = data.length or 60
        local TW = Config.TRACK_WIDTH
        local laneCount = data.laneCount or 3
        local laneWidth = (TW - 4) / laneCount
        local lanes = {}
        local playersOnLane = {}

        -- 레인별 바닥 생성
        for i = 1, laneCount do
            local xPos = -((TW - 4) / 2) + (i - 0.5) * laneWidth
            local lane = Instance.new("Part")
            lane.Name = "ElectricLane_" .. i
            lane.Size = Vector3.new(laneWidth - 1, 0.5, length)
            lane.Position = Vector3.new(xPos, 0.25, zStart + length/2)
            lane.Anchored = true
            lane.BrickColor = BrickColor.new("Medium stone grey")
            lane.Material = Enum.Material.Metal
            lane.Parent = parent

            -- 레인 번호 표시
            local laneMarker = Instance.new("Part")
            laneMarker.Size = Vector3.new(laneWidth - 2, 0.1, 4)
            laneMarker.Position = Vector3.new(xPos, 0.55, zStart + 5)
            laneMarker.Anchored = true
            laneMarker.CanCollide = false
            laneMarker.Transparency = 0.5
            laneMarker.BrickColor = BrickColor.new("Lime green")
            laneMarker.Material = Enum.Material.Neon
            laneMarker.Parent = parent
            table.insert(ActiveGimmicks, laneMarker)

            playersOnLane[i] = {}
            lane.Touched:Connect(function(hit)
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if player then playersOnLane[i][player] = true end
            end)
            lane.TouchEnded:Connect(function(hit)
                local player = Players:GetPlayerFromCharacter(hit.Parent)
                if player then playersOnLane[i][player] = nil end
            end)

            table.insert(lanes, lane)
            table.insert(ActiveGimmicks, lane)
        end

        -- 경고 표지판
        local warnSign = Instance.new("Part")
        warnSign.Size = Vector3.new(16, 6, 1)
        warnSign.Position = Vector3.new(0, 5, zStart - 5)
        warnSign.Anchored = true
        warnSign.CanCollide = false
        warnSign.BrickColor = BrickColor.new("Bright yellow")
        warnSign.Parent = parent
        local warnGui = Instance.new("SurfaceGui")
        warnGui.Face = Enum.NormalId.Front
        warnGui.Parent = warnSign
        local warnLabel = Instance.new("TextLabel")
        warnLabel.Size = UDim2.new(1, 0, 1, 0)
        warnLabel.BackgroundTransparency = 1
        warnLabel.Text = "⚡ 순차 감전! ⚡\n🟢 초록 레인 = 안전"
        warnLabel.TextColor3 = Color3.new(0, 0, 0)
        warnLabel.TextScaled = true
        warnLabel.Font = Enum.Font.GothamBold
        warnLabel.Parent = warnGui
        table.insert(ActiveGimmicks, warnSign)

        -- 순차 감전 로직
        task.spawn(function()
            local currentDanger = 1
            while lanes[1] and lanes[1].Parent do
                -- 모든 레인 안전 상태로 (노란색 경고)
                for i, lane in ipairs(lanes) do
                    if i == currentDanger then
                        lane.BrickColor = BrickColor.new("Bright yellow")  -- 다음 감전 예고
                    else
                        lane.BrickColor = BrickColor.new("Lime green")  -- 안전
                    end
                    lane.Material = Enum.Material.SmoothPlastic
                end
                task.wait(1.0)  -- 예고 시간

                -- 감전!
                local dangerLane = lanes[currentDanger]
                if dangerLane then
                    dangerLane.BrickColor = BrickColor.new("Cyan")
                    dangerLane.Material = Enum.Material.Neon

                    -- 해당 레인에 있는 플레이어 감전
                    for player, _ in pairs(playersOnLane[currentDanger]) do
                        local newSpeed = ApplySpeedBoost(player, -5)
                        Events.ItemEffect:FireClient(player, "SpeedDown", {
                            speedPercent = newSpeed,
                            message = "⚡ 감전! -5%",
                            stun = true
                        })
                    end
                end
                task.wait(0.5)

                -- 다음 레인으로
                currentDanger = currentDanger + 1
                if currentDanger > laneCount then
                    currentDanger = 1
                end
                task.wait(0.5)
            end
        end)

        return lanes[1]
    end
})

-- 🪨 RollingBoulder (스킬 업그레이드: 양쪽 회피 홈 + 경고 시스템)
GimmickRegistry:Register({
    name = "RollingBoulder",
    displayName = "굴러오는 바위",
    icon = "🪨",
    difficulty = "hard",
    description = "바위가 굴러오면 양쪽 홈으로 회피!",
    schema = {
        zStart = {type = "number", min = 0, max = 2000, default = 100, label = "시작 위치 (Z)"},
        zEnd = {type = "number", min = 0, max = 2000, default = 200, label = "끝 위치 (Z)"},
        alcoveCount = {type = "number", min = 2, max = 6, default = 3, label = "회피 홈 개수"}
    },
    builder = function(parent, data)
        if not Config.EnableRollingBoulder then return end
        local zStart = data.zStart
        local zEnd = data.zEnd
        local TW = Config.TRACK_WIDTH
        local alcoveCount = data.alcoveCount or 3
        local sectionLength = (zEnd - zStart) / alcoveCount

        -- 중앙 바위길 (좁음)
        local pathWidth = 16
        local mainPath = Instance.new("Part")
        mainPath.Name = "BoulderPath"
        mainPath.Size = Vector3.new(pathWidth, 1, zEnd - zStart)
        mainPath.Position = Vector3.new(0, 0.5, (zStart + zEnd) / 2)
        mainPath.Anchored = true
        mainPath.BrickColor = BrickColor.new("Dark stone grey")
        mainPath.Material = Enum.Material.Slate
        mainPath.Parent = parent
        table.insert(ActiveGimmicks, mainPath)

        -- 양쪽 벽 (홈 제외)
        local wallHeight = 6
        for _, side in ipairs({-1, 1}) do
            local wall = Instance.new("Part")
            wall.Size = Vector3.new(3, wallHeight, zEnd - zStart)
            wall.Position = Vector3.new(side * (pathWidth/2 + 1.5), wallHeight/2, (zStart + zEnd) / 2)
            wall.Anchored = true
            wall.BrickColor = BrickColor.new("Reddish brown")
            wall.Material = Enum.Material.Brick
            wall.Parent = parent
            table.insert(ActiveGimmicks, wall)
        end

        -- 회피 홈 생성 (양쪽에)
        local alcoves = {}
        for i = 1, alcoveCount do
            local alcoveZ = zStart + (i - 0.5) * sectionLength
            for _, side in ipairs({-1, 1}) do
                local alcoveWidth = 8
                local alcoveDepth = 10

                -- 홈 바닥
                local alcoveFloor = Instance.new("Part")
                alcoveFloor.Name = "Alcove_" .. i .. "_" .. (side == -1 and "L" or "R")
                alcoveFloor.Size = Vector3.new(alcoveDepth, 1, alcoveWidth)
                alcoveFloor.Position = Vector3.new(side * (pathWidth/2 + alcoveDepth/2 + 2), 0.5, alcoveZ)
                alcoveFloor.Anchored = true
                alcoveFloor.BrickColor = BrickColor.new("Lime green")
                alcoveFloor.Material = Enum.Material.Grass
                alcoveFloor.Parent = parent

                -- 홈 표시 (화살표)
                local alcoveSign = Instance.new("Part")
                alcoveSign.Size = Vector3.new(2, 3, 0.5)
                alcoveSign.Position = Vector3.new(side * (pathWidth/2 + 1), 2, alcoveZ)
                alcoveSign.Anchored = true
                alcoveSign.CanCollide = false
                alcoveSign.BrickColor = BrickColor.new("Lime green")
                alcoveSign.Material = Enum.Material.Neon
                alcoveSign.Parent = parent
                local signGui = Instance.new("SurfaceGui")
                signGui.Face = (side == -1) and Enum.NormalId.Right or Enum.NormalId.Left
                signGui.Parent = alcoveSign
                local signLabel = Instance.new("TextLabel")
                signLabel.Size = UDim2.new(1, 0, 1, 0)
                signLabel.BackgroundTransparency = 1
                signLabel.Text = (side == -1) and "◀" or "▶"
                signLabel.TextColor3 = Color3.new(1, 1, 1)
                signLabel.TextScaled = true
                signLabel.Font = Enum.Font.GothamBold
                signLabel.Parent = signGui

                table.insert(alcoves, {floor = alcoveFloor, sign = alcoveSign, z = alcoveZ})
                table.insert(ActiveGimmicks, alcoveFloor)
                table.insert(ActiveGimmicks, alcoveSign)
            end
        end

        -- 경고 표지판
        local warnSign = Instance.new("Part")
        warnSign.Size = Vector3.new(16, 8, 1)
        warnSign.Position = Vector3.new(0, 6, zStart - 15)
        warnSign.Anchored = true
        warnSign.CanCollide = false
        warnSign.BrickColor = BrickColor.new("Bright red")
        warnSign.Parent = parent
        local warnGui = Instance.new("SurfaceGui")
        warnGui.Face = Enum.NormalId.Front
        warnGui.Parent = warnSign
        local warnLabel = Instance.new("TextLabel")
        warnLabel.Size = UDim2.new(1, 0, 1, 0)
        warnLabel.BackgroundTransparency = 1
        warnLabel.Text = "🪨 BOULDER ZONE 🪨\n◀ 홈으로 회피! ▶"
        warnLabel.TextColor3 = Color3.new(1, 1, 1)
        warnLabel.TextScaled = true
        warnLabel.Font = Enum.Font.GothamBold
        warnLabel.Parent = warnGui
        table.insert(ActiveGimmicks, warnSign)

        -- 경고 라이트 (바위 올 때 깜빡임)
        local warnLight = Instance.new("Part")
        warnLight.Size = Vector3.new(pathWidth, 0.3, 5)
        warnLight.Position = Vector3.new(0, 0.65, zEnd - 5)
        warnLight.Anchored = true
        warnLight.CanCollide = false
        warnLight.BrickColor = BrickColor.new("Medium stone grey")
        warnLight.Material = Enum.Material.SmoothPlastic
        warnLight.Transparency = 0.3
        warnLight.Parent = parent
        table.insert(ActiveGimmicks, warnLight)

        -- 바위 스폰 로직
        task.spawn(function()
            while parent and parent.Parent do
                -- 경고 시작 (3초 전)
                warnLight.BrickColor = BrickColor.new("Bright yellow")
                warnLight.Material = Enum.Material.Neon
                for _, alcove in ipairs(alcoves) do
                    alcove.sign.BrickColor = BrickColor.new("Bright yellow")
                end
                task.wait(1)

                -- 위험 경고 (깜빡임)
                for flash = 1, 4 do
                    warnLight.BrickColor = BrickColor.new("Really red")
                    task.wait(0.25)
                    warnLight.BrickColor = BrickColor.new("Bright yellow")
                    task.wait(0.25)
                end

                -- 바위 발사!
                warnLight.BrickColor = BrickColor.new("Really red")
                local boulder = Instance.new("Part")
                boulder.Name = "Boulder"
                boulder.Size = Vector3.new(12, 12, 12)
                boulder.Position = Vector3.new(0, 7, zEnd + 10)
                boulder.Anchored = false
                boulder.Shape = Enum.PartType.Ball
                boulder.BrickColor = BrickColor.new("Dark stone grey")
                boulder.Material = Enum.Material.Slate
                boulder.Parent = parent

                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
                bv.Velocity = Vector3.new(0, 0, -40 * Config.ObstacleSpeed)
                bv.Parent = boulder

                local db = {}
                boulder.Touched:Connect(function(hit)
                    local player = Players:GetPlayerFromCharacter(hit.Parent)
                    if player and not db[player] then
                        db[player] = true
                        local newSpeed = ApplySpeedBoost(player, -5)
                        Events.ItemEffect:FireClient(player, "SpeedDown", {
                            speedPercent = newSpeed,
                            message = "🪨 으악! -5%",
                            direction = Vector3.new(0, 40, -60)
                        })
                        task.delay(1, function() db[player] = nil end)
                    end
                end)

                -- 바위가 지나간 후 안전 표시 복구
                task.delay(3, function()
                    warnLight.BrickColor = BrickColor.new("Medium stone grey")
                    warnLight.Material = Enum.Material.SmoothPlastic
                    for _, alcove in ipairs(alcoves) do
                        alcove.sign.BrickColor = BrickColor.new("Lime green")
                    end
                end)

                task.delay(10, function()
                    if boulder and boulder.Parent then boulder:Destroy() end
                end)

                task.wait(6 / Config.ObstacleSpeed)
            end
        end)

        return warnSign
    end
})

-- ⏰ DisappearingBridge
GimmickRegistry:Register({
    name = "DisappearingBridge",
    displayName = "사라지는 다리",
    icon = "⏰",
    difficulty = "hard",
    description = "밟으면 사라지는 플랫폼",
    schema = {
        z = {type = "number", min = 0, max = 2000, default = 100, label = "시작 위치 (Z)"},
        platformCount = {type = "number", min = 2, max = 20, default = 6, label = "플랫폼 수"}
    },
    builder = function(parent, data)
        if not Config.EnableDisappearingBridge then return end
        local zStart = data.z
        local platformCount = data.platformCount or 6
        local platformWidth = 10
        local gap = 6
        local TW = Config.TRACK_WIDTH
        local lava = Instance.new("Part")
        lava.Size = Vector3.new(TW, 1, platformCount * (platformWidth + gap) + 20)
        lava.Position = Vector3.new(0, -15, zStart + platformCount * (platformWidth + gap) / 2)
        lava.Anchored = true
        lava.CanCollide = false
        lava.BrickColor = BrickColor.new("Bright orange")
        lava.Material = Enum.Material.Neon
        lava.Parent = parent
        local lavaTop = Instance.new("Part")
        lavaTop.Size = Vector3.new(TW - 2, 0.5, platformCount * (platformWidth + gap) + 18)
        lavaTop.Position = Vector3.new(0, -14.5, zStart + platformCount * (platformWidth + gap) / 2)
        lavaTop.Anchored = true
        lavaTop.CanCollide = false
        lavaTop.BrickColor = BrickColor.new("Bright red")
        lavaTop.Material = Enum.Material.Neon
        lavaTop.Transparency = 0.3
        lavaTop.Parent = parent
        lava.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player then Events.ItemEffect:FireClient(player, "LavaFall", {}) end
        end)
        local warnSign = Instance.new("Part")
        warnSign.Size = Vector3.new(14, 7, 1)
        warnSign.Position = Vector3.new(0, 6, zStart - 8)
        warnSign.Anchored = true
        warnSign.CanCollide = false
        warnSign.BrickColor = BrickColor.new("Bright orange")
        warnSign.Parent = parent
        local warnGui = Instance.new("SurfaceGui")
        warnGui.Face = Enum.NormalId.Front
        warnGui.Parent = warnSign
        local warnLabel = Instance.new("TextLabel")
        warnLabel.Size = UDim2.new(1, 0, 1, 0)
        warnLabel.BackgroundTransparency = 1
        warnLabel.Text = "⏰ DISAPPEARING!\n🔥 DON'T STOP! 🔥"
        warnLabel.TextColor3 = Color3.new(1, 1, 1)
        warnLabel.TextScaled = true
        warnLabel.Font = Enum.Font.GothamBold
        warnLabel.Parent = warnGui
        for i = 1, platformCount do
            local z = zStart + (i - 1) * (platformWidth + gap)
            local xOffset = (i % 2 == 0) and -8 or 8
            local platform = Instance.new("Part")
            platform.Name = "DisappearingPlatform"
            platform.Size = Vector3.new(14, 2, platformWidth)
            platform.Position = Vector3.new(xOffset, 1, z)
            platform.Anchored = true
            platform.BrickColor = BrickColor.new("Bright orange")
            platform.Material = Enum.Material.Wood
            platform.Parent = parent
            local clockGui = Instance.new("SurfaceGui")
            clockGui.Face = Enum.NormalId.Top
            clockGui.Parent = platform
            local clockLabel = Instance.new("TextLabel")
            clockLabel.Size = UDim2.new(1, 0, 1, 0)
            clockLabel.BackgroundTransparency = 1
            clockLabel.Text = "⏰"
            clockLabel.TextScaled = true
            clockLabel.Parent = clockGui
            local db = {}
            platform.Touched:Connect(function(hit)
                local hum = hit.Parent:FindFirstChild("Humanoid")
                if hum and not db[platform] then
                    db[platform] = true
                    TweenService:Create(platform, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 0, 0)}):Play()
                    clockLabel.Text = "⏰❗"
                    task.delay(1.2, function()
                        platform.CanCollide = false
                        TweenService:Create(platform, TweenInfo.new(0.3), {
                            Transparency = 1,
                            Position = platform.Position + Vector3.new(0, -2, 0)
                        }):Play()
                        task.delay(3, function()
                            platform.Position = Vector3.new(xOffset, 1, z)
                            platform.CanCollide = true
                            platform.BrickColor = BrickColor.new("Bright orange")
                            clockLabel.Text = "⏰"
                            TweenService:Create(platform, TweenInfo.new(0.3), {Transparency = 0}):Play()
                            db[platform] = nil
                        end)
                    end)
                end
            end)
            table.insert(ActiveGimmicks, platform)
        end
        table.insert(ActiveGimmicks, lava)
        table.insert(ActiveGimmicks, lavaTop)
        table.insert(ActiveGimmicks, warnSign)
        return lava
    end
})

print("✅ GimmickRegistry: 10 gimmicks registered")

-- ============================================
-- 🏰 CREATE CASTLE EXTERIOR
-- ============================================
local function CreateCastleExterior(parent)
    print("  Building Castle Exterior...")
    
    local TL = Config.TRACK_LENGTH
    local TW = Config.TRACK_WIDTH
    
    local moat = Instance.new("Part")
    moat.Name = "Moat"
    moat.Size = Vector3.new(200, 8, 250)
    moat.Position = Vector3.new(0, -6, -50)  -- 더 아래로 이동
    moat.Anchored = true
    moat.CanCollide = false
    moat.BrickColor = BrickColor.new("Bright blue")
    moat.Material = Enum.Material.Glass  -- 유리 재질 유지
    moat.Transparency = 0.7  -- 0.3 → 0.7 (더 투명하게)
    moat.Parent = parent
    
    -- EntranceBridge 및 난간 제거됨: 스폰이 로비 바닥에서 직접 시작

    for _, xOffset in ipairs({-30, 30}) do
        local tower = Instance.new("Part")
        tower.Size = Vector3.new(20, 60, 20)
        tower.Position = Vector3.new(xOffset, 30, -15)
        tower.Anchored = true
        tower.BrickColor = BrickColor.new("Medium stone grey")
        tower.Material = Enum.Material.Brick
        tower.Parent = parent
        
        local roof = Instance.new("Part")
        roof.Size = Vector3.new(25, 20, 25)
        roof.Position = Vector3.new(xOffset, 70, -15)
        roof.Anchored = true
        roof.BrickColor = BrickColor.new("Bright red")
        roof.Material = Enum.Material.Slate
        roof.Shape = Enum.PartType.Ball
        roof.Parent = parent
        
        local flagPole = Instance.new("Part")
        flagPole.Size = Vector3.new(0.5, 25, 0.5)
        flagPole.Position = Vector3.new(xOffset, 92, -15)
        flagPole.Anchored = true
        flagPole.BrickColor = BrickColor.new("Dark stone grey")
        flagPole.Material = Enum.Material.Metal
        flagPole.Parent = parent
        
        local flag = Instance.new("Part")
        flag.Size = Vector3.new(0.2, 8, 12)
        flag.Position = Vector3.new(xOffset, 100, -9)
        flag.Anchored = true
        flag.BrickColor = BrickColor.new("Bright yellow")
        flag.Material = Enum.Material.Fabric
        flag.Parent = parent
    end
    
    local archTop = Instance.new("Part")
    archTop.Size = Vector3.new(40, 10, 8)
    archTop.Position = Vector3.new(0, 25, -15)
    archTop.Anchored = true
    archTop.BrickColor = BrickColor.new("Dark stone grey")
    archTop.Material = Enum.Material.Brick
    archTop.Parent = parent
    
    local signPart = Instance.new("Part")
    signPart.Size = Vector3.new(35, 8, 1)
    signPart.Position = Vector3.new(0, 33, -11)
    signPart.Anchored = true
    signPart.CanCollide = false
    signPart.Transparency = 1
    signPart.Parent = parent
    
    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.Parent = signPart
    local signLabel = Instance.new("TextLabel")
    signLabel.Size = UDim2.new(1,0,1,0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = "🏰 QUIZ CASTLE 🏰"
    signLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    signLabel.TextScaled = true
    signLabel.Font = Enum.Font.GothamBold
    signLabel.Parent = signGui
    
    for _, xPos in ipairs({-TW/2 - 5, TW/2 + 5}) do
        local sideWall = Instance.new("Part")
        sideWall.Size = Vector3.new(8, 25, TL + 100)
        sideWall.Position = Vector3.new(xPos, 12.5, TL/2)
        sideWall.Anchored = true
        sideWall.BrickColor = BrickColor.new("Medium stone grey")
        sideWall.Material = Enum.Material.Brick
        sideWall.Parent = parent
    end
    
    print("  ✅ Castle Exterior Complete!")
end

-- ============================================
-- 🎪 CREATE LOBBY + BRIDGE + START GATE
-- ============================================
local LobbySpawn = nil
local StartGate = nil

local function CreateLobby(parent)
    print("  Building Lobby at Z=" .. LOBBY_Z .. "...")

    local lobbyFolder = Instance.new("Folder")
    lobbyFolder.Name = "Lobby"
    lobbyFolder.Parent = parent

    local TW = Config.TRACK_WIDTH

    -- ========== 1. 로비 바닥 (Z=-30 중심) ==========
    local lobbyFloor = Instance.new("Part")
    lobbyFloor.Name = "LobbyFloor"
    lobbyFloor.Size = Vector3.new(60, 1, 40)  -- 높이 1로 줄임
    lobbyFloor.Position = Vector3.new(0, -0.5, LOBBY_Z)  -- Y=-0.5 (윗면 Y=0)
    lobbyFloor.Anchored = true
    lobbyFloor.BrickColor = BrickColor.new("Brick yellow")
    lobbyFloor.Material = Enum.Material.Cobblestone
    lobbyFloor.Parent = lobbyFolder

    -- ========== 2. 스폰 위치 (다리 전) ==========
    LobbySpawn = Instance.new("SpawnLocation")
    LobbySpawn.Name = "LobbySpawn"
    LobbySpawn.Size = Vector3.new(40, 0.1, 30)  -- 매우 얇게
    LobbySpawn.Position = Vector3.new(0, 0.1, LOBBY_Z)  -- 바닥 위로
    LobbySpawn.Anchored = true
    LobbySpawn.Transparency = 1
    LobbySpawn.CanCollide = false
    LobbySpawn.Neutral = true
    LobbySpawn.Enabled = true
    LobbySpawn.Parent = Workspace
    print("  ✅ LobbySpawn created at Z=" .. LOBBY_Z)

    -- 다리 제거됨: 로비 바닥에서 바로 출발 게이트로 이동

    -- ========== 4. 출발 게이트 ==========
    StartGate = Instance.new("Part")
    StartGate.Name = "StartGate"
    StartGate.Size = Vector3.new(TW + 4, 15, 3)
    StartGate.Position = Vector3.new(0, 7.5, GATE_Z)
    StartGate.Anchored = true
    StartGate.CanCollide = true
    StartGate.BrickColor = BrickColor.new("Bright red")
    StartGate.Material = Enum.Material.Metal
    StartGate.Transparency = 0.3
    StartGate.Parent = lobbyFolder

    local gateGui = Instance.new("SurfaceGui")
    gateGui.Face = Enum.NormalId.Back
    gateGui.Parent = StartGate
    local gateLabel = Instance.new("TextLabel")
    gateLabel.Name = "GateLabel"
    gateLabel.Size = UDim2.new(1, 0, 1, 0)
    gateLabel.BackgroundTransparency = 1
    gateLabel.Text = "⏳ WAITING..."
    gateLabel.TextColor3 = Color3.new(1, 1, 1)
    gateLabel.TextScaled = true
    gateLabel.Font = Enum.Font.GothamBold
    gateLabel.Parent = gateGui

    print("  ✅ StartGate created at Z=" .. GATE_Z)
    print("  ✅ Lobby Complete!")
    return lobbyFolder
end

-- ============================================
-- 🏃 CREATE RACE TRACK
-- ============================================
local function CreateRaceTrack(parent)
    print("  Building Race Track (starting at Z=" .. COURSE_START_Z .. ")...")

    local trackFolder = Instance.new("Folder")
    trackFolder.Name = "RaceTrack"
    trackFolder.Parent = parent

    local TL = Config.TRACK_LENGTH
    local TW = Config.TRACK_WIDTH
    local OFFSET = COURSE_OFFSET  -- 코스 시작 오프셋 (30)

    local floorSections = {
        {OFFSET + 0, OFFSET + TL * 0.2, "Brick yellow", 0},
        {OFFSET + TL * 0.2, OFFSET + TL * 0.4, "Medium stone grey", 0},
        {OFFSET + TL * 0.4, OFFSET + TL * 0.6, "Sand blue", 0},
        {OFFSET + TL * 0.6, OFFSET + TL * 0.8, "Nougat", 0},
        {OFFSET + TL * 0.8, OFFSET + TL, "Bright yellow", 0},
    }

    for _, sec in ipairs(floorSections) do
        local startZ, endZ, color, height = sec[1], sec[2], sec[3], sec[4]
        local length = endZ - startZ

        local floor = Instance.new("Part")
        floor.Size = Vector3.new(TW, 2, length)
        floor.Position = Vector3.new(0, -1 + height, startZ + length/2)
        floor.Anchored = true
        floor.BrickColor = BrickColor.new(color)
        floor.Material = Enum.Material.Cobblestone
        floor.Parent = trackFolder
    end

    -- RaceSpawn 제거됨: 플레이어가 직접 다리를 건너서 이동

    local finishLine = Instance.new("Part")
    finishLine.Name = "FinishLine"
    finishLine.Size = Vector3.new(TW, 20, 5)
    finishLine.Position = Vector3.new(0, 10, OFFSET + TL - 2)  -- 코스 끝 (Z=2098)
    finishLine.Anchored = true
    finishLine.CanCollide = false
    finishLine.BrickColor = BrickColor.new("Bright yellow")
    finishLine.Material = Enum.Material.Neon
    finishLine.Transparency = 0.5
    finishLine.Parent = trackFolder
    
    local finishGui = Instance.new("SurfaceGui")
    finishGui.Face = Enum.NormalId.Back
    finishGui.Parent = finishLine
    local finishLabel = Instance.new("TextLabel")
    finishLabel.Size = UDim2.new(1,0,1,0)
    finishLabel.BackgroundTransparency = 1
    finishLabel.Text = "🏆 FINISH 🏆"
    finishLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    finishLabel.TextScaled = true
    finishLabel.Font = Enum.Font.GothamBold
    finishLabel.Parent = finishGui

    -- 🎉 피니시 구역 축하 벽 (떨어짐 방지)
    local finishAreaLength = 50
    local wallHeight = 25
    local wallThickness = 3

    -- 뒷벽 (Congratulations!)
    local backWall = Instance.new("Part")
    backWall.Name = "FinishBackWall"
    backWall.Size = Vector3.new(TW + 10, wallHeight, wallThickness)
    backWall.Position = Vector3.new(0, wallHeight / 2, OFFSET + TL + finishAreaLength)
    backWall.Anchored = true
    backWall.CanCollide = true
    backWall.BrickColor = BrickColor.new("Gold")
    backWall.Material = Enum.Material.Neon
    backWall.Parent = trackFolder

    local congratsGui = Instance.new("SurfaceGui")
    congratsGui.Face = Enum.NormalId.Back
    congratsGui.Parent = backWall
    local congratsLabel = Instance.new("TextLabel")
    congratsLabel.Size = UDim2.new(1, 0, 1, 0)
    congratsLabel.BackgroundTransparency = 1
    congratsLabel.Text = "🎉 CONGRATULATIONS! 🎉"
    congratsLabel.TextColor3 = Color3.new(1, 1, 1)
    congratsLabel.TextScaled = true
    congratsLabel.Font = Enum.Font.GothamBold
    congratsLabel.Parent = congratsGui

    -- 앞쪽 표시 (반대편)
    local congratsGuiFront = Instance.new("SurfaceGui")
    congratsGuiFront.Face = Enum.NormalId.Front
    congratsGuiFront.Parent = backWall
    local congratsLabelFront = Instance.new("TextLabel")
    congratsLabelFront.Size = UDim2.new(1, 0, 1, 0)
    congratsLabelFront.BackgroundTransparency = 1
    congratsLabelFront.Text = "🎉 CONGRATULATIONS! 🎉"
    congratsLabelFront.TextColor3 = Color3.new(1, 1, 1)
    congratsLabelFront.TextScaled = true
    congratsLabelFront.Font = Enum.Font.GothamBold
    congratsLabelFront.Parent = congratsGuiFront

    -- 왼쪽 벽
    local leftWall = Instance.new("Part")
    leftWall.Name = "FinishLeftWall"
    leftWall.Size = Vector3.new(wallThickness, wallHeight, finishAreaLength + 10)
    leftWall.Position = Vector3.new(-TW / 2 - 5, wallHeight / 2, OFFSET + TL + finishAreaLength / 2)
    leftWall.Anchored = true
    leftWall.CanCollide = true
    leftWall.BrickColor = BrickColor.new("Gold")
    leftWall.Material = Enum.Material.Neon
    leftWall.Transparency = 0.3
    leftWall.Parent = trackFolder

    -- 오른쪽 벽
    local rightWall = Instance.new("Part")
    rightWall.Name = "FinishRightWall"
    rightWall.Size = Vector3.new(wallThickness, wallHeight, finishAreaLength + 10)
    rightWall.Position = Vector3.new(TW / 2 + 5, wallHeight / 2, OFFSET + TL + finishAreaLength / 2)
    rightWall.Anchored = true
    rightWall.CanCollide = true
    rightWall.BrickColor = BrickColor.new("Gold")
    rightWall.Material = Enum.Material.Neon
    rightWall.Transparency = 0.3
    rightWall.Parent = trackFolder

    -- 피니시 구역 바닥
    local finishFloor = Instance.new("Part")
    finishFloor.Name = "FinishFloor"
    finishFloor.Size = Vector3.new(TW + 10, 2, finishAreaLength)
    finishFloor.Position = Vector3.new(0, -1, OFFSET + TL + finishAreaLength / 2)
    finishFloor.Anchored = true
    finishFloor.CanCollide = true
    finishFloor.BrickColor = BrickColor.new("Bright yellow")
    finishFloor.Material = Enum.Material.Neon
    finishFloor.Transparency = 0.5
    finishFloor.Parent = trackFolder

    print("  🎉 Finish celebration area created!")
    
    finishLine.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and GameState.phase == "Racing" then
            if table.find(GameState.playersInRace, player) and not table.find(GameState.finishedPlayers, player) then
                table.insert(GameState.finishedPlayers, player)
                local rank = #GameState.finishedPlayers
                local raceTime = tick() - GameState.raceStartTime
                
                SavePlayerStats(player, raceTime, rank)
                
                if PlayerData[player] then
                    if not PlayerData[player].bestTime or raceTime < PlayerData[player].bestTime then
                        PlayerData[player].bestTime = raceTime
                    end
                    if rank == 1 then
                        PlayerData[player].wins = (PlayerData[player].wins or 0) + 1
                    end
                    PlayerData[player].lastRaceTime = raceTime
                end
                
                AwardXP(player, XPRewards.RaceComplete, "Race Complete")
                
                if rank == 1 then
                    AwardXP(player, XPRewards.FirstPlace, "1st Place!")
                elseif rank == 2 then
                    AwardXP(player, XPRewards.SecondPlace, "2nd Place!")
                elseif rank == 3 then
                    AwardXP(player, XPRewards.ThirdPlace, "3rd Place!")
                end
                
                PlayerStreaks[player] = (PlayerStreaks[player] or 0) + 1
                if PlayerStreaks[player] >= 3 then
                    AwardXP(player, XPRewards.StreakBonus, "3 Race Streak!")
                    PlayerStreaks[player] = 0
                end
                
                Events.GameEvent:FireClient(player, "Finished", {
                    rank = rank,
                    time = raceTime,
                    totalPlayers = #GameState.playersInRace,
                    bestTime = PlayerData[player] and PlayerData[player].bestTime
                })
                
                Events.RoundUpdate:FireAllClients("PlayerFinished", {
                    playerName = player.Name,
                    rank = rank,
                    time = raceTime
                })
                
                if #GameState.finishedPlayers >= #GameState.playersInRace then
                    EndRound()
                end
            end
        end
    end)
    
    print("  ✅ Race Track Complete!")
    return trackFolder
end
-- ============================================
-- 🏗️ COURSE ENGINE
-- ============================================
local CourseEngine = {}

function CourseEngine:BuildFromData(parent, courseData)
    -- 디버그: courseData 확인
    if not courseData then
        warn("❌ CourseEngine: courseData is nil!")
        return 0, 1
    end
    if not courseData.metadata then
        warn("❌ CourseEngine: courseData.metadata is nil!")
        return 0, 1
    end

    local courseName = courseData.metadata.name or "Unknown"
    local courseAuthor = courseData.metadata.author or "Unknown"
    print("🏗️ Building course:", courseName, "by", courseAuthor)

    local builtCount = 0
    local errorCount = 0

    if not courseData.gimmicks then
        warn("❌ CourseEngine: courseData.gimmicks is nil!")
        return 0, 1
    end

    for i, gimmick in ipairs(courseData.gimmicks) do
        -- Z 좌표에 COURSE_OFFSET 자동 적용
        local offsetGimmick = {}
        for k, v in pairs(gimmick) do
            if k == "z" or k == "triggerZ" or k == "gateZ" or k == "elevZ" or k == "zStart" or k == "zEnd" then
                offsetGimmick[k] = v + COURSE_OFFSET
            else
                offsetGimmick[k] = v
            end
        end

        local success, result = pcall(function()
            return GimmickRegistry:Build(offsetGimmick.type, parent, offsetGimmick)
        end)

        if success and result then
            builtCount = builtCount + 1
        elseif success then
            -- nil returned (config disabled)
            builtCount = builtCount + 1
        else
            errorCount = errorCount + 1
            warn(string.format("[CourseEngine] Failed to build gimmick #%d (%s): %s",
                i, gimmick.type, tostring(result)))
        end
    end

    print(string.format("✅ Course complete: %d gimmicks built, %d errors",
        builtCount, errorCount))

    return builtCount, errorCount
end

function CourseEngine:ValidateCourseData(courseData)
    local errors = {}

    if not courseData.metadata then
        table.insert(errors, "Missing metadata")
    end

    if not courseData.gimmicks or #courseData.gimmicks == 0 then
        table.insert(errors, "No gimmicks defined")
    end

    for i, gimmick in ipairs(courseData.gimmicks or {}) do
        if not gimmick.type then
            table.insert(errors, string.format("Gimmick #%d missing type", i))
        elseif not GimmickRegistry.builders[gimmick.type] then
            table.insert(errors, string.format("Unknown gimmick type: %s", gimmick.type))
        end
    end

    return #errors == 0, errors
end

-- ============================================
-- 📋 FALLBACK COURSE DATA (CourseLibrary 없을 때 사용)
-- ============================================
local FallbackCourseData = {
    metadata = {
        id = "fallback",
        name = "Quiz Castle Classic (Fallback)",
        author = "System",
        version = "3.2",
        length = 2000,
        difficulty = "medium"
    },
    gimmicks = {
        {type = "RotatingBar", z = 60, width = 28, height = 3, speed = 1.5},
        {type = "RotatingBar", z = 100, width = 30, height = 3, speed = 1.8},
        {type = "QuizGate", id = 1, triggerZ = 150, gateZ = 180, options = 2},
        {type = "RotatingBar", z = 250, width = 26, height = 3, speed = 2},
        {type = "QuizGate", id = 2, triggerZ = 320, gateZ = 350, options = 3},
        {type = "JumpPad", x = 0, y = 0.5, z = 430},
        {type = "JumpPad", x = 0, y = 0.5, z = 500},
        {type = "JumpPad", x = 0, y = 0.5, z = 570},
        {type = "Elevator", id = 1, triggerZ = 620, elevZ = 670, options = 3},
        {type = "DisappearingBridge", z = 750, platformCount = 6},
        {type = "SlimeZone", z = 830, length = 80},
        {type = "QuizGate", id = 3, triggerZ = 960, gateZ = 990, options = 4},
        {type = "ConveyorBelt", z = 1040, length = 60, direction = -1},
        {type = "ElectricFloor", z = 1130, length = 60},
        {type = "RollingBoulder", zStart = 1220, zEnd = 1380},
        {type = "PunchingCorridor", z = 1280, length = 100},
        {type = "QuizGate", id = 4, triggerZ = 1420, gateZ = 1450, options = 3},
        {type = "Elevator", id = 2, triggerZ = 1500, elevZ = 1550, options = 4},
        {type = "SlimeZone", z = 1620, length = 70},
        {type = "RotatingBar", z = 1730, width = 34, height = 3, speed = 2.5},
        {type = "RotatingBar", z = 1760, width = 34, height = 7, speed = -2},
        {type = "QuizGate", id = 5, triggerZ = 1800, gateZ = 1830, options = 2},
        {type = "ConveyorBelt", z = 1860, length = 40, direction = -1},
        {type = "ElectricFloor", z = 1920, length = 50},
        {type = "RotatingBar", z = 1970, width = 36, height = 3, speed = 3}
    }
}

-- Fallback을 CourseManager에 등록
CourseManager.courseLibrary["fallback"] = FallbackCourseData
CourseManager.courseLibrary["classic"] = FallbackCourseData  -- classic도 fallback으로 초기화

-- ============================================
-- 🏗️ BUILD FULL COURSE (CourseManager 사용)
-- ============================================
local function BuildCourse(parent)
    local courseData = CourseManager:GetCurrentCourse()
    if not courseData then
        courseData = FallbackCourseData
        warn("⚠️ No course loaded, using fallback")
    end
    CourseEngine:BuildFromData(parent, courseData)
end

-- 코스 변경 및 재시작 함수
local function ChangeCourse(courseId, source)
    if CourseManager:SetCurrentCourse(courseId, source) then
        -- 다음 라운드에 적용됨
        return true, CourseManager.currentCourse.metadata.name
    end
    return false, "Course not found"
end

-- 코스 재빌드 (게임 중 코스 변경 시)
local function RebuildCourse()
    if TrackFolder then
        ClearActiveGimmicks()
        -- 기존 기믹 제거
        for _, child in ipairs(TrackFolder:GetChildren()) do
            if child.Name ~= "Floor" and child.Name ~= "Wall" and child.Name ~= "StartGate" and child.Name ~= "FinishLine" then
                child:Destroy()
            end
        end
        BuildCourse(TrackFolder)
        CreateItemBoxes(TrackFolder)
        print("🔄 Course rebuilt!")
    end
end

-- ============================================
-- 📦 ITEM SYSTEM
-- ============================================
local itemList = {"Banana", "Booster", "Shield", "Lightning"}

local function CreateItemBoxes(parent)
    local TL = Config.TRACK_LENGTH
    local boxCount = 0

    for z = 100, TL - 150, 200 do
        boxCount = boxCount + 1
        local x = math.random(-12, 12)
        local box = Instance.new("Part")
        box.Name = "ItemBox"
        box.Size = Vector3.new(5, 5, 5)
        box.Position = Vector3.new(x, 4, COURSE_OFFSET + z)  -- 오프셋 적용
        box.Anchored = true
        box.CanCollide = false
        box.BrickColor = BrickColor.new("Bright yellow")
        box.Material = Enum.Material.Neon
        box.Transparency = 0.2
        box.Parent = parent

        -- 🔄 PERFORMANCE: 개별 루프 대신 중앙 관리 테이블에 등록
        table.insert(ItemBoxes, {
            part = box,
            rotation = math.random(0, 360)
        })

        local db, active = {}, true
        box.Touched:Connect(function(hit)
            if not active then return end

            local char = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)

            -- 액세서리 등일 경우 부모의 부모 확인
            if not player and char and char.Parent then
                player = Players:GetPlayerFromCharacter(char.Parent)
                char = char.Parent
            end

            if not player then return end
            if not PlayerData[player] then
                print("⚠️ ItemBox: No PlayerData for", player.Name)
                return
            end
            if db[player] then return end
            if PlayerData[player].currentItem then
                -- 이미 아이템 보유 중
                return
            end

            db[player] = true
            active = false
            box.Transparency = 0.85

            local itemType = itemList[math.random(#itemList)]
            PlayerData[player].currentItem = itemType
            print("📦 Item given to", player.Name, ":", itemType)
            Events.ItemEffect:FireClient(player, "GotItem", {itemType = itemType})

            task.delay(10, function()
                active = true
                box.Transparency = 0.2
                db[player] = nil
            end)
        end)
    end

    print("📦 ItemBoxes created:", boxCount)
end

Events.UseItem.OnServerEvent:Connect(function(player, itemType)
    local data = PlayerData[player]
    if not data or not data.currentItem then return end
    local char = player.Character
    local rp = char and char:FindFirstChild("HumanoidRootPart")
    if not rp then return end
    
    local usedItem = data.currentItem
    data.currentItem = nil  -- 아이템 먼저 소모
    
    -- 클라이언트에 아이템 사용됨 알림
    Events.ItemEffect:FireClient(player, "ItemUsed", {itemType = usedItem})
    
    if usedItem == "Banana" then
        local banana = Instance.new("Part")
        banana.Size = Vector3.new(2.5, 1.2, 2.5)
        banana.Position = rp.Position - rp.CFrame.LookVector * 6
        banana.Position = Vector3.new(banana.Position.X, 0.6, banana.Position.Z)
        banana.Anchored = true
        banana.BrickColor = BrickColor.new("Bright yellow")
        banana.Parent = workspace
        Debris:AddItem(banana, 35)
        local bd = {}
        banana.Touched:Connect(function(hit)
            local hp = Players:GetPlayerFromCharacter(hit.Parent)
            if hp and hp ~= player and not bd[hp] then
                bd[hp] = true
                Events.ItemEffect:FireClient(hp, "Stun", {duration = 1.5})
                banana:Destroy()
            end
        end)
    elseif usedItem == "Booster" then
        -- 실제 속도 증가
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            local origSpeed = hum.WalkSpeed
            local boostSpeed = origSpeed * 1.6  -- 60% 속도 증가
            hum.WalkSpeed = boostSpeed
            Events.ItemEffect:FireClient(player, "SpeedBoost", {duration = 4.5})

            -- 4.5초 후 원래 속도로 복구
            task.delay(4.5, function()
                if hum and hum.WalkSpeed == boostSpeed then
                    hum.WalkSpeed = origSpeed
                end
            end)
        end
    elseif usedItem == "Shield" then
        local shield = Instance.new("Part")
        shield.Size = Vector3.new(6,6,6)
        shield.CFrame = rp.CFrame
        shield.Anchored = false
        shield.CanCollide = false
        shield.Shape = Enum.PartType.Ball
        shield.Material = Enum.Material.ForceField
        shield.Transparency = 0.7
        shield.Parent = char
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1 = rp, shield
        weld.Parent = shield
        Debris:AddItem(shield, 14)
        Events.ItemEffect:FireClient(player, "Shielded", {duration = 14})
    elseif usedItem == "Lightning" then
        for _, op in ipairs(Players:GetPlayers()) do
            if op ~= player and table.find(GameState.playersInRace, op) then
                Events.ItemEffect:FireClient(op, "LightningHit", {duration = 1.8})
            end
        end
    end
end)

-- ============================================
-- 🎮 GAME FLOW
-- ============================================
local CastleFolder = nil
local LobbyFolder = nil
local TrackFolder = nil

local function ClearActiveGimmicks()
    for _, gimmick in ipairs(ActiveGimmicks) do
        if gimmick and gimmick.Parent then
            gimmick:Destroy()
        end
    end
    ActiveGimmicks = {}
    RotatingObjects = {}
    ItemBoxes = {}
end

local function InitializeMap()
    print("🏰 Building Quiz Castle v3.2...")

    -- 기존 기믹들 정리
    ClearActiveGimmicks()

    local existing = workspace:FindFirstChild("QuizCastle")
    if existing then existing:Destroy() end
    
    CastleFolder = Instance.new("Folder")
    CastleFolder.Name = "QuizCastle"
    CastleFolder.Parent = workspace
    
    CreateCastleExterior(CastleFolder)
    LobbyFolder = CreateLobby(CastleFolder)
    TrackFolder = CreateRaceTrack(CastleFolder)
    BuildCourse(TrackFolder)
    CreateItemBoxes(TrackFolder)
    
    print("🏰 Quiz Castle v3.2 Ready!")

    -- 디버그: 게임 내 모든 SpawnLocation 확인
    local spawnCount = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            spawnCount = spawnCount + 1
            print("📍 SpawnLocation found:", obj.Name, "at", obj.Position)
        end
    end
    print("📍 Total SpawnLocations:", spawnCount)
end

-- 🎯 로비 위치 상수 (새 레이아웃: Z=-30)
local LOBBY_POSITION = Vector3.new(0, 3, LOBBY_Z)

local function TeleportToLobby(player)
    local char = player.Character
    if char then
        local rp = char:FindFirstChild("HumanoidRootPart")
        if rp then
            local targetPos = LOBBY_POSITION + Vector3.new(math.random(-10, 10), 0, math.random(-5, 5))
            rp.CFrame = CFrame.new(targetPos)
        end
    end
end

-- TeleportToRace 삭제됨: 플레이어가 직접 다리를 건너서 이동

local function UpdateLobbyUI()
    local lobbyPlayers = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if PlayerData[player] and not table.find(GameState.playersInRace, player) then
            lobbyPlayers = lobbyPlayers + 1
        end
    end
    
    Events.LobbyUpdate:FireAllClients({
        playersInLobby = lobbyPlayers,
        minPlayers = Config.MIN_PLAYERS,
        phase = GameState.phase,
        countdown = GameState.countdown
    })
end

local function OpenStartGate()
    if StartGate then
        StartGate.CanCollide = false
        StartGate.Transparency = 0.9
        local gui = StartGate:FindFirstChildOfClass("SurfaceGui")
        if gui then
            local label = gui:FindFirstChild("GateLabel")
            if label then label.Text = "🏃 GO!" end
        end
    end
end

local function CloseStartGate()
    if StartGate then
        StartGate.CanCollide = true
        StartGate.Transparency = 0.3
        local gui = StartGate:FindFirstChildOfClass("SurfaceGui")
        if gui then
            local label = gui:FindFirstChild("GateLabel")
            if label then label.Text = "⏳ WAITING..." end
        end
    end
end

function StartCountdown()
    print("⏰ StartCountdown! Players walk to gate themselves (15sec)")
    GameState.phase = "Countdown"
    GameState.countdown = Config.LOBBY_COUNTDOWN
    GameState.sessionLocked = false  -- 세션 잠금 플래그

    CloseStartGate()

    -- 현재 있는 플레이어들을 레이스 참가자로 등록
    GameState.playersInRace = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if PlayerData[player] then
            table.insert(GameState.playersInRace, player)
        end
    end
    print("👥 Players in race:", #GameState.playersInRace)

    -- 15초 카운트다운
    for i = Config.LOBBY_COUNTDOWN, 1, -1 do
        GameState.countdown = i

        -- 10초 남았을 때 (5초 경과) 세션 잠금
        if i == 10 and not GameState.sessionLocked then
            GameState.sessionLocked = true
            print("🔒 Session LOCKED! No new entries.")
            Events.RoundUpdate:FireAllClients("SessionLocked", {})
        end

        -- 게이트 UI 업데이트
        if StartGate then
            local gui = StartGate:FindFirstChildOfClass("SurfaceGui")
            if gui then
                local label = gui:FindFirstChild("GateLabel")
                if label then
                    if GameState.sessionLocked then
                        label.Text = "🔒 " .. i
                    else
                        label.Text = "⏰ " .. i
                    end
                end
            end
        end

        Events.RoundUpdate:FireAllClients("Countdown", {
            count = i,
            locked = GameState.sessionLocked
        })
        task.wait(1)

        -- 플레이어 수 체크
        local stillReady = 0
        for _, p in ipairs(GameState.playersInRace) do
            if p and p.Parent then stillReady = stillReady + 1 end
        end

        if stillReady < Config.MIN_PLAYERS then
            GameState.phase = "Waiting"
            GameState.sessionLocked = false
            CloseStartGate()
            Events.RoundUpdate:FireAllClients("CountdownCancelled", {})
            print("❌ Countdown cancelled - not enough players")
            return
        end
    end

    StartRace()
end

function StartRace()
    GameState.phase = "Racing"
    GameState.roundNumber = GameState.roundNumber + 1
    GameState.finishedPlayers = {}
    GameState.raceStartTime = tick()

    -- 모든 플레이어 속도 100%로 리셋
    for _, player in ipairs(GameState.playersInRace) do
        ResetSpeedBoost(player)
    end

    OpenStartGate()

    Events.RoundUpdate:FireAllClients("RaceStart", {
        roundNumber = GameState.roundNumber,
        totalPlayers = #GameState.playersInRace,
        speedPercent = 100  -- 시작 속도
    })
    
    task.spawn(function()
        while GameState.phase == "Racing" do
            local elapsed = tick() - GameState.raceStartTime

            -- 순위 계산 (Z 위치 기준)
            local playerPositions = {}
            for _, player in ipairs(GameState.playersInRace) do
                if player and player.Parent and not table.find(GameState.finishedPlayers, player) then
                    local char = player.Character
                    local z = 0
                    if char then
                        local rp = char:FindFirstChild("HumanoidRootPart")
                        if rp then
                            z = rp.Position.Z
                        end
                    end
                    table.insert(playerPositions, {player = player, z = z})
                end
            end

            -- Z 위치로 정렬 (내림차순 = 앞서가는 순)
            table.sort(playerPositions, function(a, b) return a.z > b.z end)

            -- 각 플레이어에게 시간, 순위, 진행도 전송
            for rank, data in ipairs(playerPositions) do
                local player = data.player
                local z = data.z
                -- 진행도: (현재Z - 코스시작) / 트랙길이 * 100
                local progress = math.clamp((z - COURSE_START_Z) / Config.TRACK_LENGTH * 100, 0, 100)
                Events.TimeUpdate:FireClient(player, elapsed, rank, math.floor(progress))
            end

            task.wait(0.1)
        end
    end)
    
    task.delay(300, function()
        if GameState.phase == "Racing" then
            EndRound()
        end
    end)
end

function EndRound()
    GameState.phase = "Ended"
    
    CloseStartGate()
    
    local results = {}
    for rank, player in ipairs(GameState.finishedPlayers) do
        table.insert(results, {
            rank = rank,
            name = player.Name,
            time = PlayerData[player] and PlayerData[player].lastRaceTime or 0
        })
    end
    
    Events.RoundUpdate:FireAllClients("RoundEnd", {
        results = results,
        totalPlayers = #GameState.playersInRace
    })
    
    local lb = GetLeaderboard()
    for _, player in ipairs(Players:GetPlayers()) do
        Events.LeaderboardUpdate:FireClient(player, lb)
    end
    
    task.delay(Config.INTERMISSION, function()
        for _, player in ipairs(Players:GetPlayers()) do
            TeleportToLobby(player)
            PlayerGateAnswers[player] = {}
        end
        
        GameState.phase = "Waiting"
        GameState.playersInRace = {}
        GameState.finishedPlayers = {}
        
        Events.RoundUpdate:FireAllClients("Intermission", {duration = 0})
    end)
end

-- ============================================
-- 🎮 PLAYER MANAGEMENT
-- ============================================
local function IsAdmin(player)
    return Admins[player.UserId] or player.UserId == game.CreatorId
end

local function InitPlayer(player)
    local stats = GetPlayerStats(player)
    local xp = stats.xp
    local level = GetLevelFromXP(xp)
    local progress, xpInLevel, xpNeeded = GetLevelProgress(xp, level)
    
    PlayerData[player] = {
        bestTime = stats.bestTime,
        wins = stats.wins,
        xp = xp,
        level = level,
        currentItem = nil,
        lastRaceTime = nil
    }
    PlayerGateAnswers[player] = {}
    PlayerStreaks[player] = 0
    
    Events.GameEvent:FireClient(player, "InitPlayer", {
        bestTime = stats.bestTime,
        wins = stats.wins,
        xp = xp,
        level = level,
        levelName = LevelConfig[level].name,
        levelIcon = LevelConfig[level].icon,
        trailType = LevelConfig[level].trailType,
        progress = progress,
        xpInLevel = xpInLevel,
        xpNeeded = xpNeeded,
        isAdmin = IsAdmin(player),
        config = Config,
        levelConfig = LevelConfig
    })
    
    Events.TrailUpdate:FireAllClients({
        playerName = player.Name,
        trailType = LevelConfig[level].trailType,
        level = level
    })
    
    task.delay(1, function()
        Events.LeaderboardUpdate:FireClient(player, GetLeaderboard())
        UpdateLobbyUI()
    end)
end

-- ============================================
-- 🎮 PLAYER SETUP (함수로 분리)
-- ============================================
local function SetupPlayer(player)
    InitPlayer(player)

    -- RespawnLocation 설정 (Roblox 기본 시스템 사용)
    if LobbySpawn then
        player.RespawnLocation = LobbySpawn
        print("✅ Set RespawnLocation for", player.Name, "to LobbySpawn")
    end

    player.CharacterAdded:Connect(function(char)
        print("🔄 CharacterAdded for", player.Name, "Phase:", GameState.phase)

        -- 레이싱 중에 리스폰하면 레이스에서 제외
        if GameState.phase == "Racing" then
            local idx = table.find(GameState.playersInRace, player)
            if idx then
                table.remove(GameState.playersInRace, idx)
                print("🏃 Removed", player.Name, "from race (respawned)")
            end
        end

        -- 속도 리셋 (새 캐릭터니까)
        ResetSpeedBoost(player)

        PlayerGateAnswers[player] = {}
        if PlayerData[player] then
            PlayerData[player].currentItem = nil
            PlayerData[player].lastSafePosition = nil
            PlayerData[player].isInvincible = false
            
            local level = PlayerData[player].level or 1
            Events.TrailUpdate:FireAllClients({
                playerName = player.Name,
                trailType = LevelConfig[level].trailType,
                level = level
            })
        end
        
        UpdateLobbyUI()
        
        -- ============================================
        -- 🔄 RESPAWN SYSTEM - Out of Bounds Detection
        -- ============================================
        local humanoidRootPart = char:WaitForChild("HumanoidRootPart", 5)
        local humanoid = char:WaitForChild("Humanoid", 5)
        if not humanoidRootPart or not humanoid then return end
        
        -- Safe position tracking loop (every 0.5 seconds)
        task.spawn(function()
            while char and char.Parent and humanoid and humanoid.Health > 0 do
                task.wait(0.5)
                
                if GameState.phase == "Racing" and PlayerData[player] then
                    local pos = humanoidRootPart.Position
                    -- Check if within track bounds (X: -50 to TRACK_WIDTH+50, Z: -100 to TRACK_LENGTH+100, Y > -20)
                    if pos.X >= -50 and pos.X <= Config.TRACK_WIDTH + 50 and
                       pos.Z >= -100 and pos.Z <= Config.TRACK_LENGTH + 100 and
                       pos.Y > -20 then
                        PlayerData[player].lastSafePosition = pos
                    end
                end
            end
        end)
        
        -- Out of bounds detection loop (every 0.2 seconds)
        task.spawn(function()
            while char and char.Parent and humanoid and humanoid.Health > 0 do
                task.wait(0.2)
                
                if GameState.phase == "Racing" and PlayerData[player] and not PlayerData[player].isInvincible then
                    local pos = humanoidRootPart.Position
                    local isOutOfBounds = false
                    
                    -- Check if out of bounds
                    if pos.Y < -30 then -- Fell too far
                        isOutOfBounds = true
                    elseif pos.X < -80 or pos.X > Config.TRACK_WIDTH + 80 then -- Too far left/right
                        isOutOfBounds = true
                    elseif pos.Z < -150 or pos.Z > Config.TRACK_LENGTH + 150 then -- Too far back/forward
                        isOutOfBounds = true
                    end
                    
                    if isOutOfBounds then
                        PlayerData[player].isInvincible = true
                        
                        -- Send respawning notification
                        Events.ItemEffect:FireClient(player, "Respawning", {})
                        
                        -- Wait 3 seconds then teleport
                        task.wait(3)
                        
                        if char and char.Parent and humanoidRootPart then
                            local safePos = PlayerData[player].lastSafePosition
                            if not safePos then
                                -- Default to race start (with COURSE_OFFSET)
                                safePos = Vector3.new(0, 3, COURSE_OFFSET + 10)
                            end
                            
                            humanoidRootPart.CFrame = CFrame.new(safePos + Vector3.new(0, 5, 0))
                            humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                            
                            -- Send invincible notification
                            Events.ItemEffect:FireClient(player, "Invincible", {})
                            
                            -- Add visual invincibility (ForceField + transparency)
                            local forceField = Instance.new("ForceField")
                            forceField.Name = "RespawnShield"
                            forceField.Visible = true
                            forceField.Parent = char
                            
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Transparency = math.min(part.Transparency + 0.5, 0.8)
                                end
                            end
                            
                            -- Remove invincibility after 3 seconds
                            task.delay(3, function()
                                if char and char.Parent then
                                    local shield = char:FindFirstChild("RespawnShield")
                                    if shield then shield:Destroy() end
                                    
                                    for _, part in ipairs(char:GetDescendants()) do
                                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                            part.Transparency = math.max(part.Transparency - 0.5, 0)
                                        end
                                    end
                                end
                                
                                if PlayerData[player] then
                                    PlayerData[player].isInvincible = false
                                end
                            end)
                        else
                            if PlayerData[player] then
                                PlayerData[player].isInvincible = false
                            end
                        end
                    end
                end
            end
        end)
    end)
end

-- 새로 들어오는 플레이어
Players.PlayerAdded:Connect(SetupPlayer)

-- 이미 존재하는 플레이어 처리 (서버보다 먼저 로드된 경우)
for _, existingPlayer in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        SetupPlayer(existingPlayer)
    end)
end
print("✅ Existing players handled:", #Players:GetPlayers())

Players.PlayerRemoving:Connect(function(player)
    if PlayerData[player] then
        SavePlayerXP(player, PlayerData[player].xp or 0)
    end
    
    PlayerData[player] = nil
    PlayerGateAnswers[player] = nil
    PlayerStreaks[player] = nil
    
    local idx = table.find(GameState.playersInRace, player)
    if idx then table.remove(GameState.playersInRace, idx) end
    
    UpdateLobbyUI()
end)

for _, player in ipairs(Players:GetPlayers()) do
    InitPlayer(player)
end

-- ============================================
-- 🔄 GAME LOOP
-- ============================================
task.spawn(function()
    while true do
        task.wait(1)
        
        if GameState.phase == "Waiting" then
            local readyPlayers = 0
            for _, player in ipairs(Players:GetPlayers()) do
                if PlayerData[player] then
                    readyPlayers = readyPlayers + 1
                end
            end
            
            UpdateLobbyUI()
            
            if readyPlayers >= Config.MIN_PLAYERS then
                StartCountdown()
            end
        end
    end
end)

-- ============================================
-- 🔄 PERFORMANCE: 중앙 집중식 회전 업데이트 루프
-- ============================================
RunService.Heartbeat:Connect(function(dt)
    -- 회전 오브젝트 업데이트 (회전바 등)
    for i = #RotatingObjects, 1, -1 do
        local obj = RotatingObjects[i]
        if obj.part and obj.part.Parent then
            obj.rotation = obj.rotation + obj.speed
            if obj.rotationType == "Y" then
                obj.part.CFrame = CFrame.new(obj.part.Position) * CFrame.Angles(0, math.rad(obj.rotation), 0)
            end
        else
            -- 파트가 삭제되면 테이블에서 제거
            table.remove(RotatingObjects, i)
        end
    end

    -- 아이템 박스 업데이트
    for i = #ItemBoxes, 1, -1 do
        local obj = ItemBoxes[i]
        if obj.part and obj.part.Parent then
            obj.rotation = obj.rotation + 2
            obj.part.CFrame = CFrame.new(obj.part.Position) * CFrame.Angles(0, math.rad(obj.rotation), math.rad(obj.rotation * 0.5))
        else
            -- 파트가 삭제되면 테이블에서 제거
            table.remove(ItemBoxes, i)
        end
    end
end)

-- ============================================
-- 🎮 ADMIN COMMANDS (코스 관리)
-- ============================================
Events.AdminCommand.OnServerEvent:Connect(function(player, command, ...)
    -- 관리자 권한 체크 (게임 소유자 또는 Admins 테이블에 등록된 유저)
    local isAdmin = player.UserId == game.CreatorId or table.find(Admins, player.UserId)
    if not isAdmin then
        warn(string.format("⚠️ Non-admin %s tried to use admin command: %s", player.Name, command))
        return
    end

    local args = {...}

    if command == "courses" or command == "list" then
        -- 사용 가능한 코스 목록
        local courses = CourseManager:GetAvailableCourses()
        local msg = "📚 Available Courses:\n"
        for _, c in ipairs(courses) do
            local current = (CourseManager.currentCourse and CourseManager.currentCourse.metadata.id == c.id) and " ◀ CURRENT" or ""
            msg = msg .. string.format("  • %s (%s) - %s%s\n", c.name, c.id, c.difficulty, current)
        end
        print(msg)
        -- 클라이언트에 알림 (옵션)
        Events.AdminCommand:FireClient(player, "CourseList", courses)

    elseif command == "setcourse" then
        -- 코스 변경: /setcourse classic 또는 /setcourse mycourse github
        local courseId = args[1]
        local source = args[2] or "library"

        if not courseId then
            Events.AdminCommand:FireClient(player, "Error", "Usage: setcourse <courseId> [library|github]")
            return
        end

        local success, name = ChangeCourse(courseId, source)
        if success then
            Events.AdminCommand:FireClient(player, "Success", "Course set to: " .. name)
            print(string.format("✅ Admin %s changed course to: %s", player.Name, name))
        else
            Events.AdminCommand:FireClient(player, "Error", "Failed to load course: " .. courseId)
        end

    elseif command == "rebuild" then
        -- 코스 즉시 재빌드
        RebuildCourse()
        Events.AdminCommand:FireClient(player, "Success", "Course rebuilt!")
        print(string.format("🔄 Admin %s rebuilt the course", player.Name))

    elseif command == "loadgithub" then
        -- GitHub에서 코스 로드: /loadgithub mycourse
        local courseId = args[1]
        if not courseId then
            Events.AdminCommand:FireClient(player, "Error", "Usage: loadgithub <courseId>")
            return
        end

        local courseData = CourseManager:LoadFromGitHub(courseId)
        if courseData then
            CourseManager.currentCourse = courseData
            Events.AdminCommand:FireClient(player, "Success", "Loaded from GitHub: " .. courseData.metadata.name)
            print(string.format("🌐 Admin %s loaded course from GitHub: %s", player.Name, courseData.metadata.name))
        else
            Events.AdminCommand:FireClient(player, "Error", "Failed to load from GitHub: " .. courseId)
        end

    elseif command == "courseinfo" then
        -- 현재 코스 정보 (미리보기용 기믹 데이터 포함)
        local course = CourseManager:GetCurrentCourse()
        if course then
            local info = {
                name = course.metadata.name,
                author = course.metadata.author,
                difficulty = course.metadata.difficulty,
                length = course.metadata.length,
                gimmickCount = #course.gimmicks,
                gimmicks = course.gimmicks  -- 미리보기용 전체 기믹 데이터
            }
            Events.AdminCommand:FireClient(player, "CourseInfo", info)
            print(string.format("📋 Current Course: %s by %s (%d gimmicks)",
                info.name, info.author, info.gimmickCount))
        end

    elseif command == "autosync" then
        -- GitHub 자동 동기화 토글
        local enabled = CourseManager:ToggleAutoSync()
        local status = enabled and "ENABLED" or "DISABLED"
        Events.AdminCommand:FireClient(player, "Success", "🔄 Auto-Sync: " .. status)
        print(string.format("🔄 Auto-Sync toggled by %s: %s", player.Name, status))

    elseif command == "syncnow" then
        -- 즉시 동기화 체크
        Events.AdminCommand:FireClient(player, "Success", "🔄 Checking for updates...")
        local hasUpdate, indexData = CourseManager:CheckForUpdates()
        if hasUpdate and indexData then
            local updatedCourses = CourseManager:ApplyUpdate(indexData)
            if #updatedCourses > 0 then
                local message = string.format("🔄 %d개 코스 업데이트됨: %s",
                    #updatedCourses, table.concat(updatedCourses, ", "))
                Events.AdminCommand:FireClient(player, "Success", message)
                CourseManager:NotifyAdmins(message, {courses = updatedCourses})
            else
                Events.AdminCommand:FireClient(player, "Success", "✅ 모든 코스가 최신 상태입니다")
            end
        else
            Events.AdminCommand:FireClient(player, "Success", "✅ 업데이트 없음 (최신 버전)")
        end

    elseif command == "autosyncstatus" then
        -- 자동 동기화 상태 확인
        local status = {
            enabled = CourseManager.autoSyncEnabled,
            isPolling = CourseManager.isPolling,
            interval = CourseManager.pollInterval,
            lastVersion = CourseManager.lastKnownVersion,
            lastChecked = CourseManager.lastCheckedTime
        }
        Events.AdminCommand:FireClient(player, "AutoSyncStatus", status)

    elseif command == "getconfig" then
        -- 현재 설정 가져오기
        local configData = {
            -- 게임 설정
            MIN_PLAYERS = Config.MIN_PLAYERS,
            MAX_PLAYERS = Config.MAX_PLAYERS,
            LOBBY_COUNTDOWN = Config.LOBBY_COUNTDOWN,
            INTERMISSION = Config.INTERMISSION,

            -- 장애물 토글
            EnableRotatingBars = Config.EnableRotatingBars,
            EnableJumpPads = Config.EnableJumpPads,
            EnableSlime = Config.EnableSlime,
            EnablePunchingGloves = Config.EnablePunchingGloves,
            EnableQuizGates = Config.EnableQuizGates,
            EnableElevators = Config.EnableElevators,
            EnableDisappearingBridge = Config.EnableDisappearingBridge,
            EnableConveyorBelt = Config.EnableConveyorBelt,
            EnableElectricFloor = Config.EnableElectricFloor,
            EnableRollingBoulder = Config.EnableRollingBoulder,

            -- 밸런스
            ObstacleSpeed = Config.ObstacleSpeed,
            SlimeSlowFactor = Config.SlimeSlowFactor,
        }
        Events.AdminCommand:FireClient(player, "ConfigData", configData)

    elseif command == "setconfig" then
        -- 설정 변경
        local key = args[1]
        local value = args[2]

        if not key then
            Events.AdminCommand:FireClient(player, "Error", "Usage: setconfig <key> <value>")
            return
        end

        -- 허용된 설정 키 목록
        local allowedKeys = {
            "MIN_PLAYERS", "MAX_PLAYERS", "LOBBY_COUNTDOWN", "INTERMISSION",
            "EnableRotatingBars", "EnableJumpPads", "EnableSlime", "EnablePunchingGloves",
            "EnableQuizGates", "EnableElevators", "EnableDisappearingBridge",
            "EnableConveyorBelt", "EnableElectricFloor", "EnableRollingBoulder",
            "ObstacleSpeed", "SlimeSlowFactor"
        }

        if not table.find(allowedKeys, key) then
            Events.AdminCommand:FireClient(player, "Error", "Invalid config key: " .. key)
            return
        end

        -- 타입 변환
        local oldValue = Config[key]
        local newValue

        if type(oldValue) == "boolean" then
            newValue = (value == "true" or value == "1" or value == true)
        elseif type(oldValue) == "number" then
            newValue = tonumber(value)
            if not newValue then
                Events.AdminCommand:FireClient(player, "Error", "Invalid number value")
                return
            end
        else
            newValue = value
        end

        -- 값 적용
        Config[key] = newValue

        Events.AdminCommand:FireClient(player, "Success",
            string.format("Config changed: %s = %s (was %s)", key, tostring(newValue), tostring(oldValue)))
        print(string.format("⚙️ Admin %s changed config: %s = %s", player.Name, key, tostring(newValue)))

        -- 모든 클라이언트에 설정 업데이트 알림
        Events.ConfigUpdate:FireAllClients(key, newValue)

    elseif command == "getplayers" then
        -- 플레이어 목록 가져오기
        local playerList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local data = PlayerData[p]
            local isRacing = table.find(GameState.playersInRace, p) ~= nil
            local hasFinished = table.find(GameState.finishedPlayers, p) ~= nil

            table.insert(playerList, {
                name = p.Name,
                odisplayName = p.DisplayName,
                userId = p.UserId,
                level = data and data.level or 1,
                xp = data and data.xp or 0,
                wins = data and data.wins or 0,
                bestTime = data and data.bestTime or 0,
                currentItem = data and data.currentItem or nil,
                isRacing = isRacing,
                hasFinished = hasFinished,
                isAdmin = p.UserId == game.CreatorId or table.find(Admins, p.UserId) ~= nil
            })
        end
        Events.AdminCommand:FireClient(player, "PlayerList", playerList)

    elseif command == "kickplayer" then
        -- 플레이어 추방
        local targetName = args[1]
        local reason = args[2] or "Kicked by admin"

        if not targetName then
            Events.AdminCommand:FireClient(player, "Error", "Usage: kickplayer <name> [reason]")
            return
        end

        local targetPlayer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                targetPlayer = p
                break
            end
        end

        if not targetPlayer then
            Events.AdminCommand:FireClient(player, "Error", "Player not found: " .. targetName)
            return
        end

        if targetPlayer == player then
            Events.AdminCommand:FireClient(player, "Error", "Cannot kick yourself!")
            return
        end

        targetPlayer:Kick(reason)
        Events.AdminCommand:FireClient(player, "Success", "Kicked: " .. targetPlayer.Name)
        print(string.format("🚫 Admin %s kicked %s (reason: %s)", player.Name, targetPlayer.Name, reason))

    elseif command == "teleportplayer" then
        -- 플레이어 텔레포트
        local targetName = args[1]
        local destination = args[2] -- "lobby", "race", "tome" (to me)

        if not targetName or not destination then
            Events.AdminCommand:FireClient(player, "Error", "Usage: teleportplayer <name> <lobby|race|tome>")
            return
        end

        local targetPlayer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                targetPlayer = p
                break
            end
        end

        if not targetPlayer then
            Events.AdminCommand:FireClient(player, "Error", "Player not found: " .. targetName)
            return
        end

        local char = targetPlayer.Character
        if not char then
            Events.AdminCommand:FireClient(player, "Error", "Player has no character")
            return
        end

        local rp = char:FindFirstChild("HumanoidRootPart")
        if not rp then
            Events.AdminCommand:FireClient(player, "Error", "Player HumanoidRootPart not found")
            return
        end

        if destination == "lobby" then
            if LobbySpawn then
                rp.CFrame = LobbySpawn.CFrame + Vector3.new(0, 3, 0)
                Events.AdminCommand:FireClient(player, "Success", targetPlayer.Name .. " teleported to lobby")
            end
        elseif destination == "race" then
            if RaceSpawn then
                rp.CFrame = RaceSpawn.CFrame + Vector3.new(0, 3, 0)
                Events.AdminCommand:FireClient(player, "Success", targetPlayer.Name .. " teleported to race start")
            end
        elseif destination == "tome" then
            local adminChar = player.Character
            if adminChar then
                local adminRp = adminChar:FindFirstChild("HumanoidRootPart")
                if adminRp then
                    rp.CFrame = adminRp.CFrame + Vector3.new(3, 0, 0)
                    Events.AdminCommand:FireClient(player, "Success", targetPlayer.Name .. " teleported to you")
                end
            end
        else
            Events.AdminCommand:FireClient(player, "Error", "Invalid destination. Use: lobby, race, tome")
        end

    elseif command == "giveitem" then
        -- 아이템 지급
        local targetName = args[1]
        local itemType = args[2]

        local validItems = {"Booster", "Shield", "Banana", "Lightning"}

        if not targetName or not itemType then
            Events.AdminCommand:FireClient(player, "Error", "Usage: giveitem <name> <Booster|Shield|Banana|Lightning>")
            return
        end

        if not table.find(validItems, itemType) then
            Events.AdminCommand:FireClient(player, "Error", "Invalid item. Use: Booster, Shield, Banana, Lightning")
            return
        end

        local targetPlayer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                targetPlayer = p
                break
            end
        end

        if not targetPlayer then
            Events.AdminCommand:FireClient(player, "Error", "Player not found: " .. targetName)
            return
        end

        if PlayerData[targetPlayer] then
            PlayerData[targetPlayer].currentItem = itemType
            Events.ItemEffect:FireClient(targetPlayer, "GotItem", {itemType = itemType})
            Events.AdminCommand:FireClient(player, "Success", "Gave " .. itemType .. " to " .. targetPlayer.Name)
        end

    elseif command == "givexp" then
        -- XP 지급
        local targetName = args[1]
        local amount = tonumber(args[2])

        if not targetName or not amount then
            Events.AdminCommand:FireClient(player, "Error", "Usage: givexp <name> <amount>")
            return
        end

        local targetPlayer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                targetPlayer = p
                break
            end
        end

        if not targetPlayer then
            Events.AdminCommand:FireClient(player, "Error", "Player not found: " .. targetName)
            return
        end

        if PlayerData[targetPlayer] then
            local oldXP = PlayerData[targetPlayer].xp
            PlayerData[targetPlayer].xp = oldXP + amount

            -- Check for level up
            local newLevel = 1
            for lvl = 10, 1, -1 do
                if PlayerData[targetPlayer].xp >= LevelConfig[lvl].xp then
                    newLevel = lvl
                    break
                end
            end

            local oldLevel = PlayerData[targetPlayer].level
            PlayerData[targetPlayer].level = newLevel

            local progress, xpInLevel, xpNeeded = GetLevelProgress(PlayerData[targetPlayer].xp, newLevel)
            Events.XPUpdate:FireClient(targetPlayer, {
                xp = PlayerData[targetPlayer].xp,
                xpGained = amount,
                reason = "Admin",
                level = newLevel,
                levelName = LevelConfig[newLevel].name,
                levelIcon = LevelConfig[newLevel].icon,
                trailType = LevelConfig[newLevel].trailType,
                progress = progress,
                xpInLevel = xpInLevel,
                xpNeeded = xpNeeded
            })

            if newLevel > oldLevel then
                Events.LevelUp:FireClient(targetPlayer, {
                    newLevel = newLevel,
                    levelName = LevelConfig[newLevel].name,
                    icon = LevelConfig[newLevel].icon
                })
            end

            Events.AdminCommand:FireClient(player, "Success",
                string.format("Gave %d XP to %s (now %d XP, Lv.%d)", amount, targetPlayer.Name, PlayerData[targetPlayer].xp, newLevel))
        end

    elseif command == "setlevel" then
        -- 레벨 설정
        local targetName = args[1]
        local level = tonumber(args[2])

        if not targetName or not level or level < 1 or level > 10 then
            Events.AdminCommand:FireClient(player, "Error", "Usage: setlevel <name> <1-10>")
            return
        end

        local targetPlayer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                targetPlayer = p
                break
            end
        end

        if not targetPlayer then
            Events.AdminCommand:FireClient(player, "Error", "Player not found: " .. targetName)
            return
        end

        if PlayerData[targetPlayer] then
            PlayerData[targetPlayer].level = level
            PlayerData[targetPlayer].xp = LevelConfig[level].xp

            local progress, xpInLevel, xpNeeded = GetLevelProgress(PlayerData[targetPlayer].xp, level)
            Events.XPUpdate:FireClient(targetPlayer, {
                xp = PlayerData[targetPlayer].xp,
                xpGained = 0,
                reason = "Admin Set Level",
                level = level,
                levelName = LevelConfig[level].name,
                levelIcon = LevelConfig[level].icon,
                trailType = LevelConfig[level].trailType,
                progress = progress,
                xpInLevel = xpInLevel,
                xpNeeded = xpNeeded
            })

            Events.LevelUp:FireClient(targetPlayer, {
                newLevel = level,
                levelName = LevelConfig[level].name,
                icon = LevelConfig[level].icon
            })

            Events.AdminCommand:FireClient(player, "Success",
                string.format("Set %s to Level %d (%s)", targetPlayer.Name, level, LevelConfig[level].name))
        end

    elseif command == "heal" then
        -- 플레이어 힐
        local targetName = args[1]

        if not targetName then
            Events.AdminCommand:FireClient(player, "Error", "Usage: heal <name|all>")
            return
        end

        local targets = {}
        if targetName:lower() == "all" then
            targets = Players:GetPlayers()
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
                    table.insert(targets, p)
                    break
                end
            end
        end

        if #targets == 0 then
            Events.AdminCommand:FireClient(player, "Error", "Player not found: " .. targetName)
            return
        end

        for _, targetPlayer in ipairs(targets) do
            local char = targetPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end

        Events.AdminCommand:FireClient(player, "Success", "Healed " .. #targets .. " player(s)")
    end
end)

-- ============================================
-- 🚀 INITIALIZE
-- ============================================

-- 1. CourseLibrary 로드
CourseManager:LoadLibrary()

-- 2. GitHub Auto-Sync 시작
CourseManager:StartAutoSync()

-- 3. 맵 초기화
InitializeMap()

print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🏰 QUIZ CASTLE v3.2 Server Ready!")
print("⭐ XP & Level System Active!")
print("📚 Course Manager Active!")
print("🎮 Min Players: " .. Config.MIN_PLAYERS)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")
print("📚 Admin Commands:")
print("  • courses - List available courses")
print("  • setcourse <id> [library|github] - Change course")
print("  • loadgithub <id> - Load course from GitHub")
print("  • rebuild - Rebuild current course")
print("  • courseinfo - Show current course info")
print("  • autosync - Toggle GitHub auto-sync")
print("  • syncnow - Force sync check now")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔄 Auto-Sync: ENABLED (every 30s)")
